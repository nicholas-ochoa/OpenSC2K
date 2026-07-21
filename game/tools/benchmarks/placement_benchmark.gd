extends SceneTree


# Run with --audio-driver Dummy. Reports command and presentation CPU time.
# The fixture is in memory. No supplied city is saved.
func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene := load("res://main.tscn") as PackedScene
	var main := scene.instantiate()
	root.add_child(main)
	await process_frame
	var reference_path := ProjectSettings.globalize_path("res://../references/DEFAULT.SC2")
	main.city_files.call("_load_city_unchecked", reference_path)
	main.frame.call("_select_speed", GameSpeedController.Speed.PAUSED)

	for frame in 5:
		await process_frame

	var city := main.get("city") as CityState
	var points: Array[Vector2i] = [Vector2i(60, 60)]

	for tool in [Vector2i(14, 0), Vector2i(13, 0), Vector2i(3, 2)]:
		var start := Time.get_ticks_usec()
		var command := BuildingCommand.apply(
			city, tool.x, tool.y, points[0],
			(main.get("simulation_engine") as SimulationEngine).lfsr_random,
			main.get("tool_random")
		)
		var command_ms := (Time.get_ticks_usec() - start) / 1000.0

		if not command.ok:
			push_error(str(command.error))
			continue

		start = Time.get_ticks_usec()
		main.interface.call("_refresh_details")
		var details_ms := (Time.get_ticks_usec() - start) / 1000.0
		start = Time.get_ticks_usec()
		main.static_render.call("_refresh_after_city_edit", command)
		var display_ms := (Time.get_ticks_usec() - start) / 1000.0
		start = Time.get_ticks_usec()
		main.effects_audio.call("_play_tool_success_sound", tool.x, tool.y)
		var sound_ms := (Time.get_ticks_usec() - start) / 1000.0
		print("PLACEMENT %s command=%.2f details=%.2f display=%.2f sound=%.2f ms" % [
			ToolCatalog.tool(tool.x, tool.y).name, command_ms, details_ms, display_ms, sound_ms
		])
		print(main.get("edit_display_timings"))
		BuildingCommand.undo(city, command, (main.get("simulation_engine") as SimulationEngine).lfsr_random, main.get("tool_random"))
		main.map_render.call("_refresh_map", false)

		var render_state := main.get("static_render_state") as StaticRenderState

		while render_state.thread != null or render_state.pending:
			await process_frame

	main.queue_free()
	await process_frame
	quit()
