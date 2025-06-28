# todo: spawn traffic from the growth scan

class_name GrowthPhase
extends RefCounted

const Demolish = preload("res://src/tools/demolish_command.gd")
const MAP_VALUE_COUNT := 64 * 64
const MISC_SIZE := 4800
const MISC_TILE_COUNTS := 0x01f0
const MISC_ZONE_POPULATIONS := 0x05f0
const MISC_DEMAND := 0x0718
const MISC_BUDGETS := 0x077c
const MISC_BUDGET_RECORD_SIZE := 0x006c
const MISC_MILITARY_BASE_TYPE := 0x0e4c
const MISC_MILITARY_TILE_COUNTS := 0x0fa8
const MISC_SUBWAY_COUNT := 0x0fe8
const MISC_NORMAL_POPULATION := 0x102c
const POPULATION_BY_DENSITY := [0, 1, 8, 12, 36]
const BUILDING_BASE := [
	0, 0x70, 0x8c, 0x90, 0xae,
	0x7c, 0x94, 0x99, 0xb2,
	0x84, 0x9e, 0xa2, 0xbc,
	0x88, 0xa6, 0xa8, 0xc2,
	0x8a, 0xaa, 0xac, 0xc4,
]
const BUILDING_RANGE := [
	196, 12, 4, 4, 4,
	8, 5, 5, 10,
	4, 4, 4, 6,
	2, 2, 2, 2,
	2, 2, 2, 2,
]
const ANCHOR_MASKS := [0x80, 0x10, 0x20, 0x40]
const CORNER_BOTTOM_LEFT := [0x10, 0x20, 0x40, 0x80]
const CORNER_BOTTOM_RIGHT := [0x20, 0x40, 0x80, 0x10]
const CORNER_TOP_LEFT := [0x40, 0x80, 0x10, 0x20]
const CORNER_TOP_RIGHT := [0x80, 0x10, 0x20, 0x40]
const STATUS_NORMAL := 0
const STATUS_CONSTRUCTION := 1
const STATUS_ABANDONED := 2
const CLASS_RESIDENTIAL := 0
const CLASS_CONSTRUCTION := 3
const CLASS_ABANDONED := 4
const CHURCH_TILE := 0xf7
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


