class_name MainMenuCityBackground
extends Control

const Renderer = preload("res://src/view/city_isometric_renderer.gd")
const MINIMUM_ZOOM := 0.5
const SHOT_MAGNIFICATIONS := [3, 2, 1, 1]
const Cleanup = preload("res://src/debug/city_debug_actions.gd")

# this city has no connection to the player's document, save path, or ui events
var demo_city: CityState
var controller: GameSpeedController
var demo_texture: ImageTexture
var source_path := ""
var elapsed := 0.0
var refresh_elapsed := 0.0
var render_thread: Thread
var demo_palette: Sc2Palette
var demo_sprites: Sc2SpriteArchive
var cycle_texture: ImageTexture
var static_image: Image
var animation_elapsed := 0.0
var animation_revision := 0
var city_name_label: Label
var _discard_render := false
var presentation: MainMenuPresentation
var visual_options := VisualEnhancementOptions.normalize({})


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	city_name_label = Label.new()
	city_name_label.name = "HighlightedCityName"
	city_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	city_name_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	city_name_label.position = Vector2(20, -48)
	city_name_label.modulate.a = 0.4
	var name_font := SystemFont.new()
	name_font.font_names = PackedStringArray(["Helvetica Neue", "Arial", "sans-serif"])
	name_font.font_weight = 300
	city_name_label.add_theme_font_override("font", name_font)
	city_name_label.add_theme_color_override("font_color", Color.WHITE)
	city_name_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
	city_name_label.add_theme_constant_override("shadow_offset_x", 2)
	city_name_label.add_theme_constant_override("shadow_offset_y", 2)
	city_name_label.add_theme_font_size_override("font_size", 20)
	add_child(city_name_label)


func _process(delta: float) -> void:
	if render_thread != null and not render_thread.is_alive():
		var result: RenderResult = render_thread.wait_to_finish()
		render_thread = null

		# a render that was running at release belongs to the released city
		if result.ok and not _discard_render:
			static_image = result.image
			demo_texture = ImageTexture.create_from_image(static_image)
			if presentation != null:
				presentation.publish(static_image, demo_texture, result.city, result.occlusion_commands)
			_refresh_animation()

		_discard_render = false

		if demo_city != null and static_image == null:
			_start_render()

	if not is_visible_in_tree() or demo_city == null:
		return

	elapsed += delta
	animation_elapsed += delta
	refresh_elapsed += delta
	# Discard this private city's UI and sound events. A blocking event can still stop its clock.
	controller.advance_time(minf(delta, 0.2) * 1000.0)

	if controller.engine.pending_disaster_type != 0 or controller.engine.active_disaster_type != 0:
		Cleanup.end_disaster(demo_city, demo_city.document, controller.engine)

	if presentation != null and presentation.needs_render:
		refresh_elapsed = 10.0
		presentation.needs_render = false
	if refresh_elapsed >= 10.0 and render_thread == null:
		refresh_elapsed = 0.0
		_start_render()

	if animation_elapsed >= 0.1:
		animation_elapsed = fmod(animation_elapsed, 0.1)
		_refresh_animation()

	var camera := _camera()
	if presentation != null:
		presentation.advance(delta, camera.offset, camera.scale)
	queue_redraw()


func _draw() -> void:
	if demo_texture == null or demo_city == null:
		return

	draw_rect(Rect2(Vector2.ZERO, size), Color(0.0, 0.0, 0.0, 0.14))


func _exit_tree() -> void:
	if presentation != null:
		presentation.close()
		presentation = null
	if render_thread != null:
		render_thread.wait_to_finish()
		render_thread = null


func configure(reference_root: String, palette: Sc2Palette, sprites: Sc2SpriteArchive, options: Dictionary = {}) -> void:
	set_visual_options(options)
	if demo_city != null:
		if static_image == null and render_thread == null:
			_start_render()

		return

	if palette == null or sprites == null:
		return

	var paths := PackedStringArray()
	_collect_cities(reference_root.path_join("CITIES"), paths)

	if paths.is_empty():
		return

	var start := randi_range(0, paths.size() - 1)

	for offset in paths.size():
		var path := paths[(start + offset) % paths.size()]
		var source := Sc2File.load_path(path)

		if not source.is_valid() or source.find_chunk("SCEN") != null:
			continue

		var candidate := CityState.from_document(source.duplicate_document())

		if not candidate.is_valid():
			continue

		demo_city = candidate
		source_path = path
		break

	if demo_city == null:
		return

	city_name_label.text = demo_city.city_name()
	demo_palette = palette
	demo_sprites = sprites
	demo_city.set_no_disasters_enabled(true)
	demo_city.set_auto_budget_enabled(true)
	demo_city.set_auto_goto_enabled(false)
	demo_city.set_sound_enabled(false)
	demo_city.set_music_enabled(false)
	var engine := SimulationEngine.new(demo_city)
	Cleanup.end_disaster(demo_city, demo_city.document, engine)
	controller = GameSpeedController.new(engine)
	controller.set_speed(GameSpeedController.Speed.TURTLE)
	presentation = MainMenuPresentation.new(self, demo_city, controller, palette, sprites, visual_options)

	# _process starts the render after it drains a worker from the released city
	if render_thread == null:
		_start_render()


