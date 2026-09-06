class_name HighwayPlacement
extends HighwayConstants


class Result extends RefCounted:
	var ok := false
	var error := ""
	var kind := 0
	var graded := false

	static func failure(message: String) -> Result:
		var result := Result.new()
		result.error = message

		return result


static func _place_straight_section(
	buildings: PackedByteArray,
	zones: PackedByteArray,
	misc: PackedByteArray,
	anchor: Vector2i,
	orientation: int,
	map_edge: int = 128,
) -> void:
	for offset in [Vector2i.ZERO, Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
		var point: Vector2i = anchor + offset
		var index := point.x * map_edge + point.y
		zones[index] &= 0xf0
		var tile_id := _straight_replacement(buildings[index], orientation)
		NetworkState.replace_building(buildings, zones, misc, index, tile_id)
		zones[index] |= 0xf0


static func _straight_replacement(old_tile: int, orientation: int) -> int:
	match old_tile:
		0x0e:
			return 0x50
		0x0f:
			return 0x4f
		0x1d:
			return 0x4c
		0x1e:
			return 0x4b
		0x2c:
			return 0x4e
		0x2d:
			return 0x4d
		_:
			return STRAIGHT_FIRST + orientation


static func _place_section(
	buildings: PackedByteArray,
	terrain: PackedByteArray,
	zones: PackedByteArray,
	flags: PackedByteArray,
	altitude: PackedByteArray,
	text_overlays: PackedByteArray,
	misc: PackedByteArray,
	anchor: Vector2i,
	direction: int,
	rotation: int,
	map_edge: int = 128,
) -> Result:
	if HighwayGeometry.terrain_section_shape(buildings, terrain, altitude, anchor, map_edge) == INVALID_TERRAIN_SHAPE:
		return Result.failure("highway terrain grade is invalid")

	_clear_section_zone_types(zones, anchor, map_edge)
	var old_kind := HighwayGeometry._section_kind(buildings, zones, flags, anchor, map_edge)
	var kind := HighwayRoutes.select_section_kind(
		buildings,
		terrain,
		zones,
		flags,
		altitude,
		text_overlays,
		anchor,
		direction, map_edge
	)
	var installed_grade := kind >= 4 and kind <= 7

	if kind >= 0:
		_write_section_kind(
			buildings, terrain, zones, altitude, misc, anchor, kind, rotation, map_edge
		)

	for step in DIRECTIONS:
		var neighbor: Vector2i = anchor + step * 2

		if (
			HighwayGeometry._anchor_is_in_bounds(neighbor, map_edge)
			and HighwayGeometry._section_kind(buildings, zones, flags, neighbor, map_edge) > 1
		):
			_retile_section(
				buildings,
				terrain,
				zones,
				flags,
				altitude,
				text_overlays,
				misc,
				neighbor,
				direction,
				rotation, map_edge
			)

	_retile_section(
		buildings,
		terrain,
		zones,
		flags,
		altitude,
		text_overlays,
		misc,
		anchor,
		direction,
		rotation, map_edge
	)

	var result := Result.new()
	result.ok = true
	result.kind = kind if kind >= 0 else old_kind
	result.graded = installed_grade
	result.error = ""

	return result


static func _clear_section_zone_types(zones: PackedByteArray, anchor: Vector2i, map_edge: int = 128) -> void:
	for offset in [Vector2i.ZERO, Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1)]:
		var point: Vector2i = anchor + offset
		zones[point.x * map_edge + point.y] &= 0xf0


static func _retile_affected_sections(
	buildings: PackedByteArray,
	terrain: PackedByteArray,
	zones: PackedByteArray,
	flags: PackedByteArray,
	altitude: PackedByteArray,
	misc: PackedByteArray,
	placed: Array[Vector2i],
	rotation: int,
	text_overlays := PackedByteArray(),
	route_directions := {},
	map_edge: int = 128,
) -> void:
	var affected := {}

	for anchor in placed:
		affected[anchor] = true

		for step in DIRECTIONS:
			var neighbor: Vector2i = anchor + step * 2

			if (
				HighwayGeometry._anchor_is_in_bounds(neighbor, map_edge)
				and HighwayGeometry._section_kind(buildings, zones, flags, neighbor, map_edge) > 1
			):
				affected[neighbor] = true
	for anchor: Vector2i in affected:
		_retile_section(
			buildings,
			terrain,
			zones,
			flags,
			altitude,
			text_overlays,
			misc,
			anchor,
			int(route_directions.get(anchor, 0)),
			rotation, map_edge
		)


static func _retile_section(
	buildings: PackedByteArray,
	terrain: PackedByteArray,
	zones: PackedByteArray,
	flags: PackedByteArray,
	altitude: PackedByteArray,
	text_overlays: PackedByteArray,
	misc: PackedByteArray,
	anchor: Vector2i,
	direction: int,
	rotation: int,
	map_edge: int = 128,
) -> int:
	var kind := HighwayRoutes.select_section_kind(
		buildings,
		terrain,
		zones,
		flags,
		altitude,
		text_overlays,
		anchor,
		direction, map_edge
	)

	if kind >= 0:
		_write_section_kind(
			buildings, terrain, zones, altitude, misc, anchor, kind, rotation, map_edge
		)

	return kind


