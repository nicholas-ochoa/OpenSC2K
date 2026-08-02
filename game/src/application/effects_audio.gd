class_name ApplicationEffectsAudio
extends RefCounted


const IsometricRenderer = preload("res://src/view/city_isometric_renderer.gd")
const ToolSounds = preload("res://src/audio/tool_sound_rules.gd")

var app: CityApplication


func _init(application: CityApplication) -> void:
	app = application


func _play_music_track(track_id: int) -> bool:
	return app.audio_controller != null and app.audio_controller.play_music_track(track_id)


func _on_music_activity_changed(active: bool) -> void:
	if app.simulation_engine != null:
		app.simulation_engine.midi_playback_active = active


func _music_playback_is_active() -> bool:
	return (
		app.city != null
		and app.city.music_enabled()
		and app.audio_controller != null
		and app.audio_controller.music_playback_is_active()
	)


func _handle_application_focus_out() -> void:
	if app.audio_controller != null:
		app.audio_controller.handle_application_focus_out()


func _handle_application_focus_in() -> void:
	if app.audio_controller != null:
		app.audio_controller.handle_application_focus_in(
			(app.assets_ready and app.main_menu != null and app.main_menu.visible and app.preferences.music_volume > 0.0
			and (app.city == null or app.city.music_enabled()))
			or (app.city != null and app.city.music_enabled())
		)


func _stop_music() -> void:
	if app.audio_controller != null:
		app.audio_controller.stop_music()


func _stop_sound_effects() -> void:
	if app.audio_controller != null:
		app.audio_controller.stop_sound_effects()


func _show_effect_events(effect_events: Array, sound_events: Array) -> void:
	if app.city == null:
		return

	effect_events = _parallel_dust_events(effect_events)
	var visuals: Array[Dictionary] = []

	for effect in effect_events:
		if effect.get("type", "") == "earthquake":
			app.map_view.shake_view(
				int(effect.get("frames", 24)),
				float(effect.get("frame_msec", 5)) / 1000.0,
				float(effect.get("distance", 4)),
			)

	if app.overlay_mode == CityViewMode.Mode.CITY:
		var view_size := app.static_render._city_view_size()
		var sprite_archive := app.static_render._sprite_archive_for_view(view_size)
		var divisor := int(IsometricRenderer.view_configuration(view_size).divisor)

		for effect in effect_events:
			if effect.get("type", "") == "earthquake":
				continue

			var sprite_id := IsometricRenderer.effect_sprite_id(
				int(effect.get("sprite_id", 0)), view_size
			)
			var sprite := sprite_archive.find_sprite(sprite_id)

			if sprite == null:
				continue

			var rendered := sprite.create_image(app.palette)

			if not rendered.ok:
				continue

			var effect_image: Image = rendered.image

			if effect.get("flip", false):
				effect_image.flip_x()

			var position := IsometricRenderer.transient_effect_position(
				app.city, effect, effect_image.get_height(), view_size
			)

			if position.x < 0 or position.y < 0:
				continue

			if divisor > 1:
				effect_image.resize(
					effect_image.get_width() * divisor,
					effect_image.get_height() * divisor,
					Image.INTERPOLATE_NEAREST
				)

			visuals.append({
				"texture": ImageTexture.create_from_image(effect_image),
				"position": Vector2(position * divisor),
				"frame": int(effect.get("frame", 0)),
			})

		app.map_view.show_transient_effects(visuals, 0.1)

	_play_sound_events(sound_events)


func _play_sound_events(sound_events: Array) -> void:
	if app.city == null or app.audio_controller == null:
		return

	app.audio_controller.play_sound_events(
		sound_events, app.city.sound_enabled(), app.overlay_mode, app.static_render._city_view_size()
	)


func _play_tool_success_sound(
	group_index: int, subtool_index: int, free_mode := false
) -> void:
	if free_mode:
		return

	_play_sound_events(ToolSounds.success_events(group_index, subtool_index))


func _play_tool_failure_sound(
	group_index: int,
	subtool_index: int,
	error := "",
	free_mode := false
) -> void:
	if free_mode:
		return

	_play_sound_events(
		ToolSounds.failure_events(group_index, subtool_index, str(error))
	)


func _start_tool_loop_sound(sound_id: int) -> void:
	if app.audio_controller != null:
		app.audio_controller.start_tool_loop_sound(
			sound_id, app.city != null and app.city.sound_enabled()
		)


func _stop_tool_loop_sound() -> void:
	if app.audio_controller != null:
		app.audio_controller.stop_tool_loop_sound()


static func _parallel_dust_events(events: Array) -> Array:
	var groups := {}

	for event in events:
		if event.has("point") and event.get("type", "") != "earthquake":
			var key: Vector2i = event.point

			if not groups.has(key):
				groups[key] = []

			groups[key].append(event)

	if groups.size() < 2:
		return events

	var order := groups.keys()
	order.shuffle() # presentation randomness does not consume simulation random state
	var starts := {}

	for index in order.size():
		var first := 2147483647

		for event in groups[order[index]]:
			first = mini(first, int(event.get("frame", 0)))

		starts[order[index]] = {"first": first, "start": index % 5}

	var result: Array = []

	for source in events:
		var event: Dictionary = source.duplicate()

		if event.has("point") and starts.has(event.point):
			var timing: Dictionary = starts[event.point]
			event.frame = int(event.get("frame", 0)) - int(timing.first) + int(timing.start)

		result.append(event)

	return result
