class_name GameAssetSource
extends RefCounted
# load a graphics pack without access to the original installation. the data pack
# supplies the game data files

const MODES := ["auto", "original", "folder"]
var assets: OriginalGameAssets
var import_revision := ImportedPackRevision.NOT_IMPORTED
var uses_graphics_pack := false
var graphics_name := ""
var error := ""
var pack_root := ""
var warnings := PackedStringArray()


static func load_source(_base_root: String, mode: String, folder := "", override_folder := "") -> GameAssetSource:
	var result := GameAssetSource.new()

	if mode not in MODES:
		result.error = "Unknown graphics source: %s" % mode

		return result

	var root := override_folder

	if root.is_empty():
		root = folder if mode == "folder" else MediaPack.default_folder("graphics")

	if root.get_file() == "pack.json":
		root = root.get_base_dir()

	var pack := GraphicsPack.load_root(root)

	if not pack.error.is_empty():
		result.error = "Import assets or select a valid graphics pack. " + pack.error

		return result

	result.assets = OriginalGameAssets.new()
	result.pack_root = root
	result.import_revision = pack.import_revision

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
