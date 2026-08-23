extends "res://tools/benchmarks/fixture_paths.gd"

# Compare timings on the same host.
const StatusScript = preload("res://src/ui/shell/city_status_bar.gd")
const SCENE_PATH := "res://src/ui/shell/city_status_bar.tscn"
const SAMPLES := 11
const CREATIONS := 200
const UPDATES := 2000


func _benchmark_initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var host := Control.new()
	host.theme = AppUiTheme.current()
	root.add_child(host)
	var scene := load(SCENE_PATH) as PackedScene if ResourceLoader.exists(SCENE_PATH) else null

	if "--preview" in OS.get_cmdline_user_args():
		root.size = Vector2i(1280, 150)
		root.title = "Status bar scene review (Dummy audio)"
		var bar := scene.instantiate() as CityStatusBar if scene != null else StatusScript.new()
		host.add_child(bar)
		bar.size = Vector2(1280, 31)
		bar.set_environment(Vector3i(1200, -500, 800), "Clear")
		bar.set_speed("Cheetah")
		bar.set_reports(PackedStringArray(["City milestone"]))
		return

	var creation_samples: Array[float] = []
	var update_samples: Array[float] = []

	for sample in range(SAMPLES + 1):
		var started := Time.get_ticks_usec()

		for index in CREATIONS:
			var bar := scene.instantiate() as CityStatusBar if scene != null else StatusScript.new()
			host.add_child(bar)
			bar.free()

		var creation_usec := float(Time.get_ticks_usec() - started) / CREATIONS
		var bar := scene.instantiate() as CityStatusBar if scene != null else StatusScript.new()
		host.add_child(bar)
		bar.size = Vector2(1280, 31)
		bar.set_reports(PackedStringArray(["City milestone", "New invention", "Weather report"]))
		await process_frame
		await process_frame
		started = Time.get_ticks_usec()

		for index in UPDATES:
			bar.set_environment(Vector3i(index % 2000, -500, 800), "Clear")
			bar.set_speed("Cheetah")
			bar.set_zoom(100)
			bar.update_report_rotation(0.016)
			bar.refresh_tooltips()

		var update_usec := float(Time.get_ticks_usec() - started) / UPDATES
		bar.free()

		if sample > 0:
			creation_samples.append(creation_usec)
			update_samples.append(update_usec)

	print(JSON.stringify({
		"godot": Engine.get_version_info().string,
		"scene": scene != null,
		"creation_and_free_usec": creation_samples,
		"update_bundle_usec": update_samples,
	}))

	host.free()
	quit()


static func fixture_paths() -> PackedStringArray:
	return PackedStringArray([
		"res://src/ui/shell/city_status_bar.gd", SCENE_PATH,
	])
