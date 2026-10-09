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
var ground_views: Dictionary[int, CityNightGround] = {}
var source: CityMapSource
var blur_rects: Array[TextureRect] = []
var copies: Array[CanvasItem] = []
var moving: CityDynamicSpriteCanvas
var life: LifeEmission
var moving_revision := -1
var fades := CityLightFade.new()
var detail_enabled := true
var moving_detail_enabled := true


func _init(application: CityApplication) -> void:
	app = application


func reset() -> void:
	fades.reset()
	source = null
	moving_revision = -1
	for receiver in ground_views.values():
		receiver.reset()
		receiver.clock = 0.0


func process(active: bool, night: float, options: Dictionary, elapsed := 0.0, presentation_elapsed := 0.0) -> void:
	fades.advance(presentation_elapsed)
	detail_enabled = VisualEnhancementOptions.detail_lights_visible(options, app.map_view.zoom_factor)
	var enabled := active and night > 0.001 and app.map_view.city_source != null
	var glow := enabled and float(options.night_glow) > 0.0
	var prepare := active and detail_enabled and app.map_view.city_source != null and float(options.night_ground) > 0.0
	if output == null and not enabled and not prepare:
		return
	if output == null:
		_create()
	_select_ground(app.static_render.city_view_size())
	output.visible = glow
	for buffer in buffers:
		buffer.render_target_update_mode = SubViewport.UPDATE_ALWAYS if glow else SubViewport.UPDATE_DISABLED
	ground.sync(app, night * float(options.night_ground) / 100.0 if enabled and detail_enabled else 0.0, elapsed, prepare)
	var before: Control = app.visual_environment.clouds.layer
	if before == null:
		before = app.visual_environment.weather.layer
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


func _select_ground(view_size: int) -> void:
	# Each original-art size has different foreground silhouettes. Keep its
	# finished receivers when zoom switches to another size, rather than reset.
	if not ground_views.has(view_size):
		var receiver := CityNightGround.new()
		receiver.fades = fades
		receiver.texture_budget = int(CityNightGround.MAX_TEXTURE_BYTES / 3.0)
		app.map_view.add_child(receiver)
		ground_views[view_size] = receiver
	var next: CityNightGround = ground_views[view_size]
	if ground == next:
		return
	if ground != null:
		next.clock = ground.clock
		ground.hide()
	ground = next
	ground.signals.queue_redraw()


func invalidate_regions(changes: Array[Rect2i]) -> void:
	# An edit must also reach the currently hidden artwork-size variants.
	for receiver in ground_views.values():
		receiver.invalidate_regions(changes)


func invalidate_all() -> void:
	for receiver in ground_views.values():
		receiver.invalidate_all()


func _create() -> void:
	_select_ground(app.static_render.city_view_size())
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
	life = LifeEmission.new()
	life.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var life_material := ShaderMaterial.new()
	life_material.shader = EMISSION
	life_material.set_shader_parameter("has_emission", true)
	life.material = life_material
	scene.add_child(life)


func _rebuild(value: CityMapSource) -> void:
	var previous := source
	source = value
	# Region snapshots retain unchanged immutable mesh descriptors. Only update
	# changed light geometry instead of recreating every canvas item and material.
	if previous != null and previous.texture == null and value.texture == null \
			and previous.tiles.is_empty() and value.tiles.is_empty() \
			and previous.meshes.size() == value.meshes.size() and copies.size() == value.meshes.size():
		for index in value.meshes.size():
			var entry := value.meshes[index]
			if entry == previous.meshes[index] and entry.immutable:
				continue
			var mesh := copies[index] as MeshInstance2D
			mesh.mesh = entry.mesh
			mesh.texture = entry.texture
			mesh.position = entry.position
			mesh.scale = Vector2.ONE * entry.divisor
			var shader := mesh.material as ShaderMaterial
			shader.set_shader_parameter("emission", entry.emission)
			shader.set_shader_parameter("has_emission", entry.emission != null)
		return
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
	if moving.visible and (moving_revision != canvas.visual_revision or moving_detail_enabled != detail_enabled):
		moving_detail_enabled = detail_enabled
		moving_revision = canvas.visual_revision
		var visible_art: Array[CityDynamicVisual] = canvas.visuals.filter(func(visual: CityDynamicVisual) -> bool:
			return not visual.shadow and not visual.transparent_shadow and (detail_enabled or not visual.vehicle_light))
		moving.set_visuals(visible_art, 1.0, Vector2.ZERO)
	var figures := app.city_life.canvas
	life.figures = figures
	life.visible = detail_enabled and figures != null and figures.visible and figures.texture != null
	if life.visible:
		life.queue_redraw()


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


class LifeEmission extends Node2D:
	var figures: CityLifeCanvas


	func _draw() -> void:
		if not is_instance_valid(figures) or not figures.visible or figures.texture == null:
			return
		var atlas := figures.atlas
		# The atlas packs occupied squares; its texture coordinates are not
		# world positions. Match the vehicle canvas before blurring its lamps.
		# City life updates after lighting, so read the matching texture and
		# rectangles together at draw time, including atlas growth and panning.
		(material as ShaderMaterial).set_shader_parameter("emission", figures.emission_texture)
		for index in atlas.destinations.size():
			var destination := Rect2i(atlas.destinations[index])
			destination.position += figures.source_bounds.position
			draw_texture_rect_region(atlas.texture, destination, atlas.sources[index])
