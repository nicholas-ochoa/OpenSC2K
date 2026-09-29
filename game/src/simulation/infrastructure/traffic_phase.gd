class_name TrafficPhase
extends RefCounted

const MAP_SIZE := 64


static func run(city: CityState) -> Result:
	if city == null or not city.is_valid():
		return _failed("city is invalid")

	return NativeSimulationBridge.run("traffic", city, null, null, null).result


static func _failed(message: String) -> Result:
	var result := Result.new()
	result.error = message

	return result


class Result extends PhaseResult:
	var traffic_count := 0
