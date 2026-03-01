class_name SpecialZoneGrowth
extends RefCounted

const MovingThings = preload("res://src/simulation/moving_things/moving_thing_spawner.gd")
const MISC_TILE_COUNTS := 0x01f0
const MISC_MILITARY_BASE_TYPE := 0x0e4c
const MISC_MILITARY_TILE_COUNTS := 0x0fa8
const MISC_SUBWAY_COUNT := 0x0fe8
const SOUND_SHIP := 517
const CORNER_BOTTOM_LEFT := [0x10, 0x20, 0x40, 0x80]
const CORNER_BOTTOM_RIGHT := [0x20, 0x40, 0x80, 0x10]
const CORNER_TOP_LEFT := [0x40, 0x80, 0x10, 0x20]
const CORNER_TOP_RIGHT := [0x80, 0x10, 0x20, 0x40]
const SPECIAL_SIMPLE_TILES := [0xe1, 0xe2, 0xe3, 0xe4, 0xe5, 0xe6, 0xe7, 0xe8, 0xea]
const SPECIAL_TWO_BY_TWO_TILES := [0xee, 0xef, 0xf0, 0xf1, 0xf2, 0xf6]
const CARDINAL_DIRECTIONS := [
	Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, 0),
]
const MILITARY_TILE_COUNT_INDEX := {
	0xdd: 1,
	0xde: 2,
	0xef: 3,
	0xf2: 4,
	0xea: 5,
	0xe3: 6,
	0xe4: 7,
	0xe5: 8,
	0xf1: 9,
	0xe0: 10,
	0xe2: 11,
	0xe7: 12,
	0xe8: 13,
	0xf6: 14,
	0xf9: 15,
}


static func process(
	buildings: PackedByteArray,
	zones: PackedByteArray,
	underground: PackedByteArray,
	flags: PackedByteArray,
	terrain: PackedByteArray,
	altitudes: PackedInt32Array,
	text_overlays: PackedByteArray,
	things: PackedByteArray,
	misc: PackedByteArray,
	point: Vector2i,
	random,
	rotation: int,
	counters: Dictionary,
	map_edge: int = 128,
) -> void:
	var index := _index(point, map_edge)
	var zone := int(zones[index]) & 0x0f
	var current_tile := int(buildings[index])
	var selected_tile := -1
	var fallback_tile := -1

	if zone == 7:
		match _read_u32(misc, MISC_MILITARY_BASE_TYPE) & 0xff:
			2:
				if random.next_u15() & 3:
					return

				var parking_count := int(_special_tile_count(misc, 0xef, true, map_edge) / 4)
				selected_tile = 0xef

				if int(_special_tile_count(misc, 0xe8, true, map_edge) / 12) < parking_count:
					selected_tile = 0xe8

				fallback_tile = 0xe8
			3:
				selected_tile = _airport_growth_selection(
					flags, text_overlays, things, misc, point, current_tile,
					true, rotation, random, counters, map_edge
				)
			4:
				selected_tile = _seaport_growth_selection(
					terrain, text_overlays, things, misc, point, current_tile,
					true, random, counters, map_edge
				)
				fallback_tile = 0xe3
			5:
				if current_tile != 0xf9:
					selected_tile = 0xf9
			_:
				return
	elif zone == 8:
		selected_tile = _airport_growth_selection(
			flags, text_overlays, things, misc, point, current_tile,
			false, rotation, random, counters, map_edge
		)
	elif zone == 9:
		selected_tile = _seaport_growth_selection(
			terrain, text_overlays, things, misc, point, current_tile,
			false, random, counters, map_edge
		)
		fallback_tile = 0xe3
	else:
		return

	if selected_tile < 0:
		return

	counters.special_growth_attempts += 1
	var placed := _grow_special_zone(
		buildings,
		zones,
		underground,
		flags,
		terrain,
		altitudes,
		misc,
		point,
		selected_tile,
		zone,
		rotation, map_edge,
	)

	if not placed.ok and fallback_tile >= 0:
		placed = _grow_special_zone(
			buildings, zones, underground, flags, terrain, altitudes, misc,
			point, fallback_tile, zone, rotation, map_edge
		)

	counters.special_tiles_placed += int(placed.get("changed_tiles", 0))


