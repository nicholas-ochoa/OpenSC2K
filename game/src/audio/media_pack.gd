class_name MediaPack
extends RefCounted

var error := ""
var pack_name := ""
var import_revision := ImportedPackRevision.NOT_IMPORTED
var files: Dictionary = {}


static func default_folder(kind: String) -> String:
	return AppPaths.path("packs").path_join(kind)


static func load_folder(folder: String, kind: String) -> MediaPack:
	var pack := MediaPack.new()
	var automatic := folder.strip_edges().is_empty()
	var root := default_folder(kind) if automatic else folder.strip_edges()

	if root.get_file() == "pack.json":
		root = root.get_base_dir()

	var path := root.path_join("pack.json")

	if automatic and not FileAccess.file_exists(path):
		return pack

	if not FileAccess.file_exists(path):
		pack.error = "Cannot read %s pack.json: %s" % [kind, root]

		return pack

	# the native library checks the manifest; see native/core/assets/src/packs/media.rs.
	# the files before a manifest problem still decode first, in manifest order
	var manifest := NativePacks.media_manifest(FileAccess.get_file_as_string(path), kind, root)
	pack.pack_name = manifest.name
	pack.import_revision = manifest.revision
	var ids: PackedInt64Array = manifest.ids
	var paths: PackedStringArray = manifest.paths

	for index in ids.size():
		var full := paths[index]

		if kind == "sound" and AudioStreamWAV.load_from_file(full) == null:
			pack.error = "Cannot decode sound: " + full

			return pack

		if full.get_extension().to_lower() in ["mid", "midi"]:
			var midi := StandardMidiFile.load_path(full)

			if not midi.parse_error.is_empty():
				pack.error = "Cannot decode MIDI: " + full

				return pack

		pack.files[ids[index]] = full

	pack.error = manifest.error

	return pack
