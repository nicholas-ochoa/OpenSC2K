class_name GrowthConstruction
extends GrowthConstants



static func _can_advance_density(
	zone_byte: int,
	zone: int,
	density: int,
	land_value: PackedByteArray,
	x: int,
	y: int,
	map_edge: int = 128,
) -> bool:
	if density == 4:
		return false

	if zone_byte & 1 and density >= 1:
		return false

	if zone > 4:
		return true

	var value := int(land_value[CityDataGrid.index(land_value, map_edge, x, y)])

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
	rotation: int,
	map_edge: int = 128,
) -> bool:
	match density:
		0:
			return GrowthDevelopment._place_zone(
				buildings, zones, flags, misc, land_value, point,
				1, CLASS_CONSTRUCTION, random, rotation, map_edge
			)
		1:
			var height := altitudes[GrowthState._index(point, map_edge)] & 0x1f
			var right := point + Vector2i(1, 0)
			var down := point + Vector2i(0, 1)
			var down_right := point + Vector2i(1, 1)

			if (
				_can_build_site(buildings, zones, altitudes, right, height, zone, 0x8c, map_edge)
				and _can_build_site(buildings, zones, altitudes, down, height, zone, 0x8c, map_edge)
				and _can_build_site(buildings, zones, altitudes, down_right, height, zone, 0x8c, map_edge)
			):
				return GrowthDevelopment._place_zone(
					buildings, zones, flags, misc, land_value, down,
					2, CLASS_CONSTRUCTION, random, rotation, map_edge
				)

			var up := point + Vector2i(0, -1)
			var up_right := point + Vector2i(1, -1)

			if (
				_can_build_site(buildings, zones, altitudes, right, height, zone, 0x8c, map_edge)
				and _can_build_site(buildings, zones, altitudes, up, height, zone, 0x8c, map_edge)
				and _can_build_site(buildings, zones, altitudes, up_right, height, zone, 0x8c, map_edge)
			):
				return GrowthDevelopment._place_zone(
					buildings, zones, flags, misc, land_value, point,
					2, CLASS_CONSTRUCTION, random, rotation, map_edge
				)

			var left := point + Vector2i(-1, 0)
			var down_left := point + Vector2i(-1, 1)

			if (
				_can_build_site(buildings, zones, altitudes, down, height, zone, 0x8c, map_edge)
				and _can_build_site(buildings, zones, altitudes, left, height, zone, 0x8c, map_edge)
				and _can_build_site(buildings, zones, altitudes, down_left, height, zone, 0x8c, map_edge)
			):
				return GrowthDevelopment._place_zone(
					buildings, zones, flags, misc, land_value, down_left,
					2, CLASS_CONSTRUCTION, random, rotation, map_edge
				)

			var up_left := point + Vector2i(-1, -1)

			if (
				_can_build_site(buildings, zones, altitudes, up, height, zone, 0x8c, map_edge)
				and _can_build_site(buildings, zones, altitudes, left, height, zone, 0x8c, map_edge)
				and _can_build_site(buildings, zones, altitudes, up_left, height, zone, 0x8c, map_edge)
			):
				return GrowthDevelopment._place_zone(
					buildings, zones, flags, misc, land_value, left,
					2, CLASS_CONSTRUCTION, random, rotation, map_edge
				)
		2:
			return GrowthDevelopment._place_zone(
				buildings, zones, flags, misc, land_value, point,
				3, CLASS_CONSTRUCTION, random, rotation, map_edge
			)
		3:
			return _advance_to_density_four(
				buildings, zones, flags, misc, land_value, altitudes,
				point, zone, random, rotation, map_edge
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
	rotation: int,
	map_edge: int = 128,
) -> bool:
	var height := altitudes[GrowthState._index(point, map_edge)] & 0x1f

	for candidate_index in 4:
		var anchor := point + Vector2i(-(candidate_index & 1), int(IntegerMath.div_trunc(candidate_index, 2)))
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
			if not _can_build_site(buildings, zones, altitudes, checked_point, height, zone, 0xae, map_edge):
				valid = false
				break

		if not valid or not _has_density_four_road(buildings, anchor, map_edge):
			continue

		for checked_point in perimeter:
			var index := GrowthState._index(checked_point, map_edge)

			if index >= 0 and buildings[index] > 0x8b:
				_clear_growth_building(
					buildings, zones, flags, misc, land_value,
					checked_point, random, rotation, map_edge
				)

		return GrowthDevelopment._place_zone(
			buildings, zones, flags, misc, land_value, anchor,
			4, CLASS_CONSTRUCTION, random, rotation, map_edge
		)

	return false


static func _has_density_four_road(buildings: PackedByteArray, anchor: Vector2i, map_edge: int = 128) -> bool:
	var checks := [
		[anchor + Vector2i(-1, 1), [0x23, 0x27, 0x28, 0x2b]],
		[anchor + Vector2i(-1, -3), [0x24, 0x28, 0x29, 0x2b]],
		[anchor + Vector2i(3, -3), [0x25, 0x29, 0x2a, 0x2b]],
		[anchor + Vector2i(3, 1), [0x26, 0x2a, 0x27, 0x2b]],
	]

	for check in checks:
		var index := GrowthState._index(check[0], map_edge)

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
	rotation: int,
	map_edge: int = 128,
) -> void:
	var direction: int

	match zones[GrowthState._index(point, map_edge)] & 0xf0:
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
		GrowthDevelopment._place_zone(
			buildings, zones, flags, misc, land_value, abandoned_point,
			1, CLASS_ABANDONED, random, rotation, map_edge
		)


static func _can_build_site(
	buildings: PackedByteArray,
	zones: PackedByteArray,
	altitudes: PackedInt32Array,
	point: Vector2i,
	height: int,
	zone: int,
	maximum_building: int,
	map_edge: int = 128,
) -> bool:
	var index := GrowthState._index(point, map_edge)

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
