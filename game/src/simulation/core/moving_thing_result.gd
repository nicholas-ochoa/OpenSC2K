class_name MovingThingResult
extends PhaseResult


class ConnectionChange extends RefCounted:
	var kind: String
	var delta: int
	var point: Vector2i

	func _init(connection_kind: String, count_delta: int, location: Vector2i) -> void:
		kind = connection_kind
		delta = count_delta
		point = location


class DisasterRequest extends RefCounted:
	var type: int
	var point: Vector2i

	func _init(disaster_type: int, location: Vector2i) -> void:
		type = disaster_type
		point = location


var scanned_records := 0
var active_airplanes := 0
var active_helicopters := 0
var active_ships := 0
var active_monsters := 0
var active_explosions := 0
var active_sailboats := 0
var active_trains := 0
var active_tornadoes := 0
var active_maxis_men := 0
var moved_helicopters := 0
var moved_airplanes := 0
var moved_ships := 0
var moved_monsters := 0
var moved_sailboats := 0
var moved_trains := 0
var moved_tornadoes := 0
var moved_maxis_men := 0
var turned_sailboats := 0
var turned_trains := 0
var paused_trains := 0
var reversed_trains := 0
var distressed_sailboats := 0
var removed_sailboats := 0
var removed_trains := 0
var removed_helicopters := 0
var crashed_helicopters := 0
var removed_airplanes := 0
var crashed_airplanes := 0
var landed_airplanes := 0
var removed_ships := 0
var crashed_ships := 0
var docked_ships := 0
var departing_ships := 0
var removed_explosions := 0
var removed_tornadoes := 0
var removed_maxis_men := 0
var removed_monsters := 0
var monster_damage_hits := 0
var monster_forced_airplanes := 0
var monster_forced_helicopters := 0
var monster_military_collisions := 0
var tornado_demolitions := 0
var maxis_man_extinguished_fires := 0
var maxis_man_destroyed_targets := 0
var maxis_man_explosions := 0
var spread_explosion_fires := 0
var rubble_explosion_hits := 0
var damaged_facilities := 0
var deferred_facility_explosion_hits := 0
var malformed_records := 0
var traffic_news_checks := 0
var traffic_news_time_msec := 0
var traffic_news_deadline_msec := 0
var connection_count_changes: Array[ConnectionChange] = []
var created_train_crash_explosions := 0
var disaster_start_requests: Array[DisasterRequest] = []
var sailboats_complete := false
var train_routes_complete := false
var helicopters_save_visible_complete := false
var ships_save_visible_complete := false
var airplanes_save_visible_complete := false
var explosion_records_complete := false
var tornadoes_save_visible_complete := false
var maxis_man_save_visible_complete := false
var monsters_save_visible_complete := false
var explosion_map_damage_complete := false


static func failure(message: String) -> MovingThingResult:
	var result := MovingThingResult.new()
	result.error = message

	return result
