class_name QueryInfo
extends QueryConstants



static func inspect(
	city: CityState, point: Vector2i, resource_strings: Dictionary = {}
) -> Dictionary:
	var map_edge: int = city.map_size if city != null else 128

	if city == null or not city.is_valid():
		return {"ok": false, "error": "city is invalid"}

	if city.index_of(point.x, point.y) < 0:
		return {"ok": false, "error": "query position is outside the city"}

	for checked in [
		["XTRF", (IntegerMath.div_trunc(map_edge, 2)) * (IntegerMath.div_trunc(map_edge, 2))],
		["XPLT", (IntegerMath.div_trunc(map_edge, 2)) * (IntegerMath.div_trunc(map_edge, 2))],
		["XVAL", (IntegerMath.div_trunc(map_edge, 2)) * (IntegerMath.div_trunc(map_edge, 2))],
		["XCRM", (IntegerMath.div_trunc(map_edge, 2)) * (IntegerMath.div_trunc(map_edge, 2))],
	]:
		var chunk := city.document.find_chunk(checked[0])

		if chunk == null or chunk.decoded_payload.size() != city.document.decoded_size(str(checked[0])):
			return {"ok": false, "error": "%s data is missing or invalid" % checked[0]}

	var overlay := city.text_overlay_id(point.x, point.y)

	if OverlayData.is_facility(overlay):
		var microsim := city.microsim(OverlayData.facility_record(overlay))

		if not microsim.is_empty() and microsim.tile_id != 0:
			var microsim_type := int(MICROSIM_TYPE_BY_TILE.get(microsim.tile_id, 0))
			var action := ""
			var action_resource_id := -1

			if microsim.tile_id == CITY_HALL:
				action = "city_analysis"
				action_resource_id = CITY_HALL_ACTION_RESOURCE
			elif microsim.tile_id == LIBRARY:
				action = "library_ruminate"
				action_resource_id = LIBRARY_ACTION_RESOURCE

			var specific := {
				"ok": true,
				"kind": "specific",
				"point": point,
				"title": city.label(overlay),
				"overlay_id": overlay,
				"microsim_id": OverlayData.facility_record(overlay),
				"microsim": microsim,
				"microsim_type": microsim_type,
				"lines": _specific_lines(
					city, microsim, microsim_type, resource_strings
				),
				"action": action,
				"action_resource_id": action_resource_id,
				"sound_events": specific_sound_events(
					int(microsim.tile_id), int(microsim.stat_0)
				),
				"error": "",
			}
			specific.merge(_advanced_details(
				city, point, OverlayData.facility_record(overlay)
			))
			specific["sprite_id"] = Presentation.sprite_id(city, specific)

			return specific

	var building := city.building_id(point.x, point.y)
	var zone := city.zone_id(point.x, point.y)
	var water_level := city.document.misc_u32(0x0e40)
	var land_altitude := city.land_altitude(point.x, point.y)
	var terrain := city.terrain_id(point.x, point.y)
	var wet_tile := false
	var altitude_is_depth := false
	var altitude_feet := 0

	if land_altitude < water_level:
		altitude_feet = 100 * (water_level - land_altitude) - 50
		altitude_is_depth = true
		wet_tile = true
	elif terrain == 0 or terrain >= 0x10:
		altitude_feet = 100 * (land_altitude - water_level) + 50
		wet_tile = terrain >= 0x10
	else:
		altitude_feet = 25 * (4 * (land_altitude - water_level) + 4)

	var detail_index := CityDataGrid.index(city.document.find_chunk("XVAL").decoded_payload, map_edge, point.x, point.y)
	var traffic_chunk := city.document.find_chunk("XTRF")
	var pollution_chunk := city.document.find_chunk("XPLT")
	var land_value_chunk := city.document.find_chunk("XVAL")
	var crime_chunk := city.document.find_chunk("XCRM")
	var result := {
		"ok": true,
		"kind": "general",
		"point": point,
		"title": _tile_description(city, point, building, resource_strings),
		"building_id": building,
		"terrain_id": terrain,
		"zone_id": zone,
		"zone_name": ZONE_NAMES[zone] if zone < ZONE_NAMES.size() else "Unknown zone",
		"zone_density": ZONE_DENSITIES[zone] if zone < ZONE_DENSITIES.size() else "",
		"shows_traffic": _is_traffic_tile(building),
		"traffic": _traffic(city, traffic_chunk.decoded_payload, point, building),
		"altitude_feet": altitude_feet,
		"altitude_is_depth": altitude_is_depth,
		"shows_land_value": not wet_tile or land_altitude < water_level,
		"land_value": int(land_value_chunk.decoded_payload[detail_index]) + 1,
		"crime": int(crime_chunk.decoded_payload[detail_index]),
		"crime_level": _level_name(crime_chunk.decoded_payload[detail_index]),
		"pollution": int(pollution_chunk.decoded_payload[detail_index]),
		"pollution_level": _level_name(pollution_chunk.decoded_payload[detail_index]),
		"shows_utilities": (
			building >= FIRST_BUILDING_WITH_UTILITIES and zone != MILITARY_ZONE and not wet_tile
		),
		"powered": city.is_powered(point.x, point.y),
		"watered": city.is_watered(point.x, point.y),
		"water_detail": _water_detail(city, point, building),
		"overlay_id": overlay,
		"sound_events": [],
		"error": "",
	}
	result.merge(_advanced_details(city, point))
	result["sprite_id"] = Presentation.sprite_id(city, result)

	return result


