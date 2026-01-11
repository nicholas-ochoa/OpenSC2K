class_name MainMenuCityBackground
extends Control

const Renderer = preload("res://src/view/city_isometric_renderer.gd")
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


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


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
			demo_texture = ImageTexture.create_from_image(result.image)
	if not is_visible_in_tree() or demo_city == null:
		return
	elapsed += delta
	refresh_elapsed += delta
	# Discard this private city's UI and sound events. A blocking event can still stop its clock.
	controller.advance_time(minf(delta, 0.2) * 1000.0)
	if controller.engine.pending_disaster_type != 0 or controller.engine.active_disaster_type != 0:
		Cleanup.end_disaster(demo_city, demo_city.document, controller.engine)
	if refresh_elapsed >= 10.0 and render_thread == null:
		refresh_elapsed = 0.0
		_start_render()
	queue_redraw()


func _start_render() -> void:
	var snapshot := CityState.from_document(demo_city.document.duplicate_document())
	render_thread = Thread.new()
	var error := render_thread.start(_render.bind(snapshot, demo_palette, demo_sprites), Thread.PRIORITY_LOW)
	if error != OK:
		render_thread = null


static func _render(snapshot: CityState, palette: Sc2Palette, sprites: Sc2SpriteArchive) -> Dictionary:
	return Renderer.create_image(snapshot, palette, sprites, Renderer.VIEW_LARGE, 0, true, false, false)


func _draw() -> void:
	if demo_texture == null or demo_city == null:
		return
	var center := Renderer.tile_polygon(demo_city, 64, 64)[2]
	center += Vector2(sin(elapsed / 50.0) * 460.0, cos(elapsed / 67.0) * 160.0)
	var scale := maxf(size.x / 2400.0, size.y / 1250.0) * (1.05 + 0.08 * sin(elapsed / 83.0))
	draw_texture_rect(demo_texture, Rect2(size / 2.0 - center * scale, demo_texture.get_size() * scale), false)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.0, 0.0, 0.0, 0.14))


func _exit_tree() -> void:
	if render_thread != null:
		render_thread.wait_to_finish()
		render_thread = null
