class_name IsometricGeometry
extends IsometricConstants


@warning_ignore_start("integer_division")


static func dirty_screen_rect(
	dirty_indices: PackedInt32Array,
	sprites: Sc2SpriteArchive,
	view_size := VIEW_LARGE,
	sprite_limit := Vector2i.ZERO,
	map_edge: int = 128,
) -> Rect2i:
	var configuration := view_configuration(view_size)

	if configuration == null or sprites == null or not sprites.is_valid():
		return Rect2i()

	if sprite_limit.x <= 0 or sprite_limit.y <= 0:
		sprite_limit = maximum_sprite_size(sprites)

	if sprite_limit.x <= 0 or sprite_limit.y <= 0:
		return Rect2i()

	var result := Rect2i()
	var has_result := false
	var seen := {}

	for value in dirty_indices:
		var index := int(value)

		if index < 0 or index >= (map_edge * map_edge) or seen.has(index):
			continue

		seen[index] = true
		var x := int(index / map_edge)
		var y := index % map_edge
		var bounds := potential_tile_bounds(
			configuration, sprite_limit, x, y, map_edge
		)
		result = result.merge(bounds) if has_result else bounds
		has_result = true

	if not has_result:
		return Rect2i()

	return result.intersection(Rect2i(Vector2i.ZERO, output_size_for_view(view_size, map_edge)))


# return the largest sprite width and height in the archive
# callers reuse this limit for every tile bounds query in one pass
# returns zero when the archive is missing
static func maximum_sprite_size(sprites: Sc2SpriteArchive) -> Vector2i:
	var result := Vector2i.ZERO

	if sprites == null:
		return result

	for entry in sprites.entries:
		result.x = maxi(result.x, entry.width)
		result.y = maxi(result.y, entry.height)

	return result


# return the screen rectangle that the sprites of one tile can touch
# the rectangle allows for the full altitude range and for `sprite_limit`
# it is a conservative bound, not the painted area. region renderers cull
# with it. `dirty_screen_rect` merges it for a set of tiles
static func potential_tile_bounds(
	configuration: CityViewConfiguration, sprite_limit: Vector2i, x: int, y: int,
	map_edge: int = 128,
) -> Rect2i:
	var origin_x := (
		configuration.side_margin
		+ map_edge * configuration.half_width
	)
	var screen_x := origin_x + (x - y) * configuration.half_width
	var flat_base_y := (
		configuration.top_margin
		+ (x + y) * configuration.half_height
	)
	var top := (
		flat_base_y
		- 31 * configuration.altitude_step
		- configuration.altitude_step
		- sprite_limit.y
	)
	var bottom := (
		flat_base_y
		+ configuration.tile_height
		+ int(sprite_limit.x / 4)
		+ 1
	)

	return Rect2i(
		Vector2i(screen_x - sprite_limit.x, top),
		Vector2i(
			configuration.tile_width + sprite_limit.x * 2 + 1,
			bottom - top
		)
	)


# return the diagonals and screen columns whose tiles can touch `bounds`
# diagonal d holds the tiles with x + y == d. difference c holds the tiles
# with x - y == c. the margins allow for the largest sprite overhang and the
# full altitude range, as `potential_tile_bounds` does. the underground view
# also draws down to 31 altitude steps below the surface
# walk the diagonals in order and use `diagonal_rows` for the rows of each
static func region_tile_span(
	configuration: CityViewConfiguration, sprite_limit: Vector2i, bounds: Rect2i,
	map_edge: int, underground: bool
) -> CityRegionTileSpan:
	var half_width := configuration.half_width
	var half_height := configuration.half_height
	var origin := configuration.side_margin + map_edge * half_width
	var bottom := configuration.tile_height + int(sprite_limit.x / 4) + 1

	if underground:
		bottom += 31 * configuration.altitude_step

	var top := 32 * configuration.altitude_step + sprite_limit.y

	var result := CityRegionTileSpan.new()
	result.first_diagonal = maxi(0, floori(float(bounds.position.y - configuration.top_margin - bottom) / half_height))
	result.last_diagonal = mini(2 * (map_edge - 1), ceili(float(bounds.end.y - configuration.top_margin + top) / half_height))
	result.first_difference = floori(float(bounds.position.x - origin - sprite_limit.x - configuration.tile_width - 1) / half_width)
	result.last_difference = ceili(float(bounds.end.x - origin + sprite_limit.x) / half_width)

	return result


