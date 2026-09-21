class_name CityMinimap
extends RefCounted

@warning_ignore_start("integer_division")

const Tiles = preload("res://src/tools/shared/building_tile_ids.gd")

const MODES := [
	"structures",
	"zones",
	"roads",
	"rail",
	"traffic",
	"power",
	"water",
	"density",
	"growth",
	"crime",
	"police_power",
	"police_stations",
	"pollution",
	"land_value",
	"fire_power",
	"fire_stations",
	"schools",
	"colleges",
]

const ZONE_COLORS := [0, 59, 59, 92, 92, 50, 50, 0, 0, 0, 0, 0, 0, 0, 0, 0]
const POWER_LINE_FIRST := Tiles.POWER_LINE_STRAIGHT_1
const POWER_LINE_LAST := Tiles.POWER_LINE_CROSSROADS
const POLICE_STATION := Tiles.POLICE_STATION
const FIRE_STATION := Tiles.FIRE_STATION
const SCHOOL := Tiles.SCHOOL
const COLLEGE := Tiles.COLLEGE


static func create_image(city: CityState, palette: Sc2Palette, mode := "structures") -> Image:
	var map_edge: int = city.map_size if city != null else 128
	var image := Image.create(
		map_edge, map_edge, false, Image.FORMAT_RGBA8
	)

	if city == null or not city.is_valid() or palette == null or not palette.is_valid():
		return image

	for x in map_edge:
		for y in map_edge:
			image.set_pixel(x, y, palette.color(color_index(city, x, y, mode)))

	return image


static func color_index(city: CityState, x: int, y: int, mode := "structures") -> int:
	if city == null or not city.is_valid() or city.index_of(x, y) < 0:
		return 0

	var building := city.building_id(x, y)
	var base := _base_index(city, x, y, building)

	match mode:
		"structures":
			return base
		"zones":
			var zone := city.zone_id(x, y)

			return ZONE_COLORS[zone] if zone != 0 else base
		"roads":
			return 0xff if _is_road_map_tile(building) else base
		"rail":
			return 0xff if _is_rail_map_tile(building) else base
		"traffic":
			var traffic := _coarse_value(city, "XTRF", city.map_size / 2, 2, x, y) >> 4

			if traffic != 0:
				return traffic + 0x9b

			return 0xff if _is_traffic_network(building) else base
		"power":
			if _is_power_line(building):
				return 0xff

			if city.is_powered(x, y):
				return 0x32

			return 0x1d if city.is_powerable(x, y) else base
		"water":
			var underground := city.underground_id(x, y)

			if underground >= UndergroundTileIds.PIPE_LR and underground <= UndergroundTileIds.SUBWAY_ENTRANCE:
				return 0xff

			if city.is_watered(x, y):
				return 0x32

			return 0x1d if city.is_piped(x, y) else base
		"density":
			return _gradient_or_base(city, "XPOP", city.map_size / 4, 4, x, y, base)
		"growth":
			var growth := _coarse_value(city, "XROG", city.map_size / 4, 4, x, y)

			if growth < 0x7d:
				return 0x1d

			if growth >= 0x83:
				return 0x43

			return base
		"crime":
			return _gradient_or_base(city, "XCRM", city.map_size / 2, 2, x, y, base)
		"police_power":
			return _gradient_or_base(city, "XPLC", city.map_size / 4, 4, x, y, base)
		"police_stations":
			return 0xff if building == POLICE_STATION else base
		"pollution":
			return _gradient_or_base(city, "XPLT", city.map_size / 2, 2, x, y, base)
		"land_value":
			return _gradient_or_base(city, "XVAL", city.map_size / 2, 2, x, y, base)
		"fire_power":
			return _gradient_or_base(city, "XFIR", city.map_size / 4, 4, x, y, base)
		"fire_stations":
			return 0xff if building == FIRE_STATION else base
		"schools":
			return 0xff if building == SCHOOL else base
		"colleges":
			return 0xff if building == COLLEGE else base

	return base


