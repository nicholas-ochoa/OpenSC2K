class_name SpecialZonePlacement
extends SpecialZoneConstants



const UnderTiles = preload("res://src/tools/shared/underground_tile_ids.gd")

class Result extends RefCounted:
	var ok := false
	var changed_tiles := 0


static func _place_runway(
	buildings: PackedByteArray,
	zones: PackedByteArray,
	flags: PackedByteArray,
	misc: PackedByteArray,
	point: Vector2i,
	zone: int,
	rotation: int,
	map_edge: int = 128,
	terrain: PackedByteArray = PackedByteArray(),
	underground: PackedByteArray = PackedByteArray(),
) -> Result:
	# military runway orientation uses its own count, as in sc2kfix
	var count := SpecialZoneState._special_tile_count(misc, Tiles.RUNWAY, zone == 7, map_edge)
	var direction := Vector2i.ZERO

	if count & 1 == 0:
		if point.x & 1:
			direction = Vector2i(0, 1)
		elif point.y & 1:
			direction = Vector2i(1, 0)
		else:
			var result := Result.new()
			result.ok = false
			result.changed_tiles = 0

			return result
	else:
		if point.y & 1:
			direction = Vector2i(1, 0)
		elif point.x & 1:
			direction = Vector2i(0, 1)
		else:
			var result := Result.new()
			result.ok = false
			result.changed_tiles = 0

			return result

	var new_tiles := 0
	var checked := point

	while SpecialZoneState._index(checked, map_edge) >= 0:
		var checked_index := SpecialZoneState._index(checked, map_edge)

		if (zones[checked_index] & Sc2ZoneLayout.TYPE_MASK) != zone:
			var result := Result.new()
			result.ok = false
			result.changed_tiles = 0

			return result

		if zone == 7:
			var tile := int(buildings[checked_index])
			if (tile >= Tiles.FIRST_ROAD and tile <= Tiles.LAST_ROAD) or tile == Tiles.CRANE or tile == Tiles.MISSILE_SILO:
				var result := Result.new()
				result.ok = false
				result.changed_tiles = 0

				return result
			if (not terrain.is_empty() and terrain[checked_index] != TerrainTileIds.FLAT) or (not underground.is_empty() and underground[checked_index] != UnderTiles.EMPTY):
				var result := Result.new()
				result.ok = false
				result.changed_tiles = 0

				return result

		if buildings[checked_index] == Tiles.RUNWAY or buildings[checked_index] == Tiles.RUNWAY_CROSSING:
			new_tiles -= 1

		new_tiles += 1
		checked += direction

		if new_tiles >= 5:
			break

	if new_tiles < 5:
		var result := Result.new()
		result.ok = false
		result.changed_tiles = 0

		return result

	var flip := SpecialZoneState._special_axis_is_flipped(direction.x, rotation)
	var changed_tiles := 0
	var placed_tiles := 0
	var current := point

	while placed_tiles < 5:
		var index := SpecialZoneState._index(current, map_edge)
		var current_tile := int(buildings[index])

		if current_tile == Tiles.RUNWAY or current_tile == Tiles.RUNWAY_CROSSING:
			placed_tiles -= 1

			if current_tile == Tiles.RUNWAY and bool(flags[index] & Sc2TileFlags.FLIPPED) != flip:
				SpecialZoneState._replace_special_building(buildings, zones, misc, index, Tiles.RUNWAY_CROSSING)
				zones[index] |= Sc2ZoneLayout.CORNERS_MASK

				if zone != 7:
					flags[index] |= Sc2TileFlags.POWER_MASK

				flags[index] &= ~Sc2TileFlags.FLIPPED & 0xff
				changed_tiles += 1
		else:
			_clear_special_building(buildings, zones, flags, misc, current, map_edge)
			SpecialZoneState._replace_special_building(buildings, zones, misc, index, Tiles.RUNWAY)
			zones[index] |= Sc2ZoneLayout.CORNERS_MASK

			if zone != 7:
				flags[index] |= Sc2TileFlags.POWER_MASK

			if flip:
				flags[index] |= Sc2TileFlags.FLIPPED

			changed_tiles += 1

		placed_tiles += 1
		current += direction

	var result := Result.new()
	result.ok = true
	result.changed_tiles = changed_tiles

	return result


