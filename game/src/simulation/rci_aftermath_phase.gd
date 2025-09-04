class_name RciAftermathPhase
extends RefCounted

const ToolAvailability = preload("res://src/tools/tool_availability.gd")
const NewsQueue = preload("res://src/simulation/news_queue.gd")

const MISC_SIZE := 4800
const MISC_START_YEAR := 0x000c
const MISC_WEATHER_HEAT := 0x0060
const MISC_WEATHER_WIND := 0x0064
const MISC_WEATHER_RAIN := 0x0068
const MISC_WEATHER_TREND := 0x006c
const MISC_INVENTION_YEARS := 0x0738
const MISC_TILE_COUNTS := 0x01f0
const MISC_UNEMPLOYMENT := 0x0fa4
const MISC_MILITARY_TILE_COUNTS := 0x0fa8
const MISC_STADIUM_TEAMS := 0x1028

const RADIOACTIVITY_TILE := 0x05
const FIRST_TREE_TILE := 0x06
const LAST_GROWING_TREE_TILE := 0x0b
const LAST_TREE_TILE := 0x0d
const STADIUM_TILE := 0xd7
const INVENTION_COUNT := 17

const NEWS_JUNK := 0x01
const NEWS_INVENTION := 0x04
const NEWS_INNOVATION := 0x05
const NEWS_WAR := 0x06
const NEWS_MARKET := 0x07
const NEWS_SPORTS := 0x08
const NEWS_HIGH_CRIME := 0x10
const NEWS_HIGH_TRAFFIC := 0x11
const NEWS_HIGH_POLLUTION := 0x12
const NEWS_POOR_EDUCATION := 0x13
const NEWS_POOR_HEALTH := 0x14
const NEWS_POOR_EMPLOYMENT := 0x15
const NEWS_LOW_CRIME := 0x3d
const NEWS_LOW_TRAFFIC := 0x3e
const NEWS_LOW_POLLUTION := 0x3f
const NEWS_GOOD_EDUCATION := 0x40
const NEWS_GOOD_HEALTH := 0x41
const NEWS_GOOD_EMPLOYMENT := 0x42

const GRAPH_TRAFFIC := 4
const GRAPH_POLLUTION := 5
const GRAPH_CRIME := 7

const WEATHER_NAMES := [
	"Cold", "Clear", "Hot", "Foggy", "Chilly", "Overcast",
	"Snow", "Rain", "Windy", "Blizzard", "Hurricane", "Tornado",
]

# four 12-by-8 season blocks. each row is the current weather trend and each
# column is the low three bits of the process-random value
const WEATHER_TRANSITIONS := [
	# season 0
	0, 0, 0, 3, 4, 5, 1, 8, 1, 1, 1, 0, 0, 3, 4, 8,
	2, 1, 1, 1, 8, 8, 5, 3, 3, 3, 0, 1, 4, 5, 8, 7,
	4, 4, 0, 1, 4, 5, 7, 6, 5, 5, 1, 4, 3, 7, 7, 8,
	6, 6, 7, 7, 5, 4, 0, 9, 7, 7, 7, 6, 8, 8, 4, 3,
	8, 8, 8, 7, 7, 5, 4, 4, 9, 6, 6, 6, 6, 7, 7, 3,
	7, 7, 6, 6, 7, 7, 7, 8, 8, 8, 8, 8, 8, 7, 6, 4,
	# season 1
	0, 0, 0, 1, 1, 1, 3, 4, 1, 1, 1, 1, 2, 2, 0, 4,
	2, 2, 2, 1, 1, 5, 4, 3, 3, 3, 0, 8, 1, 1, 4, 7,
	4, 4, 4, 1, 8, 0, 5, 3, 5, 5, 5, 7, 2, 4, 1, 8,
	6, 7, 7, 7, 3, 8, 5, 5, 7, 7, 7, 6, 3, 5, 8, 10,
	8, 8, 8, 7, 5, 4, 1, 1, 7, 6, 6, 7, 7, 8, 8, 4,
	10, 7, 7, 7, 8, 8, 4, 4, 8, 8, 8, 8, 8, 4, 1, 2,
	# season 2
	0, 0, 0, 1, 1, 1, 3, 4, 1, 1, 1, 1, 2, 2, 0, 4,
	2, 2, 2, 1, 1, 5, 4, 3, 3, 3, 0, 8, 1, 1, 4, 7,
	4, 4, 4, 1, 8, 0, 5, 3, 5, 5, 5, 7, 2, 4, 1, 8,
	6, 7, 7, 7, 3, 8, 5, 4, 7, 7, 7, 6, 3, 5, 8, 8,
	8, 8, 8, 7, 5, 4, 1, 11, 7, 6, 6, 7, 7, 8, 8, 4,
	6, 7, 7, 7, 8, 8, 4, 4, 11, 8, 8, 8, 8, 4, 1, 2,
	# season 3
	0, 0, 0, 3, 4, 5, 1, 8, 1, 1, 1, 0, 0, 3, 4, 8,
	2, 1, 1, 1, 8, 8, 5, 3, 3, 3, 0, 1, 4, 5, 8, 7,
	4, 4, 0, 1, 4, 5, 7, 6, 5, 5, 1, 4, 3, 7, 7, 8,
	6, 6, 7, 7, 5, 4, 0, 0, 7, 7, 7, 6, 8, 4, 3, 10,
	8, 8, 8, 7, 7, 5, 4, 5, 6, 6, 6, 6, 7, 7, 7, 3,
	10, 7, 6, 6, 7, 7, 7, 8, 8, 8, 8, 8, 8, 7, 6, 4,
]

