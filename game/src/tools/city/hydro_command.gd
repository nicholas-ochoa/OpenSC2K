class_name HydroCommand
extends RefCounted

const Power = preload("res://src/simulation/infrastructure/power_phase.gd")

const GROUP_POWER := 3
const SUBTOOL_HYDRO := 3
const TERRAIN_WATERFALL_A := 0x2e
const TERRAIN_WATERFALL_B := 0x3e
const FLAG_POWERABLE := 0x80
const HYDRO_TILE_A := 0xc6
const HYDRO_ORIENTATION := [1, 1, 0, 1, 1, 0, 1, 0, 0, 1, 1, 1, 1, 0, 1, 1]


static func supports_tool(group_index: int, subtool_index: int) -> bool:
	return group_index == GROUP_POWER and subtool_index == SUBTOOL_HYDRO


static func apply(
	city: CityState,
	group_index: int,
	subtool_index: int,
	point: Vector2i,
	process_random: SimRandom
) -> Dictionary:
	if city == null or not city.is_valid():
		return {"ok": false, "error": "city is invalid"}

	if not supports_tool(group_index, subtool_index):
		return {"ok": false, "error": "tool is not hydroelectric power"}

	if process_random == null:
		return {"ok": false, "error": "process random state is required"}

	var index := city.index_of(point.x, point.y)

	if index < 0:
		return {"ok": false, "error": "hydroelectric site is outside the city"}

	if city.terrain[index] != TERRAIN_WATERFALL_A and city.terrain[index] != TERRAIN_WATERFALL_B:
		return {"ok": false, "error": "hydroelectric power requires a waterfall"}

	if city.buildings[index] != 0:
		return {"ok": false, "error": "waterfall already contains a building"}

	var cost := int(ToolCatalog.tool(group_index, subtool_index).cost)

	if city.funds() < cost:
		return {"ok": false, "error": "insufficient funds", "cost": cost}

	var old_payloads := BuildingState._city_payloads(city)

	if old_payloads.is_empty():
		return {"ok": false, "error": "required city data is missing or invalid"}

	var changed_payloads := BuildingState._duplicate_payloads(old_payloads)
	var buildings: PackedByteArray = changed_payloads.XBLD
	var zones: PackedByteArray = changed_payloads.XZON
	var flags: PackedByteArray = changed_payloads.XBIT
	var text_overlays: PackedByteArray = changed_payloads.XTXT
	var labels: PackedByteArray = changed_payloads.XLAB
	var microsims: PackedByteArray = changed_payloads.XMIC
	var misc: PackedByteArray = changed_payloads.MISC
	var tile_id := _hydro_tile(city, point)
	var process_random_state_before := process_random.state

	BuildingState.update_building_count(misc, zones[index] & 0x0f, buildings[index], tile_id, city.map_size)
	buildings[index] = tile_id
	flags[index] |= FLAG_POWERABLE
	zones[index] = 0xf0
	var overlay_id := BuildingFacilities.provision_microsim(
		microsims, labels, text_overlays, tile_id, city.current_year(), process_random
	)

	if overlay_id != 0:
		OverlayData.write(text_overlays, index, overlay_id)

	BuildingState._write_u32_be(misc, BuildingCommand.MISC_FUNDS, city.funds() - cost)

	var changed_ids := PackedStringArray()

	for chunk_id in ["XBLD", "XZON", "XBIT", "XTXT", "XLAB", "XMIC", "MISC"]:
		if changed_payloads[chunk_id] != old_payloads[chunk_id]:
			changed_ids.append(chunk_id)

	if not BuildingState._apply_payloads(city, changed_ids, changed_payloads, old_payloads):
		process_random.state = process_random_state_before

		return {"ok": false, "error": "cannot store hydroelectric changes"}

	var immediate_power_refresh := false

	if city.document.misc_u32(BuildingCommand.MISC_NORMAL_POPULATION) < BuildingCommand.IMMEDIATE_UTILITY_POPULATION_LIMIT:
		var power_result := Power.run(city, process_random)

		if not power_result.ok:
			BuildingState._restore_payloads(city, old_payloads)
			process_random.state = process_random_state_before

			return {"ok": false, "error": "cannot refresh power after hydroelectric placement"}

		immediate_power_refresh = true
		changed_payloads = BuildingState._city_payloads(city)

		if changed_payloads.is_empty():
			BuildingState._restore_payloads(city, old_payloads)
			process_random.state = process_random_state_before

			return {"ok": false, "error": "cannot capture hydroelectric power changes"}

		changed_ids.clear()

		for chunk_id in changed_payloads:
			if changed_payloads[chunk_id] != old_payloads[chunk_id]:
				changed_ids.append(chunk_id)

	return {
		"ok": true,
		"command_type": "hydro",
		"group_index": group_index,
		"subtool_index": subtool_index,
		"tile_id": tile_id,
		"tile_indices": PackedInt32Array([index]),
		"overlay_id": overlay_id,
		"cost": cost,
		"changed_ids": changed_ids,
		"old_payloads": old_payloads,
		"new_payloads": changed_payloads,
		"process_random_state_before": process_random_state_before,
		"process_random_state_after": process_random.state,
		"immediate_power_refresh": immediate_power_refresh,
		"error": "",
	}


static func undo(city: CityState, command: Dictionary, process_random: SimRandom) -> Dictionary:
	if city == null or not city.is_valid():
		return {"ok": false, "error": "city is invalid"}

	if not command.get("ok", false) or command.get("command_type", "") != "hydro":
		return {"ok": false, "error": "hydroelectric command is invalid"}

	if process_random == null:
		return {"ok": false, "error": "process random state is required"}

	if process_random.state != int(command.get("process_random_state_after", -1)):
		return {"ok": false, "error": "process random state changed after this hydroelectric command"}

	var changed_ids: PackedStringArray = command.get("changed_ids", PackedStringArray())
	var old_payloads: Dictionary = command.get("old_payloads", {})
	var new_payloads: Dictionary = command.get("new_payloads", {})

	for chunk_id in changed_ids:
		var chunk := city.document.find_chunk(chunk_id)

		if chunk == null or not new_payloads.has(chunk_id) or chunk.decoded_payload != new_payloads[chunk_id]:
			return {"ok": false, "error": "city changed after this hydroelectric command"}

	if not BuildingState._apply_payloads(city, changed_ids, old_payloads, new_payloads):
		return {"ok": false, "error": "cannot restore hydroelectric changes"}

	process_random.state = int(command.process_random_state_before)

	return {"ok": true, "restored_tiles": 1, "error": ""}


static func _hydro_tile(city: CityState, point: Vector2i) -> int:
	var map_edge: int = city.map_size if city != null else 128
	var altitude := city.land_altitude(point.x, point.y)
	var higher_neighbors := 0

	if point.y > 0 and altitude < city.land_altitude(point.x, point.y - 1):
		higher_neighbors |= 1

	if point.x < (map_edge - 1) and altitude < city.land_altitude(point.x + 1, point.y):
		higher_neighbors |= 2

	if point.y < (map_edge - 1) and altitude < city.land_altitude(point.x, point.y + 1):
		higher_neighbors |= 4

	if point.x > 0 and altitude < city.land_altitude(point.x - 1, point.y):
		higher_neighbors |= 8

	var orientation: int = HYDRO_ORIENTATION[higher_neighbors]

	if city.compass_rotation() & 1:
		orientation ^= 1

	return HYDRO_TILE_A + orientation
