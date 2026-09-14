class_name GameAssetSource
extends RefCounted
# load a graphics pack with optional original support data

const MODES := ["auto", "original", "folder"]
var assets: OriginalGameAssets
var use_original_data := false
var uses_graphics_pack := false
var graphics_name := ""
var error := ""
var reference_root := ""
var warnings := PackedStringArray()


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

	if installed.ok:
		result.assets = OriginalGameAssets.load_root(result.reference_root)
		result.use_original_data = result.assets.error.is_empty()

		if not result.use_original_data:
			result.warnings.append("The original support set could not be loaded: " + result.assets.error)

	if not result.use_original_data:
		# a city pack can stand alone. optional ui and text consumers already
		# supply controls or report missing content without an original executable
		if pack.large_sprites.entries.is_empty() or pack.small_medium_sprites.entries.is_empty():
			result.error = "This graphics pack needs a base set for its missing city sprite size group. Import both large and small/medium city sprites to start without a base."
			return result

		result.assets = OriginalGameAssets.new()
		result.reference_root = pack_root
		result.warnings.append("This pack runs without original Windows support files. Missing interface artwork and text use the available built-in controls and messages.")
	if not pack.apply_to(result.assets):
		result.error = "Cannot load graphics pack: " + pack.error

		return result

	if result.assets.palette == null or not result.assets.palette.is_valid():
		result.error = "The graphics pack does not provide a valid city palette."
		return result

	result.graphics_name = pack.pack_name
	result.uses_graphics_pack = true

	return result