# return the first and last y of the tiles on `diagonal` inside `span`
static func diagonal_rows(span: CityRegionTileSpan, diagonal: int, map_edge: int) -> Vector2i:
	return Vector2i(
		maxi(maxi(0, diagonal - map_edge + 1), ceili(float(diagonal - int(span.last_difference)) / 2.0)),
		mini(mini(map_edge - 1, diagonal), floori(float(diagonal - int(span.first_difference)) / 2.0))
	)


static func surface_terrain_id(city: CityState, x: int, y: int) -> int:
	var terrain := city.terrain_id(x, y)

	if terrain < TerrainTileIds.SURFACE_WATER_FIRST or terrain > TerrainTileIds.CHANNEL_LAST or terrain == TerrainTileIds.WATERFALL:
		return terrain

	var height := city.land_altitude(x, y)

	if city.water_altitude(x, y) != height:
		return terrain

	for delta in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
		var near: Vector2i = Vector2i(x, y) + delta

		if city.index_of(near.x, near.y) >= 0 and city.land_altitude(near.x, near.y) > height:
			return TerrainTileIds.WATERFALL

	return terrain


static func terrain_sprite_id(terrain: int, water_flag: bool, sprite_base := 1000) -> int:
	var tile_id := 256

	if terrain >= TerrainTileIds.FLAT and terrain <= TerrainTileIds.LAND_DRAW_LAST:
		tile_id = 256 + terrain
	elif terrain >= TerrainTileIds.SHORE_FIRST and terrain <= TerrainTileIds.FORBIDDEN_COAST:
		tile_id = 256 + terrain - 18
	elif terrain >= TerrainTileIds.SURFACE_WATER_FIRST and terrain <= TerrainTileIds.WATERFALL:
		tile_id = 256 + terrain - 34
	elif terrain >= TerrainTileIds.CHANNEL_FIRST and terrain <= TerrainTileIds.CHANNEL_LAST:
		tile_id = 256 + terrain - 35
	elif water_flag or (terrain >= TerrainTileIds.DEEP_WATER_FIRST and terrain <= TerrainTileIds.DEEP_WATER_DRAW_LAST):
		tile_id = 270

	return sprite_base + tile_id


static func view_configuration(view_size: int) -> CityViewConfiguration:
	return CityViewConfigurations.for_size(view_size)


static func output_size_for_view(view_size: int, map_edge: int = 128) -> Vector2i:
	var configuration := view_configuration(view_size)

	if configuration == null:
		return Vector2i.ZERO

	return (IMAGE_SIZE_LARGE + Vector2i((map_edge - 128) * 32, (map_edge - 128) * 16)) / configuration.divisor


static func tile_polygon(city: CityState, x: int, y: int, land_surface := false) -> PackedVector2Array:
	var map_edge: int = city.map_size if city != null else 128

	if city == null or not city.is_valid() or city.index_of(x, y) < 0:
		return PackedVector2Array()

	var altitude := city.land_altitude(x, y)

	if not land_surface and city.terrain_id(x, y) >= TerrainTileIds.DEEP_WATER_FIRST:
		altitude = city.water_altitude(x, y)

	var origin_x := SIDE_MARGIN + map_edge * HALF_WIDTH
	var left := Vector2(
		origin_x + (x - y) * HALF_WIDTH,
		TOP_MARGIN + (x + y) * HALF_HEIGHT - altitude * ALTITUDE_STEP
	)

	return PackedVector2Array([
		left + Vector2(HALF_WIDTH, 0),
		left + Vector2(TILE_WIDTH, HALF_HEIGHT),
		left + Vector2(HALF_WIDTH, TILE_HEIGHT - 1),
		left + Vector2(0, HALF_HEIGHT),
	])


static func terrain_surface_polygon(
	city: CityState, x: int, y: int, land_surface := false
) -> PackedVector2Array:
	var polygon := tile_polygon(city, x, y, land_surface)

	if polygon.size() != 4:
		return polygon

	var terrain := city.terrain_id(x, y)

	# shoreline art can show the seabed, but its selectable surface is flat water
	if terrain < TerrainTileIds.FLAT or (not land_surface and terrain >= TerrainTileIds.DEEP_WATER_FIRST):
		return polygon

	var shape := terrain & TerrainTileIds.SHAPE_MASK
	if land_surface and terrain >= TerrainTileIds.SURFACE_WATER_FIRST:
		# water picking uses the flat surface, not the seabed drawn underneath
		# surface water encodes connecting banks, not the ground corner mask
		var mask := 0
		var altitude := city.land_altitude(x, y)
		for index in TerrainCommand.NEIGHBOR_OFFSETS.size():
			var near: Vector2i = Vector2i(x, y) + TerrainCommand.NEIGHBOR_OFFSETS[index]
			if city.index_of(near.x, near.y) >= 0 and city.land_altitude(near.x, near.y) > altitude:
				mask |= TerrainCommand.NEIGHBOR_MASKS[index]
		shape = TerrainCommand.TERRAIN_SHAPES[mask]

	if shape >= TERRAIN_SURFACE_CORNER_MASKS.size():
		return polygon

	var raised_corners: int = TERRAIN_SURFACE_CORNER_MASKS[shape]

	for corner in 4:
		if (raised_corners & (1 << corner)) != 0:
			polygon[corner].y -= ALTITUDE_STEP

	return polygon


