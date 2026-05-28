class_name DisasterMapPhase
extends DisasterMapConstants



static func run_all(
	city: CityState, random, lfsr_random, map_counter: int, hurricane_counter := 0
) -> Dictionary:
	return DisasterMapScanDispatch.run_all(city, random, lfsr_random, map_counter, hurricane_counter)


static func run_fire(city: CityState, random, lfsr_random) -> Dictionary:
	return DisasterMapFireFlood.run_fire(city, random, lfsr_random)


static func run_flood(
	city: CityState, random, lfsr_random, map_counter: int
) -> Dictionary:
	return DisasterMapFireFlood.run_flood(city, random, lfsr_random, map_counter)


static func run_toxic(city: CityState, random, lfsr_random) -> Dictionary:
	return DisasterMapMarkers.run_toxic(city, random, lfsr_random)


static func run_riot(city: CityState, random, lfsr_random) -> Dictionary:
	return DisasterMapMarkers.run_riot(city, random, lfsr_random)


static func run_dispatch(city: CityState, random, lfsr_random) -> Dictionary:
	return DisasterMapScanDispatch.run_dispatch(city, random, lfsr_random)


static func _process_fire_cell(
	city: CityState,
	payloads: Dictionary,
	point: Vector2i,
	index: int,
	random,
	lfsr_random,
	counters: Dictionary,
	runtime_events: Dictionary,
) -> void:
	DisasterMapFireFlood._process_fire_cell(city, payloads, point, index, random, lfsr_random, counters, runtime_events)


static func _process_flood_cell(
	city: CityState,
	payloads: Dictionary,
	point: Vector2i,
	index: int,
	counter: int,
	random,
	lfsr_random,
	counters: Dictionary,
	runtime_events: Dictionary,
) -> void:
	DisasterMapFireFlood._process_flood_cell(
		city, payloads, point, index, counter, random, lfsr_random, counters, runtime_events
	)


static func _process_toxic_cell(
	city: CityState,
	payloads: Dictionary,
	point: Vector2i,
	index: int,
	random,
	lfsr_random,
	counters: Dictionary
) -> void:
	DisasterMapMarkers._process_toxic_cell(city, payloads, point, index, random, lfsr_random, counters)


static func _process_riot_cell(
	city: CityState,
	payloads: Dictionary,
	point: Vector2i,
	index: int,
	marker: int,
	random,
	lfsr_random,
	counters: Dictionary,
	runtime_events: Dictionary,
) -> void:
	DisasterMapMarkers._process_riot_cell(city, payloads, point, index, marker, random, lfsr_random, counters, runtime_events)


static func _process_dispatch_cell(
	city: CityState,
	payloads: Dictionary,
	point: Vector2i,
	overlay: int,
	random,
	lfsr_random,
	counters: Dictionary
) -> void:
	DisasterMapScanDispatch._process_dispatch_cell(city, payloads, point, overlay, random, lfsr_random, counters)


static func _apply_damage(
	city: CityState,
	payloads: Dictionary,
	point: Vector2i,
	random,
	lfsr_random,
	runtime_events: Dictionary = {},
) -> int:
	return DisasterMapFireFlood._apply_damage(city, payloads, point, random, lfsr_random, runtime_events)


static func _starts_fire(result_code: int) -> bool:
	return DisasterMapFireFlood._starts_fire(result_code)


static func _apply_flood_damage(
	city: CityState,
	payloads: Dictionary,
	point: Vector2i,
	maximum_altitude: int,
	random,
	lfsr_random,
	runtime_events: Dictionary = {},
) -> int:
	return DisasterMapFireFlood._apply_flood_damage(city, payloads, point, maximum_altitude, random, lfsr_random, runtime_events)


static func _collapse_structure(
	city: CityState,
	payloads: Dictionary,
	point: Vector2i,
	_tile: int,
	random,
	lfsr_random
) -> void:
	DisasterMapState._collapse_structure(city, payloads, point, _tile, random, lfsr_random)


static func _building_site(
	city: CityState, payloads: Dictionary, point: Vector2i, tile: int
) -> Rect2i:
	return DisasterMapState._building_site(city, payloads, point, tile)


static func _abandon_toxic_structure(
	city: CityState, payloads: Dictionary, point: Vector2i, random
) -> bool:
	return DisasterMapMarkers._abandon_toxic_structure(city, payloads, point, random)


static func _is_construction_or_abandoned(tile: int) -> bool:
	return DisasterMapMarkers._is_construction_or_abandoned(tile)


static func _lowest_toxic_direction(altitude: PackedByteArray, point: Vector2i, map_edge: int = 128) -> int:
	return DisasterMapMarkers._lowest_toxic_direction(altitude, point, map_edge)


static func _place_toxic_marker(text: PackedByteArray, point: Vector2i, map_edge: int = 128) -> bool:
	return DisasterMapState._place_toxic_marker(text, point, map_edge)


static func _riot_supports(buildings: PackedByteArray, point: Vector2i, map_edge: int = 128) -> bool:
	return DisasterMapMarkers._riot_supports(buildings, point, map_edge)


static func _place_riot_marker(
	text: PackedByteArray, point: Vector2i, marker: int,
	map_edge: int = 128,
) -> bool:
	return DisasterMapMarkers._place_riot_marker(text, point, marker, map_edge)


static func _extinguish_dispatch_fire(
	city: CityState, payloads: Dictionary, point: Vector2i, random, lfsr_random
) -> bool:
	return DisasterMapScanDispatch._extinguish_dispatch_fire(city, payloads, point, random, lfsr_random)


static func _clear_riot_marker(text: PackedByteArray, point: Vector2i, map_edge: int = 128) -> bool:
	return DisasterMapState._clear_riot_marker(text, point, map_edge)


static func _seed_special_toxic(
	payloads: Dictionary, site: Rect2i, point: Vector2i,
	map_edge: int = 128,
) -> int:
	return DisasterMapState._seed_special_toxic(payloads, site, point, map_edge)


static func _spawn_explosion(
	text: PackedByteArray,
	things: PackedByteArray,
	point: Vector2i,
	height: int,
	state: int,
	goal: int,
	map_edge: int = 128,
) -> bool:
	return DisasterMapState._spawn_explosion(text, things, point, height, state, goal, map_edge)


static func _map_payloads(city: CityState) -> Dictionary:
	return DisasterMapState._map_payloads(city)


static func _duplicate_payloads(payloads: Dictionary) -> Dictionary:
	return DisasterMapState._duplicate_payloads(payloads)


static func _payloads_changed(original: Dictionary, payloads: Dictionary) -> bool:
	return DisasterMapState._payloads_changed(original, payloads)


static func _apply_map_payloads(
	city: CityState, original: Dictionary, payloads: Dictionary
) -> bool:
	return DisasterMapState._apply_map_payloads(city, original, payloads)


static func _refresh_city_arrays(city: CityState) -> void:
	DisasterMapState._refresh_city_arrays(city)


static func _index(point: Vector2i, map_edge: int = 128) -> int:
	return DisasterMapState._index(point, map_edge)


static func _altitude_word(altitude: PackedByteArray, index: int) -> int:
	return DisasterMapState._altitude_word(altitude, index)
