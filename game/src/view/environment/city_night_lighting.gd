class_name CityNightLighting
extends RefCounted
## Presentation-only light buffers. Shares static meshes and authored brightmaps.

const EMISSION := preload("res://src/view/environment/night_emission.gdshader")
const BLUR := preload("res://src/view/environment/night_blur.gdshader")
const GLOW := preload("res://src/view/environment/night_glow.gdshader")
const PADDING := 24.0
var app: CityApplication
var buffers: Array[SubViewport] = []
var scene: Node2D
var output: TextureRect
var ground: CityNightGround
var source: CityMapSource
var blur_rects: Array[TextureRect] = []
var copies: Array[CanvasItem] = []
var moving: CityDynamicSpriteCanvas
var life: TextureRect
var moving_revision := -1


func _init(application: CityApplication) -> void:
	app = application


func reset() -> void:
	source = null
	moving_revision = -1
	if ground != null:
		ground.reset()


func process(active: bool, night: float, options: Dictionary) -> void:
	var enabled := active and night > 0.001 and app.map_view.city_source != null
	var glow := enabled and float(options.night_glow) > 0.0
	if output == null and not enabled:
		return
	if output == null:
		_create()
	output.visible = glow
	for buffer in buffers:
		buffer.render_target_update_mode = SubViewport.UPDATE_ALWAYS if glow else SubViewport.UPDATE_DISABLED
	ground.sync(app, night * float(options.night_ground) / 100.0 if enabled else 0.0)
	var before: Control = app.visual_environment.weather.layer
	if before == null:
		before = app.map_view.layers.overlay_layer
	if before != null:
		if ground.get_index() > before.get_index():
			app.map_view.move_child(ground, before.get_index())
		if output.get_index() > before.get_index():
			app.map_view.move_child(output, before.get_index())
	if not glow:
		return
	var map := app.map_view
	var bounds := map.camera._camera_rect()
	var padded := bounds.grow(PADDING)
	var reduction := minf(0.5, 1024.0 / maxf(padded.size.x, padded.size.y))
	var size := Vector2i((padded.size * reduction).ceil())
	for buffer in buffers:
		buffer.size = size
	for rect in blur_rects:
		rect.size = Vector2(size)
		(rect.material as ShaderMaterial).set_shader_parameter("radius", maxf(0.65, map.camera._view_scale() * reduction * 1.5))
	var view_scale := map.camera._view_scale()
	scene.scale = Vector2.ONE * view_scale * reduction
	scene.position = (map.camera._draw_offset(view_scale) - padded.position) * reduction
	if source != map.city_source:
		_rebuild(map.city_source)
	_sync_moving()
	output.position = bounds.position
	output.size = bounds.size
	var shader := output.material as ShaderMaterial
	shader.set_shader_parameter("strength", night * float(options.night_glow) / 100.0 * 1.6)
	shader.set_shader_parameter("sample_scale", bounds.size * reduction / Vector2(size))
	shader.set_shader_parameter("sample_offset", Vector2.ONE * PADDING * reduction / Vector2(size))


func _create() -> void:
	ground = CityNightGround.new()
	app.map_view.add_child(ground)
	for i in 3:
		var buffer := SubViewport.new()
		buffer.disable_3d = true
		buffer.size = Vector2i(8, 8)
		buffer.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
		buffer.transparent_bg = true
		buffer.use_hdr_2d = app.map_view.get_viewport().use_hdr_2d
		buffer.world_2d = World2D.new()
		app.map_view.add_child(buffer)
		buffers.append(buffer)
		if i == 0:
			scene = Node2D.new()
			buffer.add_child(scene)
		else:
			var rect := TextureRect.new()
			rect.texture = buffers[i - 1].get_texture()
			rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
			var shader := ShaderMaterial.new()
			shader.shader = BLUR
			shader.set_shader_parameter("direction", Vector2.RIGHT if i == 1 else Vector2.DOWN)
			rect.material = shader
			buffer.add_child(rect)
			blur_rects.append(rect)
	output = TextureRect.new()
	output.name = "NightLightGlow"
	output.mouse_filter = Control.MOUSE_FILTER_IGNORE
	output.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	output.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	output.texture = buffers.back().get_texture()
	var material := ShaderMaterial.new()
	material.shader = GLOW
	output.material = material
	app.map_view.add_child(output)
	moving = CityDynamicSpriteCanvas.new()
	var moving_material := ShaderMaterial.new()
	moving_material.shader = preload("res://src/view/environment/night_moving_emission.gdshader")
	moving.material = moving_material
	scene.add_child(moving)
	life = TextureRect.new()
	life.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	life.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var life_material := ShaderMaterial.new()
	life_material.shader = EMISSION
	life_material.set_shader_parameter("has_emission", true)
	life.material = life_material
	scene.add_child(life)


func _rebuild(value: CityMapSource) -> void:
	source = value
	for copy in copies:
		copy.free()
	copies.clear()
	if value.texture != null:
		_add_texture(value.texture, value.emission, Vector2.ZERO, Vector2(value.size))
	for tile in value.tiles:
		_add_texture(tile.texture, tile.emission, tile.position, tile.size)
	for entry in value.meshes:
		var mesh := MeshInstance2D.new()
		mesh.mesh = entry.mesh
		mesh.texture = entry.texture
		mesh.position = entry.position
		mesh.scale = Vector2.ONE * entry.divisor
		_register(mesh, entry.emission)
	scene.move_child(moving, -1)
	scene.move_child(life, -1)


func _sync_moving() -> void:
	var canvas := app.map_view.layers.dynamic_canvas
	moving.visible = canvas != null and canvas.visible
	if moving.visible and moving_revision != canvas.visual_revision:
		moving_revision = canvas.visual_revision
		var visible_art: Array[CityDynamicVisual] = canvas.visuals.filter(func(visual: CityDynamicVisual) -> bool:
			return not visual.shadow and not visual.transparent_shadow)
		moving.set_visuals(visible_art, 1.0, Vector2.ZERO)
	var figures := app.city_life.canvas
	life.visible = figures != null and figures.visible and figures.texture != null
	if life.visible:
		life.texture = figures.texture
		life.position = figures.source_bounds.position
		life.size = figures.source_bounds.size
		(life.material as ShaderMaterial).set_shader_parameter("emission", figures.emission_texture)


func _add_texture(texture: Texture2D, emission: Texture2D, position: Vector2, size: Vector2) -> void:
	var rect := TextureRect.new()
	rect.texture = texture
	rect.position = position
	rect.size = size
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_register(rect, emission)


func _register(item: CanvasItem, emission: Texture2D) -> void:
	var material := ShaderMaterial.new()
	material.shader = EMISSION
	material.set_shader_parameter("emission", emission)
	material.set_shader_parameter("has_emission", emission != null)
	item.material = material
	item.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	scene.add_child(item)
	copies.append(item)
