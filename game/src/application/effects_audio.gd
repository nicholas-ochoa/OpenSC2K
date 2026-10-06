class_name ApplicationEffectsAudio
extends RefCounted


@warning_ignore_start("integer_division")


const IsometricRenderer = preload("res://src/view/city_isometric_renderer.gd")
const ToolSounds = preload("res://src/audio/tool_sound_rules.gd")
const EFFECT_CACHE_LIMIT := 2048
# large view pixels above a launching arcology that a structure in front can reach
const LAUNCH_MASK_REACH := 320
# draw layers at one depth: a launching arcology, then fire, then dust and smoke
const LAYER_BUILDING := 0
const LAYER_FIRE := 1
const LAYER_SMOKE := 2
# large view pixels below a launching arcology that its exhaust can reach
const EXHAUST_REACH := 64

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
var disaster_effects: CityDisasterEffects
# (position, size, depth tile, view size) -> the static silhouettes over an
# effect sprite, or null. see ApplicationMovingSprites.effect_occluder_mask
var occluder_mask: Callable
# scaled effect sprite images, and their textures with and without occlusion
var _effect_images: Dictionary[String, Image] = {}
var _effect_textures: Dictionary[String, Texture2D] = {}
# the exhaust flames of each phase under a launching arcology, by view and sprite size
var _exhaust_images: Dictionary[String, Array] = {}


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


# `simulation` paces the sounds of a simulation tick. player actions pass false
func show_effect_events(effect_events: Array[EffectEvent], sound_events: Array[SoundEvent], simulation := false) -> void:
	if document_state.city == null:
		return

	effect_events = CityEffectTiming.expand_launch_fires(CityEffectTiming.parallel_dust_events(effect_events))
	if disaster_effects != null:
		effect_events = disaster_effects.consume_effects(effect_events, simulation)
	var visuals: Array[CityTransientEffectVisual] = []

	for effect in effect_events:
		if effect.type == "earthquake":
			if disaster_effects != null and disaster_effects.active():
				disaster_effects.shake_view()
				continue
			map_view.shake_view(
				int(effect.frames),
				float(effect.frame_msec) / 1000.0,
				float(effect.distance) * (preferences.visual_enhancements.disaster_shake if preferences.visual_enhancements.disaster_enabled else 1.0),
			)

	if view_state.overlay_mode == CityViewMode.Mode.CITY:
		var view_size: int = current_view_size.call()
		var sprite_archive: Sc2SpriteArchive = sprites_for_view.call(view_size)

		if _effect_textures.size() > EFFECT_CACHE_LIMIT:
			_effect_textures.clear()

		var launches: Array[CityTransientEffectVisual] = []

		for effect in effect_events:
			if effect.type == "earthquake":
				continue

			if effect.type == CityEffectTiming.LAUNCH_ARCOLOGY:
				launches.append_array(_launch_visuals(effect, view_size, sprite_archive))
				continue

			var visual := _effect_visual(effect, view_size, sprite_archive)

			if visual != null:
				visuals.append(visual)

		# an empty list would stop the effects that still play
		if not visuals.is_empty():
			map_view.show_transient_effects(visuals, 0.1)

		if not launches.is_empty():
			map_view.show_transient_effects(launches, 1.0 / CityEffectTiming.LAUNCH_FPS)

	play_sound_events(sound_events, simulation)


# the effect sprite at its view position, without the pixels of the
# structures in front of its depth tile
func _effect_visual(effect: EffectEvent, view_size: int, sprite_archive: Sc2SpriteArchive) -> CityTransientEffectVisual:
	var divisor := IsometricRenderer.view_configuration(view_size).divisor
	var sprite_id := IsometricRenderer.effect_sprite_id(int(effect.sprite_id), view_size)
	var image := _effect_image(sprite_archive, sprite_id, effect.flip, divisor)

	if image == null:
		return null

	var position := IsometricRenderer.transient_effect_position(
		document_state.city, effect, image.get_height() / divisor, view_size
	)

	if position.x < 0 or position.y < 0:
		return null

	var origin := position * divisor
	var depth_tile: Vector2i = effect.depth_point if effect.depth_point.x >= 0 else effect.point
	var mask: Image = occluder_mask.call(origin, image.get_size(), depth_tile, view_size) if occluder_mask.is_valid() else null
	var key := "%d:%d:%d:%d" % [sprite_id, int(effect.flip), divisor, mask.get_instance_id() if mask != null else 0]

	if not _effect_textures.has(key):
		var visible := image

		if mask != null:
			visible = IsometricRenderer.occlude_dynamic_with_mask(image, mask, origin).image

		_effect_textures[key] = ImageTexture.create_from_image(visible)

	var fire_first := IsometricRenderer.effect_sprite_id(CityEffectTiming.FIRE_SPRITE, view_size)
	var layer := LAYER_FIRE if sprite_id >= fire_first and sprite_id < fire_first + 4 else LAYER_SMOKE

	return CityTransientEffectVisual.new(_effect_textures[key], Vector2(origin), int(effect.frame), _depth_order(depth_tile), layer)


