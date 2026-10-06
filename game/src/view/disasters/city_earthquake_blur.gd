class_name CityEarthquakeBlur
extends RefCounted

const SHADER := preload("res://src/view/disasters/earthquake_blur.gdshader")
var canvas: Node2D
var rect: ColorRect
var material: ShaderMaterial


func update(map: CityMapControl, amount: float) -> void:
	if canvas == null and amount <= 0.0:
		return
	if canvas == null:
		canvas = Node2D.new()
		canvas.show_behind_parent = true
		map.add_child(canvas)
		# The map's selection and interface stay crisp above this city-only pass.
		var copy := BackBufferCopy.new()
		copy.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
		canvas.add_child(copy)
		rect = ColorRect.new()
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		material = ShaderMaterial.new()
		material.shader = SHADER
		rect.material = material
		canvas.add_child(rect)
	canvas.visible = amount > 0.0
	rect.size = map.size
	material.set_shader_parameter("amount", clampf(amount, 0.0, 1.0))
