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


static func has_nearby_transport(buildings: PackedByteArray, origin: Vector2i, map_edge: int = 128) -> bool:
	return TransportTripSearch._find_transport(buildings, origin, map_edge) >= 0