static func format_text(info: Dictionary) -> String:
	if not info.get("ok", false):
		return "Query failed: %s" % info.get("error", "unknown error")

	var point: Vector2i = info.point

	if info.kind == "specific":
		var title: String = info.title

		if title.is_empty():
			title = "City facility"

		var specific_lines := PackedStringArray([title, ""])
		specific_lines.append_array(info.lines)
		specific_lines.append("")
		specific_lines.append_array(_advanced_lines(info))

		return "\n".join(specific_lines)

	var lines := PackedStringArray([
		info.title,
		"Tile: %d, %d" % [point.x, point.y],
	])

	if info.zone_id != 0:
		lines.append("Zone: %s" % info.zone_name)

		if not info.zone_density.is_empty():
			lines.append("Density: %s" % info.zone_density)

	if info.shows_traffic:
		lines.append("Traffic: %d cars/minute" % info.traffic)

	lines.append(
		"Altitude: %d feet%s"
		% [info.altitude_feet, " deep" if info.altitude_is_depth else ""]
	)

	if info.shows_land_value:
		lines.append("Land value: $%d,000/acre" % info.land_value)

	lines.append("Crime: %s" % info.crime_level)
	lines.append("Pollution: %s" % info.pollution_level)

	if info.shows_utilities:
		lines.append("Powered: %s" % ("Yes" if info.powered else "No"))

		if info.water_detail.is_empty():
			lines.append("Watered: %s" % ("Yes" if info.watered else "No"))
		else:
			lines.append(info.water_detail)

	lines.append("")
	lines.append_array(_advanced_lines(info))

	return "\n".join(lines)


static func _advanced_details(
	city: CityState, point: Vector2i, microsim_id := -1
) -> Dictionary:
	return QueryDetails._advanced_details(city, point, microsim_id)


static func _advanced_lines(info: Dictionary) -> PackedStringArray:
	var point: Vector2i = info.point
	var flag_names: PackedStringArray = info.get("flag_names", PackedStringArray())
	var flag_text := "none" if flag_names.is_empty() else " ".join(flag_names)
	var result := PackedStringArray([
		"Advanced tile data",
		"Tile ID: %d / 0x%02X" % [info.tile_id, info.tile_id],
		"Sprite ID: %d / 0x%04X" % [info.sprite_id, info.sprite_id],
		"Coordinates: X=%d  Y=%d" % [point.x, point.y],
		"ALTM: 0x%04X" % info.altitude_raw,
		"XVAL: %d / 0x%02X" % [info.land_value_raw, info.land_value_raw],
		"XCRM: %d / 0x%02X" % [info.crime_raw, info.crime_raw],
		"XPLT: %d / 0x%02X" % [info.pollution_raw, info.pollution_raw],
		"XTXT: %d / 0x%02X" % [info.overlay_id, info.overlay_id],
		"XZON: %s, zone 0x%X (raw 0x%02X)"
		% [info.corner_name, info.zone_id, info.zone_raw],
		"XBIT: %s (0x%02X)" % [flag_text, info.flags_raw],
		"Underground: %s (XUND %d / 0x%02X)"
		% [info.underground_name, info.underground_id, info.underground_id],
	])
	var microsim_id := int(info.get("microsim_id", -1))

	if microsim_id < 0:
		result.append("Microsim ID: None")
	else:
		var microsim: Dictionary = info.get("microsim", {})
		var microsim_label := str(info.get("microsim_label", ""))

		if not microsim_label.is_empty():
			result.append("Microsim name: %s" % microsim_label)

		result.append("Microsim ID: %d / 0x%02X" % [microsim_id, microsim_id])

		if microsim.is_empty():
			result.append("XMIC data: unavailable")
		else:
			result.append("Data 0: %d / 0x%02X" % [microsim.stat_0, microsim.stat_0])

			for data_index in range(1, 4):
				var value := int(microsim["stat_%d" % data_index])
				result.append("Data %d: %d / 0x%04X" % [data_index, value, value])

	var things: Array = info.get("things", [])

	if not things.is_empty():
		result.append("")
		result.append("XTHG moving objects")

		for thing in things:
			result.append(
				"Record %d: %s (type %d / 0x%02X)"
				% [thing.record, thing.type_name, thing.type, thing.type]
			)
			result.append(
				"Direction: %s (%d)  State: %d / 0x%02X"
				% [thing.direction_name, thing.direction, thing.state, thing.state]
			)
			result.append(
				"Position: X=%d Y=%d Z=%d  PX=%d PY=%d"
				% [thing.x, thing.y, thing.z, thing.px, thing.py]
			)
			result.append(
				"Target/data: DX=%d DY=%d  Label=%d  Goal=%d"
				% [thing.dx, thing.dy, thing.label, thing.goal]
			)

	return result


