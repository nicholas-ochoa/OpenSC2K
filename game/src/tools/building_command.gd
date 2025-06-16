class_name BuildingCommand
extends RefCounted

const MISC_FUNDS := 0x0014
const MISC_TILE_COUNTS := 0x01f0
const MISC_BUDGETS := 0x077c
const BUDGET_RECORD_SIZE := 0x006c
const BUDGET_CURRENT := {
	0xd1: 7,
	0xd2: 5,
	0xd3: 6,
	0xd6: 8,
	0xd9: 9,
}

const MILITARY_ZONE := 7
const FLAG_WATER := 0x04
const FLAG_PIPED := 0x20
const FLAG_POWERED := 0x40
const FLAG_POWERABLE := 0x80
const STRUCTURE_FLAGS := FLAG_PIPED | FLAG_POWERED | FLAG_POWERABLE
const ROAD_FIRST := 0x1d
const RADIOACTIVITY := 0x05
const SMALL_PARK := 0x0d
const BIG_PARK := 0xd5
const MARINA := 0xf8
const MICROSIM_DYNAMIC_FIRST := 10
const MICROSIM_LABEL_BASE := 51

const MICROSIM_TYPE_BY_TILE := {
	0xc6: 21,
	0xc7: 21,
	0xc8: 20,
	0xc9: 1,
	0xca: 1,
	0xcb: 1,
	0xcc: 1,
	0xcd: 1,
	0xce: 1,
	0xcf: 1,
	0xd0: 2,
	0xd1: 3,
	0xd2: 4,
	0xd3: 5,
	0xd4: 23,
	0xd5: 22,
	0xd6: 6,
	0xd7: 7,
	0xd8: 8,
	0xd9: 9,
	0xda: 10,
	0xdb: 11,
	0xe9: 19,
	0xec: 17,
	0xed: 18,
	0xf3: 12,
	0xf4: 13,
	0xf5: 24,
	0xf8: 25,
	0xfa: 14,
	0xfb: 15,
	0xfc: 15,
	0xfd: 15,
	0xfe: 15,
	0xff: 16,
}

const DEFAULT_MICROSIM_LABELS := {
	0xc6: "Hydro Power",
	0xc7: "Hydro Power",
	0xc8: "Wind Power",
	0xc9: "Gas Power",
	0xca: "Oil Power",
	0xcb: "Nuclear Power",
	0xcc: "Solar Power",
	0xcd: "Microwave Power",
	0xce: "Fusion Power",
	0xcf: "Coal Power",
	0xd0: "City Hall",
	0xd1: "Hospital",
	0xd2: "Police Station",
	0xd3: "Fire Station",
	0xd4: "Museum",
	0xd5: "SimPark System",
	0xd6: "School",
	0xd7: "Stadium",
	0xd8: "Prison",
	0xd9: "College",
	0xda: "Zoo",
	0xdb: "Statue",
	0xe9: "SimSubway",
	0xec: "SimBus System",
	0xed: "SimRail System",
	0xf3: "Mayor's House",
	0xf4: "Water Treatment",
	0xf5: "Library System",
	0xf8: "Marina",
	0xfa: "Desalinization",
	0xfb: "Plymouth Arco",
	0xfc: "Forest Arco",
	0xfd: "Darco",
	0xfe: "Launch Arco",
	0xff: "Llama Dome",
}

const TILE_BY_TOOL := {
	38: 0xcf,
	40: 0xca,
	41: 0xc9,
	42: 0xcb,
	43: 0xc8,
	44: 0xcc,
	45: 0xcd,
	46: 0xce,
	49: 0xdc,
	50: 0xeb,
	51: 0xf4,
	52: 0xfa,
	60: 0xf3,
	61: 0xd0,
	62: 0xdb,
	63: 0xff,
	65: 0xfb,
	66: 0xfc,
	67: 0xfd,
	68: 0xfe,
	76: 0xec,
	86: 0xed,
	87: 0xe9,
	144: 0xd6,
	145: 0xd9,
	146: 0xf5,
	147: 0xd4,
	156: 0xd2,
	157: 0xd3,
	158: 0xd1,
	159: 0xd8,
	168: 0x0d,
	169: 0xd5,
	170: 0xda,
	171: 0xd7,
	172: 0xf8,
}

const NUISANCE_TILES := {
	0xc9: true,
	0xca: true,
	0xcb: true,
	0xcf: true,
	0xd8: true,
	0xf4: true,
}

