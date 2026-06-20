class_name SpecialZonePlacement
extends SpecialZoneConstants



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
) -> Dictionary:
	# military runway orientation uses its own count, as in sc2kfix
	var count := SpecialZoneState._special_tile_count(misc, 0xdd, zone == 7, map_edge)
	var direction := Vector2i.ZERO

	if count & 1 == 0:
		if point.x & 1:
			direction = Vector2i(0, 1)
		elif point.y & 1:
			direction = Vector2i(1, 0)
		else:
			return {"ok": false, "changed_tiles": 0}
	else:
		if point.y & 1:
			direction = Vector2i(1, 0)
		elif point.x & 1:
			direction = Vector2i(0, 1)
		else:
			return {"ok": false, "changed_tiles": 0}

	var new_tiles := 0
	var checked := point

	while SpecialZoneState._index(checked, map_edge) >= 0:
		var checked_index := SpecialZoneState._index(checked, map_edge)

		if (zones[checked_index] & 0x0f) != zone:
			return {"ok": false, "changed_tiles": 0}

		if zone == 7:
			var tile := int(buildings[checked_index])
			if (tile >= 0x1d and tile <= 0x2b) or tile == 0xe0 or tile == 0xf9:
				return {"ok": false, "changed_tiles": 0}
			if (not terrain.is_empty() and terrain[checked_index] != 0) or (not underground.is_empty() and underground[checked_index] != 0):
				return {"ok": false, "changed_tiles": 0}

		if buildings[checked_index] == 0xdd or buildings[checked_index] == 0xde:
			new_tiles -= 1

		new_tiles += 1
		checked += direction

		if new_tiles >= 5:
			break

	if new_tiles < 5:
		return {"ok": false, "changed_tiles": 0}

	var flip := SpecialZoneState._special_axis_is_flipped(direction.x, rotation)
	var changed_tiles := 0
	var placed_tiles := 0
	var current := point

	while placed_tiles < 5:
		var index := SpecialZoneState._index(current, map_edge)
		var current_tile := int(buildings[index])

		if current_tile == 0xdd or current_tile == 0xde:
			placed_tiles -= 1

			if current_tile == 0xdd and bool(flags[index] & 0x02) != flip:
				SpecialZoneState._replace_special_building(buildings, zones, misc, index, 0xde)
				zones[index] |= 0xf0

				if zone != 7:
					flags[index] |= 0xc0

				flags[index] &= 0xfd
				changed_tiles += 1
		else:
			_clear_special_building(buildings, zones, flags, misc, current, map_edge)
			SpecialZoneState._replace_special_building(buildings, zones, misc, index, 0xdd)
			zones[index] |= 0xf0

			if zone != 7:
				flags[index] |= 0xc0

			if flip:
				flags[index] |= 0x02

			changed_tiles += 1

		placed_tiles += 1
		current += direction

	return {"ok": true, "changed_tiles": changed_tiles}


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
) -> Dictionary:
	var direction := Vector2i.ZERO

	for candidate in CARDINAL_DIRECTIONS:
		var neighbor: Vector2i = point + candidate
		var neighbor_index := SpecialZoneState._index(neighbor, map_edge)

		if neighbor_index >= 0 and flags[neighbor_index] & 0x04:
			direction = candidate
			break

	if direction == Vector2i.ZERO:
		return {"ok": false, "changed_tiles": 0}

	if (direction.y != 0 and point.x & 1) or (direction.x != 0 and point.y & 1):
		return {"ok": false, "changed_tiles": 0}

	var checked := point

	for unused in 5:
		checked += direction
		var index := SpecialZoneState._index(checked, map_edge)

		if index < 0 or flags[index] & 0x04 == 0 or buildings[index] != 0:
			return {"ok": false, "changed_tiles": 0}

	var last_word := int(altitudes[SpecialZoneState._index(checked, map_edge)])

	if ((last_word & 0x03e0) >> 5) < (last_word & 0x1f) + 2:
		return {"ok": false, "changed_tiles": 0}

	_clear_special_building(buildings, zones, flags, misc, point, map_edge)
	var before := int(buildings[SpecialZoneState._index(point, map_edge)])
	_place_special_item(
		buildings, zones, flags, terrain, misc, point, 0xe0, 1, zone, rotation, map_edge
	)
	zones[SpecialZoneState._index(point, map_edge)] = (zones[SpecialZoneState._index(point, map_edge)] & 0xf0) | zone

	if zone == 7:
		flags[SpecialZoneState._index(point, map_edge)] &= 0x0f

	var changed_tiles := int(buildings[SpecialZoneState._index(point, map_edge)] != before)
	var flip := SpecialZoneState._special_axis_is_flipped(direction.x, rotation)
	var pier := point

	for unused in 4:
		pier += direction
		var index := SpecialZoneState._index(pier, map_edge)
		SpecialZoneState._replace_special_building(buildings, zones, misc, index, 0xdf)
		zones[index] |= 0xf0

		if flip:
			flags[index] |= 0x02

		changed_tiles += 1

	return {"ok": true, "changed_tiles": changed_tiles}


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
) -> Dictionary:
	var anchor := Vector2i(point.x & ~1, point.y & ~1)

	if anchor.x < 0 or anchor.y < 0 or anchor.x >= (map_edge - 1) or anchor.y >= (map_edge - 1):
		return {"ok": false, "changed_tiles": 0}

	var points := [
		anchor, anchor + Vector2i(1, 0), anchor + Vector2i(0, 1), anchor + Vector2i(1, 1),
	]

	for point_index in points.size():
		var checked: Vector2i = points[point_index]
		var index := SpecialZoneState._index(checked, map_edge)
		var checked_tile := int(buildings[index])

		if checked_tile == 0xdd or checked_tile == 0xde or checked_tile == 0xe0:
			return {"ok": false, "changed_tiles": 0}

		# The original checks 0xeb..0xff only at the anchor. sc2kfix checks
		# the missile-silo restriction across the whole footprint.
		if point_index == 0 and checked_tile > 0xea:
			return {"ok": false, "changed_tiles": 0}

		if zone == 7:
			if (checked_tile >= 0x1d and checked_tile <= 0x2b) or checked_tile == 0xf9 or checked_tile == 0x05 or checked_tile == 0x0d:
				return {"ok": false, "changed_tiles": 0}
			if terrain[index] != 0 or flags[index] & 0x04 or (not underground.is_empty() and underground[index] != 0):
				return {"ok": false, "changed_tiles": 0}

		if (zones[index] & 0x0f) != zone:
			return {"ok": false, "changed_tiles": 0}

	for checked in points:
		_clear_special_building(buildings, zones, flags, misc, checked, map_edge)

	var before := buildings.duplicate()
	_place_special_item(
		buildings, zones, flags, terrain, misc, anchor, tile, 2, zone, rotation, map_edge
	)

	for checked in points:
		var index := SpecialZoneState._index(checked, map_edge)
		zones[index] = (zones[index] & 0xf0) | zone

		if zone == 7:
			flags[index] &= 0x0f

	var changed_tiles := 0

	for checked in points:
		var index := SpecialZoneState._index(checked, map_edge)
		changed_tiles += int(buildings[index] != before[index])

	return {"ok": true, "changed_tiles": changed_tiles}


