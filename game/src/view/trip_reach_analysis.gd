class_name TripReachAnalysis
extends RefCounted
## The trip reach overlay query. The native library explores the routes.

const Tiles = preload("res://src/tools/shared/building_tile_ids.gd")


static func inspect(city: CityState, clicked: Vector2i) -> TransportTripReachResult:
	if city == null or not city.is_valid():
		return TransportTripReachResult.rejected("Select a tile inside the city.")

	return NativeSimulationBridge.run("trip_reach", city, null, null, null, {"clicked": clicked}).result


# the whole footprint of the building at `point`, or the tile itself
static func _building_site(city: CityState, point: Vector2i) -> Rect2i:
	var tile := city.building_id(point.x, point.y)
	if tile < Tiles.DEVELOPED_FIRST:
		return Rect2i(point, Vector2i.ONE)
	var site := DemolishEffectsSites._find_building_site(city.buildings, city.zones, point,
		tile, DemolishEffectsSites._building_area(tile), city.compass_rotation(), city.map_size)
	# partial buildings or missing corner flags have no complete footprint
	# keep their query coverage and marker on the actual tile, never a zero-area site
	return site if site.has_area() else Rect2i(point, Vector2i.ONE)
