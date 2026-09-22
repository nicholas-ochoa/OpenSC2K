class_name ApplicationEffectsAudio
extends RefCounted


const IsometricRenderer = preload("res://src/view/city_isometric_renderer.gd")
const ToolSounds = preload("res://src/audio/tool_sound_rules.gd")


var document_state: ActiveDocumentState
var view_state: ViewState
var asset_state: LoadedAssetState
var simulation_state: SimulationSessionState
var preferences: AppPreferences
var current_view_size: Callable
var sprites_for_view: Callable
var audio_controller: CityAudioController
var map_view: CityMapControl
var main_menu: MainMenuControl


func _init(document: ActiveDocumentState, view: ViewState, assets: LoadedAssetState,
		simulation: SimulationSessionState, settings: AppPreferences, graphics_size: Callable, sprites: Callable) -> void:
	document_state = document
	view_state = view
	asset_state = assets
	simulation_state = simulation
	preferences = settings
	current_view_size = graphics_size
	sprites_for_view = sprites


func bind_audio(controller: CityAudioController) -> void:
	audio_controller = controller


func bind_view(map: CityMapControl, menu: MainMenuControl) -> void:
	map_view = map
	main_menu = menu


func play_music_track(track_id: int) -> bool:
	return audio_controller != null and audio_controller.play_music_track(track_id)


func on_music_activity_changed(active: bool) -> void:
	if simulation_state.simulation_engine != null:
		simulation_state.simulation_engine.midi_playback_active = active


func music_playback_is_active() -> bool:
	return (
		document_state.city != null
		and document_state.city.music_enabled()
		and audio_controller != null
		and audio_controller.music_playback_is_active()
	)


func handle_application_focus_out() -> void:
	if audio_controller != null:
		audio_controller.handle_application_focus_out()


func handle_application_focus_in() -> void:
	if audio_controller != null:
		audio_controller.handle_application_focus_in(
			(asset_state.assets_ready and main_menu != null and main_menu.visible and preferences.music_volume > 0.0
			and (document_state.city == null or document_state.city.music_enabled()))
			or (document_state.city != null and document_state.city.music_enabled())
		)


func stop_music() -> void:
	if audio_controller != null:
		audio_controller.stop_music()


func stop_sound_effects() -> void:
	if audio_controller != null:
		audio_controller.stop_sound_effects()


func show_effect_events(effect_events: Array[EffectEvent], sound_events: Array[SoundEvent]) -> void:
	if document_state.city == null:
		return

	effect_events = CityEffectTiming.parallel_dust_events(effect_events)
	var visuals: Array[CityTransientEffectVisual] = []

	for effect in effect_events:
		if effect.type == "earthquake":
			map_view.shake_view(
				int(effect.frames),
				float(effect.frame_msec) / 1000.0,
				float(effect.distance),
			)

	if view_state.overlay_mode == CityViewMode.Mode.CITY:
		var view_size: int = current_view_size.call()
		var sprite_archive: Sc2SpriteArchive = sprites_for_view.call(view_size)
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

			var rendered := sprite.create_image(asset_state.palette)

			if not rendered.ok:
				continue

			var effect_image: Image = rendered.image

			if effect.flip:
				effect_image.flip_x()

			var position := IsometricRenderer.transient_effect_position(
				document_state.city, effect, effect_image.get_height(), view_size
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

		map_view.show_transient_effects(visuals, 0.1)

	play_sound_events(sound_events)


func play_sound_ids(sound_ids: Array[int]) -> void:
	play_sound_events(SoundEvent.from_ids(sound_ids))


func play_sound_events(sound_events: Array[SoundEvent]) -> void:
	if document_state.city == null or audio_controller == null:
		return

	audio_controller.play_sound_events(
		sound_events, document_state.city.sound_enabled(), view_state.overlay_mode, current_view_size.call()
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
	if audio_controller != null:
		audio_controller.start_tool_loop_sound(
			sound_id, document_state.city != null and document_state.city.sound_enabled()
		)


func stop_tool_loop_sound() -> void:
	if audio_controller != null:
		audio_controller.stop_tool_loop_sound()
