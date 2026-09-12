class_name Sc2ImportSource
extends RefCounted
## Discover assets by file contents and record names, not a release hash list.

const MAX_FILE_BYTES := 64 * 1024 * 1024
const MAX_FILES := 20000
const MAX_DEPTH := 12
const MAX_SOURCE_BYTES := 256 * 1024 * 1024

var platform := "Unknown platform"
var resources: Array[Sc2ImportResource] = []
var warnings := PackedStringArray()
var error := ""
var root := ""
var _files := PackedStringArray()
var _platforms: Dictionary[String, bool] = {}
var _bytes_read := 0
var _network := false


static func scan(path: String) -> Sc2ImportSource:
	var source := Sc2ImportSource.new()
	var selected := ProjectSettings.globalize_path(path).simplify_path()

	if FileAccess.file_exists(selected):
		if selected.get_extension().to_lower() in ["pkg", "dmg", "iso", "zip", "7z", "rar"]:
			source.error = "Install the game or extract its files first. For GOG, select the installed game folder or macOS .app instead of the installer."
			return source

		var selected_file := FileAccess.open(selected, FileAccess.READ)

		if selected_file != null and selected_file.get_length() > MAX_FILE_BYTES:
			source.error = "This file exceeds the import size limit. Install the game or extract its files first, then select its game folder or macOS .app."
			return source

		source.root = selected.get_base_dir()
		source._files.append(selected)
		source._list(source.root, 0)
	elif DirAccess.dir_exists_absolute(selected):
		source.root = selected
		source._list(selected, 0)
	else:
		source.error = "Select an existing game folder or asset file."
		return source

	var visited: Dictionary[String, bool] = {}

	for file in source._files:
		if source._bytes_read >= MAX_SOURCE_BYTES:
			source.warnings.append("The asset scan reached its memory limit. Select one game's folder to include the remaining files.")
			break

		if visited.has(file):
			continue

		visited[file] = true
		source._read(file, file == selected)

	if source._platforms.size() == 1:
		source.platform = source._platforms.keys()[0]
	elif source._platforms.size() > 1:
		source.error = "This folder contains assets from multiple platforms (%s). Select one game's folder." % ", ".join(source._platforms.keys())
	elif not source.resources.is_empty():
		# Loose standard media is useful even when its original executable is gone.
		source.platform = "Unidentified SC2K"

	if source.platform == "Windows" and source._network:
		source.platform = "Windows Network Edition"

	if source.resources.is_empty() and source.error.is_empty():
		source.error = "No readable SC2K assets were found. Select the extracted game files, not an installer or an unopened disc image."

	return source


func _list(folder: String, depth: int) -> void:
	if depth > MAX_DEPTH or _files.size() >= MAX_FILES:
		warnings.append("The folder scan reached its limit. Select a smaller game folder to include the remaining files.")
		return

	var directory := DirAccess.open(folder)

	if directory == null:
		warnings.append("Cannot read folder: " + folder.get_file())
		return

	directory.include_hidden = true
	var files := directory.get_files()
	files.sort()

	for name in files:
		if not directory.is_link(name):
			_files.append(folder.path_join(name))

		if _files.size() >= MAX_FILES:
			warnings.append("The folder contains too many files. Select one game's folder.")
			return

	var folders := directory.get_directories()
	folders.sort()

	for name in folders:
		if not name.begins_with(".") and not directory.is_link(name):
			_list(folder.path_join(name), depth + 1)


func _read(path: String, explicitly_selected: bool) -> void:
	var name := path.get_file()
	var upper := name.to_upper()
	var extension := name.get_extension().to_lower()
	var resource_fork := extension == "rsrc" or name.begins_with("._")
	var executable := extension in ["exe", "dll", "wad"]
	var mac_candidate := extension == "bin" or upper.contains("SIMCITY") or upper.contains("SIM CITY")
	var loose := extension in ["wav", "mid", "midi", "xmi", "voc", "bmp", "pal", "dat", "idx", "mif", "hed", "bin", "raw", "rsc", "spr", "scl", "db"]

	if not explicitly_selected and not resource_fork and not executable and not loose and not mac_candidate:
		return

	var file := FileAccess.open(path, FileAccess.READ)

	if file == null:
		warnings.append("Cannot read " + name)
		return

	if file.get_length() > MAX_FILE_BYTES or _bytes_read + file.get_length() > MAX_SOURCE_BYTES:
		warnings.append("Skipped large container %s. Select its extracted files." % name)
		return

	var bytes := file.get_buffer(file.get_length())
	_bytes_read += bytes.size()

	if resource_fork or (bytes.size() >= 4 and Sc2ImportContainer.be32(bytes, 0) in [0x00051607, 0x00051600]):
		_accept(Sc2ImportContainer.macintosh(bytes, path), "Macintosh", name)
		return

	if bytes.slice(0, 2).get_string_from_ascii() == "MZ":
		var parsed := Sc2ImportContainer.windows(bytes, path)

		if parsed.error.is_empty():
			_network = _network or upper == "2KCLIENT.EXE"

			var header := int(bytes.decode_u32(60))
			var family := "Windows 3.x" if bytes.slice(header, header + 2).get_string_from_ascii() == "NE" else "Windows"

			var game_program := upper.contains("SC2000") or upper.contains("SC2K") or upper.contains("SIMCITY") or upper in ["SIMDEMO.EXE", "2KCLIENT.EXE"]

			for resource in parsed.resources:
				if resource.type == "2" and resource.id in [178, 247]:
					game_program = true

			# Setup programs and support DLLs can use a different Windows ABI.
			# Their resource tables alone must not mark a second game platform.
			_accept(parsed, family if game_program else "", name)
		elif explicitly_selected and upper not in ["SC2000.EXE", "SC2K.EXE"]:
			warnings.append(name + ": " + parsed.error)

		return

	if upper == "SC2000.DAT":
		var parsed := Sc2ImportContainer.named_archive(bytes, path)
		_accept(parsed, "DOS", name)
		return

	if (explicitly_selected or mac_candidate) and (not loose or extension == "bin"):
		var parsed := Sc2ImportContainer.macintosh(bytes, path)

		if parsed.error.is_empty():
			_accept(parsed, "Macintosh", name)
			return

		var fork_path := path.path_join("..namedfork/rsrc")

		if FileAccess.file_exists(fork_path):
			var fork := FileAccess.open(fork_path, FileAccess.READ)

			if fork != null and fork.get_length() <= MAX_FILE_BYTES and _bytes_read + fork.get_length() <= MAX_SOURCE_BYTES:
				var fork_bytes := fork.get_buffer(fork.get_length())
				_bytes_read += fork_bytes.size()
				_accept(Sc2ImportContainer.macintosh(fork_bytes, fork_path), "Macintosh", name)
			else:
				warnings.append("Cannot read the resource fork for " + name)

			return

	if loose:
		resources.append(Sc2ImportResource.make(upper, bytes, path))


func _accept(parsed: Sc2ImportContainer, family: String, name: String) -> void:
	if not parsed.error.is_empty():
		warnings.append(name + ": " + parsed.error)
		return

	if not parsed.resources.is_empty():
		if not family.is_empty():
			_platforms[family] = true

		resources.append_array(parsed.resources)
