class_name OriginalPackImporter
extends RefCounted



static func import_executable(executable: String, packs_root: String, saved_root := "") -> AssetImportResult:
	var target := packs_root.path_join("Original-SC2K-%d-%d" % [Time.get_unix_time_from_system(), Time.get_ticks_usec()])
	var stage := target + ".staging"
	var source := executable.get_base_dir()
	var checked_source := OriginalGameInstaller.validate_install_root(source)

	if not checked_source.ok:
		return checked_source

	var destination := ProjectSettings.globalize_path(packs_root).simplify_path()
	var origin := ProjectSettings.globalize_path(source).simplify_path()

	if destination == origin or destination.begins_with(origin + "/") or origin.begins_with(destination + "/"):
		return AssetImportResult.failure("Choose an import destination separate from the source game folder.")

	# The exporter checks the graphics pack as the game loads it.
	var exported := OriginalPackExporter.new().export_packs(source, stage)

	var saved_games := AssetImportResult.new()
	saved_games.ok = true

	if exported.ok:
		saved_games = OriginalCityImporter.import_saved_games(source, saved_root if not saved_root.is_empty()
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
	outcome.root = target.path_join("data")
	outcome.cities = saved_games.cities
	outcome.scenarios = saved_games.scenarios
	outcome.graphics = target.path_join("graphics/pack.json")
	outcome.sound = target.path_join("sound/pack.json")
	outcome.music = target.path_join("music/pack.json")
	outcome.data = target.path_join("data/pack.json")

	return outcome
