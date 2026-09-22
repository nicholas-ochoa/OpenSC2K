class_name CityRotationCommand
extends RefCounted

const UnderTiles = preload("res://src/tools/shared/underground_tile_ids.gd")

const Tiles = preload("res://src/tools/shared/building_tile_ids.gd")

const MAP_SIZE := CityState.MAP_SIZE
const COMPASS_OFFSET := 0x0008
const TILE_COUNT_OFFSET := 0x01f0
const MILITARY_ZONE := 7
const FLIP_FLAG := 0x02

const REQUIRED_CHUNKS := [
	["MISC", 4800],
	["ALTM", 32768],
	["XTER", 16384],
	["XBLD", 16384],
	["XZON", 16384],
	["XUND", 16384],
	["XTXT", 16384],
	["XTHG", 480],
	["XBIT", 16384],
	["XTRF", 4096],
	["XPLT", 4096],
	["XVAL", 4096],
	["XCRM", 4096],
	["XPLC", 1024],
	["XFIR", 1024],
	["XPOP", 1024],
	["XROG", 1024],
]


# View rotation rewrites the saved city coordinates.
static func apply(city: CityState, counter_clockwise: bool) -> RotationEditResult:
	var map_edge: int = city.map_size if city != null else 128

	if city == null or not city.is_valid():
		return RotationEditResult.rejected("city is invalid")

	var old_payloads := _payloads(city)

	if old_payloads.is_empty():
		return RotationEditResult.rejected("rotation data is missing or invalid")

	var changed := _duplicate_payloads(old_payloads)
	var surface_table := _surface_table(counter_clockwise)
	changed.ALTM = _rotate_grid(changed.ALTM, map_edge, 2, counter_clockwise)
	changed.XTER = _rotate_byte_grid(
		changed.XTER, map_edge, counter_clockwise, _terrain_table(counter_clockwise)
	)
	changed.XBLD = _rotate_byte_grid(
		changed.XBLD, map_edge, counter_clockwise, surface_table
	)
	changed.XZON = _rotate_grid(changed.XZON, map_edge, 1, counter_clockwise)
	changed.XUND = _rotate_byte_grid(
		changed.XUND, map_edge, counter_clockwise, _underground_table(counter_clockwise)
	)
	var overlay_cells := map_edge * map_edge
	var rotated_text := _rotate_grid(changed.XTXT.slice(0, overlay_cells), map_edge, 1, counter_clockwise)

	if changed.XTXT.size() > overlay_cells:
		rotated_text.append_array(_rotate_grid(changed.XTXT.slice(overlay_cells), map_edge, 1, counter_clockwise))

	changed.XTXT = rotated_text
	changed.XBIT = _rotate_grid(changed.XBIT, map_edge, 1, counter_clockwise)
	_rotate_surface_tile_counts(changed.MISC, surface_table)
	_rotate_special_surface(
		changed.XBLD,
		changed.XZON,
		changed.XBIT,
		changed.MISC,
		surface_table,
		counter_clockwise,
	)

	for chunk_id in ["XTRF", "XPLT", "XVAL", "XCRM"]:
		changed[chunk_id] = _rotate_grid(changed[chunk_id], CityDataGrid.edge(changed[chunk_id], map_edge), 1, counter_clockwise)

	for chunk_id in ["XPLC", "XFIR", "XPOP", "XROG"]:
		changed[chunk_id] = _rotate_grid(changed[chunk_id], CityDataGrid.edge(changed[chunk_id], map_edge), 1, counter_clockwise)

	_rotate_things(changed.XTHG, counter_clockwise, map_edge)
	var old_compass := BinaryData.read_u32_be(changed.MISC, COMPASS_OFFSET) & 3
	var new_compass := (old_compass + (1 if counter_clockwise else 3)) & 3
	BinaryData.write_u32_be(changed.MISC, COMPASS_OFFSET, new_compass)

	var changed_ids := PackedStringArray()

	for specification in REQUIRED_CHUNKS:
		var chunk_id: String = specification[0]

		if changed[chunk_id] != old_payloads[chunk_id]:
			changed_ids.append(chunk_id)

	if not _apply_payloads(city, changed_ids, changed, old_payloads):
		return RotationEditResult.rejected("cannot store rotated city data")

	var result := RotationEditResult.new()
	result.ok = true
	result.counter_clockwise = counter_clockwise
	result.old_compass = old_compass
	result.new_compass = new_compass
	result.changed_ids = changed_ids
	result.error = ""

	return result