static func run(
	city: CityState, random, step: int, substep: int, lfsr_random = null
) -> Dictionary:
	if city == null or not city.is_valid():
		return {"ok": false, "error": "city is invalid"}
	if random == null or not random.has_method("next_u15"):
		return {"ok": false, "error": "a compatible random generator is required"}
	if lfsr_random == null:
		lfsr_random = SimLfsrRandom.new(1)
	if not lfsr_random.has_method("next_mask"):
		return {"ok": false, "error": "a compatible LFSR generator is required"}
	if step < 0 or step > 3 or substep < 0 or substep > 3:
		return {"ok": false, "error": "growth partition is outside the supported range"}
	var payloads := _payloads(city)
	if payloads.is_empty():
		return {"ok": false, "error": "growth input chunks are missing or have the wrong size"}

	var original := _duplicate_payloads(payloads)
	var altitude: PackedByteArray = payloads.ALTM
	var altitudes := city.altitude_words.duplicate()
	var terrain: PackedByteArray = payloads.XTER
	var buildings: PackedByteArray = payloads.XBLD
	var zones: PackedByteArray = payloads.XZON
	var underground: PackedByteArray = payloads.XUND
	var flags: PackedByteArray = payloads.XBIT
	var text_overlays: PackedByteArray = payloads.XTXT
	var traffic: PackedByteArray = payloads.XTRF
	var land_value: PackedByteArray = payloads.XVAL
	var misc: PackedByteArray = payloads.MISC
	var rotation := city.compass_rotation() & 3
	var anchor_mask: int = ANCHOR_MASKS[rotation]
	var counters := {
		"scanned_tiles": 0,
		"rci_tiles": 0,
		"population_added": 0,
		"abandoned_population_added": 0,
		"started_construction": 0,
		"advanced_construction": 0,
		"completed_construction": 0,
		"abandoned_buildings": 0,
		"recovered_buildings": 0,
		"churches_built": 0,
		"successful_trips": 0,
		"failed_trips": 0,
		"decayed_roads": 0,
		"decayed_rails": 0,
		"decayed_highway_tiles": 0,
		"decayed_subway_tiles": 0,
		"collapsed_bridges": 0,
		"removed_subway_stations": 0,
		"deferred_bridge_collapses": 0,
		"deferred_bridge_effects": 0,
		"deferred_station_removals": 0,
		"special_growth_attempts": 0,
		"special_tiles_placed": 0,
		"deferred_airplanes": 0,
		"deferred_helicopters": 0,
		"deferred_ships": 0,
	}

	for x in range(step, CityState.MAP_SIZE, 4):
		for y in range(substep, CityState.MAP_SIZE, 4):
			counters.scanned_tiles += 1
			var index := x * CityState.MAP_SIZE + y
			var zone_byte := int(zones[index])
			var zone := zone_byte & 0x0f
			if zone == 0:
				_process_surface_maintenance(
					altitude, altitudes, terrain, buildings, zones, underground, flags,
					misc, Vector2i(x, y), random, lfsr_random, counters
				)
				_process_subway_maintenance(
					terrain, buildings, zones, flags, text_overlays, underground, misc,
					Vector2i(x, y), random, lfsr_random, counters
				)
				continue
			if zone > 6:
				_process_special_zone(
					buildings,
					zones,
					underground,
					flags,
					terrain,
					altitudes,
					misc,
					Vector2i(x, y),
					random,
					rotation,
					counters,
				)
				_process_subway_maintenance(
					terrain, buildings, zones, flags, text_overlays, underground, misc,
					Vector2i(x, y), random, lfsr_random, counters
				)
				continue
			var building := int(buildings[index])
			var density := 0
			var status := STATUS_NORMAL
			if building < 0x70:
				if building >= 0x1d or not TransportTrip.has_nearby_transport(buildings, Vector2i(x, y)):
					_process_subway_maintenance(
						terrain, buildings, zones, flags, text_overlays, underground, misc,
						Vector2i(x, y), random, lfsr_random, counters
					)
					continue
			else:
				if building > 0xc5 or zone_byte & anchor_mask == 0:
					_process_subway_maintenance(
						terrain, buildings, zones, flags, text_overlays, underground, misc,
						Vector2i(x, y), random, lfsr_random, counters
					)
					continue
				density = _density(building)
				status = _status(building)
			counters.rci_tiles += 1

			var growth_pressure := 0
			var decline_pressure := 4000
			if _has_power(flags, x, y):
				var trip := TransportTrip.trace(
					buildings,
					zones,
					underground,
					text_overlays,
					altitudes,
					traffic,
					Vector2i(x, y),
					zone,
					density,
					random,
					100,
				)
				if not trip.ok:
					return trip
				if trip.reached_destination:
					counters.successful_trips += 1
					growth_pressure = _read_i32(
						misc, MISC_DEMAND + int((zone - 1) / 2) * 4
					) + 2000
					decline_pressure = 4000 - growth_pressure
				else:
					counters.failed_trips += 1

			if density > 0 and status == STATUS_NORMAL:
				var population: int = POPULATION_BY_DENSITY[density]
				_add_i32(misc, MISC_ZONE_POPULATIONS + zone * 4, population)
				counters.population_added += population
				if random.next_u15() < int(decline_pressure / density):
					_abandon(
						buildings,
						zones,
						flags,
						misc,
						Vector2i(x, y),
						density,
						random.next_u15() & 1,
						random,
						rotation,
						land_value,
					)
					counters.abandoned_buildings += 1
					_process_subway_maintenance(
						terrain, buildings, zones, flags, text_overlays, underground, misc,
						Vector2i(x, y), random, lfsr_random, counters
					)
					continue

			if status == STATUS_CONSTRUCTION:
				if random.next_u15() < int(0x4000 / density):
					if (
						_read_u32(misc, MISC_NORMAL_POPULATION)
						> _read_u32(misc, MISC_TILE_COUNTS + CHURCH_TILE * 4) * 2500
						and (density & 2) != 0
						and zone < 3
					):
						_place_church(buildings, zones, flags, misc, Vector2i(x, y), rotation)
						counters.churches_built += 1
					else:
						_place_zone(
							buildings,
							zones,
							flags,
							misc,
							land_value,
							Vector2i(x, y),
							density,
							int((zone - 1) / 2),
							random,
							rotation,
						)
					counters.completed_construction += 1
					_process_subway_maintenance(
						terrain, buildings, zones, flags, text_overlays, underground, misc,
						Vector2i(x, y), random, lfsr_random, counters
					)
					continue
			elif status == STATUS_ABANDONED:
				var abandoned_population: int = POPULATION_BY_DENSITY[density]
				_add_i32(misc, MISC_ZONE_POPULATIONS + 7 * 4, abandoned_population)
				counters.abandoned_population_added += abandoned_population
				if random.next_u15() < int(growth_pressure * 15 / density):
					_place_zone(
						buildings,
						zones,
						flags,
						misc,
						land_value,
						Vector2i(x, y),
						density,
						int((zone - 1) / 2),
						random,
						rotation,
					)
					counters.recovered_buildings += 1
				_process_subway_maintenance(
					terrain, buildings, zones, flags, text_overlays, underground, misc,
					Vector2i(x, y), random, lfsr_random, counters
				)
				continue

			if _can_advance_density(zone_byte, zone, density, land_value, x, y):
				if random.next_u15() < int(growth_pressure * 3 / (density + 1)):
					var advanced := _advance_construction(
						buildings,
						zones,
						flags,
						misc,
						land_value,
						altitudes,
						Vector2i(x, y),
						density,
						zone,
						random,
						rotation,
					)
					if advanced:
						if density == 0:
							counters.started_construction += 1
						else:
							counters.advanced_construction += 1
			_process_subway_maintenance(
				terrain, buildings, zones, flags, text_overlays, underground, misc,
				Vector2i(x, y), random, lfsr_random, counters
			)

	var changed_ids := PackedStringArray()
	for chunk_id in ["ALTM", "XTER", "XBLD", "XZON", "XUND", "XTXT", "XBIT", "XTRF", "MISC"]:
		if payloads[chunk_id] != original[chunk_id]:
			changed_ids.append(chunk_id)
	if not _apply_payloads(city, changed_ids, payloads, original):
		return {"ok": false, "error": "cannot store growth phase data"}
	counters["ok"] = true
	counters["rci_complete"] = true
	counters["complete"] = false
	counters["error"] = ""
	return counters


static func _process_special_zone(
	buildings: PackedByteArray,
	zones: PackedByteArray,
	underground: PackedByteArray,
	flags: PackedByteArray,
	terrain: PackedByteArray,
	altitudes: PackedInt32Array,
	misc: PackedByteArray,
	point: Vector2i,
	random,
	rotation: int,
	counters: Dictionary
) -> void:
	var index := _index(point)
	var zone := int(zones[index]) & 0x0f
	var current_tile := int(buildings[index])
	var selected_tile := -1
	var fallback_tile := -1
	if zone == 7:
		match _read_u32(misc, MISC_MILITARY_BASE_TYPE) & 0xff:
			2:
				if random.next_u15() & 3:
					return
				var parking_count := int(_special_tile_count(misc, 0xef, true) / 4)
				selected_tile = 0xef
				if int(_special_tile_count(misc, 0xe8, true) / 12) < parking_count:
					selected_tile = 0xe8
				fallback_tile = 0xe8
			3:
				selected_tile = _airport_growth_selection(
					buildings, flags, misc, point, current_tile, true, random, counters
				)
			4:
				selected_tile = _seaport_growth_selection(
					misc, current_tile, true, random, counters
				)
				fallback_tile = 0xe3
			5:
				if current_tile != 0xf9:
					selected_tile = 0xf9
			_:
				return
	elif zone == 8:
		selected_tile = _airport_growth_selection(
			buildings, flags, misc, point, current_tile, false, random, counters
		)
	elif zone == 9:
		selected_tile = _seaport_growth_selection(misc, current_tile, false, random, counters)
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
		rotation,
	)
	if not placed.ok and fallback_tile >= 0:
		placed = _grow_special_zone(
			buildings, zones, underground, flags, terrain, altitudes, misc,
			point, fallback_tile, zone, rotation
		)
	counters.special_tiles_placed += int(placed.get("changed_tiles", 0))


