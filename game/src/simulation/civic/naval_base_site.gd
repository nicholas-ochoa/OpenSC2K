class_name NavalBaseSite
extends RefCounted
## The Navy base site search. The native library searches the coast.

const INLAND_STEPS := [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]


# the first coastal site with clear, level land, or an empty rectangle
static func find(city: CityState) -> Rect2i:
	return NativeSimulationBridge.run("military.naval_site", city, null, null, null).result
