class_name TrafficPhase
extends RefCounted

const MAP_SIZE := 64
const VALUE_COUNT := MAP_SIZE * MAP_SIZE
const MISC_TRAFFIC_COUNT := 0x30


static func run(city: CityState) -> Dictionary:
	var map_edge: int = city.map_size if city != null else 128
	if city == null or not city.is_valid():
		return {"ok": false, "error": "city is invalid"}
	var chunk := city.document.find_chunk("XTRF")
	if chunk == null or chunk.decoded_payload.size() != ((map_edge / 2) * (map_edge / 2)):
		return {"ok": false, "error": "XTRF is missing or has the wrong size"}
	var traffic := chunk.decoded_payload.duplicate()
	var total := 0
	for index in traffic.size():
		if city.simulation_slice != null and (index & 127) == 0:
			city.simulation_slice.checkpoint()
		var decayed := int(traffic[index]) - (int(traffic[index]) >> 2)
		traffic[index] = decayed
		total += decayed
	if not chunk.set_decoded_payload(traffic):
		return {"ok": false, "error": "cannot store updated XTRF data"}
	if not city.document.set_misc_u32(MISC_TRAFFIC_COUNT, total):
		return {"ok": false, "error": "cannot store the city traffic count"}
	return {"ok": true, "traffic_count": total, "error": ""}
