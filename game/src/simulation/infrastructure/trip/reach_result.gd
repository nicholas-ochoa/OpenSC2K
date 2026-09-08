class_name TransportTripReachResult
extends TransportTripResult
# read-only route exploration and its displayed building coverage

class ReachNode extends RefCounted:
	var point: Vector2i
	var mode: int
	var cost: int

	func _init(location: Vector2i, travel_mode: int, trip_cost: int) -> void:
		point = location
		mode = travel_mode
		cost = trip_cost


class Link extends RefCounted:
	var from: Vector2i
	var to: Vector2i
	var from_mode: int
	var mode: int
	var cost: int

	func _init(origin: Vector2i, destination: Vector2i, source_mode: int, travel_mode: int, trip_cost: int) -> void:
		from = origin
		to = destination
		from_mode = source_mode
		mode = travel_mode
		cost = trip_cost


var reachable: Array[ReachNode] = []
var links: Array[Link] = []
var destinations: Dictionary[Vector2i, int] = {}
var limit_points: Dictionary[Vector2i, String] = {}
var limit := 0
var start := Vector2i(-1, -1)
var origin := Vector2i(-1, -1)
var clicked := Vector2i(-1, -1)
var summary := PackedStringArray()
var rci := false
var powered := false
var demand := 0
var access_tiles: Dictionary[Vector2i, int] = {}
var origin_tiles: Dictionary[Vector2i, int] = {}


static func rejected(message: String) -> TransportTripReachResult:
	var result := TransportTripReachResult.new()
	result.error = message

	return result