static func rotate_point(point: Vector2i, size: int, counter_clockwise: bool) -> Vector2i:
	if size < 1 or point.x < 0 or point.x >= size or point.y < 0 or point.y >= size:
		return Vector2i(-1, -1)

	if counter_clockwise:
		return Vector2i(point.y, size - 1 - point.x)

	return Vector2i(size - 1 - point.y, point.x)


static func surface_tile_after_rotation(tile: int, counter_clockwise: bool) -> int:
	if tile < 0 or tile > Tiles.MAX_ID:
		return tile

	return _surface_table(counter_clockwise)[tile]


static func terrain_tile_after_rotation(tile: int, counter_clockwise: bool) -> int:
	var table := _terrain_table(counter_clockwise)

	return table[tile] if tile >= 0 and tile < table.size() else tile


static func underground_tile_after_rotation(tile: int, counter_clockwise: bool) -> int:
	var table := _underground_table(counter_clockwise)

	return table[tile] if tile >= 0 and tile < table.size() else tile


static func _payloads(city: CityState) -> Dictionary[String, PackedByteArray]:
	var result: Dictionary[String, PackedByteArray] = {}

	for specification in REQUIRED_CHUNKS:
		var chunk_id: String = specification[0]
		var expected_size: int = city.document.decoded_size(chunk_id)
		var chunk := city.document.find_chunk(chunk_id)

		if chunk == null or chunk.decoded_payload.size() != expected_size:
			return {}

		result[chunk_id] = chunk.decoded_payload.duplicate()

	return result


static func _duplicate_payloads(payloads: Dictionary[String, PackedByteArray]) -> Dictionary[String, PackedByteArray]:
	var result: Dictionary[String, PackedByteArray] = {}

	for chunk_id in payloads:
		result[chunk_id] = payloads[chunk_id].duplicate()

	return result


static func _apply_payloads(
	city: CityState, chunk_ids: PackedStringArray, payloads: Dictionary[String, PackedByteArray], rollback: Dictionary[String, PackedByteArray]
) -> bool:
	var applied := PackedStringArray()

	for chunk_id in chunk_ids:
		var chunk := city.document.find_chunk(chunk_id)

		if chunk == null or not chunk.set_decoded_payload(payloads[chunk_id]):
			for rollback_id in applied:
				city.document.find_chunk(rollback_id).set_decoded_payload(rollback[rollback_id])

			city.resync_mirrors(CityState.MIRRORED_CHUNKS)

			return false

		applied.append(chunk_id)

	city.resync_mirrors(CityState.MIRRORED_CHUNKS)

	return true


# Scan x first to match the original rotation order.
static func _rotate_grid(
	input: PackedByteArray, size: int, record_size: int, counter_clockwise: bool
) -> PackedByteArray:
	var output := PackedByteArray()
	output.resize(input.size())

	for old_x in size:
		for old_y in size:
			var destination := rotate_point(
				Vector2i(old_x, old_y), size, counter_clockwise
			)
			var source_offset := (old_x * size + old_y) * record_size
			var destination_offset := (destination.x * size + destination.y) * record_size

			for byte_index in record_size:
				output[destination_offset + byte_index] = input[source_offset + byte_index]

	return output


static func _rotate_byte_grid(
	input: PackedByteArray,
	size: int,
	counter_clockwise: bool,
	mapping: PackedByteArray
) -> PackedByteArray:
	var output := _rotate_grid(input, size, 1, counter_clockwise)

	for index in output.size():
		var value := int(output[index])

		if value < mapping.size():
			output[index] = mapping[value]

	return output


static func _identity_table(size: int) -> PackedByteArray:
	var table := PackedByteArray()
	table.resize(size)

	for index in size:
		table[index] = index

	return table


