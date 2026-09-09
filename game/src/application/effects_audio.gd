class_name ApplicationEffectsAudio
extends RefCounted


const IsometricRenderer = preload("res://src/view/city_isometric_renderer.gd")
const ToolSounds = preload("res://src/audio/tool_sound_rules.gd")

class DustTiming extends RefCounted:
	var first: int
	var start: int

	func _init(first_frame: int, start_frame: int) -> void:
		first = first_frame
		start = start_frame


var app: CityApplication


func _init(application: CityApplication) -> void:
	app = application


func play_music_track(track_id: int) -> bool:
	return app.audio_controller != null and app.audio_controller.play_music_track(track_id)


func on_music_activity_changed(active: bool) -> void:
	if app.simulation_state.simulation_engine != null:
		app.simulation_state.simulation_engine.midi_playback_active = active


func music_playback_is_active() -> bool:
	return (
		app.document_state.city != null
		and app.document_state.city.music_enabled()
		and app.audio_controller != null
		and app.audio_controller.music_playback_is_active()
	)


func handle_application_focus_out() -> void:
	if app.audio_controller != null:
		app.audio_controller.handle_application_focus_out()


func handle_application_focus_in() -> void:
	if app.audio_controller != null:
		app.audio_controller.handle_application_focus_in(
			(app.asset_state.assets_ready and app.main_menu != null and app.main_menu.visible and app.preferences.music_volume > 0.0
			and (app.document_state.city == null or app.document_state.city.music_enabled()))
			or (app.document_state.city != null and app.document_state.city.music_enabled())
		)


func stop_music() -> void:
	if app.audio_controller != null:
		app.audio_controller.stop_music()


func stop_sound_effects() -> void:
	if app.audio_controller != null:
		app.audio_controller.stop_sound_effects()


func show_effect_events(effect_events: Array[EffectEvent], sound_events: Array[SoundEvent]) -> void:
	if app.document_state.city == null:
		return

	effect_events = _parallel_dust_events(effect_events)
	var visuals: Array[CityTransientEffectVisual] = []

	for effect in effect_events:
		if effect.type == "earthquake":
			app.map_view.shake_view(
				int(effect.frames),
				float(effect.frame_msec) / 1000.0,
				float(effect.distance),
			)

	if app.view_state.overlay_mode == CityViewMode.Mode.CITY:
		var view_size := app.static_render.city_view_size()
		var sprite_archive := app.static_render.sprite_archive_for_view(view_size)
		var divisor := IsometricRenderer.view_configuration(view_size).divisor

		for effect in effect_events:
			if effect.type == "earthquake":
				continue

			var sprite_id := IsometricRenderer.effect_sprite_id(
				int(effect.sprite_id), view_size
			)
			var sprite := sprite_archive.find_sprite(sprite_id)

			if sprite == null:
				continue

			var rendered := sprite.create_image(app.asset_state.palette)

			if not rendered.ok:
				continue

			var effect_image: Image = rendered.image

			if effect.flip:
				effect_image.flip_x()

			var position := IsometricRenderer.transient_effect_position(
				app.document_state.city, effect, effect_image.get_height(), view_size
			)

			if position.x < 0 or position.y < 0:
				continue

			if divisor > 1:
				effect_image.resize(
					effect_image.get_width() * divisor,
					effect_image.get_height() * divisor,
					Image.INTERPOLATE_NEAREST
				)

			visuals.append(CityTransientEffectVisual.new(
				ImageTexture.create_from_image(effect_image),
				Vector2(position * divisor), int(effect.frame)
			))

		app.map_view.show_transient_effects(visuals, 0.1)

	play_sound_events(sound_events)


func play_sound_ids(sound_ids: Array[int]) -> void:
	play_sound_events(SoundEvent.from_ids(sound_ids))


func play_sound_events(sound_events: Array[SoundEvent]) -> void:
	if app.document_state.city == null or app.audio_controller == null:
		return

	app.audio_controller.play_sound_events(
		sound_events, app.document_state.city.sound_enabled(), app.view_state.overlay_mode, app.static_render.city_view_size()
	)


func play_tool_success_sound(
	group_index: int, subtool_index: int, free_mode := false
) -> void:
	if free_mode:
		return

	play_sound_ids(ToolSounds.success_events(group_index, subtool_index))


func play_tool_failure_sound(
	group_index: int,
	subtool_index: int,
	error := "",
	free_mode := false
) -> void:
	if free_mode:
		return

	play_sound_ids(
		ToolSounds.failure_events(group_index, subtool_index, str(error))
	)


func start_tool_loop_sound(sound_id: int) -> void:
	if app.audio_controller != null:
		app.audio_controller.start_tool_loop_sound(
			sound_id, app.document_state.city != null and app.document_state.city.sound_enabled()
		)


func stop_tool_loop_sound() -> void:
	if app.audio_controller != null:
		app.audio_controller.stop_tool_loop_sound()


static func _parallel_dust_events(events: Array[EffectEvent]) -> Array[EffectEvent]:
	var groups: Dictionary[Vector2i, Array] = {}

	for event in events:
		if event.point != Vector2i(-1, -1) and event.type != "earthquake":
			var key: Vector2i = event.point

			if not groups.has(key):
				groups[key] = []

			groups[key].append(event)

	if groups.size() < 2:
		return events

	var order := groups.keys()
	order.shuffle() # presentation randomness does not consume simulation random state
	var starts: Dictionary[Vector2i, DustTiming] = {}

	for index in order.size():
		var first := 2147483647

		for event in groups[order[index]]:
			first = mini(first, int(event.frame))

		starts[order[index]] = DustTiming.new(first, index % 5)

	var result: Array[EffectEvent] = []

	for source in events:
		var event := source.copy()

		if event.point != Vector2i(-1, -1) and starts.has(event.point):
			var timing := starts[event.point]
			event.frame = int(event.frame) - int(timing.first) + int(timing.start)

		result.append(event)

	return result
