class_name GameAssetSource
extends RefCounted
# load imported packs without access to the original installation

const MODES := ["auto", "original", "folder"]
var assets: OriginalGameAssets
var has_city_template := false
var uses_graphics_pack := false
var graphics_name := ""
var error := ""
var reference_root := ""
var warnings := PackedStringArray()


static func default_reference_root() -> String:
	return MediaPack.default_folder("graphics").path_join("runtime")


static func load_source(_base_root: String, mode: String, folder := "", override_folder := "") -> GameAssetSource:
	var result := GameAssetSource.new()


	if mode not in MODES:
		result.error = "Unknown graphics source: %s" % mode

		return result

	var pack_root := override_folder

	if pack_root.is_empty():
		pack_root = folder if mode == "folder" else MediaPack.default_folder("graphics")

	if pack_root.get_file() == "pack.json":
		pack_root = pack_root.get_base_dir()

	var pack := GraphicsPack.load_root(pack_root)

	if not pack.error.is_empty():
		result.error = "Import assets or select a valid graphics pack. " + pack.error

		return result

	result.assets = OriginalGameAssets.new()
	result.reference_root = pack_root
	var metadata: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(pack_root.path_join("pack.json")))

	if metadata.has("runtime_data"):
		var relative: Variant = metadata.runtime_data

		if not relative is String or relative.is_empty() or relative.is_absolute_path() or relative.contains(":") or relative.contains("\\"):
			result.error = "runtime_data must be a relative folder path."
			return result

		for part in relative.split("/"):
			if part in ["", ".", ".."]:
				result.error = "runtime_data cannot contain empty, dot, or parent components."
				return result

		result.reference_root = pack_root.path_join(relative)
		result.assets.load_text_data(result.reference_root)
		result.has_city_template = FileAccess.file_exists(result.reference_root.path_join("DEFAULT.SC2"))

		if not result.has_city_template or result.assets.newspaper_data == null or not result.assets.newspaper_data.is_valid() or result.assets.library_texts.is_empty() or result.assets.original_credits.is_empty():
			result.error = "The graphics pack has incomplete runtime data. Import it again."
			return result

	if pack.large_sprites.entries.is_empty() or pack.small_medium_sprites.entries.is_empty():
		result.error = "This graphics pack needs both city sprite size groups."
		return result

	if not pack.apply_to(result.assets):
		result.error = "Cannot load graphics pack: " + pack.error

		return result

	if result.assets.palette == null or not result.assets.palette.is_valid():
		result.error = "The graphics pack does not provide a valid city palette."
		return result

	result.graphics_name = pack.pack_name
	result.uses_graphics_pack = true

	return result
