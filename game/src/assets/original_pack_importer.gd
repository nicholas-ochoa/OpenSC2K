class_name OriginalPackImporter
extends RefCounted


static func import_executable(executable: String, packs_root: String, saved_root := "") -> Dictionary:
	var target := packs_root.path_join("Original-SC2K-%d-%d" % [Time.get_unix_time_from_system(), Time.get_ticks_usec()])
	var stage := target + ".staging"
	var support := stage.path_join("original")
	var installed := OriginalGameInstaller.install_from_executable(executable, support)
	if not installed.ok:
		OriginalGameInstaller.remove_tree(stage)
		return installed
	var exported := OriginalPackExporter.new().export_packs(support, stage, "original")
	if exported.ok and DirAccess.rename_absolute(support, stage.path_join("graphics/original")) != OK:
		exported = {"ok": false, "error": "Cannot attach original support data to the graphics pack."}
	if exported.ok:
		var checked := GameAssetSource.load_source("", "folder", stage.path_join("graphics/pack.json"))
		if not checked.error.is_empty():
			exported = {"ok": false, "error": checked.error}
	var saved_games := {"ok": true, "created": PackedStringArray()}
	if exported.ok:
		saved_games = OriginalCityImporter.import_saved_games(stage.path_join("graphics/original"), saved_root if not saved_root.is_empty() else packs_root.path_join("saved"))
		if not saved_games.ok:
			exported = saved_games
	if exported.ok and DirAccess.rename_absolute(stage, target) != OK:
		exported = {"ok": false, "error": "Cannot activate the imported packs."}
	if not exported.ok:
		OriginalCityImporter.rollback(saved_games.get("created", PackedStringArray()))
		OriginalGameInstaller.remove_tree(stage)
		return exported
	return {"ok": true, "error": "", "root": target.path_join("graphics/original"),
		"cities": saved_games.get("cities", 0), "scenarios": saved_games.get("scenarios", 0),
		"graphics": target.path_join("graphics/pack.json"), "sound": target.path_join("sound/pack.json"),
		"music": target.path_join("music/pack.json")}
