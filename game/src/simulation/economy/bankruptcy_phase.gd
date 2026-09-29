class_name BankruptcyPhase
extends RefCounted

const BANKRUPTCY_LIMIT := -100000


static func _failed(message: String) -> Result:
	var result := Result.new()
	result.error = message

	return result


static func run(city: CityState) -> Result:
	if city == null or not city.is_valid():
		return _failed("city is invalid")

	return NativeSimulationBridge.run("bankruptcy", city, null, null, null).result


class Result extends PhaseResult:
	var bankrupt := false
	var funds := 0
