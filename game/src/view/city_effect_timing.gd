class_name CityEffectTiming
extends RefCounted


class DustTiming extends RefCounted:
	var first: int
	var start: int

	func _init(first_frame: int, start_frame: int) -> void:
		first = first_frame
		start = start_frame


static func parallel_dust_events(events: Array[EffectEvent]) -> Array[EffectEvent]:
	var groups: Dictionary[Vector2i, Array] = {}

	for event in events:
		if event.point != Vector2i(-1, -1) and event.type != "earthquake":
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

		if event.point != Vector2i(-1, -1) and starts.has(event.point):
			var timing := starts[event.point]
			event.frame = int(event.frame) - int(timing.first) + int(timing.start)

		result.append(event)

	return result