static func _place_crane_and_pier(
	buildings: PackedByteArray,
	zones: PackedByteArray,
	flags: PackedByteArray,
	terrain: PackedByteArray,
	altitudes: PackedInt32Array,
	misc: PackedByteArray,
	point: Vector2i,
	zone: int,
	rotation: int,
	map_edge: int = 128,
) -> Result:
	var direction := Vector2i.ZERO

	for candidate in CARDINAL_DIRECTIONS:
		var neighbor: Vector2i = point + candidate
		var neighbor_index := SpecialZoneState._index(neighbor, map_edge)

		if neighbor_index >= 0 and flags[neighbor_index] & Sc2TileFlags.WATER:
			direction = candidate
			break

	if direction == Vector2i.ZERO:
		var result := Result.new()
		result.ok = false
		result.changed_tiles = 0

		return result

	if (direction.y != 0 and point.x & 1) or (direction.x != 0 and point.y & 1):
		var result := Result.new()
		result.ok = false
		result.changed_tiles = 0

		return result

	var checked := point

	for unused in 5:
		checked += direction
		var index := SpecialZoneState._index(checked, map_edge)

		if index < 0 or flags[index] & Sc2TileFlags.WATER == 0 or buildings[index] != Tiles.EMPTY:
			var result := Result.new()
			result.ok = false
			result.changed_tiles = 0

			return result

	var last_word := int(altitudes[SpecialZoneState._index(checked, map_edge)])

	if ((last_word & Sc2AltitudeLayout.WATER_MASK) >> Sc2AltitudeLayout.WATER_SHIFT) < (last_word & Sc2AltitudeLayout.LEVEL_MASK) + 2:
		var result := Result.new()
		result.ok = false
		result.changed_tiles = 0

		return result

	_clear_special_building(buildings, zones, flags, misc, point, map_edge)
	var before := int(buildings[SpecialZoneState._index(point, map_edge)])
	place_special_item(
		buildings, zones, flags, terrain, misc, point, Tiles.CRANE, 1, zone, rotation, map_edge
	)
	zones[SpecialZoneState._index(point, map_edge)] = (zones[SpecialZoneState._index(point, map_edge)] & Sc2ZoneLayout.CORNERS_MASK) | zone

	if zone == 7:
		flags[SpecialZoneState._index(point, map_edge)] &= ~Sc2TileFlags.UTILITY_MASK & 0xff

	var changed_tiles := int(buildings[SpecialZoneState._index(point, map_edge)] != before)
	var flip := SpecialZoneState._special_axis_is_flipped(direction.x, rotation)
	var pier := point

	for unused in 4:
		pier += direction
		var index := SpecialZoneState._index(pier, map_edge)
		SpecialZoneState._replace_special_building(buildings, zones, misc, index, Tiles.PIER)
		zones[index] |= Sc2ZoneLayout.CORNERS_MASK

		if flip:
			flags[index] |= Sc2TileFlags.FLIPPED

		changed_tiles += 1

	var result := Result.new()
	result.ok = true
	result.changed_tiles = changed_tiles

	return result