# the frames of a launching arcology: the building sprite where the painter
# drew it, still, then shaking, then flying off the top of the map. one mask
# of the structures in front covers the whole shake and the low flight
func _launch_visuals(effect: EffectEvent, view_size: int, sprite_archive: Sc2SpriteArchive) -> Array[CityTransientEffectVisual]:
	var visuals: Array[CityTransientEffectVisual] = []
	var divisor := IsometricRenderer.view_configuration(view_size).divisor
	var sprite_id := IsometricRenderer.effect_sprite_id(int(effect.sprite_id), view_size)
	var image := _effect_image(sprite_archive, sprite_id, effect.flip, divisor)

	if image == null:
		return visuals

	var position := IsometricGeometry.building_sprite_position(
		document_state.city, effect.point, int(effect.altitude), image.get_size() / divisor, view_size
	)
	var origin := position * divisor
	var bounds := Rect2i(origin - Vector2i(divisor, LAUNCH_MASK_REACH),
		image.get_size() + Vector2i(divisor * 2, LAUNCH_MASK_REACH + EXHAUST_REACH))
	var mask: Image = occluder_mask.call(bounds.position, bounds.size, effect.depth_point, view_size) if occluder_mask.is_valid() else null
	var used := mask.get_used_rect() if mask != null else Rect2i()
	var plain := _plain_effect_texture(sprite_id, effect.flip, divisor, image)
	var offsets := CityEffectTiming.launch_offsets(int(effect.frames), divisor, origin.y, image.get_height() + EXHAUST_REACH)
	var liftoff := CityEffectTiming.liftoff_frame(int(effect.frames))
	var exhaust := _exhaust(sprite_archive, view_size, image.get_size())
	var depth := _depth_order(effect.depth_point)
	# the shake repeats offsets
	var masked: Dictionary[String, Texture2D] = {}

	for frame in offsets.size():
		var offset := offsets[frame]
		var at := origin + offset - bounds.position
		var texture := _masked_launch_texture(image, mask, used, at, plain, masked)
		visuals.append(CityTransientEffectVisual.new(texture, Vector2(origin + offset), frame, depth, LAYER_BUILDING))

		if frame < liftoff or exhaust.is_empty():
			continue

		var flames: ExhaustImage = exhaust[(frame / CityEffectTiming.EXHAUST_FRAME_STEP) % exhaust.size()]
		var flame_texture := _masked_launch_texture(flames.image, mask, used, at + flames.offset, flames.texture, masked)
		visuals.append(CityTransientEffectVisual.new(flame_texture, Vector2(origin + offset + flames.offset), frame, depth, LAYER_FIRE))

	return visuals