# the tile number has a direction baked into it too
static func _surface_table(counter_clockwise: bool) -> PackedByteArray:
	var table := _identity_table(Tiles.COUNT)

	for pair in [
		[Tiles.POWER_LINE_STRAIGHT_1, Tiles.POWER_LINE_STRAIGHT_2],
		[Tiles.ROAD_STRAIGHT_1, Tiles.ROAD_STRAIGHT_2],
		[Tiles.RAIL_STRAIGHT_1, Tiles.RAIL_STRAIGHT_2],
		[Tiles.ROAD_POWER_CROSSING_1, Tiles.ROAD_POWER_CROSSING_2],
		[Tiles.ROAD_RAIL_CROSSING_1, Tiles.ROAD_RAIL_CROSSING_2],
		[Tiles.RAIL_POWER_CROSSING_1, Tiles.RAIL_POWER_CROSSING_2],
		[Tiles.HIGHWAY_STRAIGHT_1, Tiles.HIGHWAY_STRAIGHT_2],
		[Tiles.HIGHWAY_ROAD_CROSSING_1, Tiles.HIGHWAY_ROAD_CROSSING_2],
		[Tiles.HIGHWAY_RAIL_CROSSING_1, Tiles.HIGHWAY_RAIL_CROSSING_2],
		[Tiles.HIGHWAY_POWER_CROSSING_1, Tiles.HIGHWAY_POWER_CROSSING_2],
		[Tiles.SUSPENSION_BRIDGE_1, Tiles.SUSPENSION_BRIDGE_5],
		[Tiles.SUSPENSION_BRIDGE_2, Tiles.SUSPENSION_BRIDGE_4],
	]:
		_swap(table, pair[0], pair[1])

	for cycle in [
		[Tiles.POWER_LINE_SLOPE_1, Tiles.POWER_LINE_SLOPE_2, Tiles.POWER_LINE_SLOPE_3, Tiles.POWER_LINE_SLOPE_4],
		[Tiles.POWER_LINE_CURVE_1, Tiles.POWER_LINE_CURVE_2, Tiles.POWER_LINE_CURVE_3, Tiles.POWER_LINE_CURVE_4],
		[Tiles.POWER_LINE_JUNCTION_1, Tiles.POWER_LINE_JUNCTION_2, Tiles.POWER_LINE_JUNCTION_3, Tiles.POWER_LINE_JUNCTION_4],
		[Tiles.ROAD_SLOPE_1, Tiles.ROAD_SLOPE_2, Tiles.ROAD_SLOPE_3, Tiles.ROAD_SLOPE_4],
		[Tiles.ROAD_CURVE_1, Tiles.ROAD_CURVE_2, Tiles.ROAD_CURVE_3, Tiles.ROAD_CURVE_4], [Tiles.ROAD_JUNCTION_1, Tiles.ROAD_JUNCTION_2, Tiles.ROAD_JUNCTION_3, Tiles.ROAD_JUNCTION_4],
		[Tiles.RAIL_SLOPE_1, Tiles.RAIL_SLOPE_2, Tiles.RAIL_SLOPE_3, Tiles.RAIL_SLOPE_4], [Tiles.RAIL_CURVE_1, Tiles.RAIL_CURVE_2, Tiles.RAIL_CURVE_3, Tiles.RAIL_CURVE_4],
		[Tiles.RAIL_JUNCTION_1, Tiles.RAIL_JUNCTION_2, Tiles.RAIL_JUNCTION_3, Tiles.RAIL_JUNCTION_4], [Tiles.RAIL_SLOPE_5, Tiles.RAIL_SLOPE_6, Tiles.RAIL_SLOPE_7, Tiles.RAIL_SLOPE_8],
		[Tiles.TUNNEL_ENTRANCE_1, Tiles.TUNNEL_ENTRANCE_2, Tiles.TUNNEL_ENTRANCE_3, Tiles.TUNNEL_ENTRANCE_4],
		[Tiles.HIGHWAY_SLOPE_1, Tiles.HIGHWAY_SLOPE_2, Tiles.HIGHWAY_SLOPE_3, Tiles.HIGHWAY_SLOPE_4],
		[Tiles.HIGHWAY_CURVE_1, Tiles.HIGHWAY_CURVE_2, Tiles.HIGHWAY_CURVE_3, Tiles.HIGHWAY_CURVE_4],
		[Tiles.RAIL_SUBWAY_ENTRANCE_1, Tiles.RAIL_SUBWAY_ENTRANCE_2, Tiles.RAIL_SUBWAY_ENTRANCE_3, Tiles.RAIL_SUBWAY_ENTRANCE_4],
	]:
		_set_cycle(table, cycle, counter_clockwise)

	return table


