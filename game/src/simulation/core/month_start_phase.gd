class_name MonthStartPhase
extends RefCounted

const MISC_SIZE := Sc2MiscLayout.SIZE
const ZONE_POPULATION_COUNT := 8


class Result extends PhaseResult:
	var cleared_population_fields := 0


static func run(city: CityState) -> Result:
	if city == null or not city.is_valid():
		return _failed("city is invalid")

	var misc := city.document.find_chunk("MISC")

	if misc == null or misc.decoded_payload.size() != MISC_SIZE:
		return _failed("MISC is missing or has the wrong size")

	var changed: PackedByteArray = misc.decoded_payload.duplicate()

	for index in ZONE_POPULATION_COUNT:
		BinaryData.write_u32_be(changed, Sc2MiscLayout.ZONE_POPULATIONS + index * 4, 0)

	if not misc.set_decoded_payload(changed):
		return _failed("cannot clear zone population totals")

	var result := Result.new()
	result.ok = true
	result.cleared_population_fields = ZONE_POPULATION_COUNT

	return result


static func _failed(message: String) -> Result:
	var result := Result.new()
	result.error = message

	return result