static func _airport_growth_selection(
	flags: PackedByteArray,
	text_overlays: PackedByteArray,
	things: PackedByteArray,
	misc: PackedByteArray,
	point: Vector2i,
	current_tile: int,
	military: bool,
	rotation: int,
	random,
	counters: Dictionary,
	map_edge: int = 128,
) -> int:
	if random.next_u15() & 3:
		if military or current_tile != 0xdd or random.next_u15() % 30 != 0:
			return -1

		if flags[_index(point, map_edge)] & 0x40 == 0:
			return -1

		if random.next_u15() % 10 < 4:
			var helicopter := MovingThings.spawn_helicopter(
				things, text_overlays, point, random, map_edge
			)

			if helicopter.spawned:
				counters.spawned_helicopters += 1
		else:
			var runway_axis := 2 if bool(flags[_index(point, map_edge)] & 0x02) != bool(rotation & 1) else 0
			var airplane := MovingThings.spawn_airplane(
				things, text_overlays, point, runway_axis, random, map_edge
			)

			if airplane.spawned:
				counters.spawned_airplanes += 1

		return -1

	var runway_groups := int(
		(_special_tile_count(misc, 0xdd, military, map_edge) + _special_tile_count(misc, 0xde, military, map_edge)) / 5
	)
	var parking_tile := 0xef if military else 0xee

	if int(_special_tile_count(misc, parking_tile, military, map_edge) / 4) >= runway_groups:
		return 0xdd

	var selected := 0xe2 if military else 0xe1

	if _special_tile_count(misc, selected, military, map_edge) * 2 < runway_groups:
		return selected

	selected = 0xea

	if _special_tile_count(misc, selected, military, map_edge) * 2 < runway_groups:
		return selected

	selected = 0xe7 if military else 0xe6

	if _special_tile_count(misc, selected, military, map_edge) < runway_groups:
		return selected

	selected = 0xe4

	if int(_special_tile_count(misc, selected, military, map_edge) / 2) < runway_groups:
		return selected

	selected = 0xe5

	if int(_special_tile_count(misc, selected, military, map_edge) / 2) < runway_groups:
		return selected

	if int(_special_tile_count(misc, 0xf6, military, map_edge) / 4) < runway_groups:
		return 0xf6

	return parking_tile


static func _seaport_growth_selection(
	terrain: PackedByteArray,
	text_overlays: PackedByteArray,
	things: PackedByteArray,
	misc: PackedByteArray,
	point: Vector2i,
	current_tile: int,
	military: bool,
	random,
	counters: Dictionary,
	map_edge: int = 128,
) -> int:
	if random.next_u15() & 3:
		if not military and current_tile == 0xe0 and random.next_u15() & 3 == 0:
			var ship := MovingThings.spawn_ship(
				terrain, things, text_overlays, point, random, map_edge
			)

			if ship.spawned:
				counters.spawned_ships += 1
				counters["ship_home"] = ship.point
				counters.sound_events.append({
					"sound_id": SOUND_SHIP,
					"thing_type": 3,
					"record": int(ship.record),
					"point": ship.point,
				})

		return -1

	var crane_count := _special_tile_count(misc, 0xe0, military, map_edge)

	if int(_special_tile_count(misc, 0xf2, military, map_edge) / 4) >= crane_count:
		return 0xe0

	var second_tile := 0xf1 if military else 0xf0

	if int(_special_tile_count(misc, second_tile, military, map_edge) / 4) < crane_count:
		return second_tile

	if int(_special_tile_count(misc, 0xe3, military, map_edge) / 3) < crane_count:
		return 0xe3

	return 0xf2