const CORNER_BOTTOM_LEFT := [0x10, 0x20, 0x40, 0x80]
const CORNER_BOTTOM_RIGHT := [0x20, 0x40, 0x80, 0x10]
const CORNER_TOP_LEFT := [0x40, 0x80, 0x10, 0x20]
const CORNER_TOP_RIGHT := [0x80, 0x10, 0x20, 0x40]


static func supports_tool(group_index: int, subtool_index: int) -> bool:
	return TILE_BY_TOOL.has(group_index * ToolCatalog.MAX_SLOTS_PER_GROUP + subtool_index)


static func tile_for_tool(group_index: int, subtool_index: int) -> int:
	return int(TILE_BY_TOOL.get(
		group_index * ToolCatalog.MAX_SLOTS_PER_GROUP + subtool_index, 0
	))


# the pointer isn't the footprint origin for the bigger buildings
static func footprint(selected: Vector2i, area: int) -> Rect2i:
	if area < 1 or area > 4:
		return Rect2i()
	var origin := selected
	if area > 2:
		origin -= Vector2i.ONE
	return Rect2i(origin, Vector2i(area, area))


static func apply(
	city: CityState,
	group_index: int,
	subtool_index: int,
	selected: Vector2i,
	nuisance_random: GameLcgRandom,
	process_random: SimRandom
) -> Dictionary:
	if city == null or not city.is_valid():
		return {"ok": false, "error": "city is invalid"}
	if not supports_tool(group_index, subtool_index):
		return {"ok": false, "error": "tool does not place a shared building"}
	if nuisance_random == null:
		return {"ok": false, "error": "nuisance random state is required"}
	if process_random == null:
		return {"ok": false, "error": "process random state is required"}

	var tool := ToolCatalog.tool(group_index, subtool_index)
	var cost := int(tool.cost)
	if cost != 0 and city.funds() < cost:
		return {"ok": false, "error": "insufficient funds", "cost": cost}
	var area := int(tool.area)
	var site := footprint(selected, area)
	if not _footprint_is_in_bounds(site, area):
		return {"ok": false, "error": "building does not fit inside the map", "cost": cost}

	var old_payloads := _city_payloads(city)
	if old_payloads.is_empty():
		return {"ok": false, "error": "required city data is missing or invalid"}
	var changed_payloads := _duplicate_payloads(old_payloads)
	var buildings: PackedByteArray = changed_payloads.XBLD
	var terrain: PackedByteArray = changed_payloads.XTER
	var zones: PackedByteArray = changed_payloads.XZON
	var flags: PackedByteArray = changed_payloads.XBIT
	var text_overlays: PackedByteArray = changed_payloads.XTXT
	var labels: PackedByteArray = changed_payloads.XLAB
	var microsims: PackedByteArray = changed_payloads.XMIC
	var misc: PackedByteArray = changed_payloads.MISC
	var tile_id := tile_for_tool(group_index, subtool_index)

	var site_check := _check_site(buildings, terrain, zones, flags, site, tile_id)
	if not site_check.ok:
		return {"ok": false, "error": site_check.error, "cost": cost}

	var random_state_before := nuisance_random.state
	var process_random_state_before := process_random.state
	if NUISANCE_TILES.has(tile_id):
		var residential_tiles := _count_nearby_residential(zones, selected, area)
		if nuisance_random.next_mod(200) < residential_tiles:
			return {
				"ok": false,
				"error": "residents rejected this site",
				"cost": cost,
				"residential_tiles": residential_tiles,
			}

	var overlay_id := _provision_microsim(
		microsims, labels, text_overlays, tile_id, city.current_year(), process_random
	)

	var placed_flags := FLAG_PIPED if tile_id == SMALL_PARK or tile_id == BIG_PARK else STRUCTURE_FLAGS
	var tile_indices := PackedInt32Array()
	for x in range(site.position.x, site.end.x):
		for y in range(site.position.y, site.end.y):
			var index := x * CityState.MAP_SIZE + y
			_update_building_count(misc, zones[index] & 0x0f, buildings[index], tile_id)
			buildings[index] = tile_id
			zones[index] = 0
			flags[index] = (flags[index] & 0x1f) | placed_flags
			if overlay_id != 0:
				text_overlays[index] = overlay_id
			tile_indices.append(index)
	_set_corners(zones, site, area, city.compass_rotation())
	if BUDGET_CURRENT.has(tile_id):
		var budget_offset: int = MISC_BUDGETS + int(BUDGET_CURRENT[tile_id]) * BUDGET_RECORD_SIZE
		_write_u32_be(misc, budget_offset, _read_u32_be(misc, budget_offset) + 1)
	_write_u32_be(misc, MISC_FUNDS, city.funds() - cost)

	var changed_ids := PackedStringArray()
	for chunk_id in ["XBLD", "XZON", "XBIT", "XTXT", "XLAB", "XMIC", "MISC"]:
		if changed_payloads[chunk_id] != old_payloads[chunk_id]:
			changed_ids.append(chunk_id)
	if not _apply_payloads(city, changed_ids, changed_payloads, old_payloads):
		nuisance_random.state = random_state_before
		process_random.state = process_random_state_before
		return {"ok": false, "error": "cannot store building changes"}

	return {
		"ok": true,
		"command_type": "building",
		"group_index": group_index,
		"subtool_index": subtool_index,
		"tile_id": tile_id,
		"site": site,
		"tile_indices": tile_indices,
		"cost": cost,
		"overlay_id": overlay_id,
		"changed_ids": changed_ids,
		"old_payloads": old_payloads,
		"new_payloads": changed_payloads,
		"random_state_before": random_state_before,
		"random_state_after": nuisance_random.state,
		"process_random_state_before": process_random_state_before,
		"process_random_state_after": process_random.state,
		"error": "",
	}