const WEATHER_HEAT_TARGETS := [80, 165, 210, 100, 145, 175, 80, 150, 175, 60, 140, 175]
const WEATHER_WIND_TARGETS := [15, 30, 0, 0, 15, 5, 10, 30, 60, 100, 100, 100]
const WEATHER_RAIN_TARGETS := [0, 0, 0, 15, 15, 15, 30, 30, 30, 60, 60, 60]

const MILITARY_TILE_COUNT_INDEX := {
	0xdd: 1, 0xde: 2, 0xef: 3, 0xf2: 4, 0xea: 5, 0xe3: 6,
	0xe4: 7, 0xe5: 8, 0xf1: 9, 0xe0: 10, 0xe2: 11, 0xe7: 12,
	0xe8: 13, 0xf6: 14, 0xf9: 15,
}


static func run(city: CityState, random, season: int) -> Dictionary:
	if city == null or not city.is_valid():
		return {"ok": false, "error": "city is invalid"}
	if random == null or not random.has_method("next_u15"):
		return {"ok": false, "error": "a compatible process random generator is required"}
	if season < 0 or season > 3:
		return {"ok": false, "error": "weather season is out of range"}
	var misc_chunk := city.document.find_chunk("MISC")
	var building_chunk := city.document.find_chunk("XBLD")
	var zone_chunk := city.document.find_chunk("XZON")
	var flag_chunk := city.document.find_chunk("XBIT")
	var graph_chunk := city.document.find_chunk("XGRP")
	if misc_chunk == null or misc_chunk.decoded_payload.size() != MISC_SIZE:
		return {"ok": false, "error": "MISC is missing or has the wrong size"}
	if building_chunk == null or building_chunk.decoded_payload.size() != CityState.TILE_COUNT:
		return {"ok": false, "error": "XBLD is missing or has the wrong size"}
	if zone_chunk == null or zone_chunk.decoded_payload.size() != CityState.TILE_COUNT:
		return {"ok": false, "error": "XZON is missing or has the wrong size"}
	if flag_chunk == null or flag_chunk.decoded_payload.size() != CityState.TILE_COUNT:
		return {"ok": false, "error": "XBIT is missing or has the wrong size"}
	if graph_chunk == null or graph_chunk.decoded_payload.size() != 16 * 52 * 4:
		return {"ok": false, "error": "XGRP is missing or has the wrong size"}

	var old_misc: PackedByteArray = misc_chunk.decoded_payload.duplicate()
	var old_buildings: PackedByteArray = building_chunk.decoded_payload.duplicate()
	var misc := old_misc.duplicate()
	var buildings := old_buildings.duplicate()
	var zones: PackedByteArray = zone_chunk.decoded_payload
	var flags: PackedByteArray = flag_chunk.decoded_payload
	var graphs: PackedByteArray = graph_chunk.decoded_payload
	var map_changes: Array = []

	_update_random_tree(city, random, buildings, zones, flags, misc, map_changes)
	var queue_decay := NewsQueue.decay_and_sort(misc)
	if not queue_decay.ok:
		return queue_decay
	var news_items: Array = [{"type": NEWS_JUNK, "argument": 0}]
	_append_general_news(random, misc, graphs, news_items)
	var invention_index := _release_invention(city, random, misc, news_items)
	if invention_index >= 0:
		ToolAvailability.rebuild_reward_mask(misc)

	var old_trend := _read_u32(misc, MISC_WEATHER_TREND) & 0xff
	if old_trend >= WEATHER_NAMES.size():
		return {"ok": false, "error": "weather trend is out of range"}
	var weather_roll: int = random.next_u15() & 7
	var new_trend := weather_transition(old_trend, season, weather_roll)
	var old_heat := _read_u32(misc, MISC_WEATHER_HEAT) & 0xff
	var old_wind := _read_u32(misc, MISC_WEATHER_WIND) & 0xff
	var old_rain := _read_u32(misc, MISC_WEATHER_RAIN) & 0xff
	var new_heat := int((old_heat + WEATHER_HEAT_TARGETS[new_trend]) / 2)
	var new_wind := int((old_wind + WEATHER_WIND_TARGETS[new_trend]) / 2)
	var new_rain := int((old_rain + WEATHER_RAIN_TARGETS[new_trend]) / 2)
	_write_u32(misc, MISC_WEATHER_HEAT, new_heat)
	_write_u32(misc, MISC_WEATHER_WIND, new_wind)
	_write_u32(misc, MISC_WEATHER_RAIN, new_rain)
	_write_u32(misc, MISC_WEATHER_TREND, new_trend)
	var queue_insert := NewsQueue.insert_items(misc, news_items)
	if not queue_insert.ok:
		return queue_insert

	if not building_chunk.set_decoded_payload(buildings):
		return {"ok": false, "error": "cannot store the monthly tree update"}
	if not misc_chunk.set_decoded_payload(misc):
		building_chunk.set_decoded_payload(old_buildings)
		city.buildings = old_buildings
		return {"ok": false, "error": "cannot store the monthly RCI side effects"}
	city.buildings = buildings.duplicate()

	return {
		"ok": true,
		"error": "",
		"season": season,
		"old_weather_trend": old_trend,
		"weather_trend": new_trend,
		"weather_name": WEATHER_NAMES[new_trend],
		"weather_roll": weather_roll,
		"heat": new_heat,
		"wind": new_wind,
		"rain": new_rain,
		"map_changes": map_changes,
		"map_changed": not map_changes.is_empty(),
		"invention_index": invention_index,
		"news_items": news_items,
		"news_queue_updated": true,
	}


