class_name MainMenuCityBackground
extends Control

const Renderer = preload("res://src/view/city_isometric_renderer.gd")
const MINIMUM_ZOOM := 0.5
const SHOT_MAGNIFICATIONS := [1, 2, 1, 3]
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
var static_layer: Sprite2D
var cycle_texture: ImageTexture
var static_image: Image
var occlusion_commands: Array[Dictionary] = []
var occlusion_grid := {}
var sprite_cache := {}
var dynamic_visuals: Array[Dictionary] = []
var animation_elapsed := 0.0
var animation_revision := 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	static_layer = Sprite2D.new()
	static_layer.centered = false
	static_layer.show_behind_parent = true
	var shader := Shader.new()
	shader.code = CityMapControl.PALETTE_CYCLE_SHADER
	var shader_material := ShaderMaterial.new()
	shader_material.shader = shader
	shader_material.set_shader_parameter("palette_lookup_all", true)
	shader_material.set_shader_parameter("palette_cycle_enabled", true)
	static_layer.material = shader_material
	add_child(static_layer)


func configure(reference_root: String, palette: Sc2Palette, sprites: Sc2SpriteArchive) -> void:
	if demo_city != null or palette == null or sprites == null:
		return
	var paths := PackedStringArray()
	_collect_cities(reference_root.path_join("CITIES"), paths)
	if paths.is_empty() and FileAccess.file_exists(reference_root.path_join("DEFAULT.SC2")):
		paths.append(reference_root.path_join("DEFAULT.SC2"))
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


func _process(delta: float) -> void:
	if render_thread != null and not render_thread.is_alive():
		var result: Dictionary = render_thread.wait_to_finish()
		render_thread = null
		if result.get("ok", false):
			static_image = result.image
			demo_texture = ImageTexture.create_from_image(static_image)
			static_layer.texture = demo_texture
			occlusion_commands.assign(result.occlusion_commands)
			occlusion_grid = Renderer.build_occlusion_grid(occlusion_commands, 1)
			_refresh_animation()
	if not is_visible_in_tree() or demo_city == null:
		return
	elapsed += delta
	animation_elapsed += delta
	refresh_elapsed += delta
	# Discard this private city's UI and sound events. A blocking event can still stop its clock.
	controller.advance_time(minf(delta, 0.2) * 1000.0)
	if controller.engine.pending_disaster_type != 0 or controller.engine.active_disaster_type != 0:
		Cleanup.end_disaster(demo_city, demo_city.document, controller.engine)
	if refresh_elapsed >= 10.0 and render_thread == null:
		refresh_elapsed = 0.0
		_start_render()
	if animation_elapsed >= 0.1:
		animation_elapsed = fmod(animation_elapsed, 0.1)
		_refresh_animation()
	var camera := _camera()
	static_layer.position = camera.offset
	static_layer.scale = Vector2.ONE * float(camera.scale)
	queue_redraw()


func _start_render() -> void:
	var snapshot := CityState.from_document(demo_city.document.duplicate_document())
	render_thread = Thread.new()
	var error := render_thread.start(_render.bind(snapshot, demo_palette, demo_sprites), Thread.PRIORITY_LOW)
	if error != OK:
		render_thread = null


static func _render(snapshot: CityState, palette: Sc2Palette, sprites: Sc2SpriteArchive) -> Dictionary:
	var result := Renderer.create_image(snapshot, Sc2Palette.index_encoding(), sprites, Renderer.VIEW_LARGE, 0, false, true, false, false)
	result["occlusion_commands"] = Renderer.static_occlusion_commands(snapshot, sprites)
	return result


func _camera() -> Dictionary:
	# hold each framing for 24 seconds. integral scales preserve source pixels;
	# fractional continuous zoom makes nearest-neighbor artwork shimmer
	var shot := int(elapsed / 24.0) % 4
	var centers := [Vector2i(64, 64), Vector2i(48, 56), Vector2i(76, 64), Vector2i(62, 80)]
	var point: Vector2i = centers[shot]
	var center := Renderer.tile_polygon(demo_city, point.x, point.y)[2]
	var travel := fmod(elapsed, 24.0) - 12.0
	center += Vector2(travel * 2.0, travel)
	var pixel_scale := maxf(0.001, get_viewport_transform().get_scale().x)
	var scale := camera_zoom(shot, pixel_scale)
	var offset := ((size / 2.0 - center * scale) * pixel_scale).round() / pixel_scale
	return {"offset": offset, "scale": scale}