static func undo(
	city: CityState,
	command: Dictionary,
	nuisance_random: GameLcgRandom,
	process_random: SimRandom
) -> Dictionary:
	if city == null or not city.is_valid():
		return {"ok": false, "error": "city is invalid"}
	if not command.get("ok", false) or command.get("command_type", "") != "building":
		return {"ok": false, "error": "building command is invalid"}
	if nuisance_random == null:
		return {"ok": false, "error": "nuisance random state is required"}
	if process_random == null:
		return {"ok": false, "error": "process random state is required"}
	if nuisance_random.state != int(command.get("random_state_after", -1)):
		return {"ok": false, "error": "random state changed after this building command"}
	if process_random.state != int(command.get("process_random_state_after", -1)):
		return {"ok": false, "error": "process random state changed after this building command"}
	var changed_ids: PackedStringArray = command.get("changed_ids", PackedStringArray())
	var old_payloads: Dictionary = command.get("old_payloads", {})
	var new_payloads: Dictionary = command.get("new_payloads", {})
	for chunk_id in changed_ids:
		var chunk := city.document.find_chunk(chunk_id)
		if chunk == null or not new_payloads.has(chunk_id) or chunk.decoded_payload != new_payloads[chunk_id]:
			return {"ok": false, "error": "city changed after this building command"}
	if not _apply_payloads(city, changed_ids, old_payloads, new_payloads):
		return {"ok": false, "error": "cannot restore building changes"}
	nuisance_random.state = int(command.random_state_before)
	process_random.state = int(command.process_random_state_before)
	var indices: PackedInt32Array = command.get("tile_indices", PackedInt32Array())
	return {"ok": true, "restored_tiles": indices.size(), "error": ""}


static func _footprint_is_in_bounds(site: Rect2i, area: int) -> bool:
	if site.size != Vector2i(area, area):
		return false
	if area == 1:
		return site.position.x >= 0 and site.position.y >= 0 and site.end.x <= 128 and site.end.y <= 128
	return site.position.x >= 1 and site.position.y >= 1 and site.end.x <= 127 and site.end.y <= 127


static func _check_site(
	buildings: PackedByteArray,
	terrain: PackedByteArray,
	zones: PackedByteArray,
	flags: PackedByteArray,
	site: Rect2i,
	tile_id: int
) -> Dictionary:
	var marina_water_tiles := 0
	for x in range(site.position.x, site.end.x):
		for y in range(site.position.y, site.end.y):
			var index := x * CityState.MAP_SIZE + y
			var old_building := int(buildings[index])
			if old_building >= ROAD_FIRST or old_building == RADIOACTIVITY or old_building == SMALL_PARK:
				return {"ok": false, "error": "site contains a protected tile"}
			if (zones[index] & 0x0f) == MILITARY_ZONE:
				return {"ok": false, "error": "site is in a military zone"}
			var is_water := (flags[index] & FLAG_WATER) != 0
			if tile_id == MARINA and is_water:
				marina_water_tiles += 1
			elif terrain[index] != 0 or is_water:
				return {"ok": false, "error": "site is not clear"}
	if tile_id == MARINA and (marina_water_tiles == 0 or marina_water_tiles == site.size.x * site.size.y):
		return {"ok": false, "error": "marina must span land and water"}
	return {"ok": true, "error": ""}


