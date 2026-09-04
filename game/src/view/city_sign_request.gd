class_name CitySignRequest
extends RefCounted
# sign bounds and painter order sent to the regional render worker

var key: int
var bounds: Rect2i
var draw_order: int


func _init(sign_key: int, area: Rect2i, order: int) -> void:
	key = sign_key
	bounds = area
	draw_order = order
