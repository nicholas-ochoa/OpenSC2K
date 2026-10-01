class_name GrowthInspection
extends RefCounted
## The growth inputs of a residential, commercial or industrial tile for the
## Tile Inspector: the growth visit, power, nearby transport, the trip, the
## class demand, the land value step and the density advance chance. Each
## native query copies the city chunks, so the inspector asks only for a pinned
## tile. The queries do not change the city.

@warning_ignore_start("integer_division")

const STATUS_NAMES := ["normal", "under construction", "abandoned"]
const CLASS_NAMES := ["Residential", "Commercial", "Industrial"]


static func rows(city: CityState, point: Vector2i) -> Array:
	var inputs: Dictionary = NativeSimulationBridge.run("growth_inputs", city, null, null, null, { "point": point }).result

	if inputs.is_empty() or not bool(inputs.rci):
		return []

	var result := []
	var zone := int(inputs.zone_type)
	var density := int(inputs.density)
	var status: String = STATUS_NAMES[int(inputs.status)] if int(inputs.status) < STATUS_NAMES.size() else "unknown"
	result.append(["Growth", "%s, density %d (%s)" % [DebugTileLayers.ZONE_NAMES[zone], density, status]])
	result.append(["  Visit", ("month day %d" % (int(inputs.visit_day) + 1)) if bool(inputs.visited)
		else "none: %s" % ("no road or rail nearby" if int(inputs.building) < BuildingTileIds.DEVELOPED_FIRST
		else "not the anchor tile of its building")])
	result.append(["  Power", "yes" if bool(inputs.powered) else "no (no trip, no growth pressure)"])

	if int(inputs.building) < BuildingTileIds.DEVELOPED_FIRST:
		result.append(["  Transport", "road or rail nearby" if bool(inputs.transport) else "none nearby"])

	result.append(["  Trip", trip_text(city, point)])
	result.append(["  Demand", "%s %d; a completed trip gives pressure %d" % [CLASS_NAMES[(zone - 1) / 2], int(inputs.class_demand),
		int(inputs.pressure)]])
	var needed := int(inputs.needed_land_value)
	result.append(["  Land value", "%d%s" % [int(inputs.land_value), "" if needed < 0 else ", needs more than %d to grow" % needed]])
	result.append(["  Advance", ("%.2f%% chance in each visit after a completed trip" % (int(inputs.advance_chance) / 100.0))
		if bool(inputs.can_advance) and bool(inputs.powered) else "cannot advance now"])

	return result


# the read-only trip of the Trip Query from this tile
static func trip_text(city: CityState, point: Vector2i) -> String:
	var trip := TripReachAnalysis.inspect(city, point)

	if trip == null or not trip.ok:
		return "no trip: %s" % (trip.error if trip != null else "no result")

	if not trip.reached_destination:
		return "no destination within the limit of %d" % trip.limit

	return "reaches a destination: cost %d of %d, %d destinations" % [trip.cost, trip.limit, trip.destinations.size()]