static func weather_transition(current_trend: int, season: int, roll: int) -> int:
	if current_trend < 0 or current_trend >= 12 or season < 0 or season >= 4:
		return -1
	return WEATHER_TRANSITIONS[(season * 12 + current_trend) * 8 + (roll & 7)]


static func _update_random_tree(
	city: CityState,
	random,
	buildings: PackedByteArray,
	zones: PackedByteArray,
	flags: PackedByteArray,
	misc: PackedByteArray,
	map_changes: Array
) -> void:
	var point := Vector2i(random.next_u15() & 0x7f, random.next_u15() & 0x7f)
	var index := point.x * CityState.MAP_SIZE + point.y
	var old_tile := int(buildings[index])
	if old_tile == RADIOACTIVITY_TILE and (random.next_u15() & 0x0f) == 0:
		_replace_building(buildings, zones, misc, index, 0)
		map_changes.append({"point": point, "old_tile": old_tile, "new_tile": 0})
	if flags[index] & 0x04 != 0:
		return
	if not (old_tile >= FIRST_TREE_TILE and old_tile <= LAST_TREE_TILE):
		if (random.next_u15() & 0x0f) != 0:
			return
	if old_tile >= FIRST_TREE_TILE and old_tile <= LAST_GROWING_TREE_TILE:
		_replace_building(buildings, zones, misc, index, old_tile + 1)
		map_changes.append({"point": point, "old_tile": old_tile, "new_tile": old_tile + 1})

	match random.next_u15() & 3:
		0:
			point.x = mini(point.x + 1, CityState.MAP_SIZE - 1)
		1:
			point.x = maxi(point.x - 1, 0)
		2:
			point.y = mini(point.y + 1, CityState.MAP_SIZE - 1)
		3:
			point.y = maxi(point.y - 1, 0)
	index = point.x * CityState.MAP_SIZE + point.y
	old_tile = int(buildings[index])
	if flags[index] & 0x04 != 0 or old_tile >= 0x0c or old_tile == RADIOACTIVITY_TILE:
		return
	var new_tile := FIRST_TREE_TILE if old_tile < FIRST_TREE_TILE else old_tile + 1
	_replace_building(buildings, zones, misc, index, new_tile)
	map_changes.append({"point": point, "old_tile": old_tile, "new_tile": new_tile})


