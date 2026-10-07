class_name CityTornadoRenderer
extends RefCounted
## Keep original indexed artwork. Scroll through a retained foreground mask on the GPU.

const SHADER := preload("res://src/view/disasters/tornado_sprite.gdshader")
const PADDING := Vector2i(48, 48)
var app: CityApplication
var canvas: Node2D
var entries: Dictionary[int, Entry] = {}
var seen: Dictionary[int, bool] = {}
var signature: Array = []
var mask_builds := 0


func process(delta: float) -> void:
	var blending: bool = app.preferences.visual_enhancements.disaster_blending
	for entry in entries.values():
		if not app.moving_sprites.hazard_animation.frozen():
			entry.blend = minf(1.0, entry.blend + clampf(delta, 0.0, 0.25) / 0.1)
		entry.material.set_shader_parameter("frame_mix", entry.blend if blending else 1.0)


func _init(application: CityApplication) -> void:
	app = application


func begin() -> void:
	seen.clear()
	var city := app.document_state.city
	var next: Array = [] if city == null else [city.document.get_instance_id(), city.compass_rotation(), city.visible_altitude_levels]
	if next != signature:
		for entry in entries.values():
			entry.sprite.queue_free()
		entries.clear()
		signature = next


func draw(command: CityDynamicCommand, source: CityDynamicCommand, resource: CitySpriteResource, position: Vector2, divisor: int) -> void:
	if canvas == null:
		canvas = Node2D.new()
		canvas.show_behind_parent = true
		canvas.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		app.map_view.add_child(canvas)
		app.map_view.move_child(canvas, app.map_view.layers.dynamic_canvas.get_index())
	var entry: Entry = entries.get(command.record)
	if entry == null:
		entry = Entry.new()
		entry.sprite = Sprite2D.new()
		entry.sprite.centered = false
		entry.material = ShaderMaterial.new()
		entry.material.shader = SHADER
		entry.sprite.material = entry.material
		canvas.add_child(entry.sprite)
		entries[command.record] = entry
	seen[command.record] = true
	if entry.divisor != divisor:
		entry.current = null
		entry.resource = null
		entry.divisor = divisor
	var blending: bool = app.preferences.visual_enhancements.disaster_blending
	var extent := resource.native_size
	if blending:
		if entry.current != resource.texture:
			var previous := entry.resource if entry.resource != null else resource
			entry.blend = 0.0 if entry.resource != null else 1.0
			entry.extent = Vector2i(maxi(previous.native_size.x, extent.x), maxi(previous.native_size.y, extent.y))
			var atlas := Image.create(entry.extent.x, entry.extent.y * 2, false, Image.FORMAT_RGBA8)
			# Tornado art is anchored at its lower right corner.
			atlas.blit_rect(previous.image, Rect2i(Vector2i.ZERO, previous.native_size), entry.extent - previous.native_size)
			atlas.blit_rect(resource.image, Rect2i(Vector2i.ZERO, extent), entry.extent - extent + Vector2i(0, entry.extent.y))
			entry.atlas = ImageTexture.create_from_image(atlas)
			entry.current = resource.texture
			entry.resource = resource
		entry.sprite.texture = entry.atlas
		entry.sprite.scale = Vector2(1.0, 0.5)
		position += Vector2(extent - entry.extent)
		extent = entry.extent
	else:
		entry.current = null
		entry.resource = null
		entry.sprite.texture = resource.texture
		entry.sprite.scale = Vector2.ONE
	entry.material.set_shader_parameter("frame_blending", blending)
	entry.material.set_shader_parameter("frame_mix", entry.blend if blending else 1.0)
	entry.sprite.position = position
	# The padded mask is fixed to the confirmed tile, not rebuilt per interpolated pixel.
	var bounds := Rect2i(source.position * divisor + resource.native_size - extent - PADDING, extent + PADDING * 2)
	var key: Array = [bounds, command.depth_order, app.static_render_state.epoch, divisor]
	if key != entry.mask_signature:
		entry.mask_signature = key
		var tile := IsometricFloatingOcclusion.depth_tile(command.depth_order, app.document_state.city.map_size)
		var mask := app.moving_sprites.effect_occluder_mask(bounds.position, bounds.size, tile, app.static_render.city_view_size())
		entry.material.set_shader_parameter("has_foreground", mask != null)
		if mask != null:
			entry.material.set_shader_parameter("foreground", ImageTexture.create_from_image(mask))
		mask_builds += 1
	entry.material.set_shader_parameter("mask_offset", position - Vector2(bounds.position))
	entry.material.set_shader_parameter("mask_size", Vector2(bounds.size))
	entry.material.set_shader_parameter("sprite_size", Vector2(extent))
	entry.material.set_shader_parameter("animated_palette", app.map_view.animated_palette_texture)
	app.map_view.layers._apply_environment(entry.material)
	entry.sprite.show()


func finish() -> void:
	for record in entries.keys():
		if not seen.has(record):
			entries[record].sprite.queue_free()
			entries.erase(record)
	if canvas != null:
		canvas.visible = not entries.is_empty()
		sync_transform()


func sync_transform() -> void:
	if canvas != null:
		var scale_value := app.map_view.camera._view_scale()
		canvas.scale = Vector2.ONE * scale_value
		canvas.position = app.map_view.camera._draw_offset(scale_value)


class Entry extends RefCounted:
	var divisor := -1
	var resource: CitySpriteResource
	var current: Texture2D
	var atlas: Texture2D
	var extent := Vector2i.ZERO
	var blend := 1.0
	var sprite: Sprite2D
	var material: ShaderMaterial
	var mask_signature: Array = []
