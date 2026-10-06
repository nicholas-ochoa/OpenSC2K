class_name WaterReflectionRegion
extends RefCounted
## Worker-owned images become textures only on the main thread.

const PADDING := 3

var bounds := Rect2i()
var divisor := 1
var surface: Image
var reflected: Image
var emission: Image
var seasons: Image
var seabed: Image
var textures: Dictionary = {}
var moving_signature: Array = []
var moving_textures: Dictionary = {}


static func from_native(data: Dictionary, area: Rect2i, scale_divisor: int) -> WaterReflectionRegion:
	if data.is_empty() or data.has("error"):
		return null
	var result := WaterReflectionRegion.new()
	result.bounds = area.grow(PADDING)
	result.divisor = scale_divisor
	result.surface = data.surface
	result.reflected = data.reflected
	result.emission = data.emission
	result.seasons = data.seasons
	result.seabed = data.get("seabed")
	return result


func upload() -> void:
	if not textures.is_empty():
		return
	for pair in [["surface", surface], ["reflected", reflected], ["emission", emission], ["seasons", seasons], ["seabed", seabed]]:
		if pair[1] != null:
			textures[pair[0]] = ImageTexture.create_from_image(pair[1])


func prepare(material: ShaderMaterial) -> void:
	upload()
	material.set_shader_parameter("water_surface", textures.surface)
	material.set_shader_parameter("environment_emission", textures.emission)
	material.set_shader_parameter("environment_has_emission", true)
	material.set_shader_parameter("environment_season_mask", textures.seasons)
	material.set_shader_parameter("environment_has_seasons", true)
	material.set_shader_parameter("water_seabed", textures.get("seabed"))
	material.set_shader_parameter("water_has_seabed", textures.has("seabed"))
	material.set_shader_parameter("water_origin", Vector2(bounds.position * divisor))
	material.set_shader_parameter("water_divisor", float(divisor))
	material.set_shader_parameter("water_padding", float(PADDING))


func compose_moving(sprites: Array[WaterReflectionSprite]) -> Dictionary:
	var overlapping: Array[WaterReflectionSprite] = []
	var signature: Array = []
	var area := Rect2i(bounds.position * divisor, bounds.size * divisor)
	for sprite in sprites:
		if area.intersects(Rect2i(sprite.position, sprite.image.get_size())):
			overlapping.append(sprite)
			signature.append(sprite)
	if signature == moving_signature:
		return moving_textures
	moving_signature = signature
	if overlapping.is_empty():
		moving_textures.clear()
		return moving_textures
	var pixels := reflected.duplicate()
	var lights := emission.duplicate()
	var natural := seasons.duplicate()
	for sprite in overlapping:
		var overlap := area.intersection(Rect2i(sprite.position, sprite.image.get_size()))
		var first := Vector2i((Vector2(overlap.position - area.position) / divisor).floor())
		var last := Vector2i((Vector2(overlap.end - area.position) / divisor).ceil())
		for y in range(first.y, last.y):
			for x in range(first.x, last.x):
				var mask := surface.get_pixel(x, y)
				if mask.a == 0 or roundi(mask.r * 255.0) != sprite.level + 1:
					continue
				var point := area.position + Vector2i(x, y) * divisor - sprite.position
				if not Rect2i(Vector2i.ZERO, sprite.image.get_size()).has_point(point):
					continue
				var pixel := sprite.image.get_pixelv(point)
				if pixel.a == 0:
					continue
				pixels.set_pixel(x, y, pixel)
				lights.set_pixel(x, y, sprite.emission.get_pixelv(point))
				natural.set_pixel(x, y, Color.TRANSPARENT)
	# Region dimensions stay fixed. Keep GPU allocations while ships move.
	for pair in [["reflected", pixels], ["emission", lights], ["seasons", natural]]:
		if moving_textures.has(pair[0]):
			(moving_textures[pair[0]] as ImageTexture).update(pair[1])
		else:
			moving_textures[pair[0]] = ImageTexture.create_from_image(pair[1])
	return moving_textures
