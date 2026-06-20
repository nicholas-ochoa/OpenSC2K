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
				"lines": QueryText._specific_lines(
					city, microsim, microsim_type, resource_strings
				),
				"action": action,
				"action_resource_id": action_resource_id,
				"sound_events": QueryText.specific_sound_events(
					int(microsim.tile_id), int(microsim.stat_0)
				),
				"error": "",
			}
			specific.merge(QueryDetails._advanced_details(
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
		"title": QueryText._tile_description(city, point, building, resource_strings),
		"building_id": building,
		"terrain_id": terrain,
		"zone_id": zone,
		"zone_name": ZONE_NAMES[zone] if zone < ZONE_NAMES.size() else "Unknown zone",
		"zone_density": ZONE_DENSITIES[zone] if zone < ZONE_DENSITIES.size() else "",
		"shows_traffic": QueryDetails._is_traffic_tile(building),
		"traffic": QueryDetails._traffic(city, traffic_chunk.decoded_payload, point, building),
		"altitude_feet": altitude_feet,
		"altitude_is_depth": altitude_is_depth,
		"shows_land_value": not wet_tile or land_altitude < water_level,
		"land_value": int(land_value_chunk.decoded_payload[detail_index]) + 1,
		"crime": int(crime_chunk.decoded_payload[detail_index]),
		"crime_level": QueryDetails._level_name(crime_chunk.decoded_payload[detail_index]),
		"pollution": int(pollution_chunk.decoded_payload[detail_index]),
		"pollution_level": QueryDetails._level_name(pollution_chunk.decoded_payload[detail_index]),
		"shows_utilities": (
			building >= FIRST_BUILDING_WITH_UTILITIES and zone != MILITARY_ZONE and not wet_tile
		),
		"powered": city.is_powered(point.x, point.y),
		"watered": city.is_watered(point.x, point.y),
		"water_detail": QueryDetails._water_detail(city, point, building),
		"overlay_id": overlay,
		"sound_events": [],
		"error": "",
	}
	result.merge(QueryDetails._advanced_details(city, point))
	result["sprite_id"] = Presentation.sprite_id(city, result)

	return result


static func format_text(info: Dictionary) -> String:
	return QueryText.format_text(info)


static func _advanced_details(
	city: CityState, point: Vector2i, microsim_id := -1
) -> Dictionary:
	return QueryDetails._advanced_details(city, point, microsim_id)


static func _advanced_lines(info: Dictionary) -> PackedStringArray:
	return QueryText._advanced_lines(info)


static func _things_at(city: CityState, point: Vector2i) -> Array[Dictionary]:
	return QueryDetails._things_at(city, point)


static func specific_sound_events(tile_id: int, statistic_0: int) -> Array[int]:
	return QueryText.specific_sound_events(tile_id, statistic_0)


static func _corner_name(mask: int) -> String:
	return QueryDetails._corner_name(mask)


static func resource_string_ids() -> PackedInt32Array:
	return QueryText.resource_string_ids()


static func _specific_lines(
	city: CityState,
	microsim: Dictionary,
	microsim_type: int,
	resource_strings: Dictionary
) -> PackedStringArray:
	return QueryText._specific_lines(city, microsim, microsim_type, resource_strings)


static func _expand_specific_template(
	city: CityState,
	microsim: Dictionary,
	template: String,
	resource_strings: Dictionary
) -> String:
	return QueryText._expand_specific_template(city, microsim, template, resource_strings)


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
	return QueryText._tile_description(city, point, building, resource_strings)


static func general_name_resource_id(
	city: CityState, point: Vector2i, building := -1
) -> int:
	return QueryText.general_name_resource_id(city, point, building)


static func _fallback_tile_description(
	city: CityState, point: Vector2i, building: int
) -> String:
	return QueryText._fallback_tile_description(city, point, building)
