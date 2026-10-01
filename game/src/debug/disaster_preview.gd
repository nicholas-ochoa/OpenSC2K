class_name DisasterPreview
extends RefCounted
## A disaster dry run. It starts the disaster in a copy of the simulation, with
## copies of the random states, runs some disaster ticks, and compares the copy
## with the city. The city, its random states and its file do not change, so
## the preview shows what the same start would do now.

const MAX_TICKS := 500


static func run(controller: GameSpeedController, disaster_type: int, point: Vector2i, ticks: int) -> Result:
	if controller == null or controller.engine == null or controller.engine.city == null:
		return Result.failure("Load a city before you preview a disaster.")

	var working := SimulationSnapshot.capture(controller, SimulationSliceBudget.new())
	# no frame grants time to this copy. it runs to the end on this thread
	working.engine.city.simulation_slice = null
	var engine := working.engine
	var started := engine.start_disaster(disaster_type, point)

	if not started.ok:
		return Result.failure("The disaster cannot start: %s." % started.error)

	if not started.started:
		return Result.failure("The disaster does not start at this tile.")

	var ran := 1

	while ran < clampi(ticks, 1, MAX_TICKS) and engine.active_disaster_type != 0:
		var tick := engine.advance_disaster_tick()

		if not tick.ok:
			return Result.failure("A disaster tick failed: %s." % tick.error)

		ran += 1

	var before := NativeTileSnapshot.new()
	before.capture(ApplicationDebugTileViews.tiles(controller.engine.city))
	var difference := before.difference(ApplicationDebugTileViews.tiles(engine.city), Sc2TileFlags.MARK)
	var result := Result.new()
	result.ok = true
	result.values = difference.values
	result.counts = difference.counts
	result.tiles = int(difference.tiles)
	result.ticks = ran
	result.ended = engine.active_disaster_type == 0
	result.things = _things(engine.city) - _things(controller.engine.city)
	result.point = point
	result.disaster_type = disaster_type

	return result


static func _things(city: CityState) -> int:
	var count := 0

	for id in range(1, city.thing_count()):
		var record := city.thing(id)

		if record != null and record.type != 0:
			count += 1

	return count


class Result extends RefCounted:
	var ok := false
	var error := ""
	var values := PackedByteArray()
	var counts := PackedInt32Array()
	var tiles := 0
	var ticks := 0
	var ended := false
	var things := 0
	var point := Vector2i(-1, -1)
	var disaster_type := 0

	static func failure(message: String) -> Result:
		var result := Result.new()
		result.error = message

		return result

	func summary() -> String:
		if not ok:
			return error

		var parts := PackedStringArray()

		for plane in counts.size():
			if counts[plane] > 0:
				parts.append("%s %d" % [DebugTileLayers.CHANGE_NAMES[plane], counts[plane]])

		return "%s at %d, %d: %d tiles change after %d ticks%s%s. Moving things %+d." % [
			CityMenuBar.disaster_name(disaster_type), point.x, point.y, tiles, ticks, " (the disaster ended)" if ended else "",
			(": " + ", ".join(parts)) if not parts.is_empty() else "", things]
