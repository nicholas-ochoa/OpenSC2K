class_name TunnelCommand
extends RefCounted

const UnderTiles = preload("res://src/tools/shared/underground_tile_ids.gd")

const Tiles = preload("res://src/tools/shared/building_tile_ids.gd")

const GROUP_ROADS := 6
const SUBTOOL_TUNNEL := 2
const MAX_CLEAR_BUILDING := Tiles.SMALL_PARK
const RADIOACTIVITY := Tiles.RADIOACTIVE_WASTE
const FIRST_ENTRANCE := Tiles.TUNNEL_FIRST
const TUNNEL_MASK := Sc2AltitudeLayout.TUNNEL_MASK
const ALTITUDE_DATA_MASK := Sc2AltitudeLayout.LAND_MASK | Sc2AltitudeLayout.WATER_MASK
const ONE_TUNNEL_LEVEL := 1 << Sc2AltitudeLayout.TUNNEL_SHIFT
const CONFIRMATION_UNSELECTED := -1
const CONFIRMATION_CANCELLED := 0
const CONFIRMATION_CONFIRMED := 1
const DIRECTIONS := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]


static func supports_tool(group_index: int, subtool_index: int) -> bool:
	return group_index == GROUP_ROADS and subtool_index == SUBTOOL_TUNNEL


static func apply(
	city: CityState,
	group_index: int,
	subtool_index: int,
	start: Vector2i,
	confirmation_choice := CONFIRMATION_UNSELECTED,
	free_mode := false
) -> TunnelEditResult:
	var map_edge: int = city.map_size if city != null else 128

	if city == null or not city.is_valid():
		return TunnelEditResult.rejected("city is invalid")

	if not supports_tool(group_index, subtool_index):
		return TunnelEditResult.rejected("tool is not a tunnel")

	var start_index := city.index_of(start.x, start.y)

	if start_index < 0:
		return TunnelEditResult.rejected("tunnel entrance is outside the city")

	if city.buildings[start_index] > MAX_CLEAR_BUILDING or city.buildings[start_index] == RADIOACTIVITY:
		return TunnelEditResult.rejected("tunnel entrance contains a protected building")

	if city.underground[start_index] != UnderTiles.EMPTY:
		return TunnelEditResult.rejected("tunnel entrance conflicts with an underground network")

	var start_terrain := int(city.terrain[start_index])

	if start_terrain < TerrainTileIds.SLOPE_TOP_LEFT or start_terrain > TerrainTileIds.SLOPE_BOTTOM_LEFT:
		return TunnelEditResult.rejected("tunnel entrance requires a cardinal slope")

	var direction_index := (start_terrain + 2) & 3
	var direction: Vector2i = DIRECTIONS[direction_index]
	var start_altitude := city.land_altitude(start.x, start.y)
	var current := start

	while true:
		if current.x < 0 or current.x > map_edge - 2 or current.y < 0 or current.y > map_edge - 2:
			return TunnelEditResult.rejected("tunnel cannot reach an opposite slope")

		var current_index := city.index_of(current.x, current.y)
		var altitude_word := int(city.altitude_words[current_index])

		if (altitude_word & TUNNEL_MASK) != 0:
			return TunnelEditResult.rejected("tunnel path conflicts with another tunnel")

		var altitude_difference := (altitude_word & Sc2AltitudeLayout.LEVEL_MASK) - start_altitude

		if altitude_difference > 30:
			return TunnelEditResult.rejected("tunnel path is too deep")

		if altitude_difference == 1 and _underground_blocks_tunnel(city.underground[current_index]):
			return TunnelEditResult.rejected("tunnel path conflicts with an underground network")

		current += direction
		var next_index := city.index_of(current.x, current.y)

		if next_index < 0 or city.land_altitude(current.x, current.y) <= start_altitude:
			break

	var finish := current
	var finish_index := city.index_of(finish.x, finish.y)
	var expected_terrain := ((start_terrain + 1) & 3) + 1

	if finish_index < 0 or city.terrain[finish_index] != expected_terrain:
		return TunnelEditResult.rejected("tunnel cannot reach an opposite slope")

	var points: Array[Vector2i] = []
	current = start

	while true:
		points.append(current)

		if current == finish:
			break

		current += direction

	var listed_cost := (
		points.size() * int(ToolCatalog.tool(group_index, subtool_index).cost)
	)
	var cost := 0 if free_mode else listed_cost

	if confirmation_choice == CONFIRMATION_UNSELECTED:
		var proposal := TunnelEditResult.rejected("tunnel construction confirmation is required", cost)
		proposal.confirmation_required = true
		proposal.start = start
		proposal.finish = finish
		proposal.points = points
		proposal.listed_cost = listed_cost
		proposal.free_mode = free_mode

		return proposal

	if confirmation_choice == CONFIRMATION_CANCELLED:
		var proposal := TunnelEditResult.rejected("tunnel construction canceled", cost)
		proposal.cancelled = true
		proposal.start = start
		proposal.finish = finish
		proposal.points = points
		proposal.listed_cost = listed_cost
		proposal.free_mode = free_mode

		return proposal

	if confirmation_choice != CONFIRMATION_CONFIRMED:
		return TunnelEditResult.rejected("tunnel confirmation choice is invalid")

	if city.funds() < cost:
		return TunnelEditResult.rejected("insufficient funds", cost)

	var old_payloads := NetworkState.city_payloads(city)

	if old_payloads.is_empty():
		return TunnelEditResult.rejected("required city data is missing or invalid")

	var changed_payloads := NetworkState._duplicate_payloads(old_payloads)
	var altitude: PackedByteArray = changed_payloads.ALTM
	var buildings: PackedByteArray = changed_payloads.XBLD
	var terrain: PackedByteArray = changed_payloads.XTER
	var zones: PackedByteArray = changed_payloads.XZON
	var flags: PackedByteArray = changed_payloads.XBIT
	var text_overlays: PackedByteArray = changed_payloads.XTXT
	var misc: PackedByteArray = changed_payloads.MISC

	var start_tile := start_terrain + (FIRST_ENTRANCE - 1)
	var finish_tile := ((start_terrain + 1) & 3) + FIRST_ENTRANCE
	NetworkState.replace_building(buildings, zones, misc, start_index, start_tile)
	_set_tunnel_level(altitude, start_index, 1)
	_retile_adjacent_roads(
		buildings, terrain, zones, flags, misc, start, text_overlays, map_edge
	)

	for point_index in range(1, points.size() - 1):
		var point := points[point_index]
		var index := point.x * map_edge + point.y
		_set_tunnel_level(altitude, index, city.land_altitude(point.x, point.y) - start_altitude + 1)

	NetworkState.replace_building(buildings, zones, misc, finish_index, finish_tile)
	_set_tunnel_level(altitude, finish_index, 1)
	_retile_adjacent_roads(
		buildings, terrain, zones, flags, misc, finish, text_overlays, map_edge
	)
	BinaryData.write_u32_be(misc, BuildingCommand.MISC_FUNDS, city.funds() - cost)

	var changed_ids := PackedStringArray()

	for chunk_id in ["ALTM", "XBLD", "MISC"]:
		if changed_payloads[chunk_id] != old_payloads[chunk_id]:
			changed_ids.append(chunk_id)

	if not NetworkState._apply_payloads(city, changed_ids, changed_payloads, old_payloads):
		return TunnelEditResult.rejected("cannot store tunnel changes")

	var result := TunnelEditResult.new()
	result.ok = true
	result.command_type = "tunnel"
	result.group_index = group_index
	result.subtool_index = subtool_index
	result.start = start
	result.finish = finish
	result.points = points
	result.start_tile = start_tile
	result.finish_tile = finish_tile
	result.cost = cost
	result.listed_cost = listed_cost
	result.free_mode = free_mode
	result.changed_ids = changed_ids
	result.old_payloads = old_payloads
	result.new_payloads = changed_payloads

	return result


