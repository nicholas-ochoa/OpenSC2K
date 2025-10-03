class_name MovingThingAudio
extends RefCounted

const Renderer = preload("res://src/view/city_isometric_renderer.gd")


static func event_sound_id(event, overlay_mode: String, view_size: int) -> int:
	if not (event is Dictionary):
		return int(event)
	var thing_type := int(event.get("thing_type", -1))
	if (
		overlay_mode != "city"
		or thing_type < 0
		or thing_type >= Renderer.THING_MINIMUM_VIEW.size()
		or view_size < Renderer.THING_MINIMUM_VIEW[thing_type]
	):
		return -1
	return int(event.get("sound_id", -1))