static func _grow_special_zone(
	buildings: PackedByteArray,
	zones: PackedByteArray,
	underground: PackedByteArray,
	flags: PackedByteArray,
	terrain: PackedByteArray,
	altitudes: PackedInt32Array,
	misc: PackedByteArray,
	point: Vector2i,
	tile: int,
	zone: int,
	rotation: int,
	map_edge: int = 128,
) -> Dictionary:
	if zone != 7 and not _has_power(flags, point.x, point.y, map_edge):
		return {"ok": false, "changed_tiles": 0}

	if tile == 0xdd:
		return _place_runway(
			buildings, zones, flags, misc, point, zone, rotation, map_edge
		)

	if tile == 0xe0:
		return _place_crane_and_pier(
			buildings, zones, flags, terrain, altitudes,
			misc, point, zone, rotation, map_edge
		)

	if SPECIAL_SIMPLE_TILES.has(tile):
		var before := int(buildings[_index(point, map_edge)])

		if before < 0x0d:
			_place_special_item(
				buildings, zones, flags, terrain, misc, point, tile, 1, zone, rotation, map_edge
			)

		zones[_index(point, map_edge)] = (zones[_index(point, map_edge)] & 0xf0) | zone

		if zone == 7:
			flags[_index(point, map_edge)] &= 0x0f

		return {"ok": true, "changed_tiles": int(buildings[_index(point, map_edge)] != before)}

	if SPECIAL_TWO_BY_TWO_TILES.has(tile):
		return _place_special_two_by_two(
			buildings, zones, flags, terrain, misc, point, tile, zone, rotation, map_edge
		)

	if tile == 0xf9:
		return _place_missile_silo(
			buildings, zones, underground, misc, point, zone, rotation, map_edge
		)

	return {"ok": true, "changed_tiles": 0}


static func _place_runway(
	buildings: PackedByteArray,
	zones: PackedByteArray,
	flags: PackedByteArray,
	misc: PackedByteArray,
	point: Vector2i,
	zone: int,
	rotation: int,
	map_edge: int = 128,
) -> Dictionary:
	# the supplied win95 executable always uses the normal runway count here
	# sc2kfix changes this to use the military count for a military zone
	var count := _special_tile_count(misc, 0xdd, false, map_edge)
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

	while _index(checked, map_edge) >= 0:
		var checked_index := _index(checked, map_edge)

		if (zones[checked_index] & 0x0f) != zone:
			return {"ok": false, "changed_tiles": 0}

		if buildings[checked_index] == 0xdd or buildings[checked_index] == 0xde:
			new_tiles -= 1

		new_tiles += 1
		checked += direction

		if new_tiles >= 5:
			break

	if new_tiles < 5:
		return {"ok": false, "changed_tiles": 0}

	var flip := _special_axis_is_flipped(direction.x, rotation)
	var changed_tiles := 0
	var placed_tiles := 0
	var current := point

	while placed_tiles < 5:
		var index := _index(current, map_edge)
		var current_tile := int(buildings[index])

		if current_tile == 0xdd or current_tile == 0xde:
			placed_tiles -= 1

			if current_tile == 0xdd and bool(flags[index] & 0x02) != flip:
				_replace_special_building(buildings, zones, misc, index, 0xde)
				zones[index] |= 0xf0

				if zone != 7:
					flags[index] |= 0xc0

				flags[index] &= 0xfd
				changed_tiles += 1
		else:
			_clear_special_building(buildings, zones, flags, misc, current, map_edge)
			_replace_special_building(buildings, zones, misc, index, 0xdd)
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
		var neighbor_index := _index(neighbor, map_edge)

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
		var index := _index(checked, map_edge)

		if index < 0 or flags[index] & 0x04 == 0 or buildings[index] != 0:
			return {"ok": false, "changed_tiles": 0}

	var last_word := int(altitudes[_index(checked, map_edge)])

	if ((last_word & 0x03e0) >> 5) < (last_word & 0x1f) + 2:
		return {"ok": false, "changed_tiles": 0}

	_clear_special_building(buildings, zones, flags, misc, point, map_edge)
	var before := int(buildings[_index(point, map_edge)])
	_place_special_item(
		buildings, zones, flags, terrain, misc, point, 0xe0, 1, zone, rotation, map_edge
	)
	zones[_index(point, map_edge)] = (zones[_index(point, map_edge)] & 0xf0) | zone

	if zone == 7:
		flags[_index(point, map_edge)] &= 0x0f

	var changed_tiles := int(buildings[_index(point, map_edge)] != before)
	var flip := _special_axis_is_flipped(direction.x, rotation)
	var pier := point

	for unused in 4:
		pier += direction
		var index := _index(pier, map_edge)
		_replace_special_building(buildings, zones, misc, index, 0xdf)
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
) -> Dictionary:
	var anchor := Vector2i(point.x & ~1, point.y & ~1)

	if anchor.x < 0 or anchor.y < 0 or anchor.x >= (map_edge - 1) or anchor.y >= (map_edge - 1):
		return {"ok": false, "changed_tiles": 0}

	var points := [
		anchor, anchor + Vector2i(1, 0), anchor + Vector2i(0, 1), anchor + Vector2i(1, 1),
	]

	for point_index in points.size():
		var checked: Vector2i = points[point_index]
		var index := _index(checked, map_edge)
		var checked_tile := int(buildings[index])

		if checked_tile == 0xdd or checked_tile == 0xde or checked_tile == 0xe0:
			return {"ok": false, "changed_tiles": 0}

		# The original checks 0xeb..0xff only at the anchor. sc2kfix checks
		# the missile-silo restriction across the whole footprint.
		if point_index == 0 and checked_tile > 0xea:
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
		var index := _index(checked, map_edge)
		zones[index] = (zones[index] & 0xf0) | zone

		if zone == 7:
			flags[index] &= 0x0f

	var changed_tiles := 0

	for checked in points:
		var index := _index(checked, map_edge)
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
			var index := _index(point, map_edge)

			if index < 0 or (area > 1 and (x < 1 or y < 1 or x > map_edge - 2 or y > map_edge - 2)):
				return false

			if buildings[index] >= 0x1d or buildings[index] == 0x05 or buildings[index] == 0x0d:
				return false

			if (zones[index] & 0x0f) == 7:
				return false

			if terrain[index] != 0 or flags[index] & 0x04:
				return false

			points.append(point)

	for point in points:
		var index := _index(point, map_edge)
		flags[index] = (flags[index] & 0x1f) | 0xe0
		_replace_special_building(buildings, zones, misc, index, tile)
		zones[index] = 0

	if area == 1:
		zones[_index(origin, map_edge)] |= 0xf0
	else:
		_set_corners(zones, origin, area, rotation, map_edge)

	for point in points:
		zones[_index(point, map_edge)] = (zones[_index(point, map_edge)] & 0xf0) | zone

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

		if _index(left, map_edge) >= 0 and (zones[_index(left, map_edge)] & 0x0f) == zone:
			origin = left

	for unused in 2:
		var upper := origin + Vector2i(0, -1)

		if _index(upper, map_edge) >= 0 and (zones[_index(upper, map_edge)] & 0x0f) == zone:
			origin = upper

	if origin.x < 0 or origin.y < 0 or origin.x > map_edge - 3 or origin.y > map_edge - 3:
		return {"ok": false, "changed_tiles": 0}

	var changed_tiles := 0

	for x in range(origin.x, origin.x + 3):
		for y in range(origin.y, origin.y + 3):
			var index := x * map_edge + y

			if buildings[index] != 0xf9:
				changed_tiles += 1

			_replace_special_building(buildings, zones, misc, index, 0xf9)
			_replace_underground(underground, zones, misc, index, 0x22)

	_set_corners(zones, origin, 3, rotation, map_edge)

	return {"ok": true, "changed_tiles": changed_tiles}