static func undo(city: CityState, command: TunnelEditResult) -> EditCommandResult:
	if city == null or not city.is_valid():
		return EditCommandResult.failure("city is invalid")

	if command == null or not command.ok or command.command_type != "tunnel":
		return EditCommandResult.failure("tunnel command is invalid")

	var changed_ids := command.changed_ids
	var old_payloads := command.old_payloads
	var new_payloads := command.new_payloads

	for chunk_id in changed_ids:
		var chunk := city.document.find_chunk(chunk_id)

		if chunk == null or not new_payloads.has(chunk_id) or chunk.decoded_payload != new_payloads[chunk_id]:
			return EditCommandResult.failure("city changed after this tunnel command")

	if not NetworkState._apply_payloads(city, changed_ids, old_payloads, new_payloads):
		return EditCommandResult.failure("cannot restore tunnel changes")

	return EditCommandResult.undone(command.points.size())


static func _underground_blocks_tunnel(tile_id: int) -> bool:
	return (
		(tile_id >= UnderTiles.SUBWAY_LR and tile_id <= UnderTiles.PIPE_LR_SUBWAY_TB)
		or tile_id == UnderTiles.MISSILE_SILO
		or tile_id == UnderTiles.SUBWAY_ENTRANCE
	)


static func _set_tunnel_level(altitude: PackedByteArray, index: int, level: int) -> void:
	var offset := index * 2
	var word := (altitude[offset] << 8) | altitude[offset + 1]
	word = (word & ALTITUDE_DATA_MASK) | ((level & Sc2AltitudeLayout.LEVEL_MASK) << Sc2AltitudeLayout.TUNNEL_SHIFT)
	altitude[offset] = (word >> 8) & 0xff
	altitude[offset + 1] = word & 0xff


static func _retile_adjacent_roads(
	buildings: PackedByteArray,
	terrain: PackedByteArray,
	zones: PackedByteArray,
	flags: PackedByteArray,
	misc: PackedByteArray,
	point: Vector2i,
	text_overlays := PackedByteArray(),
	map_edge: int = 128,
) -> void:
	for offset in DIRECTIONS:
		var neighbor: Vector2i = point + offset

		if neighbor.x >= 0 and neighbor.x < map_edge and neighbor.y >= 0 and neighbor.y < map_edge:
			NetworkTiles.retile_surface(
				buildings,
				terrain,
				zones,
				flags,
				misc,
				neighbor,
				NetworkCommand.MODE_ROAD,
				text_overlays, map_edge
			)
