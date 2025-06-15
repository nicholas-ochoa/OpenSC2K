class_name QueryInfo
extends RefCounted

const FULL_MAP_SIZE := CityState.MAP_SIZE
const DETAIL_MAP_SIZE := 64
const FIRST_MICROSIM_LABEL := 51
const LAST_MICROSIM_LABEL := 200
const FIRST_BUILDING_WITH_UTILITIES := 13
const MILITARY_ZONE := 7
const WATER_PUMP := 0xdc
const WATER_TOWER := 0xeb

const ZONE_NAMES := [
	"Unzoned",
	"Residential",
	"Residential",
	"Commercial",
	"Commercial",
	"Industrial",
	"Industrial",
	"Military",
	"Airport",
	"Seaport",
]

const ZONE_DENSITIES := [
	"",
	"low-density",
	"high-density",
	"low-density",
	"high-density",
	"low-density",
	"high-density",
	"",
	"",
	"",
]


static func inspect(city: CityState, point: Vector2i) -> Dictionary:
	if city == null or not city.is_valid():
		return {"ok": false, "error": "city is invalid"}
	if city.index_of(point.x, point.y) < 0:
		return {"ok": false, "error": "query position is outside the city"}
	for checked in [
		["XTRF", DETAIL_MAP_SIZE * DETAIL_MAP_SIZE],
		["XPLT", DETAIL_MAP_SIZE * DETAIL_MAP_SIZE],
		["XVAL", DETAIL_MAP_SIZE * DETAIL_MAP_SIZE],
		["XCRM", DETAIL_MAP_SIZE * DETAIL_MAP_SIZE],
	]:
		var chunk := city.document.find_chunk(checked[0])
		if chunk == null or chunk.decoded_payload.size() != checked[1]:
			return {"ok": false, "error": "%s data is missing or invalid" % checked[0]}

	var overlay := city.text_overlay_id(point.x, point.y)
	if overlay >= FIRST_MICROSIM_LABEL and overlay <= LAST_MICROSIM_LABEL:
		var microsim := city.microsim(overlay - FIRST_MICROSIM_LABEL)
		if not microsim.is_empty() and microsim.tile_id != 0:
			return {
				"ok": true,
				"kind": "specific",
				"point": point,
				"title": city.label(overlay),
				"overlay_id": overlay,
				"microsim_id": overlay - FIRST_MICROSIM_LABEL,
				"microsim": microsim,
				"error": "",
			}

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

	var detail_index := int(point.x / 2) * DETAIL_MAP_SIZE + int(point.y / 2)
	var traffic_chunk := city.document.find_chunk("XTRF")
	var pollution_chunk := city.document.find_chunk("XPLT")
	var land_value_chunk := city.document.find_chunk("XVAL")
	var crime_chunk := city.document.find_chunk("XCRM")
	var result := {
		"ok": true,
		"kind": "general",
		"point": point,
		"title": _tile_description(city, point, building),
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
		"error": "",
	}
	return result


static func format_text(info: Dictionary) -> String:
	if not info.get("ok", false):
		return "Query failed: %s" % info.get("error", "unknown error")
	var point: Vector2i = info.point
	if info.kind == "specific":
		var microsim: Dictionary = info.microsim
		var title: String = info.title
		if title.is_empty():
			title = "City facility"
		return (
			"%s\nTile: %d, %d\n\nRating: %d\nValue 1: %d\nValue 2: %d\nValue 3: %d"
			% [
				title,
				point.x,
				point.y,
				microsim.stat_0,
				microsim.stat_1,
				microsim.stat_2,
				microsim.stat_3,
			]
		)

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
	return "\n".join(lines)


static func _traffic(
	city: CityState, values: PackedByteArray, point: Vector2i, building: int
) -> int:
	if not _is_traffic_tile(building):
		return 0
	var total := 0
	for neighbor in [
		Vector2i(point.x - 1, point.y),
		Vector2i(point.x, point.y - 1),
		Vector2i(point.x + 1, point.y),
		Vector2i(point.x, point.y + 1),
	]:
		if city.index_of(neighbor.x, neighbor.y) < 0:
			continue
		var index := int(neighbor.x / 2) * DETAIL_MAP_SIZE + int(neighbor.y / 2)
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


static func _level_name(value: int) -> String:
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
	if building == WATER_PUMP:
		var supply := 0
		if city.is_powered(point.x, point.y):
			supply = city.document.misc_u32(0x0e40) * 5
			supply += int((city.document.misc_u32(0x68) & 0xff) / 2)
			for x in range(maxi(point.x - 1, 0), mini(point.x + 2, FULL_MAP_SIZE)):
				for y in range(maxi(point.y - 1, 0), mini(point.y + 2, FULL_MAP_SIZE)):
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


static func _tile_description(city: CityState, point: Vector2i, building: int) -> String:
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
