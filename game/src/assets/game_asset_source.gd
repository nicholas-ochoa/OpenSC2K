class_name GameAssetSource
extends RefCounted
# load the original base set and apply an optional external graphics pack

const MODES := ["auto", "original", "folder"]
var assets: OriginalGameAssets
var use_original_data := false
var uses_graphics_pack := false
var graphics_name := ""
var error := ""


static func default_reference_root() -> String:
	var imported := ProjectSettings.globalize_path("user://original_game").simplify_path()
	if FileAccess.file_exists(imported.path_join("SIMCITY.EXE")) or not OS.has_feature("editor"):
		return imported
	return ProjectSettings.globalize_path("res://../references").simplify_path()


static func load_source(reference_root: String, mode: String, folder := "", override_folder := "") -> GameAssetSource:
	var result := GameAssetSource.new()
	if mode not in MODES:
		result.error = "Unknown graphics source: %s" % mode
		return result
	var installed := OriginalGameInstaller.validate_install_root(reference_root)
	if not installed.ok:
		result.error = "Import the original SimCity 2000 game files to start."
		return result
	result.use_original_data = true
	result.assets = OriginalGameAssets.load_root(reference_root)
	if not result.assets.error.is_empty():
		result.error = result.assets.error
		return result
	result.graphics_name = "SimCity 2000"
	var pack_root := override_folder
	if pack_root.is_empty():
		if mode == "folder":
			pack_root = folder
			if pack_root.is_empty():
				result.error = "Choose a graphics pack.json file."
				return result
	if not pack_root.is_empty():
		var pack := GraphicsPack.load_root(pack_root)
		if not pack.apply_to(result.assets):
			result.error = "Cannot load graphics pack: %s" % pack.error
			return result
		result.graphics_name = pack.pack_name
		result.uses_graphics_pack = true
	return result
