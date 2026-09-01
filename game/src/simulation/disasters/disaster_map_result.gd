class_name DisasterMapResult
extends PhaseResult


var active := false
var map_counter := 0
var hurricane_counter := 0
var map_changed := false
var disaster_type := 0
var ended_type := 0
# diagnostic counts and marker activity from the scan
var counters: Dictionary[String, int] = {}
var active_markers: Dictionary[String, bool] = {}
var dispatch_map: DisasterMapResult


static func failure(message: String) -> DisasterMapResult:
	var result := DisasterMapResult.new()
	result.error = message

	return result
