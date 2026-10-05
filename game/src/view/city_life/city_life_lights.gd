class_name CityLifeLights
extends RefCounted
## Cosmetic emission and road-only light. All city geometry is read-only.

const HEADLIGHT := Color("ffe3a0")
const TAILLIGHT := Color("ff3426")
const FORWARD := [Vector2.UP, Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT]
const REACH := 22.0
var masks: Dictionary[String, Image] = {}
var roads: Dictionary[Vector3i, Array] = {}
var surfaces: Dictionary[Vector4i, Dictionary] = {}


func lamp_mask(sprite: Image, kind: int, direction: int) -> Image:
	var key := "%d:%d" % [kind, direction]
	if not masks.has(key):
		var mask := Image.create(sprite.get_width(), sprite.get_height(), false, Image.FORMAT_RGBA8)
		for y in sprite.get_height():
			for x in sprite.get_width():
				var pixel := sprite.get_pixel(x, y)
				if pixel == Color("e9dfba"):
					mask.set_pixel(x, y, HEADLIGHT)
				elif pixel == Color("ab423b"):
					mask.set_pixel(x, y, TAILLIGHT)
		masks[key] = mask
	return masks[key]


func surface(city: CityState, tile: Vector2i, enter: int, direction: int, lookup := Callable()) -> Dictionary:
	var key := Vector4i(tile.x, tile.y, enter % 2, direction)
	if surfaces.has(key):
		return surfaces[key]
	var center := CityLifePaths.point(city, tile, enter, (enter + 2) % 4, 0.5, false)
	var bounds := Rect2i(Vector2i(center) - Vector2i(48, 48), Vector2i(96, 96))
	# Numeric world coordinates let the GPU draw the cone on sloping roads and decks.
	var image := Image.create(96, 96, false, Image.FORMAT_RGBAF)
	for step in 3:
		var occluders: Array = lookup.call(tile, enter) if lookup.is_valid() else []
		for road: Dictionary in _road_patches(city, tile, enter):
			for sample: Vector4 in road.samples:
				var point := Vector2i(int(sample.x), int(sample.y))
				if bounds.has_point(point) and not CityLifeCanvas.hidden_at(point, occluders):
					image.set_pixelv(point - bounds.position, Color(sample.z, sample.w, 0.0, 1.0))
		if not CityLifePaths.connected(city, tile, direction):
			break
		tile += CityLifePaths.DIRECTIONS[direction]
		enter = (direction + 2) % 4
	var result := {"image": image, "texture": ImageTexture.create_from_image(image), "origin": bounds.position}
	surfaces[key] = result
	return result


static func vehicle_world(city: CityState, figure: CityLifeController.Figure) -> Vector2:
	var altitude := lerpf(CityLifePaths.edge_height(city, figure.tile, figure.enter),
		CityLifePaths.edge_height(city, figure.tile, figure.exit), figure.progress)
	var local := figure.position - _project(city, figure.tile, Vector2.ZERO, altitude)
	return Vector2(figure.tile) + Vector2(local.x / 32.0 + local.y / 16.0, local.y / 16.0 - local.x / 32.0)


func _road_patches(city: CityState, tile: Vector2i, enter: int) -> Array:
	var key := Vector3i(tile.x, tile.y, enter % 2)
	if roads.has(key):
		return roads[key]
	var patches: Array = []
	var ports := CityLifePaths.ports(city, tile)
	var exit := (enter + 2) % 4
	if not ports & (1 << exit):
		for direction in 4:
			if direction != enter and ports & (1 << direction) and CityLifePaths.can_turn(city, tile, enter, direction):
				exit = direction
				break
	var height := (CityLifePaths.edge_height(city, tile, enter) + CityLifePaths.edge_height(city, tile, exit)) * 0.5
	for direction in 4:
		if not ports & (1 << direction) or (direction != enter and not CityLifePaths.can_turn(city, tile, enter, direction)):
			continue
		var forward: Vector2 = FORWARD[direction]
		var side := Vector2(-forward.y, forward.x)
		var center := _project(city, tile, Vector2.ZERO, height)
		var end := _project(city, tile, forward * 0.5, CityLifePaths.edge_height(city, tile, direction))
		var across := Vector2((side.x - side.y) * 8.0, (side.x + side.y) * 4.0)
		var transform := Transform2D(end - center, across, center - across * 0.5)
		if absf(transform.determinant()) < 0.01:
			continue
		var bounds := Rect2(transform.origin, Vector2.ZERO)
		for uv in [Vector2.RIGHT, Vector2.ONE, Vector2.DOWN]:
			bounds = bounds.expand(transform * uv)
		var inverse := transform.affine_inverse()
		var raster := Rect2i(bounds.grow(1.0))
		var samples: Array[Vector4] = []
		for y in range(raster.position.y, raster.end.y):
			for x in range(raster.position.x, raster.end.x):
				var uv: Vector2 = inverse * Vector2(x + 0.5, y + 0.5)
				if uv.x >= 0.0 and uv.x <= 1.0 and uv.y >= 0.0 and uv.y <= 1.0:
					var world := Vector2(tile) + forward * uv.x * 0.5 + side * (uv.y - 0.5) * 0.5
					samples.append(Vector4(x, y, world.x, world.y))
		patches.append({"samples": samples})
	roads[key] = patches
	return patches


static func _project(city: CityState, tile: Vector2i, offset: Vector2, altitude: float) -> Vector2:
	return Vector2(48 + (city.map_size + tile.x - tile.y) * 16, 520 + (tile.x + tile.y) * 8) \
		+ Vector2((offset.x - offset.y) * 16.0, (offset.x + offset.y) * 8.0 - altitude * 12.0)
