extends SceneTree
## Import a Windows install whose names differ in case from the documented names,
## from a game disc that holds more than one version.

const ImportedAssetChecks = preload("res://tests/support/imported_asset_checks.gd")


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	_test_names()
	var folder := ProjectSettings.globalize_path("user://sc2-import-disc-test-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()])
	var reference := ProjectSettings.globalize_path("res://../references/SIMCITY2000")
	var disc := folder.path_join("disc")
	_test_find(folder.path_join("find"))

	# A Linux mount without name mapping shows each ISO 9660 file name with a version suffix.
	# Some file systems also show lowercase names. A version suffix makes each name differ from the
	# documented name on a file system that ignores case too.
	_copy_renamed(reference, disc.path_join("win95/sc2k"))
	assert(DirAccess.make_dir_recursive_absolute(disc.path_join("dos")) == OK)
	_store(disc.path_join("dos/sc2000.dat;1"), _archive({ "TXT128": "Credits".to_ascii_buffer() }))

	var imported := Sc2MediaImporter.import_assets(disc, folder.path_join("packs"), PackedStringArray(["graphics", "data"]))
	assert(imported.ok and imported.failures.is_empty(), imported.summary())
	assert(imported.platform == "Windows", imported.platform)
	assert(imported.notes[0].contains("more than one version (") and imported.notes[0].contains("DOS"))
	assert(not imported.partial, imported.summary())

	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(imported.graphics))

	for group in ["city_ui", "desktop", "scurk"]:
		assert(manifest.has(group), group)

	var selected := GameAssetSource.load_source("", "folder", imported.graphics)
	assert(selected.error.is_empty(), selected.error)
	ImportedAssetChecks.check(reference, imported.graphics.get_base_dir(), selected.assets)

	# The data pack uses the documented names. City names keep their case without the version suffix.
	var pack := DataPack.load_folder(imported.data)
	assert(pack.is_loaded() and not FileAccess.file_exists(pack.root.path_join("DEFAULT.SC2")), pack.error)
	var expected := OriginalGameAssets.new()
	expected.load_text_data(reference)
	assert(pack.text.original_credits == expected.original_credits)
	assert(pack.text.newspaper_data.grammar == expected.newspaper_data.grammar)

	for relative in DataPack.REQUIRED_FILES + DataPack.NEWSPAPER_FILES:
		assert(FileAccess.get_sha256(pack.root.path_join(relative)) == FileAccess.get_sha256(reference.path_join(relative)), relative)

	for pair in DataPack.FOLDERS:
		var copied := PackedStringArray()
		var original := PackedStringArray()
		OriginalCityImporter._collect(pack.root, pair[0], pair[1], copied)
		OriginalCityImporter._collect(reference, pair[0], pair[1], original)
		assert(not copied.is_empty() and copied.size() == original.size(), pair[0])
		assert(str(pair[0]).path_join(original[0].trim_prefix(pair[0] + "/").to_lower()) in copied, original[0])

	# A disc image file must be mounted first.
	_store(folder.path_join("game.iso"), PackedByteArray([0]))
	assert(Sc2ImportSource.scan(folder.path_join("game.iso")).error.begins_with("Mount the disc image"))

	assert(OriginalGameInstaller.remove_tree(folder) == OK)
	print("PASS: case-insensitive install files, ISO 9660 version suffixes, and version choice on a multi-version disc")
	quit()


func _test_names() -> void:
	assert(Sc2ImportPath.key("simcity.exe;1") == "SIMCITY.EXE")
	assert(Sc2ImportPath.key("Readme.") == "README")
	assert(Sc2ImportPath.original_name("My City.sc2;1") == "My City.sc2")
	assert(Sc2ImportPath.original_name("a;b") == "a;b")


func _test_find(root: String) -> void:
	assert(DirAccess.make_dir_recursive_absolute(root.path_join("Data/Sub")) == OK)
	_store(root.path_join("Data/text_usa.dat;1"), PackedByteArray([1]))
	# A file system that ignores case can keep the requested case of a folder name.
	assert(Sc2ImportPath.find_file(root, "DATA/TEXT_USA.DAT").get_file() == "text_usa.dat;1")
	assert(DirAccess.dir_exists_absolute(Sc2ImportPath.find(root, "DATA/SUB")))
	assert(Sc2ImportPath.find_file(root, "DATA/SUB").is_empty())
	assert(Sc2ImportPath.find(root, "DATA/MISSING.DAT").is_empty())
	assert(Sc2ImportPath.resolve(root, "DATA/MISSING.DAT") == root.path_join("DATA/MISSING.DAT"))


# copy a folder with lowercase names. Add a version suffix to each file name.
func _copy_renamed(source: String, destination: String) -> void:
	assert(DirAccess.make_dir_recursive_absolute(destination) == OK)

	for name in DirAccess.get_files_at(source):
		assert(DirAccess.copy_absolute(source.path_join(name), destination.path_join(name.to_lower() + ";1")) == OK)

	for name in DirAccess.get_directories_at(source):
		_copy_renamed(source.path_join(name), destination.path_join(name.to_lower()))


# the DOS SC2000.DAT directory: a 12-byte name and an offset for each record
func _archive(files: Dictionary) -> PackedByteArray:
	var archive := PackedByteArray()
	archive.resize(files.size() * 16)
	var record := 0

	for name: String in files:
		var text := name.to_ascii_buffer()

		for index in text.size():
			archive[record * 16 + index] = text[index]

		archive.encode_u32(record * 16 + 12, archive.size())
		archive.append_array(files[name])
		record += 1

	return archive


func _store(path: String, bytes: PackedByteArray) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(bytes)
	file.close()