# four turns won't recover garbage tile ids
static func _terrain_table(counter_clockwise: bool) -> PackedByteArray:
	var table := _identity_table(TerrainTileIds.ROTATION_TABLE_SIZE)

	for invalid in [TerrainTileIds.UNUSED_0E, TerrainTileIds.UNUSED_0F, TerrainTileIds.UNUSED_1E, TerrainTileIds.UNUSED_1F, TerrainTileIds.UNUSED_2F, TerrainTileIds.UNUSED_3F, TerrainTileIds.UNUSED_46, TerrainTileIds.UNUSED_47]:
		table[invalid] = TerrainTileIds.FLAT

	_swap(table, TerrainTileIds.CHANNEL_NS, TerrainTileIds.CHANNEL_EW)

	for cycle in [
		[TerrainTileIds.SLOPE_TOP_LEFT, TerrainTileIds.SLOPE_TOP_RIGHT, TerrainTileIds.SLOPE_BOTTOM_RIGHT, TerrainTileIds.SLOPE_BOTTOM_LEFT], [TerrainTileIds.RAISED_EXCEPT_BOTTOM, TerrainTileIds.RAISED_EXCEPT_LEFT, TerrainTileIds.RAISED_EXCEPT_TOP, TerrainTileIds.RAISED_EXCEPT_RIGHT],
		[TerrainTileIds.CORNER_TOP, TerrainTileIds.CORNER_RIGHT, TerrainTileIds.CORNER_BOTTOM, TerrainTileIds.CORNER_LEFT], [TerrainTileIds.DEEP_WATER_SLOPE_TOP_LEFT, TerrainTileIds.DEEP_WATER_SLOPE_TOP_RIGHT, TerrainTileIds.DEEP_WATER_SLOPE_BOTTOM_RIGHT, TerrainTileIds.DEEP_WATER_SLOPE_BOTTOM_LEFT],
		[TerrainTileIds.DEEP_WATER_RAISED_EXCEPT_BOTTOM, TerrainTileIds.DEEP_WATER_RAISED_EXCEPT_LEFT, TerrainTileIds.DEEP_WATER_RAISED_EXCEPT_TOP, TerrainTileIds.DEEP_WATER_RAISED_EXCEPT_RIGHT], [TerrainTileIds.DEEP_WATER_CORNER_TOP, TerrainTileIds.DEEP_WATER_CORNER_RIGHT, TerrainTileIds.DEEP_WATER_CORNER_BOTTOM, TerrainTileIds.DEEP_WATER_CORNER_LEFT],
		[TerrainTileIds.SHORE_SLOPE_TOP_LEFT, TerrainTileIds.SHORE_SLOPE_TOP_RIGHT, TerrainTileIds.SHORE_SLOPE_BOTTOM_RIGHT, TerrainTileIds.SHORE_SLOPE_BOTTOM_LEFT], [TerrainTileIds.SHORE_RAISED_EXCEPT_BOTTOM, TerrainTileIds.SHORE_RAISED_EXCEPT_LEFT, TerrainTileIds.SHORE_RAISED_EXCEPT_TOP, TerrainTileIds.SHORE_RAISED_EXCEPT_RIGHT],
		[TerrainTileIds.SHORE_CORNER_TOP, TerrainTileIds.SHORE_CORNER_RIGHT, TerrainTileIds.SHORE_CORNER_BOTTOM, TerrainTileIds.SHORE_CORNER_LEFT], [TerrainTileIds.SURFACE_WATER_NES, TerrainTileIds.SURFACE_WATER_ESW, TerrainTileIds.SURFACE_WATER_NSW, TerrainTileIds.SURFACE_WATER_NEW],
		[TerrainTileIds.SURFACE_WATER_ES, TerrainTileIds.SURFACE_WATER_SW, TerrainTileIds.SURFACE_WATER_NW, TerrainTileIds.SURFACE_WATER_NE], [TerrainTileIds.SURFACE_WATER_BANK_NW, TerrainTileIds.SURFACE_WATER_BANK_NE, TerrainTileIds.SURFACE_WATER_BANK_SE, TerrainTileIds.SURFACE_WATER_BANK_SW],
		[TerrainTileIds.CHANNEL_E, TerrainTileIds.CHANNEL_S, TerrainTileIds.CHANNEL_W, TerrainTileIds.CHANNEL_N],
	]:
		_set_cycle(table, cycle, counter_clockwise)

	return table


