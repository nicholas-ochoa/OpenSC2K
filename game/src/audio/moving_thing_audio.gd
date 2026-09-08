class_name MovingThingAudio
extends RefCounted

const Renderer = preload("res://src/view/city_isometric_renderer.gd")


static func event_sound_id(event: SoundEvent, overlay_mode: CityViewMode.Mode, view_size: int) -> int:
	if not event.from_thing:
		return event.sound_id

	var thing_type := event.thing_type

	if (
		overlay_mode != CityViewMode.Mode.CITY
		or thing_type < 0
		or thing_type >= Renderer.THING_MINIMUM_VIEW.size()
		or view_size < Renderer.THING_MINIMUM_VIEW[thing_type]
	):
		return -1

	return event.sound_id