# try the heights and keep the front tile; one inverse transform isn't enough
static func screen_to_tile(city: CityState, point: Vector2, land_surface := false) -> Vector2i:
	var map_edge: int = city.map_size if city != null else 128

	if city == null or not city.is_valid():
		return Vector2i(-1, -1)

	# a tile can use any saved land or water altitude from 0 through 31. solve
	# the isometric axes for each possible altitude, then test only nearby map
	# cells. test the visible slope surface, retaining front-most painter order
	var origin_x := SIDE_MARGIN + map_edge * HALF_WIDTH
	var difference_axis := (point.x - origin_x - HALF_WIDTH) / float(HALF_WIDTH)
	var candidates: Dictionary = {}

	for altitude in 32:
		var sum_axis := (
			(point.y - TOP_MARGIN - HALF_HEIGHT + altitude * ALTITUDE_STEP)
			/ float(HALF_HEIGHT)
		)
		var estimated_x := (sum_axis + difference_axis) * 0.5
		var estimated_y := (sum_axis - difference_axis) * 0.5
		var center_x := roundi(estimated_x)
		var center_y := roundi(estimated_y)

		for x_offset in range(-1, 2):
			for y_offset in range(-1, 2):
				var x := center_x + x_offset
				var y := center_y + y_offset

				if city.index_of(x, y) >= 0:
					candidates[x * map_edge + y] = true

	var result := Vector2i(-1, -1)
	var result_order := -1

	for index in candidates:
		var x: int = int(index) / map_edge
		var y: int = int(index) % map_edge
		var order := (x + y) * map_edge + y
		var visible := city.land_altitude(x, y) < city.visible_altitude_levels if land_surface else city.tile_is_visible(x, y)

		if not visible or order <= result_order:
			continue

		var polygon := terrain_surface_polygon(city, x, y, land_surface)

		if Geometry2D.is_point_in_polygon(point, polygon):
			result = Vector2i(x, y)
			result_order = order

	return result


static func transient_effect_position(
	city: CityState,
	effect: EffectEvent,
	sprite_height: int,
	view_size := VIEW_LARGE
) -> Vector2i:
	var map_edge: int = city.map_size if city != null else 128

	if city == null or not city.is_valid():
		return Vector2i(-1, -1)

	var point: Vector2i = effect.point

	if city.index_of(point.x, point.y) < 0 or sprite_height < 0:
		return Vector2i(-1, -1)

	var configuration := view_configuration(view_size)

	if configuration == null:
		return Vector2i(-1, -1)

	var divisor := configuration.divisor
	var large_offset: Vector2i = effect.screen_offset
	var offset := Vector2i(
		int(large_offset.x / divisor), int(large_offset.y / divisor)
	)
	var effect_altitude := int(
		effect.altitude if effect.altitude >= 0 else city.water_altitude(point.x, point.y)
	)

	return Vector2i(
		configuration.side_margin
			+ map_edge * configuration.half_width
			+ (point.x - point.y) * configuration.half_width + offset.x,
		configuration.top_margin
			+ (point.x + point.y) * configuration.half_height
			- effect_altitude * configuration.altitude_step
			- sprite_height + offset.y
	)


static func bridge_effect_position(
	city: CityState,
	effect: EffectEvent,
	sprite_height: int,
	view_size := VIEW_LARGE
) -> Vector2i:
	return transient_effect_position(city, effect, sprite_height, view_size)


static func effect_sprite_id(large_sprite_id: int, view_size := VIEW_LARGE) -> int:
	var configuration := view_configuration(view_size)

	if configuration == null or large_sprite_id < 1000:
		return -1

	return configuration.sprite_base + large_sprite_id - 1000
