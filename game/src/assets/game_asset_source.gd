class_name GameAssetSource
extends RefCounted
# load the original base set and apply an optional external graphics pack

const MODES := ["auto", "original", "folder"]
var assets: OriginalGameAssets
var use_original_data := false
var uses_graphics_pack := false
var graphics_name := ""
var error := ""
var reference_root := ""


static func default_reference_root() -> String:
	return ProjectSettings.globalize_path("user://original_game").simplify_path()


static func load_source(base_root: String, mode: String, folder := "", override_folder := "") -> GameAssetSource:
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

	result.reference_root = base_root
	var metadata: Variant = JSON.parse_string(FileAccess.get_file_as_string(pack_root.path_join("pack.json")))

	if metadata is Dictionary and metadata.has("original_data"):
		var relative: Variant = metadata.original_data

		if not relative is String or relative.is_empty() or relative.is_absolute_path() or relative.contains(":") or relative.contains("\\"):
			result.error = "original_data must be a relative folder path."

			return result

		for part in relative.split("/"):
			if part in ["", ".", ".."]:
				result.error = "original_data cannot contain empty, dot, or parent components."

				return result

		result.reference_root = pack_root.path_join(relative)

	var installed := OriginalGameInstaller.validate_install_root(result.reference_root)

	if not installed.ok:
		result.error = "Import the original SimCity 2000 game files to start."

		return result

	result.use_original_data = true
	result.assets = OriginalGameAssets.load_root(result.reference_root)

	if not result.assets.error.is_empty():
		result.error = result.assets.error

		return result

	if not pack.apply_to(result.assets):
		result.error = "Cannot load graphics pack: " + pack.error

		return result

	result.graphics_name = pack.pack_name
	result.uses_graphics_pack = true

	return result
