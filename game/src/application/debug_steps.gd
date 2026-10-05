class_name ApplicationDebugSteps
extends RefCounted
## Day and phase steps while the game is paused. A phase step runs one action
## of the day schedule; the day stays open until its last action runs. A speed
## change finishes an open day first, so the normal simulation never skips an
## action. Each step logs its time, the changed tiles and the changed chunks.
## A phase step runs each action as its own native call. The game runs a whole
## day in one call, so a phase step is a debug view of the same work.

const MAX_LOG := 200
# step logs compare the tile arrays before and after a step up to this map size.
# larger maps report changed chunks only
const MAX_TILE_DIFF_EDGE := 1024

var app: CityApplication
# the open day: its schedule with the actions that did not run yet
var open_day: SimulationSchedule
var entries: Array[Entry] = []
# counts the appended entries, so a view sees a new entry after the oldest leaves
var serial := 0


func _init(application: CityApplication) -> void:
	app = application


func on_city_activated() -> void:
	open_day = null
	entries.clear()


# the actions that the next step runs, for the Steps tab
func next_actions() -> String:
	var engine := app.simulation_state.simulation_engine

	if engine == null:
		return "No city"

	if engine.active_disaster_type != 0:
		return "Disaster tick (%s)" % CityMenuBar.disaster_name(engine.active_disaster_type)

	if open_day != null:
		return "Open day %d: %s" % [open_day.month_day + 1, ", ".join(open_day.actions)]

	var schedule := SimulationClock.state_for_day(engine.clock.city_days + 1)

	return "Day %d: %s" % [schedule.month_day + 1, ", ".join(schedule.actions)]


func step_day() -> String:
	var blocked := _blocked()

	if not blocked.is_empty():
		return blocked

	if open_day != null:
		return finish_open_day()

	var controller := app.simulation_state.speed_controller

	# a paused fire has no elapsed fire time. a step runs its tick now
	controller.fire_elapsed_msec = GameSpeedController.FIRE_TICK_MSEC

	return _record("Day", controller.run_day)


func step_phase() -> String:
	var blocked := _blocked()

	if not blocked.is_empty():
		return blocked

	var engine := app.simulation_state.simulation_engine

	if engine.active_disaster_type != 0:
		return step_day()

	var first := open_day == null

	if first:
		open_day = engine.clock.advance_day()

		if not engine.city.set_age_in_days(engine.clock.city_days):
			open_day = null

			return "Cannot store the new simulation day."

	var action := open_day.actions[0]
	var single := open_day.copy()
	single.actions = PackedStringArray([action])
	var remaining := open_day.after(action)
	var last := remaining.actions.is_empty()
	open_day = null if last else remaining

	return _record("Phase " + action, func() -> SimulationTickResult:
		return app.simulation_state.speed_controller.step_schedule(single, first, last))


# run the actions that the open day did not run yet
func finish_open_day() -> String:
	if open_day == null:
		return ""

	var schedule := open_day
	open_day = null

	return _record("Rest of day: " + ", ".join(schedule.actions), func() -> SimulationTickResult:
		return app.simulation_state.speed_controller.step_schedule(schedule, false, true))


# the reason that a step cannot run now, or an empty string
func _blocked() -> String:
	var simulation := app.simulation_state

	if simulation.speed_controller == null or app.document_state.city == null:
		return "Load a city before you step the simulation."

	if simulation.speed_controller.speed != GameSpeedController.Speed.PAUSED:
		return "Pause the game before you step the simulation."

	if simulation.frame_simulation != null and simulation.frame_simulation.is_busy():
		return "The simulation worker is busy. Try again."

	var engine := simulation.simulation_engine

	if not engine.pending_interaction.is_empty():
		return "Answer the %s prompt first." % engine.pending_interaction.replace("_", " ")

	if engine.terminal_state:
		return "The game has ended."

	return ""


func _record(title: String, step: Callable) -> String:
	var city := app.document_state.city
	var document := city.document
	var revisions := _revisions(document)
	var before: NativeTileSnapshot = null

	if city.map_size <= MAX_TILE_DIFF_EDGE:
		before = NativeTileSnapshot.new()
		before.capture(ApplicationDebugTileViews.tiles(city))

	var date := "%02d/%02d/%04d" % [city.current_month(), city.current_day(), city.current_year()]
	var started := Time.get_ticks_usec()
	var result: SimulationTickResult = step.call()
	var entry := Entry.new()
	entry.date = date
	entry.title = title
	entry.usec = Time.get_ticks_usec() - started

	if not result.ok:
		entry.error = result.error
		_append(entry)

		return "The step failed: %s" % result.error

	app.frame.consume_simulation_result(result)
	app.map_render.refresh_map(false)
	city = app.document_state.city
	entry.changed_chunks = _changed(revisions, _revisions(city.document))
	entry.changed_tiles = -1

	if before != null:
		var difference := before.difference(ApplicationDebugTileViews.tiles(city), Sc2TileFlags.MARK)
		entry.changed_tiles = int(difference.tiles)

	_append(entry)

	return "%s ran in %.1f ms. %s" % [title, entry.usec / 1000.0, entry.change_text()]


func _append(entry: Entry) -> void:
	entries.append(entry)
	serial += 1

	if entries.size() > MAX_LOG:
		entries.pop_front()


static func _revisions(document: Sc2File) -> Dictionary[String, int]:
	var result: Dictionary[String, int] = {}
	var seen: Dictionary[String, int] = {}

	for chunk in document.chunks:
		result[ApplicationDebugTools.chunk_key(chunk.chunk_id, seen)] = chunk.mutation_revision

	return result


static func _changed(before: Dictionary[String, int], after: Dictionary[String, int]) -> PackedStringArray:
	var result := PackedStringArray()

	for key in after:
		if before.get(key, -1) != after[key]:
			result.append(key)

	return result


class Entry extends RefCounted:
	var date := ""
	var title := ""
	var usec := 0
	# -1 when the map is too large to compare
	var changed_tiles := 0
	var changed_chunks := PackedStringArray()
	var error := ""

	func change_text() -> String:
		var tiles := "tiles not compared" if changed_tiles < 0 else "%d tiles changed" % changed_tiles
		var chunks := ", ".join(changed_chunks) if not changed_chunks.is_empty() else "none"

		return "%s; changed chunks: %s." % [tiles, chunks]
