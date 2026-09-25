class_name Sc2DataExport
extends RefCounted
## Copy the original game data files into a data pack. Keep complete text files
## so that new game features can use them without a new import. Never copy an executable.

var error := ""
var count := 0


func export_pack(source: String, folder: String, pack_name: String, platform := "") -> void:
	var files := PackedStringArray(DataPack.REQUIRED_FILES)

	for pair in DataPack.FOLDERS:
		OriginalCityImporter._collect(source, pair[0], pair[1], files)

	for relative in files:
		var bytes := FileAccess.get_file_as_bytes(source.path_join(relative))

		if bytes.is_empty():
			error = "Cannot import " + relative

			return

		error = Sc2MediaImporter._write(folder.path_join(relative), bytes)

		if not error.is_empty():
			return

		count += 1

	var manifest := {"format": DataPack.FORMAT, "version": 1, "name": pack_name}

	if not platform.is_empty():
		manifest.source_platform = platform

	ImportedPackRevision.stamp("data", manifest)
	error = Sc2MediaImporter._write(folder.path_join("pack.json"), JSON.stringify(manifest, "\t").to_utf8_buffer())

	if error.is_empty():
		error = DataPack.load_folder(folder).error