static func _underground_table(counter_clockwise: bool) -> PackedByteArray:
	var table := _identity_table(UnderTiles.ROTATION_TABLE_SIZE)

	for invalid in [UnderTiles.UNUSED_24, UnderTiles.UNUSED_25, UnderTiles.UNUSED_26, UnderTiles.UNUSED_27]:
		table[invalid] = UnderTiles.EMPTY

	for pair in [[UnderTiles.SUBWAY_LR, UnderTiles.SUBWAY_TB], [UnderTiles.PIPE_LR, UnderTiles.PIPE_TB], [UnderTiles.PIPE_TB_SUBWAY_LR, UnderTiles.PIPE_LR_SUBWAY_TB]]:
		_swap(table, pair[0], pair[1])

	for cycle in [
		[UnderTiles.SUBWAY_HTB, UnderTiles.SUBWAY_LHR, UnderTiles.SUBWAY_THB, UnderTiles.SUBWAY_HLR],
		[UnderTiles.SUBWAY_BR, UnderTiles.SUBWAY_BL, UnderTiles.SUBWAY_TL, UnderTiles.SUBWAY_TR],
		[UnderTiles.SUBWAY_RTB, UnderTiles.SUBWAY_LBR, UnderTiles.SUBWAY_TLB, UnderTiles.SUBWAY_LTR],
		[UnderTiles.PIPE_HTB, UnderTiles.PIPE_LHR, UnderTiles.PIPE_THB, UnderTiles.PIPE_HLR],
		[UnderTiles.PIPE_BR, UnderTiles.PIPE_BL, UnderTiles.PIPE_TL, UnderTiles.PIPE_TR], [UnderTiles.PIPE_RTB, UnderTiles.PIPE_LBR, UnderTiles.PIPE_TLB, UnderTiles.PIPE_LTR],
	]:
		_set_cycle(table, cycle, counter_clockwise)

	return table


static func _swap(table: PackedByteArray, first: int, second: int) -> void:
	table[first] = second
	table[second] = first


static func _set_cycle(
	table: PackedByteArray, cycle: Array, counter_clockwise: bool
) -> void:
	for index in cycle.size():
		var target := index - 1 if counter_clockwise else index + 1
		table[cycle[index]] = cycle[posmod(target, cycle.size())]


# Orientation uses both the tile ID and the flip bit.
static func _rotate_special_surface(
	buildings: PackedByteArray,
	zones: PackedByteArray,
	flags: PackedByteArray,
	misc: PackedByteArray,
	surface_table: PackedByteArray,
	counter_clockwise: bool
) -> void:
	var ramp_tiles := (
		[Tiles.HIGHWAY_ONRAMP_2, Tiles.HIGHWAY_ONRAMP_1, Tiles.HIGHWAY_ONRAMP_4, Tiles.HIGHWAY_ONRAMP_3, Tiles.HIGHWAY_ONRAMP_4, Tiles.HIGHWAY_ONRAMP_3, Tiles.HIGHWAY_ONRAMP_2, Tiles.HIGHWAY_ONRAMP_1]
		if counter_clockwise
		else [Tiles.HIGHWAY_ONRAMP_4, Tiles.HIGHWAY_ONRAMP_3, Tiles.HIGHWAY_ONRAMP_2, Tiles.HIGHWAY_ONRAMP_1, Tiles.HIGHWAY_ONRAMP_2, Tiles.HIGHWAY_ONRAMP_1, Tiles.HIGHWAY_ONRAMP_4, Tiles.HIGHWAY_ONRAMP_3]
	)

	for index in buildings.size():
		var tile := int(buildings[index])
		var flipped := (flags[index] & FLIP_FLAG) != 0

		if tile >= Tiles.HIGHWAY_ONRAMP_1 and tile <= Tiles.HIGHWAY_ONRAMP_4:
			var ramp_index := tile - Tiles.HIGHWAY_ONRAMP_1 + (4 if flipped else 0)
			_replace_building(buildings, zones, misc, index, ramp_tiles[ramp_index])
			flags[index] = (flags[index] & 0xfd) | (FLIP_FLAG if ramp_index < 4 else 0)
			continue

		if not ((tile >= Tiles.SUSPENSION_BRIDGE_1 and tile <= Tiles.POWER_BRIDGE) or tile == Tiles.HIGHWAY_BRIDGE or tile == Tiles.REINFORCED_HIGHWAY_BRIDGE):
			continue

		if counter_clockwise:
			if flipped:
				flags[index] &= 0xfd
			else:
				flags[index] |= FLIP_FLAG
				_replace_building(buildings, zones, misc, index, surface_table[tile])
		else:
			if flipped:
				flags[index] &= 0xfd
				_replace_building(buildings, zones, misc, index, surface_table[tile])
			else:
				flags[index] |= FLIP_FLAG


