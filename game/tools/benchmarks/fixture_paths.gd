extends SceneTree
## Shared read-only benchmark inputs and fast preflight entry point.


static func reference_path(relative := "") -> String:
	return ProjectSettings.globalize_path("res://../references/SIMCITY2000").path_join(relative)


static func large_city_path(edge: int) -> String:
	return ProjectSettings.globalize_path("res://../local/large-cities/stitched-%d.sc2x" % edge)


static func input_path(fallback: String) -> String:
	var arguments := OS.get_cmdline_user_args()
	return arguments[0] if not arguments.is_empty() and not arguments[0].begins_with("--") else fallback


static func application_paths() -> PackedStringArray:
	var paths := PackedStringArray([reference_path("SIMCITY.EXE"), "res://../ext/graphics/pack.json"])

	for relative in OriginalGameInstaller.REQUIRED_RELATIVE_PATHS:
		paths.append(reference_path(relative))

	return paths


static func configure_application(main: CityApplication) -> void:
	main.asset_state.reference_root = reference_path()
	OS.set_environment("OPENSC2K_GRAPHICS_PACK", ProjectSettings.globalize_path("res://../ext/graphics"))


func _initialize() -> void:
	if "--check-all-inputs" in OS.get_cmdline_user_args():
		_check_all_inputs()
		return

	if not _inputs_exist(get_script().fixture_paths()):
		quit(1)
		return

	if "--check-inputs" in OS.get_cmdline_user_args():
		print("Benchmark inputs found: %s" % get_script().resource_path)
		quit()
		return

	_benchmark_initialize()


static func _inputs_exist(paths: PackedStringArray) -> bool:
	for path in paths:
		if not FileAccess.file_exists(path):
			printerr("Missing benchmark input: %s" % path)
			return false

	return true


func _check_all_inputs() -> void:
	var count := 0

	for name in DirAccess.get_files_at("res://tools/benchmarks"):
		if not name.ends_with(".gd"):
			continue

		var script := load("res://tools/benchmarks/" + name) as GDScript

		if script == null or not script.can_instantiate():
			printerr("Cannot parse benchmark script: %s" % name)
			quit(1)
			return

		# This Node is attached by the native frame benchmark, not run as a MainLoop.
		if name != "profiled_city.gd":
			if not script.has_method("fixture_paths") or not _inputs_exist(script.fixture_paths()):
				printerr("Cannot find benchmark inputs: %s" % name)
				quit(1)
				return

		count += 1
		print("PASS %s" % name)

	print("PASS %d benchmark scripts and their default inputs" % count)
	quit()


static func fixture_paths() -> PackedStringArray:
	return PackedStringArray()


func _benchmark_initialize() -> void:
	print("Shared benchmark fixture-path helper; no timed workload.")
	quit()
