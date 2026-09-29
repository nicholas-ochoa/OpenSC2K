class_name RciDemandPhase
extends RefCounted

@warning_ignore_start("integer_division")

const ZONE_POPULATION_OFFSET := Sc2MiscLayout.ZONE_POPULATIONS
const BUDGET_RECORD_SIZE := Sc2BudgetLayout.RECORD_SIZE
const CONNECTION_LABEL := Sc2OverlayLayout.CONNECTION_MARKER


static func _failed(message: String) -> Result:
	var result := Result.new()
	result.error = message

	return result


static func run(city: CityState) -> Result:
	if city == null or not city.is_valid():
		return _failed("city is invalid")

	return NativeSimulationBridge.run("rci_demand", city, null, null, null).result


# the neighbor connections that the map labels mark, as the original counts them on load
static func connection_counts(city: CityState) -> ConnectionCounts:
	var counts: Dictionary = NativeSimulationBridge.run("rci.connection_counts", city, null, null, null).result
	var result := ConnectionCounts.new()
	result.commerce = counts.commerce
	result.industry = counts.industry

	return result


class Result extends PhaseResult:
	var previous_population := 0
	var normal_population := 0
	var tax_population := PackedInt64Array()
	var targets: Array[float] = []
	var demands := PackedInt32Array()
	var commerce_connections := 0
	var industry_connections := 0


class ConnectionCounts extends RefCounted:
	var commerce := 0
	var industry := 0