static func _append_general_news(
	random, misc: PackedByteArray, graphs: PackedByteArray, news_items: Array
) -> void:
	match random.next_u15() % 6:
		0:
			if (random.next_u15() & 3) == 0:
				news_items.append({"type": NEWS_WAR, "argument": 0})
			if (random.next_u15() & 3) == 0:
				news_items.append({
					"type": NEWS_MARKET,
					"argument": _read_u32(misc, 0x005c) & 0xffff,
				})
		1:
			news_items.append({"type": 0x0b, "argument": 0})
		2:
			news_items.append({"type": 0x0c, "argument": 0})
		3:
			news_items.append({"type": 0x0d, "argument": 0})
		4:
			news_items.append({"type": 0x0e, "argument": 0})
		5:
			news_items.append({"type": 0x0f, "argument": 0})

	if _to_i16(_read_u32(misc, MISC_TILE_COUNTS + STADIUM_TILE * 4)) > 0:
		var team: int = random.next_u15() % 5
		if _to_i16(_read_u32(misc, MISC_STADIUM_TEAMS)) & (1 << team):
			news_items.append({"type": NEWS_SPORTS, "argument": team})

	_append_graph_news(random, graphs, GRAPH_TRAFFIC, NEWS_HIGH_TRAFFIC, NEWS_LOW_TRAFFIC, news_items)
	_append_graph_news(random, graphs, GRAPH_POLLUTION, NEWS_HIGH_POLLUTION, NEWS_LOW_POLLUTION, news_items)
	_append_graph_news(random, graphs, GRAPH_CRIME, NEWS_HIGH_CRIME, NEWS_LOW_CRIME, news_items)

	var unemployment := _read_i32(misc, MISC_UNEMPLOYMENT)
	if (random.next_u15() & 0x3f) < unemployment:
		news_items.append({"type": NEWS_POOR_EMPLOYMENT, "argument": 0})
	if unemployment < (random.next_u15() & 3):
		news_items.append({"type": NEWS_GOOD_EMPLOYMENT, "argument": 0})

	var education := _read_u32(misc, 0x004c)
	var education_roll: int = random.next_u15() % 80
	if education < 80:
		if education < education_roll:
			news_items.append({"type": NEWS_POOR_EDUCATION, "argument": 0})
	elif education_roll < education - 80:
		news_items.append({"type": NEWS_GOOD_EDUCATION, "argument": 0})

	var health := _read_u32(misc, 0x0048)
	var health_roll: int = random.next_u15() % 60
	if health < 60:
		if health < health_roll:
			news_items.append({"type": NEWS_POOR_HEALTH, "argument": 0})
	elif health_roll < health - 60:
		news_items.append({"type": NEWS_GOOD_HEALTH, "argument": 0})


static func _append_graph_news(
	random,
	graphs: PackedByteArray,
	series: int,
	high_type: int,
	low_type: int,
	news_items: Array
) -> void:
	var value := _read_i32(graphs, series * 52 * 4)
	if (random.next_u15() & 0x7f) < value:
		news_items.append({"type": high_type, "argument": 0})
	if value < (random.next_u15() & 0x0f):
		news_items.append({"type": low_type, "argument": 0})


static func _release_invention(
	city: CityState, random, misc: PackedByteArray, news_items: Array
) -> int:
	if (random.next_u15() & 7) != 0:
		return -1
	var current_year := _to_i16(_read_u32(misc, MISC_START_YEAR)) + int(city.age_in_days() / 300)
	for index in INVENTION_COUNT:
		var offset := MISC_INVENTION_YEARS + index * 4
		var invention_year := _to_i16(_read_u32(misc, offset))
		if invention_year == 0 or invention_year > current_year:
			continue
		var news_type := NEWS_INVENTION if index < 7 else NEWS_INNOVATION
		var argument := index if index < 7 else index - 7
		news_items.append({"type": news_type, "argument": argument})
		_write_u32(misc, offset, 0)
		return index
	return -1


static func _replace_building(
	buildings: PackedByteArray,
	zones: PackedByteArray,
	misc: PackedByteArray,
	index: int,
	new_tile: int
) -> void:
	var old_tile := int(buildings[index])
	if old_tile == new_tile:
		return
	var military := (zones[index] & 0x0f) == 7
	var old_offset := _tile_count_offset(old_tile, military)
	var new_offset := _tile_count_offset(new_tile, military)
	_write_u32(misc, old_offset, (_read_u32(misc, old_offset) - 1) & 0xffff)
	_write_u32(misc, new_offset, (_read_u32(misc, new_offset) + 1) & 0xffff)
	buildings[index] = new_tile


static func _tile_count_offset(tile: int, military: bool) -> int:
	if not military:
		return MISC_TILE_COUNTS + tile * 4
	return MISC_MILITARY_TILE_COUNTS + int(MILITARY_TILE_COUNT_INDEX.get(tile, 0)) * 4


static func _to_i16(value: int) -> int:
	var word := value & 0xffff
	return word - 0x10000 if word & 0x8000 else word


static func _read_i32(data: PackedByteArray, offset: int) -> int:
	var value := _read_u32(data, offset)
	return value - 0x100000000 if value & 0x80000000 else value


static func _read_u32(data: PackedByteArray, offset: int) -> int:
	return (
		(data[offset] << 24)
		| (data[offset + 1] << 16)
		| (data[offset + 2] << 8)
		| data[offset + 3]
	)


static func _write_u32(data: PackedByteArray, offset: int, value: int) -> void:
	var encoded := value & 0xffffffff
	data[offset] = (encoded >> 24) & 0xff
	data[offset + 1] = (encoded >> 16) & 0xff
	data[offset + 2] = (encoded >> 8) & 0xff
	data[offset + 3] = encoded & 0xff
