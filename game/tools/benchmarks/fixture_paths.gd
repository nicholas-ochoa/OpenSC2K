extends SceneTree
## Shared read-only benchmark inputs and fast preflight entry point.


static func reference_path(relative := "") -> String:
	return ProjectSettings.globalize_path("res://../references/SIMCITY2000").path_join(relative)


static func large_city_path(edge: int) -> String:
	return ProjectSettings.globalize_path("res://tests/fixtures/cities/generated-%d.sc2x" % edge)


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
	OS.set_environment("OPENSC2K_DATA_PACK", ProjectSettings.globalize_path("res://../ext/data"))


func report_metadata(workload: Dictionary) -> void:
	var inputs := {}
	for path in get_script().fixture_paths():
		inputs[path] = FileAccess.get_sha256(path)

	# the benchmark folder can be a symlink from a disposable project
	var folder := ProjectSettings.globalize_path("res://tools/benchmarks")
	var output: Array = []
	var revision := "unknown"
	if OS.execute("git", ["-C", folder, "rev-parse", "HEAD"], output) == 0:
		revision = str(output[0]).strip_edges()

	output.clear()
	var dirty: Variant = null
	if OS.execute("git", ["-C", folder, "status", "--porcelain", "--untracked-files=no"], output) == 0:
		dirty = not str(output[0]).strip_edges().is_empty()

	var load_note := OS.get_environment("CITY_BENCH_LOAD_NOTE")
	print("METADATA ", JSON.stringify({"script": get_script().resource_path, "revision": revision,
		"tracked_changes": dirty, "engine": Engine.get_version_info().string, "display": DisplayServer.get_name(),
		"arguments": OS.get_cmdline_args(), "inputs_sha256": inputs, "workload": workload,
		"concurrent_load": load_note if not load_note.is_empty() else "not recorded"}))


static func bytes_sha256(data: PackedByteArray) -> String:
	var hashing := HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	hashing.update(data)
	return hashing.finish().hex_encode()


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