static func _things_at(city: CityState, point: Vector2i) -> Array[Dictionary]:
	return QueryDetails._things_at(city, point)


static func specific_sound_events(tile_id: int, statistic_0: int) -> Array[int]:
	match tile_id:
		0xc6, 0xc7, 0xc8, 0xc9, 0xca, 0xcb, 0xcc, 0xcd, 0xce, 0xcf:
			return [514]
		0xd0, 0xd5, 0xd7, 0xdb, 0xf3, 0xff:
			return [513]
		0xd1, 0xd2:
			return [506]
		0xd3:
			return [509]
		0xd6, 0xd9:
			return [523]
		0xd8:
			return [522]
		0xda:
			return [527]
		0xec:
			return [521]
		0xed:
			return [524]
		0xf8:
			return [511]
		0xfb, 0xfc, 0xfd, 0xfe:
			if statistic_0 > 9:
				return [526, 513]

			if statistic_0 <= 3:
				return [526, 512]

			return [526]
		_:
			return []


static func _corner_name(mask: int) -> String:
	return QueryDetails._corner_name(mask)


static func resource_string_ids() -> PackedInt32Array:
	var unique := {}
	unique[CITY_HALL_ACTION_RESOURCE] = true
	unique[LIBRARY_ACTION_RESOURCE] = true

	for name_index in range(0, 154):
		unique[GENERAL_NAME_RESOURCE_BASE + name_index] = true

	for name_index in range(GENERAL_CLEAR_NAME_INDEX, GENERAL_SAILBOAT_NAME_INDEX + 1):
		unique[GENERAL_NAME_RESOURCE_BASE + name_index] = true

	for resource_id in range(
		STADIUM_SPORT_RESOURCE_BASE, STADIUM_SPORT_RESOURCE_BASE + 5
	):
		unique[resource_id] = true

	for resource_id in range(ANALYSIS_RESOURCE_BASE, ANALYSIS_RESOURCE_BASE + 12):
		unique[resource_id] = true

	for row in MICROSIM_RESOURCE_IDS:
		for resource_id in row:
			if resource_id >= 0:
				unique[resource_id] = true

	var result := PackedInt32Array()

	for resource_id in unique:
		result.append(int(resource_id))

	result.sort()

	return result


static func _specific_lines(
	city: CityState,
	microsim: Dictionary,
	microsim_type: int,
	resource_strings: Dictionary
) -> PackedStringArray:
	if resource_strings.is_empty():
		return PackedStringArray([
			"Rating: %d" % microsim.stat_0,
			"Value 1: %d" % microsim.stat_1,
			"Value 2: %d" % microsim.stat_2,
			"Value 3: %d" % microsim.stat_3,
		])

	if microsim_type < 0 or microsim_type >= MICROSIM_RESOURCE_IDS.size():
		return PackedStringArray()

	var result := PackedStringArray()

	for resource_id in MICROSIM_RESOURCE_IDS[microsim_type]:
		if resource_id < 0:
			continue

		if not resource_strings.has(resource_id):
			return _specific_lines(city, microsim, microsim_type, {})

		var template := str(resource_strings[resource_id])
		result.append(_expand_specific_template(city, microsim, template, resource_strings))

	return result


static func _expand_specific_template(
	city: CityState,
	microsim: Dictionary,
	template: String,
	resource_strings: Dictionary
) -> String:
	var grade_index := int(microsim.stat_0)
	var grade := str(grade_index)

	if grade_index >= 0 and grade_index < GRADE_NAMES.size():
		grade = GRADE_NAMES[grade_index]

	var sport_id := STADIUM_SPORT_RESOURCE_BASE + int(microsim.stat_2)
	var sport := str(microsim.stat_2)

	if resource_strings.has(sport_id):
		sport = str(resource_strings[sport_id])

	var wins_losses := ""

	if int(microsim.stat_0) != 0:
		wins_losses = "%d-%d" % [microsim.stat_0, 40 - int(microsim.stat_0)]

	return (
		template.replace("#0", str(microsim.stat_0))
		.replace("#1", str(microsim.stat_1))
		.replace("#2", str(microsim.stat_2))
		.replace("#3", str(microsim.stat_3))
		.replace("#G", grade)
		.replace("#S", sport)
		.replace("#T", city.label(int(microsim.stat_3)))
		.replace("#W", wins_losses)
	)