static func _place_special_item(
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

			if buildings[index] >= 0x1d or buildings[index] == 0x05 or buildings[index] == 0x0d:
				return false

			if (zones[index] & 0x0f) == 7 and zone != 7:
				return false

			if terrain[index] != 0 or flags[index] & 0x04:
				return false

			points.append(point)

	for point in points:
		var index := SpecialZoneState._index(point, map_edge)
		flags[index] = (flags[index] & 0x1f) | 0xe0
		SpecialZoneState._replace_special_building(buildings, zones, misc, index, tile)
		zones[index] = 0

	if area == 1:
		zones[SpecialZoneState._index(origin, map_edge)] |= 0xf0
	else:
		SpecialZoneState._set_corners(zones, origin, area, rotation, map_edge)

	for point in points:
		zones[SpecialZoneState._index(point, map_edge)] = (zones[SpecialZoneState._index(point, map_edge)] & 0xf0) | zone

	return true


static func _place_missile_silo(
	buildings: PackedByteArray,
	zones: PackedByteArray,
	underground: PackedByteArray,
	misc: PackedByteArray,
	point: Vector2i,
	zone: int,
	rotation: int,
	map_edge: int = 128,
) -> Dictionary:
	var origin := point

	for unused in 2:
		var left := origin + Vector2i(-1, 0)

		if SpecialZoneState._index(left, map_edge) >= 0 and (zones[SpecialZoneState._index(left, map_edge)] & 0x0f) == zone:
			origin = left

	for unused in 2:
		var upper := origin + Vector2i(0, -1)

		if SpecialZoneState._index(upper, map_edge) >= 0 and (zones[SpecialZoneState._index(upper, map_edge)] & 0x0f) == zone:
			origin = upper

	if origin.x < 0 or origin.y < 0 or origin.x > map_edge - 3 or origin.y > map_edge - 3:
		return {"ok": false, "changed_tiles": 0}

	var changed_tiles := 0

	for x in range(origin.x, origin.x + 3):
		for y in range(origin.y, origin.y + 3):
			var index := x * map_edge + y

			if buildings[index] != 0xf9:
				changed_tiles += 1

			SpecialZoneState._replace_special_building(buildings, zones, misc, index, 0xf9)
			SpecialZoneState._replace_underground(underground, zones, misc, index, 0x22)

	SpecialZoneState._set_corners(zones, origin, 3, rotation, map_edge)

	return {"ok": true, "changed_tiles": changed_tiles}


static func _clear_special_building(
	buildings: PackedByteArray,
	zones: PackedByteArray,
	flags: PackedByteArray,
	misc: PackedByteArray,
	point: Vector2i,
	map_edge: int = 128,
) -> void:
	var selected_index := SpecialZoneState._index(point, map_edge)

	if selected_index < 0 or buildings[selected_index] <= 0xc5:
		return

	var points: Array[Vector2i] = [point]

	if buildings[selected_index] < 0xdb or buildings[selected_index] > 0xea:
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

		SpecialZoneState._replace_special_building(buildings, zones, misc, index, 0)
		flags[index] &= 0x3f
		zones[index] &= 0x0f