static func _airport_growth_selection(
	_buildings: PackedByteArray,
	flags: PackedByteArray,
	misc: PackedByteArray,
	point: Vector2i,
	current_tile: int,
	military: bool,
	random,
	counters: Dictionary
) -> int:
	if random.next_u15() & 3:
		if military or current_tile != 0xdd or random.next_u15() % 30 != 0:
			return -1
		if flags[_index(point)] & 0x40 == 0:
			return -1
		if random.next_u15() % 10 < 4:
			counters.deferred_helicopters += 1
		else:
			counters.deferred_airplanes += 1
		return -1
	var runway_groups := int(
		(_special_tile_count(misc, 0xdd, military) + _special_tile_count(misc, 0xde, military)) / 5
	)
	var parking_tile := 0xef if military else 0xee
	if int(_special_tile_count(misc, parking_tile, military) / 4) >= runway_groups:
		return 0xdd
	var selected := 0xe2 if military else 0xe1
	if _special_tile_count(misc, selected, military) * 2 < runway_groups:
		return selected
	selected = 0xea
	if _special_tile_count(misc, selected, military) * 2 < runway_groups:
		return selected
	selected = 0xe7 if military else 0xe6
	if _special_tile_count(misc, selected, military) < runway_groups:
		return selected
	selected = 0xe4
	if int(_special_tile_count(misc, selected, military) / 2) < runway_groups:
		return selected
	selected = 0xe5
	if int(_special_tile_count(misc, selected, military) / 2) < runway_groups:
		return selected
	if int(_special_tile_count(misc, 0xf6, military) / 4) < runway_groups:
		return 0xf6
	return parking_tile


static func _seaport_growth_selection(
	misc: PackedByteArray,
	current_tile: int,
	military: bool,
	random,
	counters: Dictionary
) -> int:
	if random.next_u15() & 3:
		if not military and current_tile == 0xe0 and random.next_u15() & 3 == 0:
			counters.deferred_ships += 1
		return -1
	var crane_count := _special_tile_count(misc, 0xe0, military)
	if int(_special_tile_count(misc, 0xf2, military) / 4) >= crane_count:
		return 0xe0
	var second_tile := 0xf1 if military else 0xf0
	if int(_special_tile_count(misc, second_tile, military) / 4) < crane_count:
		return second_tile
	if int(_special_tile_count(misc, 0xe3, military) / 3) < crane_count:
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
	rotation: int
) -> Dictionary:
	if zone != 7 and not _has_power(flags, point.x, point.y):
		return {"ok": false, "changed_tiles": 0}
	if tile == 0xdd:
		return _place_runway(
			buildings, zones, flags, misc, point, zone, rotation
		)
	if tile == 0xe0:
		return _place_crane_and_pier(
			buildings, zones, flags, terrain, altitudes,
			misc, point, zone, rotation
		)
	if SPECIAL_SIMPLE_TILES.has(tile):
		var before := int(buildings[_index(point)])
		if before < 0x0d:
			_place_special_item(
				buildings, zones, flags, terrain, misc, point, tile, 1, zone, rotation
			)
		zones[_index(point)] = (zones[_index(point)] & 0xf0) | zone
		if zone == 7:
			flags[_index(point)] &= 0x0f
		return {"ok": true, "changed_tiles": int(buildings[_index(point)] != before)}
	if SPECIAL_TWO_BY_TWO_TILES.has(tile):
		return _place_special_two_by_two(
			buildings, zones, flags, terrain, misc, point, tile, zone, rotation
		)
	if tile == 0xf9:
		return _place_missile_silo(
			buildings, zones, underground, misc, point, zone, rotation
		)
	return {"ok": true, "changed_tiles": 0}


