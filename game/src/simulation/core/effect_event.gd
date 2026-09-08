class_name EffectEvent
extends RefCounted
# a demolition sprite or earthquake request passed to the main thread
# a missing point is (-1, -1). altitude -1 uses the tile's water altitude

var type := ""
var point := Vector2i(-1, -1)
var sprite_id := 0
var screen_offset := Vector2i.ZERO
var flip := false
var frame := 0
var altitude := -1
var frames := 24
var frame_msec := 5
var distance := 4


func _init(location := Vector2i(-1, -1), sprite := 0, offset := Vector2i.ZERO,
	flipped := false, frame_index := 0, height := -1) -> void:
	point = location
	sprite_id = sprite
	screen_offset = offset
	flip = flipped
	frame = frame_index
	altitude = height


static func earthquake() -> EffectEvent:
	var result := EffectEvent.new()
	result.type = "earthquake"

	return result


func copy() -> EffectEvent:
	var result := EffectEvent.new()
	result.type = type
	result.point = point
	result.sprite_id = sprite_id
	result.screen_offset = screen_offset
	result.flip = flip
	result.frame = frame
	result.altitude = altitude
	result.frames = frames
	result.frame_msec = frame_msec
	result.distance = distance

	return result


func same_values(other: EffectEvent) -> bool:
	return (other != null
		and type == other.type
		and point == other.point
		and sprite_id == other.sprite_id
		and screen_offset == other.screen_offset
		and flip == other.flip
		and frame == other.frame
		and altitude == other.altitude
		and frames == other.frames
		and frame_msec == other.frame_msec
		and distance == other.distance)


static func copy_all(events: Array[EffectEvent]) -> Array[EffectEvent]:
	var result: Array[EffectEvent] = []

	for event in events:
		result.append(event.copy())

	return result


static func same_arrays(left: Array[EffectEvent], right: Array[EffectEvent]) -> bool:
	if left.size() != right.size():
		return false

	for index in left.size():
		if not left[index].same_values(right[index]):
			return false

	return true
