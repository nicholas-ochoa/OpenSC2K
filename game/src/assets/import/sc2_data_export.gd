class_name Sc2DataExport
extends RefCounted
## Copy the original game data files into a data pack. Keep complete text files
## so that new game features can use them without a new import. Never copy an executable.

const CITY_HEADER := "FORM"
const CITY_TYPE := "SCDH"
const MAX_FOLDER_DEPTH := 4
# WINSCURK.EXE opens this file. It is not a sample city, and New City does not use it.
const SCURK_TEMPLATE_FILE := "DEFAULT.SC2"

var error := ""
var count := 0
var warnings := PackedStringArray()


# a Windows folder already has the data files
func export_pack(source: String, folder: String, pack_name: String, platform := "") -> void:
	# The pack keeps the documented names. The source names can use a different case.
	var files: Dictionary[String, String] = {}

	for relative: String in DataPack.REQUIRED_FILES:
		files[relative] = Sc2ImportPath.resolve(source, relative)

	for relative: String in DataPack.NEWSPAPER_FILES:
		var path := Sc2ImportPath.find_file(source, relative)

		if not path.is_empty():
			files[relative] = path

	for pair in DataPack.FOLDERS:
		var found := Sc2ImportPath.find(source, pair[0])
		var names := PackedStringArray()

		if not found.is_empty():
			OriginalCityImporter._collect(found, "", pair[1], names)

		for name in names:
			files[str(pair[0]).path_join(Sc2ImportPath.original_name(name))] = found.path_join(name)

	for relative in files:
		var bytes := FileAccess.get_file_as_bytes(files[relative])

		if bytes.is_empty():
			error = "Cannot import " + relative

			return

		_write(folder.path_join(relative), bytes)

		if not error.is_empty():
			return

	_finish(folder, pack_name, platform)


# DOS and Macintosh games keep the text and newspaper records inside a container.
# Windows demos keep them in renamed or loose files.
func export_records(source: Sc2ImportSource, folder: String, pack_name: String) -> void:
	var records := Sc2DataConvert.find_records(source)

	if not records.text.has(OriginalGameAssets.CREDITS_TEXT_RESOURCE_ID):
		error = "No text records were found."
		return

	var text_files := Sc2DataConvert.resource_files(records.text)
	_write(folder.path_join(DataPack.REQUIRED_FILES[0]), text_files[0])
	_write(folder.path_join(DataPack.REQUIRED_FILES[1]), text_files[1])
	var newspaper := Sc2DataConvert.windows_newspaper(records.newspaper)

	if records.newspaper.is_empty():
		warnings.append("This version has no newspaper data.")
	elif newspaper.is_empty():
		warnings.append("This version has newspaper data in an earlier format that the game cannot use.")
	else:
		var newspaper_files := Sc2DataConvert.resource_files(newspaper)
		_write(folder.path_join(DataPack.NEWSPAPER_FILES[0]), newspaper_files[0])
		_write(folder.path_join(DataPack.NEWSPAPER_FILES[1]), newspaper_files[1])

	for library_id: int in LibraryRuminateWindows.TEXT_RESOURCE_IDS:
		if not records.text.has(library_id):
			warnings.append("This version has no Library text %d." % library_id)

	_copy_city_folders(source.root, folder, 0)

	if error.is_empty():
		_finish(folder, pack_name, source.platform)


# Copy city, scenario, and SCURK files from the folders of those names, and the demo city
# beside a demo. A Macintosh city has no file extension, so the city header identifies it.
# A Macintosh scenario has a resource fork beside it and goes in no folder.
func _copy_city_folders(path: String, folder: String, depth: int) -> void:
	var directory := DirAccess.open(path)

	if directory == null or depth > MAX_FOLDER_DEPTH:
		return

	var targets := {}

	for pair in DataPack.FOLDERS:
		targets[pair[0]] = pair[1]

	var target := Sc2ImportPath.key(path.get_file())

	if depth == 0:
		for name in directory.get_files():
			var bytes := FileAccess.get_file_as_bytes(path.path_join(name)) if _is_city_name(path, name) else PackedByteArray()

			if _is_city(bytes):
				var file_name := Sc2ImportPath.original_name(name)
				_write_city(folder, "CITIES", file_name if not file_name.get_extension().is_empty() else file_name + ".SC2", bytes)
	elif targets.has(target):
		var names := directory.get_files()
		names.sort()

		for name in names:
			var extension := Sc2ImportPath.key(name).get_extension().to_lower()

			if extension == "rsrc" or directory.is_link(name):
				continue

			var bytes := FileAccess.get_file_as_bytes(path.path_join(name))

			if extension == targets[target] or (target == "CITIES" and extension.is_empty() and _is_city(bytes)):
				var file_name := Sc2ImportPath.original_name(name)
				_write_city(folder, target, file_name if not extension.is_empty() else file_name + "." + str(targets[target]).to_upper(), bytes)

				if not error.is_empty():
					return

	for name in directory.get_directories():
		if not name.begins_with(".") and not directory.is_link(name):
			_copy_city_folders(path.path_join(name), folder, depth + 1)


func _is_city_name(path: String, name: String) -> bool:
	var extension := Sc2ImportPath.key(name).get_extension().to_lower()

	if Sc2ImportPath.key(name) == SCURK_TEMPLATE_FILE:
		return false

	return extension == "sc2" or (extension.is_empty() and not FileAccess.file_exists(path.path_join(name + ".rsrc")))


func _is_city(bytes: PackedByteArray) -> bool:
	return (bytes.size() >= 12 and bytes.slice(0, 4).get_string_from_ascii() == CITY_HEADER
		and bytes.slice(8, 12).get_string_from_ascii() == CITY_TYPE)


func _write_city(folder: String, target: String, file_name: String, bytes: PackedByteArray) -> void:
	var destination := folder.path_join(target).path_join(file_name.validate_filename())

	if not FileAccess.file_exists(destination):
		_write(destination, bytes)


func _finish(folder: String, pack_name: String, platform: String) -> void:
	var manifest := { "format": DataPack.FORMAT, "version": 1, "name": pack_name }

	if not platform.is_empty():
		manifest.source_platform = platform

	ImportedPackRevision.stamp("data", manifest)
	error = Sc2MediaImporter._write(folder.path_join("pack.json"), JSON.stringify(manifest, "\t").to_utf8_buffer())

	if error.is_empty():
		error = DataPack.load_folder(folder).error


func _write(path: String, bytes: PackedByteArray) -> void:
	if not error.is_empty():
		return

	error = Sc2MediaImporter._write(path, bytes)

	if error.is_empty():
		count += 1