static func _place_runway(
	buildings: PackedByteArray,
	zones: PackedByteArray,
	flags: PackedByteArray,
	misc: PackedByteArray,
	point: Vector2i,
	zone: int,
	rotation: int
) -> Dictionary:
	# the supplied win95 executable always uses the normal runway count here
	# sc2kfix changes this to use the military count for a military zone
	var count := _special_tile_count(misc, 0xdd, false)
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
	while _index(checked) >= 0:
		var checked_index := _index(checked)
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
		var index := _index(current)
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
			_clear_special_building(buildings, zones, flags, misc, current)
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
	rotation: int
) -> Dictionary:
	var direction := Vector2i.ZERO
	for candidate in CARDINAL_DIRECTIONS:
		var neighbor: Vector2i = point + candidate
		var neighbor_index := _index(neighbor)
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
		var index := _index(checked)
		if index < 0 or flags[index] & 0x04 == 0 or buildings[index] != 0:
			return {"ok": false, "changed_tiles": 0}
	var last_word := int(altitudes[_index(checked)])
	if ((last_word & 0x03e0) >> 5) < (last_word & 0x1f) + 2:
		return {"ok": false, "changed_tiles": 0}
	_clear_special_building(buildings, zones, flags, misc, point)
	var before := int(buildings[_index(point)])
	_place_special_item(
		buildings, zones, flags, terrain, misc, point, 0xe0, 1, zone, rotation
	)
	zones[_index(point)] = (zones[_index(point)] & 0xf0) | zone
	if zone == 7:
		flags[_index(point)] &= 0x0f
	var changed_tiles := int(buildings[_index(point)] != before)
	var flip := _special_axis_is_flipped(direction.x, rotation)
	var pier := point
	for unused in 4:
		pier += direction
		var index := _index(pier)
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
	rotation: int
) -> Dictionary:
	var anchor := Vector2i(point.x & ~1, point.y & ~1)
	if anchor.x < 0 or anchor.y < 0 or anchor.x >= 127 or anchor.y >= 127:
		return {"ok": false, "changed_tiles": 0}
	var points := [
		anchor, anchor + Vector2i(1, 0), anchor + Vector2i(0, 1), anchor + Vector2i(1, 1),
	]
	for point_index in points.size():
		var checked: Vector2i = points[point_index]
		var index := _index(checked)
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
		_clear_special_building(buildings, zones, flags, misc, checked)
	var before := buildings.duplicate()
	_place_special_item(
		buildings, zones, flags, terrain, misc, anchor, tile, 2, zone, rotation
	)
	for checked in points:
		var index := _index(checked)
		zones[index] = (zones[index] & 0xf0) | zone
		if zone == 7:
			flags[index] &= 0x0f
	var changed_tiles := 0
	for checked in points:
		var index := _index(checked)
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
	rotation: int
) -> bool:
	var origin := anchor - Vector2i.ONE if area > 2 else anchor
	var points: Array[Vector2i] = []
	for x in range(origin.x, origin.x + area):
		for y in range(origin.y, origin.y + area):
			var point := Vector2i(x, y)
			var index := _index(point)
			if index < 0 or (area > 1 and (x < 1 or y < 1 or x > 126 or y > 126)):
				return false
			if buildings[index] >= 0x1d or buildings[index] == 0x05 or buildings[index] == 0x0d:
				return false
			if (zones[index] & 0x0f) == 7:
				return false
			if terrain[index] != 0 or flags[index] & 0x04:
				return false
			points.append(point)
	for point in points:
		var index := _index(point)
		flags[index] = (flags[index] & 0x1f) | 0xe0
		_replace_special_building(buildings, zones, misc, index, tile)
		zones[index] = 0
	if area == 1:
		zones[_index(origin)] |= 0xf0
	else:
		_set_corners(zones, origin, area, rotation)
	for point in points:
		zones[_index(point)] = (zones[_index(point)] & 0xf0) | zone
	return true


static func _place_missile_silo(
	buildings: PackedByteArray,
	zones: PackedByteArray,
	underground: PackedByteArray,
	misc: PackedByteArray,
	point: Vector2i,
	zone: int,
	rotation: int
) -> Dictionary:
	var origin := point
	for unused in 2:
		var left := origin + Vector2i(-1, 0)
		if _index(left) >= 0 and (zones[_index(left)] & 0x0f) == zone:
			origin = left
	for unused in 2:
		var upper := origin + Vector2i(0, -1)
		if _index(upper) >= 0 and (zones[_index(upper)] & 0x0f) == zone:
			origin = upper
	if origin.x < 0 or origin.y < 0 or origin.x > 125 or origin.y > 125:
		return {"ok": false, "changed_tiles": 0}
	var changed_tiles := 0
	for x in range(origin.x, origin.x + 3):
		for y in range(origin.y, origin.y + 3):
			var index := x * CityState.MAP_SIZE + y
			if buildings[index] != 0xf9:
				changed_tiles += 1
			_replace_special_building(buildings, zones, misc, index, 0xf9)
			_replace_underground(underground, zones, misc, index, 0x22)
	_set_corners(zones, origin, 3, rotation)
	return {"ok": true, "changed_tiles": changed_tiles}


static func _clear_special_building(
	buildings: PackedByteArray,
	zones: PackedByteArray,
	flags: PackedByteArray,
	misc: PackedByteArray,
	point: Vector2i
) -> void:
	var selected_index := _index(point)
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
		var index := _index(cleared)
		if index < 0:
			continue
		_replace_special_building(buildings, zones, misc, index, 0)
		flags[index] &= 0x3f
		zones[index] &= 0x0f


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
	_write_u32(misc, old_offset, (_read_u32(misc, old_offset) - 1) & 0xffff)
	_write_u32(misc, new_offset, (_read_u32(misc, new_offset) + 1) & 0xffff)
	buildings[index] = new_tile


static func _special_tile_count(misc: PackedByteArray, tile: int, military: bool) -> int:
	return _read_u32(misc, _special_count_offset(tile, military)) & 0xffff


static func _special_count_offset(tile: int, military: bool) -> int:
	if not military:
		return MISC_TILE_COUNTS + tile * 4
	return MISC_MILITARY_TILE_COUNTS + int(MILITARY_TILE_COUNT_INDEX.get(tile, 0)) * 4


static func _special_axis_is_flipped(x_delta: int, rotation: int) -> bool:
	return bool(rotation & 1) if x_delta == 0 else not bool(rotation & 1)


