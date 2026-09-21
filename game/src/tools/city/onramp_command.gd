class_name OnrampCommand
extends RefCounted

const Tiles = preload("res://src/tools/shared/building_tile_ids.gd")

const GROUP_ROADS := 6
const SUBTOOL_ONRAMP := 3
const MAX_CLEAR_BUILDING := Tiles.SMALL_PARK
const RADIOACTIVITY := Tiles.RADIOACTIVE_WASTE
const HIGHWAY_FIRST := Tiles.HIGHWAY_STRAIGHT_1
const HIGHWAY_LAST := Tiles.HIGHWAY_POWER_CROSSING_2
const ROAD_FIRST := Tiles.FIRST_ROAD
const ROAD_LAST := Tiles.ROAD_CROSSROADS
const ROAD_INTERSECTION := Tiles.ROAD_CROSSROADS
const RAMP_FIRST := Tiles.HIGHWAY_ONRAMP_1
const FLAG_FLIPPED := 0x02

# neighbor masks use north, east, south, and west bits. each value selects
# the road directions that can connect to the adjacent highway arrangement
const ROAD_MASK_BY_HIGHWAY_MASK := [0, 10, 5, 12, 10, 0, 9, 0, 5, 6, 0, 0, 3, 0, 0, 0]
const DIRECTIONS := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]


static func supports_tool(group_index: int, subtool_index: int) -> bool:
	return group_index == GROUP_ROADS and subtool_index == SUBTOOL_ONRAMP


static func apply(
	city: CityState,
	group_index: int,
	subtool_index: int,
	point: Vector2i,
	free_mode := false,
	preview_only := false
) -> OnrampEditResult:
	if city == null or not city.is_valid():
		return OnrampEditResult.rejected("city is invalid")

	if not supports_tool(group_index, subtool_index):
		return OnrampEditResult.rejected("tool is not an on-ramp")

	var index := city.index_of(point.x, point.y)

	if index < 0:
		return OnrampEditResult.rejected("on-ramp is outside the city")

	if city.buildings[index] > MAX_CLEAR_BUILDING or city.buildings[index] == RADIOACTIVITY:
		return OnrampEditResult.rejected("on-ramp site contains a protected building")

	if city.terrain[index] != TerrainTileIds.FLAT:
		return OnrampEditResult.rejected("on-ramp site is not clear terrain")

	var highway_mask := 0
	var road_mask := 0

	for direction in 4:
		var neighbor: Vector2i = point + DIRECTIONS[direction]
		var neighbor_index := city.index_of(neighbor.x, neighbor.y)

		if neighbor_index < 0:
			continue

		var tile_id := int(city.buildings[neighbor_index])

		if tile_id >= HIGHWAY_FIRST and tile_id <= HIGHWAY_LAST:
			highway_mask |= 1 << direction

		if tile_id >= ROAD_FIRST and tile_id <= ROAD_LAST:
			road_mask |= 1 << direction

	road_mask &= ROAD_MASK_BY_HIGHWAY_MASK[highway_mask]

	if road_mask == 0:
		return OnrampEditResult.rejected("on-ramp requires perpendicular highway and road neighbors")

	var listed_cost := int(ToolCatalog.tool(group_index, subtool_index).cost)
	var cost := 0 if free_mode else listed_cost

	if city.funds() < cost:
		return OnrampEditResult.rejected("insufficient funds", cost)

	var road_direction := 0

	while road_direction < 4 and (road_mask & (1 << road_direction)) == 0:
		road_direction += 1

	var ramp_tile := _ramp_tile(highway_mask, road_direction)
	var road_point: Vector2i = point + DIRECTIONS[road_direction]
	var road_index := city.index_of(road_point.x, road_point.y)

	if preview_only:
		var preview := OnrampEditResult.new()
		preview.ok = true

		return preview

	var old_payloads := BuildingState._city_payloads(city)

	if old_payloads.is_empty():
		return OnrampEditResult.rejected("required city data is missing or invalid")

	var changed_payloads := BuildingState._duplicate_payloads(old_payloads)
	var buildings: PackedByteArray = changed_payloads.XBLD
	var zones: PackedByteArray = changed_payloads.XZON
	var flags: PackedByteArray = changed_payloads.XBIT
	var misc: PackedByteArray = changed_payloads.MISC

	NetworkState.replace_building(buildings, zones, misc, road_index, ROAD_INTERSECTION)
	NetworkState.replace_building(buildings, zones, misc, index, ramp_tile)

	if road_direction == 0 or road_direction == 2:
		flags[index] |= FLAG_FLIPPED

	BuildingState._write_u32_be(misc, BuildingCommand.MISC_FUNDS, city.funds() - cost)

	var changed_ids := PackedStringArray()

	for chunk_id in ["XBLD", "XBIT", "MISC"]:
		if changed_payloads[chunk_id] != old_payloads[chunk_id]:
			changed_ids.append(chunk_id)

	if not BuildingState._apply_payloads(city, changed_ids, changed_payloads, old_payloads):
		return OnrampEditResult.rejected("cannot store on-ramp changes")

	var result := OnrampEditResult.new()
	result.ok = true
	result.command_type = "onramp"
	result.group_index = group_index
	result.subtool_index = subtool_index
	result.tile_id = ramp_tile
	result.road_direction = road_direction
	result.road_point = road_point
	result.cost = cost
	result.listed_cost = listed_cost
	result.free_mode = free_mode
	result.changed_ids = changed_ids
	result.old_payloads = old_payloads
	result.new_payloads = changed_payloads

	return result


static func undo(city: CityState, command: OnrampEditResult) -> EditCommandResult:
	if city == null or not city.is_valid():
		return EditCommandResult.failure("city is invalid")

	if command == null or not command.ok or command.command_type != "onramp":
		return EditCommandResult.failure("on-ramp command is invalid")

	var changed_ids := command.changed_ids
	var old_payloads := command.old_payloads
	var new_payloads := command.new_payloads

	for chunk_id in changed_ids:
		var chunk := city.document.find_chunk(chunk_id)

		if chunk == null or not new_payloads.has(chunk_id) or chunk.decoded_payload != new_payloads[chunk_id]:
			return EditCommandResult.failure("city changed after this on-ramp command")

	if not BuildingState._apply_payloads(city, changed_ids, old_payloads, new_payloads):
		return EditCommandResult.failure("cannot restore on-ramp changes")

	return EditCommandResult.undone(2)


static func _ramp_tile(highway_mask: int, road_direction: int) -> int:
	match road_direction:
		0:
			return Tiles.HIGHWAY_ONRAMP_3 if (highway_mask & 2) else Tiles.HIGHWAY_ONRAMP_2
		1:
			return RAMP_FIRST if (highway_mask & 1) else Tiles.HIGHWAY_ONRAMP_4
		2:
			return Tiles.HIGHWAY_ONRAMP_4 if (highway_mask & 2) else RAMP_FIRST
		_:
			return Tiles.HIGHWAY_ONRAMP_2 if (highway_mask & 1) else Tiles.HIGHWAY_ONRAMP_3