# upside-down fire along the two front edges of a launching arcology, like
# rocket exhaust, in each animation phase. the flames cover the front of the
# edge tiles, and so the flat tile under the building
func _exhaust(sprite_archive: Sc2SpriteArchive, view_size: int, building_size: Vector2i) -> Array:
	var key := "%d:%d:%s" % [view_size, sprite_archive.get_instance_id(), building_size]

	if _exhaust_images.has(key):
		return _exhaust_images[key]

	var configuration := IsometricRenderer.view_configuration(view_size)
	var divisor := configuration.divisor
	var size := building_size / divisor
	var phases: Array = []

	for phase in 4:
		var flames: Array[Image] = []
		var positions: Array[Vector2i] = []
		var area := Rect2i()

		for index in CityEffectTiming.EXHAUST_TILES.size():
			var tile := CityEffectTiming.EXHAUST_TILES[index]
			var sprite_id := IsometricRenderer.effect_sprite_id(CityEffectTiming.FIRE_SPRITE + ((phase + index) & 3), view_size)
			var flame := _effect_image(sprite_archive, sprite_id, (index & 1) != 0, divisor)

			if flame == null:
				return []

			flame = flame.duplicate()
			flame.flip_y()
			# three quarters down the tile, relative to the sprite origin, as the
			# painter places the building
			var position := Vector2i(
				(tile.x - tile.y) * configuration.half_width,
				(tile.x + tile.y) * configuration.half_height + configuration.half_height * 3 / 2
					- configuration.tile_height - size.x / 4 + configuration.half_height + size.y
			) * divisor
			flames.append(flame)
			positions.append(position)
			area = Rect2i(position, flame.get_size()) if area.get_area() == 0 else area.merge(Rect2i(position, flame.get_size()))

		var image := Image.create(area.size.x, area.size.y, false, Image.FORMAT_RGBA8)
		image.fill(Color.TRANSPARENT)

		for index in flames.size():
			image.blend_rect(flames[index], Rect2i(Vector2i.ZERO, flames[index].get_size()), positions[index] - area.position)

		phases.append(ExhaustImage.new(image, area.position))

	_exhaust_images[key] = phases

	return phases


# `image` without the pixels under `mask` when the sprite sits at `at` in the
# mask. `used` is the opaque area of the mask. `cache` holds the results by
# image and position
func _masked_launch_texture(
	image: Image, mask: Image, used: Rect2i, at: Vector2i, plain: Texture2D, cache: Dictionary[String, Texture2D]
) -> Texture2D:
	if mask == null:
		return plain

	var covered := Rect2i(at, image.get_size()).intersection(used)

	if covered.get_area() <= 0:
		return plain

	var key := "%d:%s" % [image.get_instance_id(), at]

	if cache.has(key):
		return cache[key]

	var crop := Image.create(image.get_width(), image.get_height(), false, mask.get_format())
	crop.blit_rect(mask, covered, covered.position - at)
	var texture := plain

	if not crop.is_invisible():
		texture = ImageTexture.create_from_image(IsometricRenderer.occlude_dynamic_with_mask(image, crop, Vector2i.ZERO).image)

	cache[key] = texture

	return texture


func _plain_effect_texture(sprite_id: int, flip: bool, divisor: int, image: Image) -> Texture2D:
	var key := "%d:%d:%d:0" % [sprite_id, int(flip), divisor]

	if not _effect_textures.has(key):
		_effect_textures[key] = ImageTexture.create_from_image(image)

	return _effect_textures[key]


func _depth_order(tile: Vector2i) -> int:
	var city := document_state.city

	return (tile.x + tile.y) * city.map_size + tile.y


func _effect_image(sprite_archive: Sc2SpriteArchive, sprite_id: int, flip: bool, divisor: int) -> Image:
	var key := "%d:%d:%d:%d" % [sprite_id, int(flip), divisor, sprite_archive.get_instance_id()]

	if _effect_images.has(key):
		return _effect_images[key]

	var sprite := sprite_archive.find_sprite(sprite_id)

	if sprite == null:
		return null

	var rendered := sprite.create_image(asset_state.palette)

	if not rendered.ok:
		return null

	var image: Image = rendered.image

	if flip:
		image.flip_x()

	if divisor > 1:
		image.resize(image.get_width() * divisor, image.get_height() * divisor, Image.INTERPOLATE_NEAREST)

	_effect_images[key] = image

	return image


func play_sound_ids(sound_ids: Array[int]) -> void:
	play_sound_events(SoundEvent.from_ids(sound_ids))


func play_sound_events(sound_events: Array[SoundEvent], simulation := false) -> void:
	if document_state.city == null or audio_controller == null:
		return

	audio_controller.play_sound_events(
		sound_events, document_state.city.sound_enabled(), view_state.overlay_mode, current_view_size.call(), simulation
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


class ExhaustImage extends RefCounted:
	var image: Image
	var texture: Texture2D
	# from the building sprite origin, in scaled view pixels
	var offset: Vector2i

	func _init(flames: Image, origin: Vector2i) -> void:
		image = flames
		texture = ImageTexture.create_from_image(flames)
		offset = origin