static func _process_surface_maintenance(
	altitude: PackedByteArray,
	altitudes: PackedInt32Array,
	terrain: PackedByteArray,
	buildings: PackedByteArray,
	zones: PackedByteArray,
	underground: PackedByteArray,
	flags: PackedByteArray,
	misc: PackedByteArray,
	point: Vector2i,
	random,
	lfsr_random,
	counters: Dictionary
) -> void:
	var index := _index(point)
	var tile := int(buildings[index])
	if tile < 0x1d or lfsr_random.next_mask(0x7f) != 0:
		return
	if _is_road_budget_tile(tile):
		if _maintenance_fails(misc, 10, random, 100):
			_replace_building(buildings, zones, misc, index, 1 + (random.next_u15() & 3))
			flags[index] &= 0x7f
			counters.decayed_roads += 1
		return
	if _is_rail_budget_tile(tile):
		if _maintenance_fails(misc, 13, random, 100):
			_replace_building(buildings, zones, misc, index, 1 + (random.next_u15() & 3))
			flags[index] &= 0x7f
			counters.decayed_rails += 1
		return
	if _is_bridge_budget_tile(tile):
		var wind := _read_u32(misc, 0x0064) & 0xff
		if _maintenance_fails(misc, 12, random, 50, wind):
			if tile == 0x6a or tile == 0x6b:
				counters.deferred_bridge_collapses += 1
				return
			var result := Demolish._demolish_bridge(
				altitude, buildings, terrain, zones, underground, flags, misc, point
			)
			if not result.get("changed", false):
				counters.deferred_bridge_collapses += 1
				return
			_sync_altitudes(altitude, altitudes)
			counters.collapsed_bridges += 1
			counters.deferred_bridge_effects += 1
		return
	if _is_highway_budget_tile(tile):
		if point.x & 1 or point.y & 1:
			return
		if not _maintenance_fails(misc, 11, random, 100):
			return
		for highway_point in [
			point,
			point + Vector2i(1, 0),
			point + Vector2i(0, 1),
			point + Vector2i(1, 1),
		]:
			var highway_index := _index(highway_point)
			var replacement := 0
			if flags[highway_index] & 0x04 == 0:
				replacement = 1 + (random.next_u15() & 3)
			_replace_building(buildings, zones, misc, highway_index, replacement)
			counters.decayed_highway_tiles += 1


static func _process_subway_maintenance(
	terrain: PackedByteArray,
	buildings: PackedByteArray,
	zones: PackedByteArray,
	flags: PackedByteArray,
	text_overlays: PackedByteArray,
	underground: PackedByteArray,
	misc: PackedByteArray,
	point: Vector2i,
	random,
	lfsr_random,
	counters: Dictionary
) -> void:
	if lfsr_random.next_mask(0x7f) != 0:
		return
	var index := _index(point)
	var old_tile := int(underground[index])
	if not _is_subway_tile(old_tile):
		return
	if not _maintenance_fails(misc, 14, random, 100):
		return
	var replacement := 0
	if old_tile == 0x1f:
		replacement = 0x11
	elif old_tile == 0x20:
		replacement = 0x10
	elif old_tile == 0x23:
		if buildings[index] != 0xe9:
			counters.deferred_station_removals += 1
			return
		var surface_replacement := 0
		if terrain[index] == 0:
			surface_replacement = 1 + (random.next_u15() & 3)
		_replace_building(buildings, zones, misc, index, surface_replacement)
		zones[index] &= 0x0f
		flags[index] &= 0x3d
		var overlay := int(text_overlays[index])
		if overlay < 0xc9 or overlay == 0xfa:
			text_overlays[index] = 0
		_replace_underground(underground, zones, misc, index, 0)
		counters.removed_subway_stations += 1
		counters.decayed_subway_tiles += 1
		return
	_replace_underground(underground, zones, misc, index, replacement)
	counters.decayed_subway_tiles += 1


static func _maintenance_fails(
	misc: PackedByteArray,
	budget_index: int,
	random,
	random_range: int,
	additional_value := 0
) -> bool:
	var funding := _read_i32(
		misc, MISC_BUDGETS + budget_index * MISC_BUDGET_RECORD_SIZE + 4
	)
	return funding != 100 and additional_value + random.next_u15() % random_range >= funding


static func _is_road_budget_tile(tile: int) -> bool:
	return (
		(tile >= 0x1d and tile <= 0x2b)
		or (tile >= 0x3f and tile <= 0x46)
		or tile == 0x4b
		or tile == 0x4c
		or (tile >= 0x5d and tile <= 0x60)
	)


static func _is_rail_budget_tile(tile: int) -> bool:
	return (
		(tile >= 0x2c and tile <= 0x3e)
		or (tile >= 0x45 and tile <= 0x48)
		or (tile >= 0x6c and tile <= 0x6f)
		or tile == 0x4d
		or tile == 0x4e
	)


static func _is_bridge_budget_tile(tile: int) -> bool:
	return (tile >= 0x51 and tile <= 0x5c) or tile == 0x6a or tile == 0x6b


static func _is_highway_budget_tile(tile: int) -> bool:
	return (tile >= 0x49 and tile <= 0x50) or (tile >= 0x61 and tile <= 0x69)


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
			count = (count - 1) & 0xffff
		if _is_subway_tile(new_tile):
			count = (count + 1) & 0xffff
		_write_u32(misc, MISC_SUBWAY_COUNT, count)
	underground[index] = new_tile


static func _can_advance_density(
	zone_byte: int,
	zone: int,
	density: int,
	land_value: PackedByteArray,
	x: int,
	y: int
) -> bool:
	if density == 4:
		return false
	if zone_byte & 1 and density >= 1:
		return false
	if zone > 4:
		return true
	var value := int(land_value[int(x / 2) * 64 + int(y / 2)])
	return (
		(density != 1 or value > 0x1f)
		and (density != 2 or value > 0x5f)
		and (density != 3 or value > 0xbf)
	)


