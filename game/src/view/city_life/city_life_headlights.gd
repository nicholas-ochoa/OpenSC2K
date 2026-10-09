class_name CityLifeHeadlights
extends Node2D
## Stable texture-array slots keep moving headlights in a few GPU draw calls.
@warning_ignore_start("integer_division")

const GROUP_SIZE := 64
const STRIDE := 8
const SHADER := preload("res://src/view/city_life/city_life_headlights.gdshader")
var groups: Array[MultiMeshInstance2D] = []
var textures: Array[Texture2DArray] = []
var buffers: Array[PackedFloat32Array] = []
var parameters: Array[PackedFloat32Array] = []
var parameter_textures: Array[ImageTexture] = []
var images: Array[Image] = []
var slots: Dictionary[int, int] = {}
var free_slots: Array[int] = []
var night := 0.0


func set_night(value: float) -> void:
	night = value
	for group in groups:
		(group.material as ShaderMaterial).set_shader_parameter("night", night)


func render(city: CityState, figures: Array, lights: CityLifeLights, offset: Vector2i, lookup: Callable) -> void:
	var seen: Dictionary[int, bool] = {}
	for figure: CityLifeController.Figure in figures:
		if not figure.walking:
			seen[figure.id] = true
	for id in slots.keys():
		if not seen.has(id):
			var slot := slots[id]
			slots.erase(id)
			free_slots.append(slot)
			images[slot] = null
			var group := slot / GROUP_SIZE
			var at := (slot % GROUP_SIZE) * STRIDE
			buffers[group][at] = 0.0
			buffers[group][at + 5] = 0.0
	for figure: CityLifeController.Figure in figures:
		if figure.walking:
			continue
		var surface := lights.surface(city, figure.tile, figure.enter, figure.direction, lookup)
		if not slots.has(figure.id):
			if free_slots.is_empty():
				_add_group()
			slots[figure.id] = free_slots.pop_back()
		var slot := slots[figure.id]
		var group := slot / GROUP_SIZE
		var layer := slot % GROUP_SIZE
		if images[slot] != surface.image:
			textures[group].update_layer(surface.image, layer)
			images[slot] = surface.image
		var at := layer * STRIDE
		var point: Vector2i = surface.origin - offset
		var world := CityLifeLights.vehicle_world(city, figure)
		# Keep world coordinates in a full-precision texture: Compatibility
		# rendering can reduce instance custom data precision.
		buffers[group][at] = 1.0
		buffers[group][at + 3] = point.x
		buffers[group][at + 5] = 1.0
		buffers[group][at + 7] = point.y
		parameters[group][layer * 4] = world.x
		parameters[group][layer * 4 + 1] = world.y
		parameters[group][layer * 4 + 2] = figure.direction + figure.vehicle_kind * 8
		parameters[group][layer * 4 + 3] = figure.opacity()
	for index in groups.size():
		groups[index].multimesh.buffer = buffers[index]
		parameter_textures[index].update(Image.create_from_data(GROUP_SIZE, 1, false, Image.FORMAT_RGBAF, parameters[index].to_byte_array()))


func _add_group() -> void:
	var blank := Image.create(96, 96, false, Image.FORMAT_RGBAF)
	var layers: Array[Image] = []
	layers.resize(GROUP_SIZE)
	layers.fill(blank)
	var texture := Texture2DArray.new()
	texture.create_from_images(layers)
	var geometry := QuadMesh.new()
	geometry.size = Vector2(96, 96)
	geometry.center_offset = Vector3(48, 48, 0)
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_2D
	multi.mesh = geometry
	multi.instance_count = GROUP_SIZE
	var shader := ShaderMaterial.new()
	shader.shader = SHADER
	shader.set_shader_parameter("surfaces", texture)
	shader.set_shader_parameter("night", night)
	var values := PackedFloat32Array()
	values.resize(GROUP_SIZE * 4)
	var parameter_texture := ImageTexture.create_from_image(Image.create_from_data(GROUP_SIZE, 1, false, Image.FORMAT_RGBAF, values.to_byte_array()))
	shader.set_shader_parameter("headlight_data", parameter_texture)
	var group := MultiMeshInstance2D.new()
	group.multimesh = multi
	group.material = shader
	add_child(group)
	var buffer := PackedFloat32Array()
	buffer.resize(GROUP_SIZE * STRIDE)
	buffer.fill(0.0)
	multi.buffer = buffer
	var start := images.size()
	images.resize(start + GROUP_SIZE)
	for slot in range(start + GROUP_SIZE - 1, start - 1, -1):
		free_slots.append(slot)
	groups.append(group)
	textures.append(texture)
	buffers.append(buffer)
	parameters.append(values)
	parameter_textures.append(parameter_texture)