func _draw() -> void:
	if demo_texture == null or demo_city == null:
		return
	var camera := _camera()
	for visual in dynamic_visuals:
		draw_texture_rect(visual.texture, Rect2(camera.offset + visual.position * float(camera.scale), visual.texture.get_size() * float(camera.scale)), false)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.0, 0.0, 0.0, 0.14))


func _refresh_animation() -> void:
	if demo_city == null or static_image == null:
		return
	animation_revision += 1
	var ticks := int(elapsed * 5.0)
	var colors := Sc2Palette.new()
	for index in demo_palette.animation_index_map(ticks):
		colors.colors.append(demo_palette.colors[index])
	var cycle_image := demo_palette.animation_image(ticks)
	if cycle_texture == null:
		cycle_texture = ImageTexture.create_from_image(cycle_image)
	else:
		cycle_texture.update(cycle_image)
	static_layer.material.set_shader_parameter("animated_palette", cycle_texture)
	dynamic_visuals.clear()
	for command in Renderer.dynamic_draw_commands(demo_city, demo_sprites, Renderer.VIEW_LARGE, int(elapsed * 10.0)):
		var sprite = demo_sprites.find_sprite(int(command.sprite_id))
		if sprite == null:
			continue
		var rendered: Dictionary = sprite.create_image(colors)
		if not rendered.ok:
			continue
		var image: Image = rendered.image
		if command.flip:
			image.flip_x()
		var position := Vector2i(command.position)
		if command.shadow:
			for y in image.get_height():
				for x in image.get_width():
					var point := position + Vector2i(x, y)
					if image.get_pixel(x, y).a == 0.0 or point.x < 0 or point.y < 0 or point.x >= static_image.get_width() or point.y >= static_image.get_height():
						continue
					var index := roundi(static_image.get_pixelv(point).r * 255.0)
					image.set_pixel(x, y, colors.colors[Renderer.shadow_palette_index(index)])
		if command.get("static_occlusion", true):
			image = _occlude(image, position, int(command.depth_order))
		dynamic_visuals.append({"texture": ImageTexture.create_from_image(image), "position": Vector2(position)})


func _occlude(image: Image, position: Vector2i, order: int) -> Image:
	var bounds := Rect2i(position, image.get_size())
	for index in Renderer.occlusion_candidate_indices(occlusion_grid, bounds):
		var command := occlusion_commands[index]
		if int(command.depth_order) <= order:
			continue
		var origin := Vector2i(command.position)
		var overlap := bounds.intersection(Rect2i(origin, command.size))
		if overlap.get_area() == 0:
			continue
		var key := Vector2i(int(command.sprite_id), int(command.flip))
		if not sprite_cache.has(key):
			var sprite = demo_sprites.find_sprite(key.x)
			if sprite == null:
				continue
			var rendered: Dictionary = sprite.create_image(demo_palette)
			if not rendered.ok:
				continue
			var mask: Image = rendered.image
			if command.flip:
				mask.flip_x()
			sprite_cache[key] = mask
		var mask: Image = sprite_cache[key]
		for y in range(overlap.position.y, overlap.end.y):
			for x in range(overlap.position.x, overlap.end.x):
				if mask.get_pixel(x - origin.x, y - origin.y).a > 0.0:
					image.set_pixel(x - position.x, y - position.y, Color.TRANSPARENT)
	return image


func _exit_tree() -> void:
	if render_thread != null:
		render_thread.wait_to_finish()
		render_thread = null


static func camera_zoom(shot: int, pixel_scale: float) -> float:
	pixel_scale = maxf(0.001, pixel_scale)
	# round the minimum up to a whole output pixel to keep camera motion crisp
	var magnification := maxf(float(SHOT_MAGNIFICATIONS[shot % SHOT_MAGNIFICATIONS.size()]), ceilf(MINIMUM_ZOOM * pixel_scale))
	return magnification / pixel_scale