static func _collect_cities(folder: String, paths: PackedStringArray) -> void:
	var directory := DirAccess.open(folder)

	if directory == null:
		return

	for file in directory.get_files():
		if file.get_extension().to_lower() == "sc2":
			paths.append(folder.path_join(file))

	for child in directory.get_directories():
		_collect_cities(folder.path_join(child), paths)


func _start_render() -> void:
	var snapshot := CityState.from_document(demo_city.document.duplicate_document())
	render_thread = Thread.new()
	var error := render_thread.start(_render.bind(snapshot, MainMenuPresentation.copy_graphics(presentation.app.asset_state.large_sprites)), Thread.PRIORITY_LOW)

	if error != OK:
		render_thread = null


static func _render(snapshot: CityState, sprites: Sc2SpriteArchive) -> RenderResult:
	var rendered := Renderer.create_image(snapshot, Sc2Palette.index_encoding(), sprites, Renderer.VIEW_LARGE, 0, false, true, false, false)
	var result := RenderResult.new()
	result.ok = rendered.ok
	result.error = rendered.error
	result.image = rendered.image
	result.city = snapshot
	result.occlusion_commands = Renderer.static_occlusion_commands(snapshot, sprites)

	return result


func _camera() -> CameraFrame:
	# hold each framing for 24 seconds. integral scales preserve source pixels;
	# fractional continuous zoom makes nearest-neighbor artwork shimmer
	var shot := int(elapsed / 24.0) % 4
	var centers := [Vector2i(64, 64), Vector2i(48, 56), Vector2i(76, 64), Vector2i(62, 80)]
	var point: Vector2i = centers[shot]
	var center := Renderer.tile_polygon(demo_city, point.x, point.y)[2]
	var travel := fmod(elapsed, 24.0) - 12.0
	center += Vector2(travel * 2.0, travel)
	var pixel_scale := maxf(0.001, get_viewport_transform().get_scale().x)
	var zoom_factor := camera_zoom(shot, pixel_scale)
	var offset := ((size / 2.0 - center * zoom_factor) * pixel_scale).round() / pixel_scale

	var result := CameraFrame.new()
	result.offset = offset
	result.scale = zoom_factor

	return result


func _refresh_animation() -> void:
	if demo_city == null or static_image == null:
		return

	animation_revision += 1
	var ticks := int(elapsed * 5.0)
	var cycle_image := demo_palette.animation_image(ticks)

	if cycle_texture == null:
		cycle_texture = ImageTexture.create_from_image(cycle_image)
	else:
		cycle_texture.update(cycle_image)

	if presentation != null:
		presentation.animate(cycle_texture)


func set_visual_options(options: Dictionary) -> void:
	visual_options = VisualEnhancementOptions.normalize(options)
	if presentation != null:
		presentation.set_options(visual_options)


func reload_visual_assets() -> void:
	if presentation != null:
		presentation.reload_visual_assets()


# Release the private city, its simulation, and its render buffers while
# playing. The next menu visit loads a new city. An in-flight render is drained
# by _process; hiding the menu must not wait for a worker or upload its image.
func release_city() -> void:
	if presentation != null:
		presentation.close()
		presentation = null
	_discard_render = render_thread != null
	demo_city = null
	controller = null
	source_path = ""
	demo_palette = null
	demo_sprites = null
	elapsed = 0.0
	refresh_elapsed = 0.0
	animation_elapsed = 0.0
	city_name_label.text = ""
	_clear_render_data()


func _clear_render_data() -> void:
	demo_texture = null
	static_image = null
	cycle_texture = null
	RenderingServer.canvas_item_clear(get_canvas_item())
	queue_redraw()


static func camera_zoom(shot: int, pixel_scale: float) -> float:
	pixel_scale = maxf(0.001, pixel_scale)
	# round the minimum up to a whole output pixel to keep camera motion crisp
	var magnification := maxf(float(SHOT_MAGNIFICATIONS[shot % SHOT_MAGNIFICATIONS.size()]), ceilf(MINIMUM_ZOOM * pixel_scale))

	return magnification / pixel_scale


func replace_graphics(palette: Sc2Palette, sprites: Sc2SpriteArchive) -> void:
	if render_thread != null:
		render_thread.wait_to_finish()
		render_thread = null

	_discard_render = false
	_clear_render_data()

	if demo_city == null:
		return

	demo_palette = palette
	demo_sprites = sprites
	if presentation != null:
		presentation.close()
	presentation = MainMenuPresentation.new(self, demo_city, controller, palette, sprites, visual_options)
	_start_render()


class CameraFrame extends RefCounted:
	var offset := Vector2.ZERO
	var scale := 1.0


class RenderResult extends AssetImageResult:
	var city: CityState
	var occlusion_commands: Array[CityStaticCommand] = []