static func _place_special_two_by_two(
	buildings: PackedByteArray,
	zones: PackedByteArray,
	flags: PackedByteArray,
	terrain: PackedByteArray,
	misc: PackedByteArray,
	point: Vector2i,
	tile: int,
	zone: int,
	rotation: int,
	map_edge: int = 128,
	underground: PackedByteArray = PackedByteArray(),
) -> Result:
	var anchor := Vector2i(point.x & ~1, point.y & ~1)

	if anchor.x < 0 or anchor.y < 0 or anchor.x >= (map_edge - 1) or anchor.y >= (map_edge - 1):
		var result := Result.new()
		result.ok = false
		result.changed_tiles = 0

		return result

	var points := [
		anchor, anchor + Vector2i(1, 0), anchor + Vector2i(0, 1), anchor + Vector2i(1, 1),
	]

	for point_index in points.size():
		var checked: Vector2i = points[point_index]
		var index := SpecialZoneState._index(checked, map_edge)
		var checked_tile := int(buildings[index])

		if checked_tile == Tiles.RUNWAY or checked_tile == Tiles.RUNWAY_CROSSING or checked_tile == Tiles.CRANE:
			var result := Result.new()
			result.ok = false
			result.changed_tiles = 0

			return result

		# The original checks 0xeb..0xff only at the anchor. sc2kfix checks
		# the missile-silo restriction across the whole footprint.
		if point_index == 0 and checked_tile > Tiles.RADAR:
			var result := Result.new()
			result.ok = false
			result.changed_tiles = 0

			return result

		if zone == 7:
			if (checked_tile >= Tiles.FIRST_ROAD and checked_tile <= Tiles.LAST_ROAD) or checked_tile == Tiles.MISSILE_SILO or checked_tile == Tiles.RADIOACTIVE_WASTE or checked_tile == Tiles.SMALL_PARK:
				var result := Result.new()
				result.ok = false
				result.changed_tiles = 0

				return result
			if terrain[index] != TerrainTileIds.FLAT or flags[index] & Sc2TileFlags.WATER or (not underground.is_empty() and underground[index] != UnderTiles.EMPTY):
				var result := Result.new()
				result.ok = false
				result.changed_tiles = 0

				return result

		if (zones[index] & Sc2ZoneLayout.TYPE_MASK) != zone:
			var result := Result.new()
			result.ok = false
			result.changed_tiles = 0

			return result

	for checked in points:
		_clear_special_building(buildings, zones, flags, misc, checked, map_edge)

	var before := buildings.duplicate()
	place_special_item(
		buildings, zones, flags, terrain, misc, anchor, tile, 2, zone, rotation, map_edge
	)

	for checked in points:
		var index := SpecialZoneState._index(checked, map_edge)
		zones[index] = (zones[index] & Sc2ZoneLayout.CORNERS_MASK) | zone

		if zone == 7:
			flags[index] &= ~Sc2TileFlags.UTILITY_MASK & 0xff

	var changed_tiles := 0

	for checked in points:
		var index := SpecialZoneState._index(checked, map_edge)
		changed_tiles += int(buildings[index] != before[index])

	var result := Result.new()
	result.ok = true
	result.changed_tiles = changed_tiles

	return result


static func place_special_item(
	buildings: PackedByteArray,
	zones: PackedByteArray,
	flags: PackedByteArray,
	terrain: PackedByteArray,
	misc: PackedByteArray,
	anchor: Vector2i,
	tile: int,
	area: int,
	zone: int,
	rotation: int,
	map_edge: int = 128,
) -> bool:
	var origin := anchor - Vector2i.ONE if area > 2 else anchor
	var points: Array[Vector2i] = []

	for x in range(origin.x, origin.x + area):
		for y in range(origin.y, origin.y + area):
			var point := Vector2i(x, y)
			var index := SpecialZoneState._index(point, map_edge)

			if index < 0 or (area > 1 and (x < 1 or y < 1 or x > map_edge - 2 or y > map_edge - 2)):
				return false

			if buildings[index] >= Tiles.FIRST_ROAD or buildings[index] == Tiles.RADIOACTIVE_WASTE or buildings[index] == Tiles.SMALL_PARK:
				return false

			if (zones[index] & Sc2ZoneLayout.TYPE_MASK) == 7 and zone != 7:
				return false

			if terrain[index] != TerrainTileIds.FLAT or flags[index] & Sc2TileFlags.WATER:
				return false

			points.append(point)

	for point in points:
		var index := SpecialZoneState._index(point, map_edge)
		flags[index] = (flags[index] & ~Sc2TileFlags.STRUCTURE_MASK & 0xff) | Sc2TileFlags.STRUCTURE_MASK
		SpecialZoneState._replace_special_building(buildings, zones, misc, index, tile)
		zones[index] = 0

	if area == 1:
		zones[SpecialZoneState._index(origin, map_edge)] |= Sc2ZoneLayout.CORNERS_MASK
	else:
		GrowthSiteRules.set_corners(zones, origin, area, rotation, map_edge)

	for point in points:
		zones[SpecialZoneState._index(point, map_edge)] = (zones[SpecialZoneState._index(point, map_edge)] & Sc2ZoneLayout.CORNERS_MASK) | zone

	return true


