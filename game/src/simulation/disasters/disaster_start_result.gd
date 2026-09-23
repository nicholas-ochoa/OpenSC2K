class_name DisasterStartResult
extends PhaseResult


class MaxisManArrival extends RefCounted:
	var record := 0
	var point := Vector2i.ZERO
	var target := Vector2i.ZERO
	var goal := 0


var disaster_type := 0
var point := Vector2i.ZERO
var started := false
var implemented := false
var record := 0
var map_counter := 0
var hurricane_counter := 0
var map_changed := false
var plant_point := Vector2i.ZERO
var plant_site := Rect2i()
var path_finish := Vector2i.ZERO
var requested_point := Vector2i.ZERO
var scan_finish := Vector2i.ZERO
var direction := 0
var terrain_indices := PackedInt32Array()
var result_codes := PackedInt32Array()
var seed_points: Array[Vector2i] = []
var candidate_points: Array[Vector2i] = []
var damage_points: Array[Vector2i] = []
var flood_points: Array[Vector2i] = []
var accepted_points: Array[Vector2i] = []
var counters: Dictionary[String, int] = {}
var maxis_man_response: MaxisManArrival


static func failed(message: String) -> DisasterStartResult:
	var result := DisasterStartResult.new()
	result.error = message

	return result