static func _clear_special_building(
	buildings: PackedByteArray,
	zones: PackedByteArray,
	flags: PackedByteArray,
	misc: PackedByteArray,
	point: Vector2i,
	map_edge: int = 128,
) -> void:
	var selected_index := _index(point, map_edge)

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
		var index := _index(cleared, map_edge)

		if index < 0:
			continue

		_replace_special_building(buildings, zones, misc, index, 0)
		flags[index] &= 0x3f
		zones[index] &= 0x0f


static func replace_building(
	buildings: PackedByteArray,
	zones: PackedByteArray,
	misc: PackedByteArray,
	index: int,
	new_tile: int
) -> void:
	_replace_special_building(buildings, zones, misc, index, new_tile)


static func _replace_special_building(
	buildings: PackedByteArray,
	zones: PackedByteArray,
	misc: PackedByteArray,
	index: int,
	new_tile: int
) -> void:
	var old_tile := int(buildings[index])

	if old_tile == new_tile:
		return

	var military := (zones[index] & 0x0f) == 7
	var old_offset := _special_count_offset(old_tile, military)
	var new_offset := _special_count_offset(new_tile, military)
	_write_u32(misc, old_offset, (_read_u32(misc, old_offset) - 1) & (0xffff if buildings.size() == 16384 else 0xffffffff))
	_write_u32(misc, new_offset, (_read_u32(misc, new_offset) + 1) & (0xffff if buildings.size() == 16384 else 0xffffffff))
	buildings[index] = new_tile