static func _count_nearby_residential(
	zones: PackedByteArray, selected: Vector2i, area: int
) -> int:
	var count := 0
	for x in range(maxi(selected.x - 8, 0), mini(selected.x + area + 8, 128)):
		for y in range(maxi(selected.y - 8, 0), mini(selected.y + area + 8, 128)):
			var zone := zones[x * CityState.MAP_SIZE + y] & 0x0f
			if zone == 1 or zone == 2:
				count += 1
	return count


static func _provision_microsim(
	microsims: PackedByteArray,
	labels: PackedByteArray,
	text_overlays: PackedByteArray,
	tile_id: int,
	current_year: int,
	process_random: SimRandom
) -> int:
	var microsim_type := int(MICROSIM_TYPE_BY_TILE.get(tile_id, 0))
	if microsim_type == 0:
		return 0
	var record_id := -1
	if microsim_type <= 16:
		for checked_id in range(MICROSIM_DYNAMIC_FIRST, CityState.MICROSIM_COUNT):
			if microsims[checked_id * CityState.MICROSIM_RECORD_SIZE] == 0:
				record_id = checked_id
				break
	else:
		record_id = microsim_type - 16
	if record_id < 0 and tile_id >= 0xfb:
		for checked_id in range(MICROSIM_DYNAMIC_FIRST, CityState.MICROSIM_COUNT):
			if microsims[checked_id * CityState.MICROSIM_RECORD_SIZE] < 0xfb:
				record_id = checked_id
				var old_overlay_id := checked_id + MICROSIM_LABEL_BASE
				for index in text_overlays.size():
					if text_overlays[index] == old_overlay_id:
						text_overlays[index] = 0
				break
	if record_id < 0:
		return 0

	var record_offset := record_id * CityState.MICROSIM_RECORD_SIZE
	if microsim_type <= 16:
		for offset in CityState.MICROSIM_RECORD_SIZE:
			microsims[record_offset + offset] = 0
	microsims[record_offset] = tile_id
	_initialize_microsim(microsims, record_id, tile_id, current_year, process_random)

	var label_id := record_id + MICROSIM_LABEL_BASE
	var label_offset := label_id * CityState.LABEL_RECORD_SIZE
	if microsim_type <= 16 or labels[label_offset] == 0:
		_write_label(labels, label_id, str(DEFAULT_MICROSIM_LABELS.get(tile_id, "")))
	return label_id


static func _initialize_microsim(
	microsims: PackedByteArray,
	record_id: int,
	tile_id: int,
	current_year: int,
	process_random: SimRandom
) -> void:
	var offset := record_id * CityState.MICROSIM_RECORD_SIZE
	match tile_id:
		0xc6, 0xc7:
			_write_u16_be(microsims, offset + 2, _read_u16_be(microsims, offset + 2) + 1)
			_write_u16_be(microsims, offset + 4, _read_u16_be(microsims, offset + 4) + 20)
		0xc8:
			_write_u16_be(microsims, offset + 2, _read_u16_be(microsims, offset + 2) + 1)
			_write_u16_be(microsims, offset + 4, _read_u16_be(microsims, offset + 4) + 4)
		0xc9, 0xcc:
			_write_u16_be(microsims, offset + 2, 50)
		0xca:
			_write_u16_be(microsims, offset + 2, 220)
		0xcb:
			_write_u16_be(microsims, offset + 2, 500)
		0xcd:
			_write_u16_be(microsims, offset + 2, 1600)
		0xce:
			_write_u16_be(microsims, offset + 2, 2500)
		0xcf:
			_write_u16_be(microsims, offset + 2, 200)
		0xd1, 0xd6, 0xd9:
			microsims[offset + 1] = 6
		0xd5:
			_write_u16_be(microsims, offset + 4, _read_u16_be(microsims, offset + 4) + 9)
		0xdb:
			_write_u16_be(microsims, offset + 2, current_year)
		0xe9, 0xec, 0xed:
			_write_u16_be(microsims, offset + 2, _read_u16_be(microsims, offset + 2) + 1)
		0xf3:
			_write_u16_be(microsims, offset + 2, current_year)
			_write_u16_be(microsims, offset + 4, process_random.next_u15() % 30 + 10)
			_write_u16_be(microsims, offset + 6, process_random.next_u15() % 60)
		0xfb:
			microsims[offset + 1] = 5
			_write_u16_be(microsims, offset + 2, 55)
			_write_u16_be(microsims, offset + 6, current_year)
		0xfc:
			microsims[offset + 1] = 5
			_write_u16_be(microsims, offset + 2, 30)
			_write_u16_be(microsims, offset + 6, current_year)
		0xfd:
			microsims[offset + 1] = 5
			_write_u16_be(microsims, offset + 2, 45)
			_write_u16_be(microsims, offset + 6, current_year)
		0xfe:
			microsims[offset + 1] = 5
			_write_u16_be(microsims, offset + 2, 65)
			_write_u16_be(microsims, offset + 6, current_year)