static func _advance_construction(
	buildings: PackedByteArray,
	zones: PackedByteArray,
	flags: PackedByteArray,
	misc: PackedByteArray,
	land_value: PackedByteArray,
	altitudes: PackedInt32Array,
	point: Vector2i,
	density: int,
	zone: int,
	random,
	rotation: int
) -> bool:
	match density:
		0:
			return _place_zone(
				buildings, zones, flags, misc, land_value, point,
				1, CLASS_CONSTRUCTION, random, rotation
			)
		1:
			var height := altitudes[_index(point)] & 0x1f
			var right := point + Vector2i(1, 0)
			var down := point + Vector2i(0, 1)
			var down_right := point + Vector2i(1, 1)
			if (
				_can_build_site(buildings, zones, altitudes, right, height, zone, 0x8c)
				and _can_build_site(buildings, zones, altitudes, down, height, zone, 0x8c)
				and _can_build_site(buildings, zones, altitudes, down_right, height, zone, 0x8c)
			):
				return _place_zone(
					buildings, zones, flags, misc, land_value, down,
					2, CLASS_CONSTRUCTION, random, rotation
				)
			var up := point + Vector2i(0, -1)
			var up_right := point + Vector2i(1, -1)
			if (
				_can_build_site(buildings, zones, altitudes, right, height, zone, 0x8c)
				and _can_build_site(buildings, zones, altitudes, up, height, zone, 0x8c)
				and _can_build_site(buildings, zones, altitudes, up_right, height, zone, 0x8c)
			):
				return _place_zone(
					buildings, zones, flags, misc, land_value, point,
					2, CLASS_CONSTRUCTION, random, rotation
				)
			var left := point + Vector2i(-1, 0)
			var down_left := point + Vector2i(-1, 1)
			if (
				_can_build_site(buildings, zones, altitudes, down, height, zone, 0x8c)
				and _can_build_site(buildings, zones, altitudes, left, height, zone, 0x8c)
				and _can_build_site(buildings, zones, altitudes, down_left, height, zone, 0x8c)
			):
				return _place_zone(
					buildings, zones, flags, misc, land_value, down_left,
					2, CLASS_CONSTRUCTION, random, rotation
				)
			var up_left := point + Vector2i(-1, -1)
			if (
				_can_build_site(buildings, zones, altitudes, up, height, zone, 0x8c)
				and _can_build_site(buildings, zones, altitudes, left, height, zone, 0x8c)
				and _can_build_site(buildings, zones, altitudes, up_left, height, zone, 0x8c)
			):
				return _place_zone(
					buildings, zones, flags, misc, land_value, left,
					2, CLASS_CONSTRUCTION, random, rotation
				)
		2:
			return _place_zone(
				buildings, zones, flags, misc, land_value, point,
				3, CLASS_CONSTRUCTION, random, rotation
			)
		3:
			return _advance_to_density_four(
				buildings, zones, flags, misc, land_value, altitudes,
				point, zone, random, rotation
			)
	return false


static func _advance_to_density_four(
	buildings: PackedByteArray,
	zones: PackedByteArray,
	flags: PackedByteArray,
	misc: PackedByteArray,
	land_value: PackedByteArray,
	altitudes: PackedInt32Array,
	point: Vector2i,
	zone: int,
	random,
	rotation: int
) -> bool:
	var height := altitudes[_index(point)] & 0x1f
	for candidate_index in 4:
		var anchor := point + Vector2i(-(candidate_index & 1), int(candidate_index / 2))
		var perimeter := [
			anchor,
			anchor + Vector2i(0, -1),
			anchor + Vector2i(0, -2),
			anchor + Vector2i(1, -2),
			anchor + Vector2i(2, -2),
			anchor + Vector2i(2, -1),
			anchor + Vector2i(2, 0),
			anchor + Vector2i(1, 0),
		]
		var valid := true
		for checked_point in perimeter:
			if not _can_build_site(buildings, zones, altitudes, checked_point, height, zone, 0xae):
				valid = false
				break
		if not valid or not _has_density_four_road(buildings, anchor):
			continue
		for checked_point in perimeter:
			var index := _index(checked_point)
			if index >= 0 and buildings[index] > 0x8b:
				_clear_growth_building(
					buildings, zones, flags, misc, land_value,
					checked_point, random, rotation
				)
		return _place_zone(
			buildings, zones, flags, misc, land_value, anchor,
			4, CLASS_CONSTRUCTION, random, rotation
		)
	return false


static func _has_density_four_road(buildings: PackedByteArray, anchor: Vector2i) -> bool:
	var checks := [
		[anchor + Vector2i(-1, 1), [0x23, 0x27, 0x28, 0x2b]],
		[anchor + Vector2i(-1, -3), [0x24, 0x28, 0x29, 0x2b]],
		[anchor + Vector2i(3, -3), [0x25, 0x29, 0x2a, 0x2b]],
		[anchor + Vector2i(3, 1), [0x26, 0x2a, 0x27, 0x2b]],
	]
	for check in checks:
		var index := _index(check[0])
		if index >= 0 and check[1].has(int(buildings[index])):
			return true
	return false


static func _clear_growth_building(
	buildings: PackedByteArray,
	zones: PackedByteArray,
	flags: PackedByteArray,
	misc: PackedByteArray,
	land_value: PackedByteArray,
	point: Vector2i,
	random,
	rotation: int
) -> void:
	var direction: int
	match zones[_index(point)] & 0xf0:
		0x10:
			direction = -rotation & 3
		0x20:
			direction = 1 - rotation & 3
		0x40:
			direction = -rotation - 2 & 3
		0x80:
			direction = -rotation - 1 & 3
		_:
			return
	var anchor := point
	if direction == 0:
		anchor.y += 1
	elif direction == 1:
		anchor += Vector2i(-1, 1)
	elif direction == 2:
		anchor.x -= 1
	for abandoned_point in [
		anchor,
		anchor + Vector2i(1, 0),
		anchor + Vector2i(1, -1),
		anchor + Vector2i(0, -1),
	]:
		_place_zone(
			buildings, zones, flags, misc, land_value, abandoned_point,
			1, CLASS_ABANDONED, random, rotation
		)