static func _base_index(city: CityState, x: int, y: int, building: int) -> int:
	if building == Tiles.EMPTY:
		if city.is_water(x, y):
			return 0x62

		var altitude := mini(city.land_altitude(x, y), 0x10)

		return 0x80 - int((altitude * 3) / 4)

	if building < Tiles.TREES_1:
		return 0x35

	if building < Tiles.SMALL_PARK:
		return 0x43

	return 0


static func _gradient_or_base(
	city: CityState,
	chunk_id: String,
	map_size: int,
	scale: int,
	x: int,
	y: int,
	base: int
) -> int:
	var gradient := _coarse_value(city, chunk_id, map_size, scale, x, y) >> 4

	return gradient + 0x9b if gradient != 0 else base


static func _coarse_value(
	city: CityState, chunk_id: String, _map_size: int, _scale: int, x: int, y: int
) -> int:
	var chunk := city.document.find_chunk(chunk_id)

	if chunk == null or chunk.decoded_payload.size() != city.document.decoded_size(chunk_id):
		return 0

	var index := CityDataGrid.index(chunk.decoded_payload, city.map_size, x, y)

	return chunk.decoded_payload[index] if index >= 0 else 0


static func _is_road_map_tile(building: int) -> bool:
	return (
		(building >= Tiles.ROAD_STRAIGHT_1 and building <= Tiles.ROAD_CROSSROADS)
		or (building >= Tiles.TUNNEL_ENTRANCE_1 and building <= Tiles.ROAD_RAIL_CROSSING_2)
		or (building >= Tiles.HIGHWAY_STRAIGHT_1 and building <= Tiles.RAISING_BRIDGE_OPEN)
		or (building >= Tiles.HIGHWAY_ONRAMP_1 and building <= Tiles.REINFORCED_HIGHWAY_BRIDGE)
		or building == Tiles.HIGHWAY_ROAD_CROSSING_1
		or building == Tiles.HIGHWAY_ROAD_CROSSING_2
	)


static func _is_rail_map_tile(building: int) -> bool:
	return (
		(building >= Tiles.RAIL_STRAIGHT_1 and building <= Tiles.RAIL_SLOPE_8)
		or (building >= Tiles.ROAD_RAIL_CROSSING_1 and building <= Tiles.RAIL_POWER_CROSSING_2)
		or (building >= Tiles.RAIL_SUBWAY_ENTRANCE_1 and building <= Tiles.RAIL_SUBWAY_ENTRANCE_4)
		or building == Tiles.HIGHWAY_RAIL_CROSSING_1
		or building == Tiles.HIGHWAY_RAIL_CROSSING_2
		or building == Tiles.RAIL_BRIDGE
		or building == Tiles.RAIL_BRIDGE_PYLON
	)


static func _is_traffic_network(building: int) -> bool:
	return (
		(building >= Tiles.ROAD_STRAIGHT_1 and building <= Tiles.RAIL_SLOPE_8)
		or (building >= Tiles.TUNNEL_ENTRANCE_1 and building <= Tiles.RAIL_POWER_CROSSING_2)
		or (building >= Tiles.HIGHWAY_STRAIGHT_1 and building <= Tiles.HIGHWAY_POWER_CROSSING_2)
		or (building >= Tiles.HIGHWAY_ROAD_CROSSING_1 and building <= Tiles.HIGHWAY_RAIL_CROSSING_2)
		or (building >= Tiles.HIGHWAY_ONRAMP_1 and building <= Tiles.RAIL_SUBWAY_ENTRANCE_4)
	)


static func _is_power_line(building: int) -> bool:
	return (
		(building >= POWER_LINE_FIRST and building <= POWER_LINE_LAST)
		or building == Tiles.ROAD_POWER_CROSSING_1
		or building == Tiles.ROAD_POWER_CROSSING_2
		or building == Tiles.RAIL_POWER_CROSSING_1
		or building == Tiles.RAIL_POWER_CROSSING_2
		or building == Tiles.POWER_BRIDGE
	)
