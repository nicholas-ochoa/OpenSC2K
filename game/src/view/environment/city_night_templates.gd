class_name CityNightTemplates
extends RefCounted
## Reusable road light rasters. Keys contain local geometry and light profiles;
## foreground silhouettes are applied separately at each world position.

const LIMIT := 256
var receivers: Dictionary[Array, Array] = {}
var textures: Dictionary[Array, Texture2D] = {}


func clear() -> void:
	receivers.clear()
	textures.clear()


func receiver(city: CityState, tile: Vector2i, origin: Vector2i, lights: Array[Dictionary], roads: CityLifeLights) -> Array:
	var height := CityLifePaths.edge_height(city, tile, 0)
	var key: Array = [CityLifePaths.ports(city, tile), CityLifePaths.diagonal(city, tile),
		CityLifeLights._project(city, tile, Vector2.ZERO, height) - Vector2(origin)]
	for enter in 4:
		key.append(CityLifePaths.edge_height(city, tile, enter) - height)
		for exit in 4:
			key.append(CityLifePaths.can_turn(city, tile, enter, exit))
	for light in lights:
		key.append([light.offset, light.get("enter", -1), light.color, light.radius, light.intensity])
	if receivers.has(key):
		var cached: Array = receivers[key]
		receivers.erase(key)
		receivers[key] = cached
		return cached
	var parts := _rasterize(city, tile, origin, lights, roads)
	if receivers.size() >= LIMIT:
		receivers.erase(receivers.keys()[0])
	receivers[key] = parts
	return parts


func texture(image: Image) -> Texture2D:
	# Identical masked output shares a GPU texture and can use renderer batching.
	# Compare complete bytes, not a hash alone. Visible entries retain references
	# even if an old interned texture leaves this bounded lookup table.
	var key: Array = [image.get_size(), image.get_format(), image.get_data()]
	if textures.has(key):
		var cached: Texture2D = textures[key]
		textures.erase(key)
		textures[key] = cached
		return cached
	var result := ImageTexture.create_from_image(image)
	if textures.size() >= LIMIT:
		textures.erase(textures.keys()[0])
	textures[key] = result
	return result


static func _rasterize(city: CityState, tile: Vector2i, origin: Vector2i, lights: Array[Dictionary], roads: CityLifeLights) -> Array:
	var parts: Array = []
	for enter in 4:
		if not CityLifePaths.ports(city, tile) & (1 << enter):
			continue
		var image := Image.create(64, 64, false, Image.FORMAT_RGBA8)
		var seen := {}
		for patch: Dictionary in roads._road_patches(city, tile, enter):
			var pixels: Image = patch.image
			for y in pixels.get_height():
				for x in pixels.get_width():
					var sample := pixels.get_pixel(x, y)
					if sample.a <= 0.0:
						continue
					var local: Vector2i = patch.origin + Vector2i(x, y) - origin
					if seen.has(local) or not Rect2i(0, 0, 64, 64).has_point(local):
						continue
					seen[local] = true
					var color := Color(0, 0, 0, 1)
					for light in lights:
						if light.has("enter") and int(light.enter) != enter and not CityLifePaths.can_turn(city, tile, enter, int(light.enter)):
							continue
						var distance := Vector2(sample.r, sample.g).distance_to(light.position)
						var falloff := pow(maxf(0.0, 1.0 - distance / float(light.radius)), 1.6)
						color += Color(str(light.color)) * falloff * float(light.intensity)
						color.a = 1.0
					image.set_pixelv(local, color.clamp())
		parts.append({"enter": enter, "image": image})
	return parts