static func _can_build_site(
	buildings: PackedByteArray,
	zones: PackedByteArray,
	altitudes: PackedInt32Array,
	point: Vector2i,
	height: int,
	zone: int,
	maximum_building: int
) -> bool:
	var index := _index(point)
	if index < 0:
		return false
	if (altitudes[index] & 0x1f) != height or (zones[index] & 0x0f) != zone:
		return false
	var building := int(buildings[index])
	if building >= maximum_building:
		return false
	return not _is_surface_network(building)


static func _is_surface_network(tile: int) -> bool:
	return (
		(tile >= 0x1d and tile <= 0x3e)
		or (tile >= 0x3f and tile <= 0x48)
		or (tile >= 0x4b and tile <= 0x4e)
		or (tile >= 0x5d and tile <= 0x60)
		or (tile >= 0x6c and tile <= 0x6f)
	)


static func _abandon(
	buildings: PackedByteArray,
	zones: PackedByteArray,
	flags: PackedByteArray,
	misc: PackedByteArray,
	point: Vector2i,
	density: int,
	pattern: int,
	random,
	rotation: int,
	land_value: PackedByteArray
) -> void:
	match density:
		1:
			_place_zone(
				buildings, zones, flags, misc, land_value, point,
				1, CLASS_ABANDONED, random, rotation
			)
		2:
			if pattern == 0:
				_place_zone(
					buildings, zones, flags, misc, land_value, point,
					2, CLASS_ABANDONED, random, rotation
				)
			else:
				for abandoned_point in [
					point,
					point + Vector2i(1, 0),
					point + Vector2i(1, -1),
					point + Vector2i(0, -1),
				]:
					_place_zone(
						buildings, zones, flags, misc, land_value, abandoned_point,
						1, CLASS_ABANDONED, random, rotation
					)
		3:
			_place_zone(
				buildings, zones, flags, misc, land_value, point,
				3 if pattern == 0 else 2, CLASS_ABANDONED, random, rotation
			)
		4:
			if pattern == 0:
				_place_zone(
					buildings, zones, flags, misc, land_value, point,
					4, CLASS_ABANDONED, random, rotation
				)
			else:
				for abandoned_point in [
					point,
					point + Vector2i(1, 0),
					point + Vector2i(2, 0),
					point + Vector2i(2, -1),
					point + Vector2i(2, -2),
					point + Vector2i(1, -2),
					point + Vector2i(0, -2),
					point + Vector2i(0, -1),
				]:
					_place_zone(
						buildings, zones, flags, misc, land_value, abandoned_point,
						1, CLASS_ABANDONED, random, rotation
					)
				var selection: int = random.next_u15() & 3
				_place_zone(
					buildings,
					zones,
					flags,
					misc,
					land_value,
					point + Vector2i(selection & 1, -int(selection / 2)),
					3,
					CLASS_ABANDONED,
					random,
					rotation,
				)


static func _place_zone(
	buildings: PackedByteArray,
	zones: PackedByteArray,
	flags: PackedByteArray,
	misc: PackedByteArray,
	land_value: PackedByteArray,
	anchor: Vector2i,
	density: int,
	building_class: int,
	random,
	rotation: int
) -> bool:
	var tile: int
	if density == 1 and building_class == CLASS_RESIDENTIAL:
		var value_index := int(anchor.x / 2) * 64 + int(anchor.y / 2)
		var value_group := mini(int(land_value[value_index]) >> 6, 2)
		tile = BUILDING_BASE[1] + value_group * 4 + (random.next_u15() & 3)
	else:
		var table_index := density + building_class * 4
		var tile_range: int = BUILDING_RANGE[table_index]
		tile = BUILDING_BASE[table_index] + random.next_u15() % tile_range
	if density == 1:
		var index := _index(anchor)
		if index < 0:
			return false
		_replace_building(buildings, zones, misc, index, tile)
		zones[index] |= 0xf0
		flags[index] |= 0xe0
		return true

	var radius := int(density / 2)
	if (
		anchor.x <= 1
		or anchor.y <= 1
		or anchor.x > 126 - radius
		or anchor.y > 126 - radius
	):
		return false
	var site_position := Vector2i(anchor.x, anchor.y - radius)
	for x in range(site_position.x, site_position.x + radius + 1):
		for y in range(site_position.y, site_position.y + radius + 1):
			var index := x * CityState.MAP_SIZE + y
			_replace_building(buildings, zones, misc, index, tile)
			zones[index] &= 0x0f
			flags[index] |= 0xe0
	_set_corners(zones, site_position, radius + 1, rotation)
	return true


static func _place_church(
	buildings: PackedByteArray,
	zones: PackedByteArray,
	flags: PackedByteArray,
	misc: PackedByteArray,
	anchor: Vector2i,
	rotation: int
) -> bool:
	if anchor.x <= 0 or anchor.y <= 0 or anchor.x >= 127 or anchor.y >= 127:
		return false
	var position := Vector2i(anchor.x, anchor.y - 1)
	for x in range(position.x, position.x + 2):
		for y in range(position.y, position.y + 2):
			var index := x * CityState.MAP_SIZE + y
			_replace_building(buildings, zones, misc, index, CHURCH_TILE)
			zones[index] = 0
			flags[index] |= 0xe0
	_set_corners(zones, position, 2, rotation)
	return true


# The zone and building corner flags share one byte.
static func _set_corners(
	zones: PackedByteArray, position: Vector2i, area: int, rotation: int
) -> void:
	var far := position + Vector2i(area - 1, area - 1)
	var view := rotation & 3
	var bottom_left := position.x * CityState.MAP_SIZE + position.y
	var bottom_right := far.x * CityState.MAP_SIZE + position.y
	var top_left := far.x * CityState.MAP_SIZE + far.y
	var top_right := position.x * CityState.MAP_SIZE + far.y
	zones[bottom_left] = (zones[bottom_left] & 0x0f) | CORNER_BOTTOM_LEFT[view]
	zones[bottom_right] = (zones[bottom_right] & 0x0f) | CORNER_BOTTOM_RIGHT[view]
	zones[top_left] = (zones[top_left] & 0x0f) | CORNER_TOP_LEFT[view]
	zones[top_right] = (zones[top_right] & 0x0f) | CORNER_TOP_RIGHT[view]


