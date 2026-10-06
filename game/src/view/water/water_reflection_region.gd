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
	var images: Array[Image] = []
	var placements := PackedInt32Array()
	for sprite in overlapping:
		images.append(sprite.image)
		images.append(sprite.emission)
		placements.append_array(PackedInt32Array([sprite.position.x, sprite.position.y, sprite.level]))
	var composed := NativeSpriteCompositor.water_moving(surface, reflected, emission, seasons,
		images, placements, Vector3i(area.position.x, area.position.y, divisor))
	# Region dimensions stay fixed. Keep GPU allocations while ships move.
	for key in ["reflected", "emission", "seasons"]:
		if moving_textures.has(key):
			(moving_textures[key] as ImageTexture).update(composed[key])
		else:
			moving_textures[key] = ImageTexture.create_from_image(composed[key])
	return moving_textures
