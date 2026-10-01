class_name CityEffectTiming
extends RefCounted

# the effect type of a launch fire, and its large view sprites
const LAUNCH_FIRE := "launch_fire"
const FIRE_SPRITE := 1396
const SMOKE_SPRITE := 1392
# a smoke puff starts every SMOKE_PERIOD frames and rises SMOKE_RISE pixels a frame
const SMOKE_PERIOD := 6
const SMOKE_FRAMES := 4
const SMOKE_RISE := 8


static func parallel_dust_events(events: Array[EffectEvent]) -> Array[EffectEvent]:
	var groups: Dictionary[Vector2i, Array] = {}

	for event in events:
		if event.point != Vector2i(-1, -1) and event.type.is_empty():
			var key: Vector2i = event.point

			if not groups.has(key):
				groups[key] = []

			groups[key].append(event)

	if groups.size() < 2:
		return events

	var order := groups.keys()
	order.shuffle() # presentation randomness does not consume simulation random state
	var starts: Dictionary[Vector2i, DustTiming] = {}

	for index in order.size():
		var first := 2147483647

		for event in groups[order[index]]:
			first = mini(first, int(event.frame))

		starts[order[index]] = DustTiming.new(first, index % 5)

	var result: Array[EffectEvent] = []

	for source in events:
		var event := source.copy()

		if event.point != Vector2i(-1, -1) and event.type.is_empty() and starts.has(event.point):
			var timing := starts[event.point]
			event.frame = int(event.frame) - int(timing.first) + int(timing.start)

		result.append(event)

	return result


# replace each launch fire with its frames of fire and rising smoke. the fire
# is only a picture: it changes no tile and does not spread
static func expand_launch_fires(events: Array[EffectEvent]) -> Array[EffectEvent]:
	var result: Array[EffectEvent] = []

	for event in events:
		if event.type != LAUNCH_FIRE:
			result.append(event)
			continue

		# mix the tile coordinates so neighbor fires do not move together
		var phase := ((event.point.x * 7 + event.point.y * 13) * 0x45d9f3b >> 8) & 0xffff
		var fires: Array[EffectEvent] = []
		var smoke: Array[EffectEvent] = []

		for frame in int(event.frames):
			var fire := _launch_sprite(event, FIRE_SPRITE + ((frame + phase) & 3), frame, Vector2i.ZERO)
			fire.flip = (phase & 1) != 0
			fires.append(fire)

			if (frame + phase) % SMOKE_PERIOD != 0:
				continue

			for rise in mini(SMOKE_FRAMES, int(event.frames) - frame):
				var sprite := SMOKE_SPRITE + ((rise + phase) & 3)
				smoke.append(_launch_sprite(event, sprite, frame + rise, Vector2i(0, -SMOKE_RISE * (rise + 1))))

		result.append_array(fires)
		result.append_array(smoke)

	return result


static func _launch_sprite(source: EffectEvent, sprite: int, frame: int, offset: Vector2i) -> EffectEvent:
	var event := source.copy()
	event.type = ""
	event.sprite_id = sprite
	event.frame = int(source.frame) + frame
	event.screen_offset = source.screen_offset + offset

	return event


class DustTiming extends RefCounted:
	var first: int
	var start: int

	func _init(first_frame: int, start_frame: int) -> void:
		first = first_frame
		start = start_frame
