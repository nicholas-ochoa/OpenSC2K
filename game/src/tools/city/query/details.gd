class_name QueryDetails
extends QueryConstants


@warning_ignore_start("integer_division")


static func _advanced_details(
	city: CityState, point: Vector2i, microsim_id := -1
) -> Dictionary:
	var map_edge: int = city.map_size if city != null else 128
	var index := city.index_of(point.x, point.y)
	var detail_index := CityDataGrid.index(city.document.find_chunk("XVAL").decoded_payload, map_edge, point.x, point.y)
	var overlay_id := city.text_overlay_id(point.x, point.y)

	if (
		microsim_id < 0
		and OverlayData.is_facility(overlay_id)
	):
		microsim_id = OverlayData.facility_record(overlay_id)

	var flags := int(city.tile_flags[index])
	var flag_names := PackedStringArray()

	for entry in FLAG_LABELS:
		if flags & int(entry[0]):
			flag_names.append(str(entry[1]))

	var underground_id := city.underground_id(point.x, point.y)
	var underground_name := "Unknown"

	if underground_id >= 0 and underground_id < UNDERGROUND_NAMES.size():
		underground_name = UNDERGROUND_NAMES[underground_id]

	var zone_raw := int(city.zones[index])
	var result := {
		"tile_id": city.building_id(point.x, point.y),
		"zone_id": zone_raw & 0x0f,
		"altitude_raw": int(city.altitude_words[index]),
		"land_value_raw": int(city.document.find_chunk("XVAL").decoded_payload[detail_index]),
		"crime_raw": int(city.document.find_chunk("XCRM").decoded_payload[detail_index]),
		"pollution_raw": int(city.document.find_chunk("XPLT").decoded_payload[detail_index]),
		"zone_raw": zone_raw,
		"corner_name": _corner_name(zone_raw & 0xf0),
		"flags_raw": flags,
		"flag_names": flag_names,
		"underground_id": underground_id,
		"underground_name": underground_name,
		"microsim_id": microsim_id,
		"things": _things_at(city, point),
	}

	if microsim_id >= 0:
		result["microsim"] = city.microsim(microsim_id)
		result["microsim_label"] = city.label(overlay_id)

	return result


static func _things_at(city: CityState, point: Vector2i) -> Array[Dictionary]:
	var result: Array[Dictionary] = []

	for record in range(1, city.thing_count()):
		var thing := city.thing(record)

		if thing == null or thing.type == 0 or thing.x != point.x or thing.y != point.y:
			continue

		var thing_type := thing.type
		var direction := thing.direction
		# the query dialog reads the stored fields plus these presentation keys
		var entry := thing.to_dictionary()
		entry["record"] = record
		entry["type_name"] = (
			THING_NAMES[thing_type]
			if thing_type >= 0 and thing_type < THING_NAMES.size()
			else "Unknown"
		)
		entry["direction_name"] = (
			DIRECTION_NAMES[direction]
			if direction >= 0 and direction < DIRECTION_NAMES.size()
			else "Unknown"
		)
		var visual := Presentation.thing_sprite(city, point, thing, record)
		entry["sprite_id"] = int(visual.get("sprite_id", -1))
		entry["sprite_flip"] = bool(visual.get("flip", false))
		result.append(entry)

	return result


static func _corner_name(mask: int) -> String:
	match mask:
		0x10:
			return "Bottom-left corner"
		0x20:
			return "Bottom-right corner"
		0x40:
			return "Top-left corner"
		0x80:
			return "Top-right corner"
		0xf0:
			return "All four corners"
		_:
			return "No corners"


static func traffic(
	city: CityState, values: PackedByteArray, point: Vector2i, building: int
) -> int:
	var map_edge: int = city.map_size if city != null else 128

	if not _is_traffic_tile(building):
		return 0

	if values.size() == map_edge * map_edge:
		var value := int(values[point.x * map_edge + point.y])

		return value if _is_highway_traffic_tile(building) else (value / 2)

	var total := 0

	for neighbor in [
		Vector2i(point.x - 1, point.y),
		Vector2i(point.x, point.y - 1),
		Vector2i(point.x + 1, point.y),
		Vector2i(point.x, point.y + 1),
	]:
		if city.index_of(neighbor.x, neighbor.y) < 0:
			continue

		var index := CityDataGrid.index(values, map_edge, neighbor.x, neighbor.y)
		total += values[index]

	if _is_highway_traffic_tile(building):
		total *= 2

	return int(total / 8)


static func _is_traffic_tile(building: int) -> bool:
	return (
		(building >= 0x1d and building <= 0x2b)
		or (building >= 0x3f and building <= 0x42)
		or (building >= 0x4b and building <= 0x5b)
		or (building >= 0x5d and building <= 0x6b)
	)


static func _is_highway_traffic_tile(building: int) -> bool:
	return (building >= 0x49 and building <= 0x50) or (
		building >= 0x61 and building <= 0x6b
	)


static func level_name(value: int) -> String:
	if value <= 1:
		return "None"

	if value <= 60:
		return "Low"

	if value <= 120:
		return "Medium"

	if value <= 180:
		return "High"

	return "Very High"


static func _water_detail(city: CityState, point: Vector2i, building: int) -> String:
	var map_edge: int = city.map_size if city != null else 128

	if building == WATER_PUMP:
		var supply := 0

		if city.is_powered(point.x, point.y):
			supply = city.document.misc_u32(0x0e40) * 5
			supply += int((city.document.misc_u32(0x68) & 0xff) / 2)

			for x in range(maxi(point.x - 1, 0), mini(point.x + 2, map_edge)):
				for y in range(maxi(point.y - 1, 0), mini(point.y + 2, map_edge)):
					if city.is_water(x, y) and not city.is_salt_water(x, y):
						supply += 10

		return "Water: %d gallons per month" % (supply * 720)

	if building == WATER_TOWER:
		return "Water: %d stored gallons" % _water_tower_storage(city, point)

	return ""


static func _water_tower_storage(city: CityState, point: Vector2i) -> int:
	for origin_x in range(point.x - 1, point.x + 1):
		for origin_y in range(point.y, point.y + 2):
			var tiles := [
				Vector2i(origin_x, origin_y),
				Vector2i(origin_x + 1, origin_y),
				Vector2i(origin_x, origin_y - 1),
				Vector2i(origin_x + 1, origin_y - 1),
			]
			var complete := true

			for tile in tiles:
				if city.building_id(tile.x, tile.y) != WATER_TOWER:
					complete = false
					break

			if not complete:
				continue

			var watered_tiles := 0

			for tile in tiles:
				if city.is_watered(tile.x, tile.y):
					watered_tiles += 1

			return watered_tiles * 10000

	return 10000 if city.is_watered(point.x, point.y) else 0
