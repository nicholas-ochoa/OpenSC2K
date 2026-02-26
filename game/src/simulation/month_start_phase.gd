class_name MonthStartPhase
extends RefCounted

const MISC_SIZE := 4800
const MISC_ZONE_POPULATIONS := 0x05f0
const ZONE_POPULATION_COUNT := 8


static func run(city: CityState) -> Dictionary:
	if city == null or not city.is_valid():
		return {"ok": false, "error": "city is invalid"}

	var misc := city.document.find_chunk("MISC")

	if misc == null or misc.decoded_payload.size() != MISC_SIZE:
		return {"ok": false, "error": "MISC is missing or has the wrong size"}

	var changed: PackedByteArray = misc.decoded_payload.duplicate()

	for index in ZONE_POPULATION_COUNT:
		_write_u32(changed, MISC_ZONE_POPULATIONS + index * 4, 0)

	if not misc.set_decoded_payload(changed):
		return {"ok": false, "error": "cannot clear zone population totals"}

	return {"ok": true, "cleared_population_fields": ZONE_POPULATION_COUNT, "error": ""}


static func _write_u32(data: PackedByteArray, offset: int, value: int) -> void:
	var encoded := value & 0xffffffff
	data[offset] = (encoded >> 24) & 0xff
	data[offset + 1] = (encoded >> 16) & 0xff
	data[offset + 2] = (encoded >> 8) & 0xff
	data[offset + 3] = encoded & 0xff
