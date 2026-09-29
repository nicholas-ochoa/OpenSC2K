class_name NativeDataMapPhase
extends RefCounted
## SC2X v3 per-tile data maps. These rules differ from the coarse grids of the
## original executable. The native library runs them.


# the full monthly scan. the day schedule runs the two halves on separate days
static func run(city: CityState) -> PollutionPhase.Result:
	return NativeSimulationBridge.run("data_maps.native", city, null, null, null).result


class PollutionCoverageResult extends PhaseResult:
	var pollution_total := 0
	var city_center := Vector2i.ZERO
