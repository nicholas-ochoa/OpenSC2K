class_name CityLifeLights
extends RefCounted
## Cosmetic emission and road-only light. All city geometry is read-only.
@warning_ignore_start("integer_division")

const HEADLIGHT := Color("ffe3a0")
const TAILLIGHT := Color("ff3426")
const FORWARD := [Vector2.UP, Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT]
const REACH := 22.0
const SURFACE_LIMIT := 1024
var masks: Dictionary[String, Image] = {}
var roads: Dictionary[Vector3i, Array] = {}
var surfaces: Dictionary[Vector4i, Dictionary] = {}
var visible_roads: Dictionary[Vector3i, Array] = {}
var geometry_reset := false
var _geometry_signature: Array = []
var _geometry_layout: Array = []
var _geometry_planes: Array[PackedByteArray] = []


# Global revisions decide when to compare. Only changed road geometry and its
# immediate connections invalidate receivers; distant development keeps them.
func sync_geometry(city: CityState) -> Dictionary[Vector2i, bool]:
	var changed: Dictionary[Vector2i, bool] = {}
	geometry_reset = false
	var layout := [city.get_instance_id(), city.map_size, city.compass_rotation(), city.visible_altitude_levels]
	var revision := [layout, city.mirror_signature(["ALTM", "XBLD", "XTER", "XZON", "XBIT"])]
	if revision == _geometry_signature:
		return changed
	_geometry_signature = revision
	# Native city setters can update a borrowed mirror in place. Own these
	# snapshots so a later edit cannot silently change both sides of the comparison.
	var planes: Array[PackedByteArray] = [city.altitude_words.to_byte_array(), city.buildings.duplicate(), city.terrain.duplicate(),
		city.zones.duplicate(), city.tile_flags.duplicate(), city.object_altitude_overrides.to_byte_array()]
	geometry_reset = layout != _geometry_layout or _geometry_planes.size() != planes.size()
	if not geometry_reset:
		for plane in planes.size():
			if planes[plane].size() != _geometry_planes[plane].size():
				geometry_reset = true
				break
			var mask := Sc2ZoneLayout.CORNERS_MASK if plane == 3 else (Sc2TileFlags.FLIPPED | Sc2TileFlags.WATER if plane == 4 else 255)
			var indices := NativeCityChanges.changed_cells(_geometry_planes[plane], planes[plane], 4 if plane in [0, 5] else 1, mask)
			if indices.size() > 1024:
				geometry_reset = true
				break
			for index in indices:
				var tile := Vector2i(index / city.map_size, index % city.map_size)
				for x in range(-1, 2):
					for y in range(-1, 2):
						changed[tile + Vector2i(x, y)] = true
	_geometry_planes = planes
	_geometry_layout = layout
	if geometry_reset:
		roads.clear()
		clear_surfaces()
		return changed
	if changed.is_empty():
		return changed
	for tile in changed:
		for axis in 2:
			var key := Vector3i(tile.x, tile.y, axis)
			roads.erase(key)
			visible_roads.erase(key)
	for key in surfaces.keys():
		for dependency in surfaces[key].occlusion_keys:
			if changed.has(Vector2i(dependency.x, dependency.y)):
				surfaces.erase(key)
				break
	return changed


func clear_surfaces() -> void:
	surfaces.clear()
	visible_roads.clear()


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
		var cached := surfaces[key]
		# Dictionary order tracks recent use. Evict one old surface, not the
		# entire working set when vehicles reach the next road tile.
		surfaces.erase(key)
		surfaces[key] = cached
		return cached
	var center := CityLifePaths.point(city, tile, enter, (enter + 2) % 4, 0.5, false)
	var bounds := Rect2i(Vector2i(center) - Vector2i(48, 48), Vector2i(96, 96))
	# Numeric world coordinates let the GPU draw the cone on sloping roads and decks.
	var image := Image.create(96, 96, false, Image.FORMAT_RGBAF)
	var occlusion_keys: Array[Vector3i] = []
	for step in 3:
		occlusion_keys.append(Vector3i(tile.x, tile.y, enter % 2))
		for road: Dictionary in _visible_road_patches(city, tile, enter, lookup):
			image.blit_rect_mask(road.image, road.image, Rect2i(Vector2i.ZERO, road.image.get_size()), road.origin - bounds.position)
		if not CityLifePaths.connected(city, tile, direction):
			break
		tile += CityLifePaths.DIRECTIONS[direction]
		enter = (direction + 2) % 4
	var result := {"image": image, "texture": ImageTexture.create_from_image(image), "origin": bounds.position,
		"occlusion_keys": occlusion_keys}
	if surfaces.size() >= SURFACE_LIMIT:
		surfaces.erase(surfaces.keys()[0])
	surfaces[key] = result
	return result


func _visible_road_patches(city: CityState, tile: Vector2i, enter: int, lookup: Callable) -> Array:
	var key := Vector3i(tile.x, tile.y, enter % 2)
	if visible_roads.has(key):
		return visible_roads[key]
	var occluders: Array = lookup.call(tile, enter) if lookup.is_valid() else []
	var result: Array = []
	for road: Dictionary in _road_patches(city, tile, enter):
		var pixels: Image = road.image.duplicate()
		var bounds := Rect2i(road.origin, pixels.get_size())
		for occluder: Dictionary in occluders:
			var overlap := bounds.intersection(Rect2i(occluder.origin, occluder.image.get_size()))
			if not overlap.has_area():
				continue
			var mask: Image = occluder.image.get_region(Rect2i(overlap.position - occluder.origin, overlap.size))
			var clear := Image.create(overlap.size.x, overlap.size.y, false, Image.FORMAT_RGBAF)
			pixels.blit_rect_mask(clear, mask, Rect2i(Vector2i.ZERO, overlap.size), overlap.position - bounds.position)
		result.append({"image": pixels, "origin": road.origin})
	visible_roads[key] = result
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
		var pixels := Image.create(raster.size.x, raster.size.y, false, Image.FORMAT_RGBAF)
		for y in range(raster.position.y, raster.end.y):
			for x in range(raster.position.x, raster.end.x):
				var uv: Vector2 = inverse * Vector2(x + 0.5, y + 0.5)
				if uv.x >= 0.0 and uv.x <= 1.0 and uv.y >= 0.0 and uv.y <= 1.0:
					var world := Vector2(tile) + forward * uv.x * 0.5 + side * (uv.y - 0.5) * 0.5
					pixels.set_pixel(x - raster.position.x, y - raster.position.y, Color(world.x, world.y, 0.0, 1.0))
		patches.append({"origin": raster.position, "image": pixels})
	roads[key] = patches
	return patches


static func _project(city: CityState, tile: Vector2i, offset: Vector2, altitude: float) -> Vector2:
	return Vector2(48 + (city.map_size + tile.x - tile.y) * 16, 520 + (tile.x + tile.y) * 8) \
		+ Vector2((offset.x - offset.y) * 16.0, (offset.x + offset.y) * 8.0 - altitude * 12.0)
