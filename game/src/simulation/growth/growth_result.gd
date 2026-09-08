class_name GrowthResult
extends PhaseResult


var scanned_tiles := 0
var rci_tiles := 0
var population_added := 0
var abandoned_population_added := 0
var started_construction := 0
var advanced_construction := 0
var completed_construction := 0
var abandoned_buildings := 0
var recovered_buildings := 0
var churches_built := 0
var successful_trips := 0
var failed_trips := 0
var bus_passengers := 0
var rail_passengers := 0
var subway_passengers := 0
var decayed_roads := 0
var decayed_rails := 0
var decayed_highway_tiles := 0
var decayed_subway_tiles := 0
var collapsed_bridges := 0
var removed_subway_stations := 0
var deferred_bridge_collapses := 0
var deferred_bridge_effects := 0
var deferred_station_removals := 0
var special_growth_attempts := 0
var special_tiles_placed := 0
var arcologies_updated := 0
var spawned_airplanes := 0
var spawned_helicopters := 0
var spawned_ships := 0
var spawned_sailboats := 0
var spawned_trains := 0
var bridge_effects: Array[EffectEvent] = []
var ship_home := Vector2i(-1, -1)
var ship_home_found := false
var rci_complete := false
