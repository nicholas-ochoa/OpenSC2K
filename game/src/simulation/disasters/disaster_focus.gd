class_name DisasterFocus
extends RefCounted
## The tile that the Go To Disaster button centers. The native simulation
## library finds it; see native/core/sim/src/sim/disasters/focus.rs.


# returns the disaster tile, or a negative point when nothing is located
static func find_point(city: CityState) -> Vector2i:
	if city == null or not city.is_valid():
		return Vector2i(-1, -1)

	return NativeSimulationBridge.run("disaster.focus", city, null, null, null).result
