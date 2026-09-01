class_name OriginalPackImporter
extends RefCounted



static func import_executable(executable: String, packs_root: String, saved_root := "") -> AssetImportResult:
	var target := packs_root.path_join("Original-SC2K-%d-%d" % [Time.get_unix_time_from_system(), Time.get_ticks_usec()])
	var stage := target + ".staging"
	var support := stage.path_join("original")
	var installed := OriginalGameInstaller.install_from_executable(executable, support)

	if not installed.ok:
		OriginalGameInstaller.remove_tree(stage)

		return installed

	var exported := OriginalPackExporter.new().export_packs(support, stage, "original")

	if exported.ok and DirAccess.rename_absolute(support, stage.path_join("graphics/original")) != OK:
		exported = AssetImportResult.failure("Cannot attach original support data to the graphics pack.")

	if exported.ok:
		var checked := GameAssetSource.load_source("", "folder", stage.path_join("graphics/pack.json"))

		if not checked.error.is_empty():
			exported = AssetImportResult.failure(checked.error)

	var saved_games := AssetImportResult.new()
	saved_games.ok = true

	if exported.ok:
		saved_games = OriginalCityImporter.import_saved_games(stage.path_join("graphics/original"), saved_root if not saved_root.is_empty()
				else packs_root.path_join("saved"))

		if not saved_games.ok:
			exported = saved_games

	if exported.ok and DirAccess.rename_absolute(stage, target) != OK:
		exported = AssetImportResult.failure("Cannot activate the imported packs.")

	if not exported.ok:
		OriginalCityImporter.rollback(saved_games.created)
		OriginalGameInstaller.remove_tree(stage)

		return exported

	var outcome := AssetImportResult.new()
	outcome.ok = true
	outcome.error = ""
	outcome.root = target.path_join("graphics/original")
	outcome.cities = saved_games.cities
	outcome.scenarios = saved_games.scenarios
	outcome.graphics = target.path_join("graphics/pack.json")
	outcome.sound = target.path_join("sound/pack.json")
	outcome.music = target.path_join("music/pack.json")

	return outcome
