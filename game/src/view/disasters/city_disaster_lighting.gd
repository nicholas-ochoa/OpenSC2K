class_name CityDisasterLighting
extends RefCounted
## Bounded screen-space illumination of the city, below all dispatch artwork.
## All lamps sample one explicit copy, so overlapping fires cannot compound contrast.

const SHADER := preload("res://src/view/disasters/disaster_light.gdshader")
const EXTENT := Vector2(192, 144)
const ANCHOR := Vector2(96, 88)
const MAX_LIGHTS := 96
var canvas: Node2D
var copy: BackBufferCopy
var lamps: Array[Sprite2D] = []
var texture: ImageTexture


func setup(map: CityMapControl, before: Node2D) -> void:
	canvas = Node2D.new()
	canvas.show_behind_parent = true
	map.add_child(canvas)
	map.move_child(canvas, before.get_index())
	copy = BackBufferCopy.new()
	copy.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	canvas.add_child(copy)
	var image := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	texture = ImageTexture.create_from_image(image)


func clear() -> void:
	if canvas != null:
		canvas.hide()


func update(sources: Array[Dictionary], offset: Vector2, scale_value: float, time: float, amount: float) -> void:
	if canvas == null:
		return
	canvas.visible = not sources.is_empty() and amount > 0.0
	if not canvas.visible:
		return
	canvas.position = offset
	canvas.scale = Vector2.ONE * scale_value
	var count := mini(sources.size(), MAX_LIGHTS)
	while lamps.size() < count:
		var sprite := Sprite2D.new()
		sprite.centered = false
		sprite.texture = texture
		sprite.scale = EXTENT
		var material := ShaderMaterial.new()
		material.shader = SHADER
		sprite.material = material
		canvas.add_child(sprite)
		lamps.append(sprite)
	for i in lamps.size():
		var lamp := lamps[i]
		lamp.visible = i < count
		if i >= count:
			continue
		# Priority sources are selected first but drawn last, above ambient fires.
		var source := sources[count - 1 - i]
		lamp.position = source.position - ANCHOR
		var material := lamp.material as ShaderMaterial
		material.set_shader_parameter("light_color", Vector3(source.color.r, source.color.g, source.color.b))
		material.set_shader_parameter("light_amount", clampf(amount * 1.8, 0.0, 1.0) * source.fade)
		material.set_shader_parameter("heat_amount", source.heat)
		material.set_shader_parameter("effect_time", time)
		material.set_shader_parameter("effect_seed", source.seed)
		material.set_shader_parameter("pixel_scale", scale_value)
