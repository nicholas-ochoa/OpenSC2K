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

	if chunk == null or chunk.decoded_payload.size() != city.document.decoded_size("XTRF"):
		return {"ok": false, "error": "XTRF is missing or has the wrong size"}

	var span := SimulationTimingSpan.new(city.simulation_slice)
	span.mark("copy traffic map")
	var traffic := chunk.decoded_payload.duplicate()
	var total := 0
	span.mark("decay and sum traffic")

	for index in traffic.size():
		if city.simulation_slice != null and (index & 127) == 0:
			city.simulation_slice.checkpoint()

		var decayed := int(traffic[index]) - (int(traffic[index]) >> 2)
		traffic[index] = decayed
		total += decayed

	span.mark("normalize total")
	if city.document.full_resolution_maps():
		total /= 4

	span.mark("store traffic map and total")
	# decay leaves an empty map unchanged. the render change signature reads the
	# xtrf revision, so a redundant write would repaint the city every phase
	if traffic != chunk.decoded_payload and not chunk.set_decoded_payload(traffic):
		return {"ok": false, "error": "cannot store updated XTRF data"}

	if not city.document.set_misc_u32(MISC_TRAFFIC_COUNT, total):
		return {"ok": false, "error": "cannot store the city traffic count"}

	return {"ok": true, "traffic_count": total, "error": "", "timing": span.finish()}
