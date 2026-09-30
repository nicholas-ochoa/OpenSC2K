class_name FacilityRecordRepair
extends RefCounted
# Repair SC2X facility records on activation. Parsing and simulation snapshots
# keep the saved bytes. The native simulation library links each facility
# building to its record; see native/simulation/src/sim/tools/commands/facility_repair.rs.


static func apply(city: CityState) -> Result:
	var result := Result.new()
	result.ok = true

	if city == null or not city.is_valid() or not city.document.is_extended():
		return result

	return NativeSimulationBridge.run("tool.facility_repair", city, null, null, null).result


class Result extends RefCounted:
	var ok := false
	var error := ""
	var created := 0
	var linked := 0
	var unfilled := 0

	static func failure(message: String) -> Result:
		var result := Result.new()
		result.error = message

		return result
