class_name MainMenuPresentation
extends RefCounted
## A detached presentation context. It never enters the scene tree, loads settings,
## activates a player document, advances simulation, or receives save/quit events.

var app := CityApplication.new()
var map: CityMapControl
var needs_render := false


func _init(parent: Control, city: CityState, controller: GameSpeedController,
		palette: Sc2Palette, sprites: Sc2SpriteArchive, options: Dictionary) -> void:
	app.frame = MenuFrame.new(app)
	app.static_render = MenuStaticRender.new(app)
	var rendering := MenuMapRender.new(app)
	rendering.refresh_requested.connect(func() -> void: needs_render = true)
	app.map_render = rendering
	app.asset_state.palette = palette
	app.asset_state.palette_index_encoding = Sc2Palette.index_encoding()
	app.asset_state.large_sprites = copy_graphics(sprites)
	app.preferences.visual_enhancements = options.duplicate()
	app.visual_environment.reload_brightmaps(false)
	map = CityMapControl.new()
	map.name = "MenuCityView"
	map.show_behind_parent = true
	parent.add_child(map)
	map.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	map.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map.set_process(false)
	map.set_process_input(false)
	map.set_process_unhandled_input(false)
	map.signs_visible = false
	app.map_view = map
	app.document_state.city = city
	app.simulation_state.speed_controller = controller
	app.simulation_state.simulation_engine = controller.engine
	# The background keeps its existing private simulation controller. Rendering
	# consumes it without changing its speed, document, random state or save path.
	app.asset_state.large_sprites.visual_city_life_traffic = bool(options.life_cars_enabled)
	app.visual_environment.configure()


static func copy_graphics(source: Sc2SpriteArchive) -> Sc2SpriteArchive:
	var copy := Sc2SpriteArchive.new()
	copy.entries.assign(source.entries)
	copy.entries_by_id.assign(source.entries_by_id)
	copy.redraw_small_highway_ground = source.redraw_small_highway_ground
	copy.visual_emission.assign(source.visual_emission)
	copy.visual_seasons.assign(source.visual_seasons)
	copy.visual_nature.assign(source.visual_nature)
	copy.visual_nature_masks.assign(source.visual_nature_masks)
	copy.visual_nature_enabled = source.visual_nature_enabled
	copy.visual_terrain_enabled = source.visual_terrain_enabled
	copy.visual_revision = source.visual_revision
	copy.water_reflections = source.water_reflections
	copy.water_indices = source.water_indices
	copy.visual_city_life_traffic = source.visual_city_life_traffic
	return copy


func set_options(options: Dictionary) -> void:
	if app.preferences.visual_enhancements == options:
		return
	app.preferences.visual_enhancements = options.duplicate()
	app.visual_environment.configure()


func reload_visual_assets() -> void:
	app.visual_environment.reload_brightmaps(false)
	app.visual_environment.profiles.reload(app.preferences.visual_enhancements.lut_folder)
	app.visual_environment._load_custom_lut(app.preferences.visual_enhancements.lut_path)
	needs_render = true


func publish(image: Image, texture: ImageTexture, city: CityState, commands: Array[CityStaticCommand]) -> void:
	app.render_caches.static_city_image = image
	app.render_caches.static_display_city = city
	app.render_caches.static_render_mode = CityViewMode.Mode.CITY
	app.static_render_state.epoch += 1
	app.moving_sprites.set_static_occlusion_commands(commands, CityIsometricRenderer.VIEW_LARGE)
	var source := CityMapSource.new(image.get_size())
	source.texture = texture
	map.set_city_view(city, source, null, true)


func animate(palette: ImageTexture) -> void:
	map.animated_palette_texture = palette
	map.layers._sync_base_material()
	app.moving_sprites.refresh_moving_things(CityIsometricRenderer.VIEW_LARGE)


func advance(delta: float, offset: Vector2, zoom: float) -> void:
	map.zoom_factor = zoom
	map.source_center = (map.size / 2.0 - offset) / zoom
	map.layers._sync_base_layer()
	app.visual_environment.process(delta)
	app.city_life.process(delta)
	app.moving_sprites.process(delta)
	map.queue_redraw()


func close() -> void:
	app.visual_environment.weather.reset()
	map.free()
	app.free()


class MenuFrame extends ApplicationFrame:
	func _simulation_suspended() -> bool:
		return app.simulation_state.speed_controller.interaction_blocked or app.simulation_state.speed_controller.terminal_blocked


class MenuStaticRender extends ApplicationStaticRender:
	# Keep the published picture and its occlusion/masks until the worker replaces it.
	func invalidate_rendered_city() -> void:
		state.epoch += 1
		clear_dynamic_composition_cache()

	func city_view_size() -> int:
		return CityIsometricRenderer.VIEW_LARGE


class MenuMapRender extends ApplicationMapRender:
	signal refresh_requested

	func refresh_map(_force := true) -> void:
		refresh_requested.emit()