static func _traffic(
	city: CityState, values: PackedByteArray, point: Vector2i, building: int
) -> int:
	return QueryDetails._traffic(city, values, point, building)


static func _is_traffic_tile(building: int) -> bool:
	return QueryDetails._is_traffic_tile(building)


static func _is_highway_traffic_tile(building: int) -> bool:
	return QueryDetails._is_highway_traffic_tile(building)


static func _level_name(value: int) -> String:
	return QueryDetails._level_name(value)


static func _water_detail(city: CityState, point: Vector2i, building: int) -> String:
	return QueryDetails._water_detail(city, point, building)


static func _water_tower_storage(city: CityState, point: Vector2i) -> int:
	return QueryDetails._water_tower_storage(city, point)


static func _tile_description(
	city: CityState,
	point: Vector2i,
	building: int,
	resource_strings: Dictionary = {}
) -> String:
	var resource_id := general_name_resource_id(city, point, building)

	if resource_strings.has(resource_id):
		var original_name := str(resource_strings[resource_id]).strip_edges()

		if not original_name.is_empty():
			return original_name

	return _fallback_tile_description(city, point, building)


static func general_name_resource_id(
	city: CityState, point: Vector2i, building := -1
) -> int:
	if city == null or city.index_of(point.x, point.y) < 0:
		return -1

	if building < 0:
		building = city.building_id(point.x, point.y)

	var name_index := 0

	if building < 0x7c:
		for upper_bound_index in GENERAL_NAME_UPPER_BOUNDS.size():
			name_index = upper_bound_index

			if building < int(GENERAL_NAME_UPPER_BOUNDS[upper_bound_index]):
				break
	else:
		name_index = building - 0x66

	if building == 0:
		name_index = GENERAL_CLEAR_NAME_INDEX

		if city.is_water(point.x, point.y):
			name_index = (
				GENERAL_SALT_WATER_NAME_INDEX
				if city.is_salt_water(point.x, point.y)
				else GENERAL_FRESH_WATER_NAME_INDEX
			)
			var overlay := city.text_overlay_id(point.x, point.y)

			if OverlayData.is_thing(overlay):
				var thing := city.thing(OverlayData.thing_record(overlay))

				if int(thing.get("type", 0)) == 9:
					name_index = GENERAL_SAILBOAT_NAME_INDEX

	return GENERAL_NAME_RESOURCE_BASE + name_index


static func _fallback_tile_description(
	city: CityState, point: Vector2i, building: int
) -> String:
	if building == 0:
		if city.is_water(point.x, point.y):
			return "Salt water" if city.is_salt_water(point.x, point.y) else "Fresh water"

		return "Clear terrain"

	if building <= 4:
		return "Rubble"

	if building == 5:
		return "Radioactive waste"

	if building <= 12:
		return "Trees"

	if building == 13:
		return "Small park"

	if building <= 28:
		return "Power lines"

	if building <= 43:
		return "Road"

	if building <= 62:
		return "Railway"

	if building <= 66:
		return "Tunnel entrance"

	if building <= 72:
		return "Transport crossover"

	if building <= 80:
		return "Highway"

	if building <= 92:
		return "Bridge"

	if building <= 107:
		return "Highway"

	if building <= 111:
		return "Subway-to-rail connection"

	if building <= 123:
		return "Residential building"

	if building <= 131:
		return "Commercial building"

	if building <= 135:
		return "Industrial building"

	if building <= 139:
		return "Construction or abandoned building"

	if building <= 147:
		return "Residential building"

	if building <= 157:
		return "Commercial building"

	if building <= 165:
		return "Industrial building"

	if building <= 173:
		return "Construction or abandoned building"

	if building <= 177:
		return "Residential building"

	if building <= 187:
		return "Commercial building"

	if building <= 193:
		return "Industrial building"

	if building <= 197:
		return "Construction or abandoned building"

	if building <= 207:
		return "Power plant"

	if building <= 219:
		return "City service"

	if building == WATER_PUMP:
		return "Water pump"

	if building == WATER_TOWER:
		return "Water tower"

	if building <= 250:
		return "City infrastructure"

	if building <= 254:
		return "Arcology"

	return "Civic landmark"
