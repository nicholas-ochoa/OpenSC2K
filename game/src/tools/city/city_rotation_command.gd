class_name CityRotationCommand
extends RefCounted
## View rotation rewrites the saved city coordinates. The native simulation
## library turns the chunks; see native/core/sim/src/sim/tools/rotation.rs.

const REQUIRED_CHUNKS: PackedStringArray = [
	"MISC", "ALTM", "XTER", "XBLD", "XZON", "XUND", "XTXT", "XTHG", "XBIT", "XTRF", "XPLT", "XVAL", "XCRM", "XPLC", "XFIR",
	"XPOP", "XROG",
]


static func apply(city: CityState, counter_clockwise: bool) -> RotationEditResult:
	if city == null or not city.is_valid():
		return RotationEditResult.rejected("city is invalid")

	for chunk_id in REQUIRED_CHUNKS:
		var chunk := city.document.find_chunk(chunk_id)

		if chunk == null or chunk.decoded_payload.size() != city.document.decoded_size(chunk_id):
			return RotationEditResult.rejected("rotation data is missing or invalid")

	# sc2x version 4 signs keep their own coordinates outside the tile index
	var turned_signs := {}

	if CitySignTable.uses_table(city):
		turned_signs = CitySignTable.rotated(city, counter_clockwise)

		if not turned_signs.ok:
			return RotationEditResult.rejected("sign data is invalid: %s" % turned_signs.error)

	var response := NativeSimulationBridge.run("rotation", city, null, null, null, {
		"counter_clockwise": counter_clockwise,
	}, REQUIRED_CHUNKS)

	if not response.ok or not response.failed_chunk.is_empty():
		return RotationEditResult.rejected("cannot store rotated city data")

	if not turned_signs.is_empty():
		city.document.find_chunk(CitySignTable.CHUNK_ID).set_decoded_payload(turned_signs.data)

	var result := RotationEditResult.new()
	result.ok = true
	result.counter_clockwise = counter_clockwise
	result.old_compass = response.result.old_compass
	result.new_compass = response.result.new_compass
	result.error = ""

	for chunk_id in REQUIRED_CHUNKS:
		if response.written.has(chunk_id):
			result.changed_ids.append(chunk_id)

	if not turned_signs.is_empty():
		result.changed_ids.append(CitySignTable.CHUNK_ID)

	return result


static func rotate_point(point: Vector2i, size: int, counter_clockwise: bool) -> Vector2i:
	if size < 1 or point.x < 0 or point.x >= size or point.y < 0 or point.y >= size:
		return Vector2i(-1, -1)

	if counter_clockwise:
		return Vector2i(point.y, size - 1 - point.x)

	return Vector2i(size - 1 - point.y, point.x)