# rotate the road counts too or misc disagrees with xbld
static func _rotate_surface_tile_counts(
	misc: PackedByteArray, surface_table: PackedByteArray
) -> void:
	var old_counts := PackedInt64Array()
	old_counts.resize(Tiles.DEVELOPED_FIRST)

	for tile in Tiles.DEVELOPED_FIRST:
		old_counts[tile] = BinaryData.read_u32_be(misc, TILE_COUNT_OFFSET + tile * 4)

	for tile in Tiles.DEVELOPED_FIRST:
		BinaryData.write_u32_be(
			misc, TILE_COUNT_OFFSET + int(surface_table[tile]) * 4, old_counts[tile]
		)


# word-sized count wrapping on the 128 map; military tiles don't count
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

	if (zones[index] & 0x0f) != MILITARY_ZONE:
		var old_offset := TILE_COUNT_OFFSET + old_tile * 4
		var new_offset := TILE_COUNT_OFFSET + new_tile * 4
		BinaryData.write_u32_be(misc, old_offset, (BinaryData.read_u32_be(misc, old_offset) - 1) & (0xffff if buildings.size() == 16384 else 0xffffffff))
		BinaryData.write_u32_be(misc, new_offset, (BinaryData.read_u32_be(misc, new_offset) + 1) & (0xffff if buildings.size() == 16384 else 0xffffffff))

	buildings[index] = new_tile


# these bytes are coordinates until the object decides they aren't
static func _rotate_things(things: PackedByteArray, counter_clockwise: bool, map_edge: int = 128) -> void:
	for record in range(1, ThingData.count(things)):
		var offset := record * CityState.THING_RECORD_SIZE
		var type := int(ThingData.read(things, offset))

		if type == 0:
			continue

		if type == 3 and map_edge > 128:
			var home := ThingData.ship_home(things, record, Vector2i(-1, -1))
			ThingData.set_ship_home(things, record, Vector2i(home.y, map_edge - 1 - home.x) if counter_clockwise else Vector2i(map_edge - 1 - home.y, home.x))

		var old_x := int(ThingData.read(things, offset + 3))
		var old_y := int(ThingData.read(things, offset + 4))

		if counter_clockwise:
			ThingData.write(things, offset + 3, old_y)
			ThingData.write(things, offset + 4, (map_edge - 1 - old_x))
		else:
			ThingData.write(things, offset + 3, (map_edge - 1 - old_y))
			ThingData.write(things, offset + 4, old_x)

		if type >= 10 and type <= 13:
			_rotate_train_thing(things, offset, counter_clockwise, map_edge)
		else:
			ThingData.write(things, offset + 1, (
				ThingData.read(things, offset + 1) + (-2 if counter_clockwise else 2)
			) & 7)
			var old_dx := int(ThingData.read(things, offset + 8))
			var old_dy := int(ThingData.read(things, offset + 9))

			if counter_clockwise:
				ThingData.write(things, offset + 8, old_dy)
				ThingData.write(things, offset + 9, (map_edge - 1 - old_dx))
			else:
				ThingData.write(things, offset + 8, (map_edge - 1 - old_dy))
				ThingData.write(things, offset + 9, old_dx)

			if type == 1:
				var turn := -0x20 if counter_clockwise else 0x20
				ThingData.write(things, offset + 2, (
					((ThingData.read(things, offset + 2) + turn) & 0x70) | (ThingData.read(things, offset + 2) & 0x0f)
				))


static func _rotate_train_thing(
	things: PackedByteArray, offset: int, counter_clockwise: bool, map_edge: int = 128
) -> void:
	ThingData.write(things, offset + 1, (
		ThingData.read(things, offset + 1) + (-1 if counter_clockwise else 1)
	) & 3)
	ThingData.write(things, offset + 8, (
		ThingData.read(things, offset + 8) + (-2 if counter_clockwise else 2)
	) & 7)
	var old_px := int(ThingData.read(things, offset + 6))
	var old_py := int(ThingData.read(things, offset + 7))

	if counter_clockwise:
		ThingData.write(things, offset + 6, old_py)
		ThingData.write(things, offset + 7, map_edge - 1 - old_px)
	else:
		ThingData.write(things, offset + 6, map_edge - 1 - old_py)
		ThingData.write(things, offset + 7, old_px)
