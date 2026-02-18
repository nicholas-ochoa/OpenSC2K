class_name MediaPack
extends RefCounted


var error := ""
var pack_name := ""
var files: Dictionary = {}

static func default_folder(kind: String) -> String:
	var base := ProjectSettings.globalize_path("res://..").simplify_path() if OS.has_feature("editor") else OS.get_executable_path().get_base_dir()
	return base.path_join("ext/" + kind)

static func load_folder(folder: String, kind: String) -> MediaPack:
	var pack := MediaPack.new()
	var automatic := folder.strip_edges().is_empty()
	var root := default_folder(kind) if automatic else folder.strip_edges()
	if root.get_file() == "pack.json":
		root = root.get_base_dir()
	var path := root.path_join("pack.json")
	if automatic and not FileAccess.file_exists(path):
		return pack
	var json := JSON.new()
	if not FileAccess.file_exists(path) or json.parse(FileAccess.get_file_as_string(path)) != OK or not json.data is Dictionary:
		pack.error = "Cannot read %s pack.json: %s" % [kind, root]
		return pack
	var data: Dictionary = json.data
	if data.get("format") != "opensc2k-" + kind or data.get("version") != 1 or not data.get("name") is String or str(data.name).strip_edges().is_empty() or not data.get("files") is Dictionary:
		pack.error = "Invalid %s manifest format, version, name, or files" % kind
		return pack
	pack.pack_name = data.name
	for key in data.files:
		var first := 500 if kind == "sound" else 10000
		var last := 529 if kind == "sound" else 10018
		var value: Variant = data.files[key]
		if not str(key).is_valid_int() or str(int(key)) != key or int(key) < first or int(key) > last or not value is String:
			pack.error = "Invalid %s resource ID or path: %s" % [kind, key]
			return pack
		var relative: String = value
		if relative.is_absolute_path() or relative.contains(":") or relative.contains("\\") or relative.is_empty():
			pack.error = "Media paths must be relative and use forward slashes"
			return pack
		for part in relative.split("/"):
			if part in ["", ".", ".."]:
				pack.error = "Media paths cannot contain empty, dot, or parent components"
				return pack
		var extensions := ["wav"] if kind == "sound" else ["mid", "midi", "wav", "ogg", "mp3", "flac"]
		var full := root.path_join(relative)
		if relative.get_extension().to_lower() not in extensions or not FileAccess.file_exists(full):
			pack.error = "Missing or unsupported media file: " + full
			return pack
		if kind == "sound" and AudioStreamWAV.load_from_file(full) == null:
			pack.error = "Cannot decode sound: " + full
			return pack
		if relative.get_extension().to_lower() in ["mid", "midi"]:
			var midi := StandardMidiFile.load_path(full)
			if not midi.parse_error.is_empty():
				pack.error = "Cannot decode MIDI: " + full
				return pack
		pack.files[int(key)] = full
	return pack