static func _write_label(labels: PackedByteArray, label_id: int, value: String) -> void:
	var encoded := value.to_ascii_buffer()
	if encoded.size() > 23:
		encoded = encoded.slice(0, 23)
	var offset := label_id * CityState.LABEL_RECORD_SIZE
	for record_byte in CityState.LABEL_RECORD_SIZE:
		labels[offset + record_byte] = 0
	labels[offset] = encoded.size()
	for index in encoded.size():
		labels[offset + 1 + index] = encoded[index]


static func _read_u16_be(data: PackedByteArray, offset: int) -> int:
	return (data[offset] << 8) | data[offset + 1]


static func _write_u16_be(data: PackedByteArray, offset: int, value: int) -> void:
	data[offset] = (value >> 8) & 0xff
	data[offset + 1] = value & 0xff


# The zone and building corner flags share one byte.
static func _set_corners(zones: PackedByteArray, site: Rect2i, area: int, rotation: int) -> void:
	if area == 1:
		zones[site.position.x * CityState.MAP_SIZE + site.position.y] = 0xf0
		return
	var far := site.end - Vector2i.ONE
	var view := rotation & 3
	zones[site.position.x * CityState.MAP_SIZE + site.position.y] = CORNER_BOTTOM_LEFT[view]
	zones[far.x * CityState.MAP_SIZE + site.position.y] = CORNER_BOTTOM_RIGHT[view]
	zones[far.x * CityState.MAP_SIZE + far.y] = CORNER_TOP_LEFT[view]
	zones[site.position.x * CityState.MAP_SIZE + far.y] = CORNER_TOP_RIGHT[view]


static func _update_building_count(
	misc: PackedByteArray, zone: int, old_building: int, new_building: int
) -> void:
	if zone == MILITARY_ZONE:
		return
	var old_offset := MISC_TILE_COUNTS + old_building * 4
	var new_offset := MISC_TILE_COUNTS + new_building * 4
	_write_u32_be(misc, old_offset, (_read_u32_be(misc, old_offset) - 1) & 0xffff)
	_write_u32_be(misc, new_offset, (_read_u32_be(misc, new_offset) + 1) & 0xffff)


static func _city_payloads(city: CityState) -> Dictionary:
	var result := {}
	for checked in [
		["XBLD", CityState.TILE_COUNT],
		["XTER", CityState.TILE_COUNT],
		["XZON", CityState.TILE_COUNT],
		["XBIT", CityState.TILE_COUNT],
		["XTXT", CityState.TILE_COUNT],
		["XLAB", CityState.LABEL_COUNT * CityState.LABEL_RECORD_SIZE],
		["XMIC", CityState.MICROSIM_COUNT * CityState.MICROSIM_RECORD_SIZE],
		["MISC", 4800],
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
	city: CityState, chunk_ids: PackedStringArray, payloads: Dictionary, rollback: Dictionary
) -> bool:
	var applied := PackedStringArray()
	for chunk_id in chunk_ids:
		var chunk := city.document.find_chunk(chunk_id)
		if chunk == null or not payloads.has(chunk_id) or not chunk.set_decoded_payload(payloads[chunk_id]):
			for rollback_id in applied:
				city.document.find_chunk(rollback_id).set_decoded_payload(rollback[rollback_id])
			_refresh_city_arrays(city)
			return false
		applied.append(chunk_id)
	_refresh_city_arrays(city)
	return true


static func _refresh_city_arrays(city: CityState) -> void:
	city.buildings = city.document.find_chunk("XBLD").decoded_payload.duplicate()
	city.terrain = city.document.find_chunk("XTER").decoded_payload.duplicate()
	city.zones = city.document.find_chunk("XZON").decoded_payload.duplicate()
	city.tile_flags = city.document.find_chunk("XBIT").decoded_payload.duplicate()
	city.text_overlays = city.document.find_chunk("XTXT").decoded_payload.duplicate()


static func _read_u32_be(data: PackedByteArray, offset: int) -> int:
	return (
		(data[offset] << 24)
		| (data[offset + 1] << 16)
		| (data[offset + 2] << 8)
		| data[offset + 3]
	)


static func _write_u32_be(data: PackedByteArray, offset: int, value: int) -> void:
	data[offset] = (value >> 24) & 0xff
	data[offset + 1] = (value >> 16) & 0xff
	data[offset + 2] = (value >> 8) & 0xff
	data[offset + 3] = value & 0xff
