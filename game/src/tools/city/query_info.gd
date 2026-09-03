class_name QueryInfo
extends QueryConstants


@warning_ignore_start("integer_division")


static func inspect(
	city: CityState, point: Vector2i, resource_strings: Dictionary = {}
) -> Dictionary:
	var map_edge: int = city.map_size if city != null else 128

	if city == null or not city.is_valid():
		return {"ok": false, "error": "city is invalid"}

	if city.index_of(point.x, point.y) < 0:
		return {"ok": false, "error": "query position is outside the city"}

	for checked in [
		["XTRF", (map_edge / 2) * (map_edge / 2)],
		["XPLT", (map_edge / 2) * (map_edge / 2)],
		["XVAL", (map_edge / 2) * (map_edge / 2)],
		["XCRM", (map_edge / 2) * (map_edge / 2)],
	]:
		var chunk := city.document.find_chunk(checked[0])

		if chunk == null or chunk.decoded_payload.size() != city.document.decoded_size(str(checked[0])):
			return {"ok": false, "error": "%s data is missing or invalid" % checked[0]}

	var overlay := city.text_overlay_id(point.x, point.y)

	if OverlayData.is_facility(overlay):
		var microsim := city.microsim(OverlayData.facility_record(overlay))

		if microsim != null and microsim.tile_id != 0:
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
		"traffic": QueryDetails.traffic(city, traffic_chunk.decoded_payload, point, building),
		"altitude_feet": altitude_feet,
		"altitude_is_depth": altitude_is_depth,
		"shows_land_value": not wet_tile or land_altitude < water_level,
		"land_value": int(land_value_chunk.decoded_payload[detail_index]) + 1,
		"crime": int(crime_chunk.decoded_payload[detail_index]),
		"crime_level": QueryDetails.level_name(crime_chunk.decoded_payload[detail_index]),
		"pollution": int(pollution_chunk.decoded_payload[detail_index]),
		"pollution_level": QueryDetails.level_name(pollution_chunk.decoded_payload[detail_index]),
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
