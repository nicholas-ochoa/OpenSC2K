class_name QueryText
extends QueryConstants



static func format_text(info: QueryResult) -> String:
	if not info.ok:
		return "Query failed: %s" % info.error

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


static func _advanced_lines(info: QueryResult) -> PackedStringArray:
	var point: Vector2i = info.point
	var flag_names: PackedStringArray = info.flag_names
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
	var microsim_id := int(info.microsim_id)

	if microsim_id < 0:
		result.append("Microsim ID: None")
	else:
		var microsim: CityRecords.Microsim = info.microsim
		var microsim_label := str(info.microsim_label)

		if not microsim_label.is_empty():
			result.append("Microsim name: %s" % microsim_label)

		result.append("Microsim ID: %d / 0x%02X" % [microsim_id, microsim_id])

		if microsim == null:
			result.append("XMIC data: unavailable")
		else:
			result.append("Data 0: %d / 0x%02X" % [microsim.stat_0, microsim.stat_0])

			for data_index in range(1, 4):
				var value := microsim.statistic(data_index)
				result.append("Data %d: %d / 0x%04X" % [data_index, value, value])

	var things: Array = info.things

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


static func specific_sound_events(tile_id: int, statistic_0: int) -> Array[int]:
	match tile_id:
		Tiles.HYDRO_POWER_1, Tiles.HYDRO_POWER_2, Tiles.WIND_POWER, \
		Tiles.GAS_POWER, Tiles.OIL_POWER, Tiles.NUCLEAR_POWER, Tiles.SOLAR_POWER, \
		Tiles.MICROWAVE_POWER, Tiles.FUSION_POWER, Tiles.COAL_POWER:
			return [514]
		Tiles.CITY_HALL, Tiles.BIG_PARK, Tiles.STADIUM, Tiles.STATUE, Tiles.MAYOR_HOUSE, Tiles.LLAMA_DOME:
			return [513]
		Tiles.HOSPITAL, Tiles.POLICE_STATION:
			return [506]
		Tiles.FIRE_STATION:
			return [509]
		Tiles.SCHOOL, Tiles.COLLEGE:
			return [523]
		Tiles.PRISON:
			return [522]
		Tiles.ZOO:
			return [527]
		Tiles.BUS_DEPOT:
			return [521]
		Tiles.RAIL_STATION:
			return [524]
		Tiles.MARINA:
			return [511]
		Tiles.PLYMOUTH_ARCOLOGY, Tiles.FOREST_ARCOLOGY, Tiles.DARCO_ARCOLOGY, Tiles.LAUNCH_ARCOLOGY:
			if statistic_0 > 9:
				return [526, 513]

			if statistic_0 <= 3:
				return [526, 512]

			return [526]
		_:
			return []


static func _specific_lines(
	city: CityState, microsim: CityRecords.Microsim, microsim_type: int
) -> PackedStringArray:
	var result := PackedStringArray()

	if microsim_type < 0 or microsim_type >= QueryStrings.MICROSIM_LINES.size():
		return result

	for template: String in QueryStrings.MICROSIM_LINES[microsim_type]:
		result.append(expand_specific_template(city, microsim, template))

	return result


static func expand_specific_template(
	city: CityState, microsim: CityRecords.Microsim, template: String
) -> String:
	var grade_index := int(microsim.stat_0)
	var grade := str(grade_index)

	if grade_index >= 0 and grade_index < GRADE_NAMES.size():
		grade = GRADE_NAMES[grade_index]

	var sport_index := int(microsim.stat_2)
	var sport := str(sport_index)

	if sport_index >= 0 and sport_index < QueryStrings.SPORTS.size():
		sport = QueryStrings.SPORTS[sport_index]

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


static func tile_name(city: CityState, point: Vector2i, building := -1) -> String:
	if city == null or city.index_of(point.x, point.y) < 0:
		return ""

	if building < Tiles.EMPTY:
		building = city.building_id(point.x, point.y)

	if building == Tiles.EMPTY:
		if not city.is_water(point.x, point.y):
			return QueryStrings.CLEAR_TERRAIN

		var overlay := city.text_overlay_id(point.x, point.y)

		if OverlayData.is_thing(overlay):
			var thing := city.thing(OverlayData.thing_record(overlay))

			if thing != null and thing.type == 9:
				return QueryStrings.SAILBOAT

		return QueryStrings.SALT_WATER if city.is_salt_water(point.x, point.y) else QueryStrings.FRESH_WATER

	return QueryStrings.tile_name(building)
