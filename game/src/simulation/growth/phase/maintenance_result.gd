class_name GrowthMaintenanceResult
extends RefCounted
# rare maintenance, special-zone, and spawn outcomes for one growth partition
# numeric metrics stay keyed; events and the discovered ship home are typed

var metrics: Dictionary[String, int] = {
	"decayed_roads": 0,
	"decayed_rails": 0,
	"decayed_highway_tiles": 0,
	"decayed_subway_tiles": 0,
	"collapsed_bridges": 0,
	"removed_subway_stations": 0,
	"deferred_bridge_collapses": 0,
	"deferred_bridge_effects": 0,
	"deferred_station_removals": 0,
	"special_growth_attempts": 0,
	"special_tiles_placed": 0,
	"arcologies_updated": 0,
	"spawned_airplanes": 0,
	"spawned_helicopters": 0,
	"spawned_ships": 0,
	"spawned_sailboats": 0,
	"spawned_trains": 0,
}
var bridge_effects: Array[EffectEvent] = []
var view_center_requests: Array[Vector2i] = []
var news_items: Array[NewsEvent] = []
var sound_events: Array[SoundEvent] = []
var ship_home_found := false
var ship_home := Vector2i(-1, -1)