static func _prepare_flat_terrain(
	terrain: PackedByteArray, altitude: PackedByteArray, anchor: Vector2i,
	map_edge: int = 128,
) -> void:
	var target := HighwayGeometry._section_altitude(terrain, altitude, anchor, map_edge)

	for offset in [Vector2i.ZERO, Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1)]:
		var point: Vector2i = anchor + offset
		var index := point.x * map_edge + point.y

		if HighwayGeometry._land_altitude(altitude, index) < target:
			terrain[index] = 0x0d


static func _prepare_shaped_terrain(
	terrain: PackedByteArray, altitude: PackedByteArray, anchor: Vector2i,
	map_edge: int = 128,
) -> void:
	var target := HighwayGeometry._section_altitude(terrain, altitude, anchor, map_edge)

	for offset in [Vector2i.ZERO, Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1)]:
		var point: Vector2i = anchor + offset
		var index := point.x * map_edge + point.y

		if terrain[index] != 0 or HighwayGeometry._land_altitude(altitude, index) < target:
			terrain[index] = 0x0d


static func _write_section_kind(
	buildings: PackedByteArray,
	terrain: PackedByteArray,
	zones: PackedByteArray,
	altitude: PackedByteArray,
	misc: PackedByteArray,
	anchor: Vector2i,
	kind: int,
	rotation: int,
	map_edge: int = 128,
) -> void:
	if kind < 4:
		_prepare_flat_terrain(terrain, altitude, anchor, map_edge)
		var orientation := kind & 1

		for offset in [Vector2i.ZERO, Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1)]:
			var point: Vector2i = anchor + offset
			var old_tile := int(buildings[point.x * map_edge + point.y])

			if old_tile == 0x0e or old_tile == 0x1d or old_tile == 0x2c:
				orientation = 1
			elif old_tile == 0x0f or old_tile == 0x1e or old_tile == 0x2d:
				orientation = 0

		_place_straight_section(buildings, zones, misc, anchor, orientation, map_edge)

		return

	if kind >= 4 and kind <= 7:
		_place_graded_section(
			altitude, buildings, terrain, zones, misc, anchor, kind, rotation, map_edge
		)

		return

	if kind >= 8 and kind <= 12:
		_prepare_shaped_terrain(terrain, altitude, anchor, map_edge)
		_write_shape(buildings, zones, misc, anchor, kind, rotation, map_edge)


static func _place_graded_section(
	altitude: PackedByteArray,
	buildings: PackedByteArray,
	terrain: PackedByteArray,
	zones: PackedByteArray,
	misc: PackedByteArray,
	anchor: Vector2i,
	kind: int,
	rotation: int,
	map_edge: int = 128,
) -> void:
	var target := HighwayGeometry._section_altitude(terrain, altitude, anchor, map_edge)
	var offsets := [
		Vector2i.ZERO,
		Vector2i(1, 0),
		Vector2i(1, 1),
		Vector2i(0, 1),
	]
	var all_at_target := true

	for offset in offsets:
		var point: Vector2i = anchor + offset
		var index := point.x * map_edge + point.y

		if HighwayGeometry._land_altitude(altitude, index) != target:
			all_at_target = false
			break

	if not all_at_target:
		for offset in offsets:
			var point: Vector2i = anchor + offset
			_set_land_altitude(
				altitude, point.x * map_edge + point.y, target - 1
			)

	var terrain_pattern: Array[int]

	match kind:
		4:
			terrain_pattern = [0x0d, 0x01, 0x01, 0x0d]
		5:
			terrain_pattern = [0x0d, 0x0d, 0x02, 0x02]
		6:
			terrain_pattern = [0x03, 0x0d, 0x0d, 0x03]
		7:
			terrain_pattern = [0x04, 0x04, 0x0d, 0x0d]
		_:
			return

	var tile_id := 0x5d + kind

	for offset_index in offsets.size():
		var point: Vector2i = anchor + offsets[offset_index]
		var index := point.x * map_edge + point.y
		terrain[index] = terrain_pattern[offset_index]
		zones[index] &= 0xf0
		NetworkState.replace_building(buildings, zones, misc, index, tile_id)

	BuildingSites.set_corners(zones, Rect2i(anchor, Vector2i(2, 2)), 2, rotation, map_edge)


static func _set_land_altitude(
	altitude: PackedByteArray, index: int, value: int
) -> void:
	var offset := index * 2
	var word := (altitude[offset] << 8) | altitude[offset + 1]
	word = (word & ~0x1f) | (value & 0x1f)
	altitude[offset] = (word >> 8) & 0xff
	altitude[offset + 1] = word & 0xff


static func _write_shape(
	buildings: PackedByteArray,
	zones: PackedByteArray,
	misc: PackedByteArray,
	anchor: Vector2i,
	kind: int,
	rotation: int,
	map_edge: int = 128,
) -> void:
	if kind == 2 or kind == 3:
		_place_straight_section(buildings, zones, misc, anchor, kind - 2, map_edge)

		return

	var tile_id := 0x5d + kind

	for offset in [Vector2i.ZERO, Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1)]:
		var point: Vector2i = anchor + offset
		var index := point.x * map_edge + point.y
		zones[index] = 0
		NetworkState.replace_building(buildings, zones, misc, index, tile_id)

	BuildingSites.set_corners(zones, Rect2i(anchor, Vector2i(2, 2)), 2, rotation, map_edge)
