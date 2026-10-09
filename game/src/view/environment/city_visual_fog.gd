class_name CityVisualFog
extends RefCounted
## A resident, world-anchored mist overlay. No simulation or city writes.

const SHADER := preload("res://src/view/environment/fog_wisps.gdshader")
const HEIGHT_SHADER := preload("res://src/view/environment/fog_height.gdshader")
const WIND := Vector2(0.36, 0.16)
const WRAP := 4096.0
var app: CityApplication
var layer: ColorRect
var material: ShaderMaterial
var field: Texture2D
var drift := Vector2.ZERO
var altitude_texture: ImageTexture
var terrain_texture: ImageTexture
var terrain_signature: Array = []
var height_viewport: SubViewport
var height_rect: ColorRect
var height_material: ShaderMaterial
var height_signature: Array = []
var height_updates := 0


func _init(application: CityApplication) -> void:
	app = application


func reset() -> void:
	drift = Vector2.ZERO
	terrain_signature.clear()
	height_signature.clear()
	if height_viewport != null:
		height_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	if layer != null:
		layer.hide()


func prepare() -> void:
	if field != null:
		return
	var noise := FastNoiseLite.new()
	noise.seed = 61453
	noise.frequency = 0.01
	noise.fractal_octaves = 2
	var pixels := noise.get_seamless_image(256, 256)
	pixels.generate_mipmaps()
	field = ImageTexture.create_from_image(pixels)


func process(elapsed: float, active: bool, fog_density: float, light: Color) -> void:
	# The cloud controller owns weather selection, switches and transitions.
	var density := clampf(fog_density * 5.0, 0.0, 1.0) * 0.65 if active else 0.0
	if density <= 0.001 or app.map_view.city_source == null:
		if layer != null:
			layer.hide()
		return
	prepare()
	drift += WIND * maxf(elapsed, 0.0)
	drift = Vector2(fposmod(drift.x, WRAP), fposmod(drift.y, WRAP))
	if layer == null:
		layer = ColorRect.new()
		layer.name = "VisualFog"
		layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		material = ShaderMaterial.new()
		material.shader = SHADER
		material.set_shader_parameter("fog_field", field)
		layer.material = material
		app.map_view.add_child(layer)
	var map := app.map_view
	var city := app.document_state.city
	var scale := map.camera._view_scale()
	var source_to_canvas := map.get_global_transform() * Transform2D(Vector2(scale, 0), Vector2(0, scale), map.camera._draw_offset(scale))
	var grid := CityVisualClouds.source_to_grid(city.map_size, city.compass_rotation()) * source_to_canvas.affine_inverse()
	material.set_shader_parameter("fog_canvas_to_grid", CityVisualClouds.shader_basis(grid))
	material.set_shader_parameter("fog_map_edge", float(city.map_size))
	material.set_shader_parameter("fog_drift", drift)
	material.set_shader_parameter("fog_density", density)
	material.set_shader_parameter("fog_light", Vector3(light.r, light.g, light.b))
	var bounds := map.camera._camera_rect()
	_sync_height(city, source_to_canvas, bounds)
	layer.position = bounds.position
	layer.size = bounds.size
	# Veil the finished city and its lights; keep clouds, precipitation and
	# tool previews above the low mist. No screen copy or city-sized buffer.
	var foreground: Control = app.visual_environment.clouds.layer
	if foreground == null:
		foreground = app.visual_environment.weather.layer
	if foreground == null:
		foreground = map.layers.overlay_layer
	if foreground != null and layer.get_index() != foreground.get_index() - 1:
		map.move_child(layer, foreground.get_index() - int(layer.get_index() < foreground.get_index()))
	layer.show()


func _sync_terrain(city: CityState) -> void:
	var revision := [city.document.get_instance_id(), city.map_size,
		city.chunk_revision("ALTM"), city.chunk_revision("XTER")]
	if terrain_signature == revision:
		return
	var edge := city.map_size
	# Upload packed source planes directly; never walk all tiles in GDScript.
	# Owned GPU textures survive camera changes and update only with terrain.
	var altitude := Image.create_from_data(edge, edge, false, Image.FORMAT_RG8, city.document.find_chunk("ALTM").decoded_payload)
	var terrain := Image.create_from_data(edge, edge, false, Image.FORMAT_R8, city.document.find_chunk("XTER").decoded_payload)
	if altitude_texture == null or altitude_texture.get_width() != edge:
		altitude_texture = ImageTexture.create_from_image(altitude)
		terrain_texture = ImageTexture.create_from_image(terrain)
	else:
		altitude_texture.update(altitude)
		terrain_texture.update(terrain)
	terrain_signature = revision
	height_signature.clear()


func _sync_height(city: CityState, source_to_canvas: Transform2D, bounds: Rect2) -> void:
	_sync_terrain(city)
	if height_viewport == null:
		height_viewport = SubViewport.new()
		height_viewport.disable_3d = true
		height_viewport.world_2d = World2D.new()
		height_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		app.map_view.add_child(height_viewport)
		height_material = ShaderMaterial.new()
		height_material.shader = HEIGHT_SHADER
		height_rect = ColorRect.new()
		height_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		height_rect.material = height_material
		height_viewport.add_child(height_rect)
		material.set_shader_parameter("fog_height_mask", height_viewport.get_texture())
		material.set_shader_parameter("fog_has_height_mask", true)
	var size := Vector2i((bounds.size * minf(1.0, 768.0 / maxf(bounds.size.x, bounds.size.y))).ceil()).max(Vector2i.ONE)
	var canvas := app.map_view.get_global_transform() * Transform2D(
		Vector2(bounds.size.x / size.x, 0), Vector2(0, bounds.size.y / size.y), bounds.position)
	# The height planes use the currently rotated city arrays, not the
	# canonical weather field. Undo the camera, but not the city rotation.
	var transform := CityVisualClouds.source_to_grid(city.map_size, 0) * source_to_canvas.affine_inverse() * canvas
	var ceiling := clampf(float(city.document.misc_u32(Sc2MiscLayout.WATER_LEVEL)), 0.0, 31.0) + 2.5
	var signature := [transform, size, ceiling, city.visible_altitude_levels, city.compass_rotation()]
	if signature == height_signature:
		return
	height_viewport.size = size
	height_rect.size = Vector2(size)
	height_material.set_shader_parameter("fog_mask_to_tiles", CityVisualClouds.shader_basis(transform))
	height_material.set_shader_parameter("fog_altitudes", altitude_texture)
	height_material.set_shader_parameter("fog_terrain", terrain_texture)
	height_material.set_shader_parameter("fog_edge", city.map_size)
	height_material.set_shader_parameter("fog_ceiling", ceiling)
	height_material.set_shader_parameter("fog_visible_levels", float(city.visible_altitude_levels))
	height_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	height_signature = signature
	height_updates += 1