static func place_missile_silo(
	buildings: PackedByteArray,
	zones: PackedByteArray,
	underground: PackedByteArray,
	misc: PackedByteArray,
	point: Vector2i,
	zone: int,
	rotation: int,
	map_edge: int = 128,
) -> Result:
	var origin := point

	for unused in 2:
		var left := origin + Vector2i(-1, 0)

		if SpecialZoneState._index(left, map_edge) >= 0 and (zones[SpecialZoneState._index(left, map_edge)] & Sc2ZoneLayout.TYPE_MASK) == zone:
			origin = left

	for unused in 2:
		var upper := origin + Vector2i(0, -1)

		if SpecialZoneState._index(upper, map_edge) >= 0 and (zones[SpecialZoneState._index(upper, map_edge)] & Sc2ZoneLayout.TYPE_MASK) == zone:
			origin = upper

	if origin.x < 0 or origin.y < 0 or origin.x > map_edge - 3 or origin.y > map_edge - 3:
		var result := Result.new()
		result.ok = false
		result.changed_tiles = 0

		return result

	var changed_tiles := 0

	for x in range(origin.x, origin.x + 3):
		for y in range(origin.y, origin.y + 3):
			var index := x * map_edge + y

			if buildings[index] != Tiles.MISSILE_SILO:
				changed_tiles += 1

			SpecialZoneState._replace_special_building(buildings, zones, misc, index, Tiles.MISSILE_SILO)
			SpecialZoneState.replace_underground(underground, zones, misc, index, UnderTiles.MISSILE_SILO)

	GrowthSiteRules.set_corners(zones, origin, 3, rotation, map_edge)

	var result := Result.new()
	result.ok = true
	result.changed_tiles = changed_tiles

	return result


static func _clear_special_building(
	buildings: PackedByteArray,
	zones: PackedByteArray,
	flags: PackedByteArray,
	misc: PackedByteArray,
	point: Vector2i,
	map_edge: int = 128,
) -> void:
	var selected_index := SpecialZoneState._index(point, map_edge)

	if selected_index < 0 or buildings[selected_index] <= Tiles.DEVELOPED_3X3_LAST:
		return

	var points: Array[Vector2i] = [point]

	if buildings[selected_index] < Tiles.STATUE or buildings[selected_index] > Tiles.RADAR:
		var anchor := Vector2i(point.x & ~1, point.y & ~1)
		points = [
			anchor,
			anchor + Vector2i(1, 0),
			anchor + Vector2i(0, 1),
			anchor + Vector2i(1, 1),
		]

	for cleared in points:
		var index := SpecialZoneState._index(cleared, map_edge)

		if index < 0:
			continue

		SpecialZoneState._replace_special_building(buildings, zones, misc, index, Tiles.EMPTY)
		flags[index] &= ~Sc2TileFlags.POWER_MASK & 0xff
		zones[index] &= Sc2ZoneLayout.TYPE_MASK
