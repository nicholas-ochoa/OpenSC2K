class_name TransportTrip
extends TransportTripConstants



static func run(
	city: CityState,
	origin: Vector2i,
	zone: int,
	traffic_weight: int,
	random: SimRandom,
	maximum_cost := 100
) -> Dictionary:
	var map_edge: int = city.map_size if city != null else 128

	if city == null or not city.is_valid():
		return {"ok": false, "error": "city is invalid"}

	if random == null:
		return {"ok": false, "error": "a compatible random generator is required"}

	if zone < 0 or zone >= DESTINATION_ZONE_MASKS.size():
		return {"ok": false, "error": "zone is outside the supported range"}

	if traffic_weight < 0:
		return {"ok": false, "error": "traffic weight cannot be negative"}

	var traffic_chunk := city.document.find_chunk("XTRF")

	if traffic_chunk == null or traffic_chunk.decoded_payload.size() != city.document.decoded_size("XTRF"):
		return {"ok": false, "error": "XTRF is missing or has the wrong size"}

	var traffic: PackedByteArray = traffic_chunk.decoded_payload.duplicate()

	if not TransportTripSearch.valid_inputs(city.buildings, city.zones, city.underground,
		city.text_overlays, city.altitude_words, traffic, map_edge):
		return {"ok": false, "error": "transport input maps have the wrong size"}

	var result := TransportTripSearch.trace(
		city.buildings,
		city.zones,
		city.underground,
		city.text_overlays,
		city.altitude_words,
		traffic,
		origin,
		zone,
		traffic_weight,
		random,
		maximum_cost, map_edge,
	)

	if not result.ok:
		return result

	if result.reached_destination and not traffic_chunk.set_decoded_payload(traffic):
		return {"ok": false, "error": "cannot store updated XTRF data"}

	return result


static func trace(
	buildings: PackedByteArray,
	zones: PackedByteArray,
	underground: PackedByteArray,
	text_overlays: PackedByteArray,
	altitudes: PackedInt32Array,
	traffic: PackedByteArray,
	origin: Vector2i,
	zone: int,
	traffic_weight: int,
	random: SimRandom,
	maximum_cost := 100,
	map_edge: int = 128,
	collect_reach := false,
	start_override := -1,
) -> Dictionary:
	return TransportTripSearch.trace(
		buildings, zones, underground, text_overlays, altitudes, traffic, origin, zone, traffic_weight, random,
		maximum_cost, map_edge, collect_reach, start_override
	)


static func valid_inputs(
	buildings: PackedByteArray,
	zones: PackedByteArray,
	underground: PackedByteArray,
	text_overlays: PackedByteArray,
	altitudes: PackedInt32Array,
	traffic: PackedByteArray,
	map_edge: int,
) -> bool:
	return TransportTripSearch.valid_inputs(
		buildings, zones, underground, text_overlays, altitudes, traffic, map_edge
	)


static func _state_key(index: int, mode: int, heading: int) -> int:
	return TransportTripSearch._state_key(index, mode, heading)


static func _walking_destinations(zones: PackedByteArray, point: Vector2i,
	mode: int, origin_zone: int, map_edge: int, any_rci := false) -> Array[Vector2i]:
	return TransportTripSearch._walking_destinations(zones, point, mode, origin_zone, map_edge, any_rci)


static func has_nearby_transport(buildings: PackedByteArray, origin: Vector2i, map_edge: int = 128) -> bool:
	return TransportTripSearch._find_transport(buildings, origin, map_edge) >= 0


static func _find_transport(buildings: PackedByteArray, origin: Vector2i, map_edge: int = 128) -> int:
	return TransportTripSearch._find_transport(buildings, origin, map_edge)


static func _advance(
	buildings: PackedByteArray,
	zones: PackedByteArray,
	underground: PackedByteArray,
	text_overlays: PackedByteArray,
	altitudes: PackedInt32Array,
	current: Vector2i,
	next_point: Vector2i,
	mode: int,
	origin_zone: int,
	map_edge: int = 128,
) -> int:
	return TransportTripSteps._advance(
		buildings, zones, underground, text_overlays, altitudes, current, next_point, mode, origin_zone, map_edge
	)


static func _move(mode: int, cost: int) -> int:
	return TransportTripSteps._move(mode, cost)


static func _result(
	reached_destination: bool,
	cost: int,
	path_length: int,
	used_bus: bool,
	used_rail: bool,
	used_subway: bool
) -> Dictionary:
	return TransportTripSearch._result(reached_destination, cost, path_length, used_bus, used_rail, used_subway)


static func _is_surface_road(tile: int) -> bool:
	return TransportTripSteps._is_surface_road(tile)


static func _is_road_bridge(tile: int) -> bool:
	return TransportTripSteps._is_road_bridge(tile)


static func _is_highway_span(tile: int) -> bool:
	return TransportTripSteps._is_highway_span(tile)


static func _is_rail(tile: int) -> bool:
	return TransportTripSteps._is_rail(tile)


static func _is_subway(tile: int) -> bool:
	return TransportTripSteps._is_subway(tile)


static func _index(point: Vector2i, map_edge: int = 128) -> int:
	return TransportTripSteps._index(point, map_edge)


# lane corners come from coordinate parity; this isn't plain flood fill
static func _highway_step(buildings: PackedByteArray, current: Vector2i,
	next_point: Vector2i, map_edge: int) -> bool:
	return TransportTripSteps._highway_step(buildings, current, next_point, map_edge)


static func _ramp_side(highway: Vector2i, ramp: Vector2i, ports: int) -> bool:
	return TransportTripSteps._ramp_side(highway, ramp, ports)


static func _highway_exit(buildings: PackedByteArray, current: Vector2i,
	next_point: Vector2i, map_edge: int) -> bool:
	return TransportTripSteps._highway_exit(buildings, current, next_point, map_edge)