static func tile_count(misc: PackedByteArray, tile: int, military: bool, map_edge: int = 128) -> int:
	return _special_tile_count(misc, tile, military, map_edge)


static func _special_tile_count(misc: PackedByteArray, tile: int, military: bool, map_edge: int = 128) -> int:
	return _read_u32(misc, _special_count_offset(tile, military)) & (0xffff if map_edge == 128 else 0xffffffff)


static func _special_count_offset(tile: int, military: bool) -> int:
	if not military:
		return MISC_TILE_COUNTS + tile * 4

	return MISC_MILITARY_TILE_COUNTS + int(MILITARY_TILE_COUNT_INDEX.get(tile, 0)) * 4


static func _special_axis_is_flipped(x_delta: int, rotation: int) -> bool:
	return bool(rotation & 1) if x_delta == 0 else not bool(rotation & 1)


static func _is_subway_tile(tile: int) -> bool:
	return (
		(tile > 0 and tile < 0x10)
		or tile == 0x1f
		or tile == 0x20
		or tile == 0x22
		or tile == 0x23
	)


static func _replace_underground(
	underground: PackedByteArray,
	zones: PackedByteArray,
	misc: PackedByteArray,
	index: int,
	new_tile: int
) -> void:
	var old_tile := int(underground[index])

	if old_tile == new_tile:
		return

	if (zones[index] & 0x0f) != 7:
		var count := _read_u32(misc, MISC_SUBWAY_COUNT)

		if _is_subway_tile(old_tile):
			count = (count - 1) & (0xffff if underground.size() == 16384 else 0xffffffff)

		if _is_subway_tile(new_tile):
			count = (count + 1) & (0xffff if underground.size() == 16384 else 0xffffffff)

		_write_u32(misc, MISC_SUBWAY_COUNT, count)

	underground[index] = new_tile


# The zone and building corner flags share one byte.
static func _set_corners(
	zones: PackedByteArray, position: Vector2i, area: int, rotation: int,
	map_edge: int = 128,
) -> void:
	var far := position + Vector2i(area - 1, area - 1)
	var view := rotation & 3
	var bottom_left := position.x * map_edge + position.y
	var bottom_right := far.x * map_edge + position.y
	var top_left := far.x * map_edge + far.y
	var top_right := position.x * map_edge + far.y
	zones[bottom_left] = (zones[bottom_left] & 0x0f) | CORNER_BOTTOM_LEFT[view]
	zones[bottom_right] = (zones[bottom_right] & 0x0f) | CORNER_BOTTOM_RIGHT[view]
	zones[top_left] = (zones[top_left] & 0x0f) | CORNER_TOP_LEFT[view]
	zones[top_right] = (zones[top_right] & 0x0f) | CORNER_TOP_RIGHT[view]


static func _has_power(flags: PackedByteArray, x: int, y: int, map_edge: int = 128) -> bool:
	var index := x * map_edge + y

	if flags[index] & 0x40:
		return true

	if x > 1 and flags[(x - 1) * map_edge + y] & 0x40:
		return true

	if y > 1 and flags[x * map_edge + y - 1] & 0x40:
		return true

	if x < (map_edge - 1) and flags[(x + 1) * map_edge + y] & 0x40:
		return true

	return y < (map_edge - 1) and (flags[x * map_edge + y + 1] & 0x40) != 0


static func _index(point: Vector2i, map_edge: int = 128) -> int:
	if point.x < 0 or point.x >= map_edge or point.y < 0 or point.y >= map_edge:
		return -1

	return point.x * map_edge + point.y


static func _read_u32(data: PackedByteArray, offset: int) -> int:
	return (
		(data[offset] << 24)
		| (data[offset + 1] << 16)
		| (data[offset + 2] << 8)
		| data[offset + 3]
	)


static func _write_u32(data: PackedByteArray, offset: int, value: int) -> void:
	var encoded := value & 0xffffffff
	data[offset] = (encoded >> 24) & 0xff
	data[offset + 1] = (encoded >> 16) & 0xff
	data[offset + 2] = (encoded >> 8) & 0xff
	data[offset + 3] = encoded & 0xff