static func _has_power(flags: PackedByteArray, x: int, y: int) -> bool:
	var index := x * CityState.MAP_SIZE + y
	if flags[index] & 0x40:
		return true
	if x > 1 and flags[(x - 1) * CityState.MAP_SIZE + y] & 0x40:
		return true
	if y > 1 and flags[x * CityState.MAP_SIZE + y - 1] & 0x40:
		return true
	if x < 127 and flags[(x + 1) * CityState.MAP_SIZE + y] & 0x40:
		return true
	return y < 127 and (flags[x * CityState.MAP_SIZE + y + 1] & 0x40) != 0


static func _density(tile: int) -> int:
	if tile <= 0x8b:
		return 1
	if tile <= 0x8f:
		return 2
	if tile <= 0x93:
		return 3
	if tile <= 0x98:
		return 2
	if tile <= 0x9d:
		return 3
	if tile <= 0xa1:
		return 2
	if tile <= 0xa5:
		return 3
	if tile <= 0xa7:
		return 2
	if tile <= 0xa9:
		return 3
	if tile <= 0xab:
		return 2
	if tile <= 0xad:
		return 3
	return 4


static func _status(tile: int) -> int:
	if (
		(tile >= 0x88 and tile <= 0x89)
		or (tile >= 0xa6 and tile <= 0xa9)
		or (tile >= 0xc2 and tile <= 0xc3)
	):
		return STATUS_CONSTRUCTION
	if (
		(tile >= 0x8a and tile <= 0x8b)
		or (tile >= 0xaa and tile <= 0xad)
		or (tile >= 0xc4 and tile <= 0xc5)
	):
		return STATUS_ABANDONED
	return STATUS_NORMAL


static func _replace_building(
	buildings: PackedByteArray,
	zones: PackedByteArray,
	misc: PackedByteArray,
	index: int,
	new_tile: int
) -> void:
	var old_tile := int(buildings[index])
	if old_tile == new_tile:
		return
	if (zones[index] & 0x0f) != 7:
		var old_offset := MISC_TILE_COUNTS + old_tile * 4
		var new_offset := MISC_TILE_COUNTS + new_tile * 4
		_write_u32(misc, old_offset, (_read_u32(misc, old_offset) - 1) & 0xffff)
		_write_u32(misc, new_offset, (_read_u32(misc, new_offset) + 1) & 0xffff)
	buildings[index] = new_tile


static func _payloads(city: CityState) -> Dictionary:
	var result := {}
	for checked in [
		["ALTM", CityState.TILE_COUNT * 2],
		["XTER", CityState.TILE_COUNT],
		["XBLD", CityState.TILE_COUNT],
		["XZON", CityState.TILE_COUNT],
		["XUND", CityState.TILE_COUNT],
		["XTXT", CityState.TILE_COUNT],
		["XBIT", CityState.TILE_COUNT],
		["XTRF", MAP_VALUE_COUNT],
		["XVAL", MAP_VALUE_COUNT],
		["MISC", MISC_SIZE],
	]:
		var chunk := city.document.find_chunk(checked[0])
		if chunk == null or chunk.decoded_payload.size() != checked[1]:
			return {}
		result[checked[0]] = chunk.decoded_payload.duplicate()
	return result


static func _duplicate_payloads(payloads: Dictionary) -> Dictionary:
	var result := {}
	for chunk_id in payloads:
		result[chunk_id] = payloads[chunk_id].duplicate()
	return result


static func _apply_payloads(
	city: CityState,
	chunk_ids: PackedStringArray,
	payloads: Dictionary,
	rollback: Dictionary
) -> bool:
	var applied := PackedStringArray()
	for chunk_id in chunk_ids:
		var chunk := city.document.find_chunk(chunk_id)
		if chunk == null or not chunk.set_decoded_payload(payloads[chunk_id]):
			for rollback_id in applied:
				city.document.find_chunk(rollback_id).set_decoded_payload(rollback[rollback_id])
			_refresh_city(city)
			return false
		applied.append(chunk_id)
	_refresh_city(city)
	return true


static func _refresh_city(city: CityState) -> void:
	var altitude: PackedByteArray = city.document.find_chunk("ALTM").decoded_payload
	for index in CityState.TILE_COUNT:
		city.altitude_words[index] = (altitude[index * 2] << 8) | altitude[index * 2 + 1]
	city.terrain = city.document.find_chunk("XTER").decoded_payload.duplicate()
	city.buildings = city.document.find_chunk("XBLD").decoded_payload.duplicate()
	city.zones = city.document.find_chunk("XZON").decoded_payload.duplicate()
	city.underground = city.document.find_chunk("XUND").decoded_payload.duplicate()
	city.text_overlays = city.document.find_chunk("XTXT").decoded_payload.duplicate()
	city.tile_flags = city.document.find_chunk("XBIT").decoded_payload.duplicate()


static func _sync_altitudes(altitude: PackedByteArray, altitudes: PackedInt32Array) -> void:
	for index in CityState.TILE_COUNT:
		altitudes[index] = (altitude[index * 2] << 8) | altitude[index * 2 + 1]


static func _index(point: Vector2i) -> int:
	if point.x < 0 or point.x >= CityState.MAP_SIZE or point.y < 0 or point.y >= CityState.MAP_SIZE:
		return -1
	return point.x * CityState.MAP_SIZE + point.y


static func _add_i32(data: PackedByteArray, offset: int, value: int) -> void:
	_write_u32(data, offset, _read_i32(data, offset) + value)


static func _read_i32(data: PackedByteArray, offset: int) -> int:
	var value := _read_u32(data, offset)
	return value - 0x100000000 if value & 0x80000000 else value


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
