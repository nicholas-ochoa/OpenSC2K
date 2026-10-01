class_name CityEffectTiming
extends RefCounted


@warning_ignore_start("integer_division")

# the effect type of a launch fire, and its large view sprites
const LAUNCH_FIRE := "launch_fire"
const FIRE_SPRITE := 1396
const SMOKE_SPRITE := 1392
# a smoke puff starts every SMOKE_PERIOD frames and rises SMOKE_RISE pixels a frame
const SMOKE_PERIOD := 6
const SMOKE_FRAMES := 4
const SMOKE_RISE := 8
# the effect type of a launching arcology. it stands for LAUNCH_STILL_FRAMES,
# shakes until liftoff, and then flies up with LAUNCH_ACCELERATION. its frames
# play at LAUNCH_FPS. the liftoff frame of the event uses 10 frames a second
const LAUNCH_ARCOLOGY := "launch_arcology"
const LAUNCH_FPS := 30
const LAUNCH_STILL_FRAMES := 15
const LAUNCH_FLIGHT_FRAMES := 90
# large view pixels a second squared
const LAUNCH_ACCELERATION := 600.0
# the front edge tiles of a 4×4 launch arcology from its anchor, the
# screen-left corner. its exhaust flames hang from these tiles
const EXHAUST_TILES: Array[Vector2i] = [
	Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0), Vector2i(3, -1), Vector2i(3, -2), Vector2i(3, -3),
]
# the exhaust flames change sprite every EXHAUST_FRAME_STEP launch frames
const EXHAUST_FRAME_STEP := 2
# view pixel offsets of the shake, one a frame
const LAUNCH_SHAKE: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(0, 0), Vector2i(-1, 0), Vector2i(0, -1), Vector2i(1, -1), Vector2i(-1, 0),
	Vector2i(0, 0), Vector2i(1, 0), Vector2i(-1, -1), Vector2i(0, 0),
]


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
	# a delayed request, such as launch dust, keeps its delay
	var delay := 2147483647

	for index in order.size():
		var first := 2147483647

		for event in groups[order[index]]:
			first = mini(first, int(event.frame))

		delay = mini(delay, first)
		starts[order[index]] = DustTiming.new(first, index % 5)

	for point in starts:
		starts[point].start += delay

	var result: Array[EffectEvent] = []

	for source in events:
		var event := source.copy()

		if event.point != Vector2i(-1, -1) and event.type.is_empty() and starts.has(event.point):
			var timing := starts[event.point]
			event.frame = int(event.frame) - int(timing.first) + int(timing.start)

		result.append(event)

	return result


# the first frame of the flight, at LAUNCH_FPS
static func liftoff_frame(liftoff: int) -> int:
	return liftoff * LAUNCH_FPS / 10


# the offset of a launching arcology in each frame, in large view pixels.
# `liftoff` is the liftoff frame at 10 frames a second. the flight ends once
# the sprite bottom, `bottom` pixels below its origin, passes `top`
static func launch_offsets(liftoff: int, divisor: int, origin_y: int, bottom: int, top := 0) -> Array[Vector2i]:
	var offsets: Array[Vector2i] = []
	for frame in liftoff_frame(liftoff):
		var shake := LAUNCH_SHAKE[frame % LAUNCH_SHAKE.size()] if frame >= LAUNCH_STILL_FRAMES else Vector2i.ZERO
		offsets.append(shake * divisor)

	for frame in LAUNCH_FLIGHT_FRAMES:
		var seconds := float(frame) / LAUNCH_FPS
		var rise := Vector2i(0, -roundi(LAUNCH_ACCELERATION * seconds * seconds / 2.0))
		offsets.append(rise)

		if origin_y + rise.y + bottom < top:
			break

	return offsets


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
