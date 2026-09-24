class_name DebugCityTables
extends RefCounted
# Read the published city snapshot. Reuse cached scans; do not serialize or draw random values.

const Tiles = preload("res://src/tools/shared/building_tile_ids.gd")

const FACILITIES = BuildingCommand.DEFAULT_MICROSIM_LABELS
const STAT_LABELS := {
	Tiles.HOSPITAL: ["Score", "Patients", "Staff", "Half funding"],
	Tiles.POLICE_STATION: ["Funding", "Funded capacity", "Crime per tile", "Arrests"],
	Tiles.FIRE_STATION: ["Funding", "Funded capacity", "Capacity / 16 + 1", "Annual random statistic"],
	Tiles.SCHOOL: ["Score", "Students", "Staff", "Quarter funding"],
	Tiles.PRISON: ["Type-specific byte", "Prisoners", "Funded capacity", "Prisoners / 100"],
	Tiles.COLLEGE: ["Score", "Students", "Staff", "Funding"],
	Tiles.SUBWAY_STATION: ["Type-specific byte", "Subway tile count", "Preserved statistic", "Annual passengers"],
	Tiles.BUS_DEPOT: ["Type-specific byte", "Bus tile count / 4", "Bus tile count", "Annual passengers"],
	Tiles.RAIL_STATION: ["Type-specific byte", "Rail tile count / 4", "Preserved statistic", "Annual passengers"],
}
# state tab rows in record order, with their descriptions. the tab sorts them by name
const ENGINE_FIELDS := {
	"developed_tiles": "Number of tiles with a zone or a structure at the last data-map scan. The value is -1 before the first scan.",
	"power_usage_percent": "Percentage of the power capacity in use at the last power scan. The value is -1 before the first scan.",
	"water_usage_percent": "Percentage of the water capacity in use at the last water scan. The value is -1 before the first scan.",
	"commerce_connections": "Number of connections to neighbor cities that increase commercial demand.",
	"industry_connections": "Number of connections to neighbor cities that increase industrial demand.",
	"bus_passengers": "Number of bus passengers since the last yearly update. The yearly update gives this number to the bus depots.",
	"rail_passengers": "Number of rail passengers since the last yearly update. The yearly update gives this number to the rail stations.",
	"subway_passengers": "Number of subway passengers since the last yearly update. The yearly update gives this number to the subway stations.",
	"mayor_approval": "Mayor approval from the last query of the mayor's house.",
	"ship_home": "The tile where the cargo ship returns. The value is (-1, -1) when the city has no cargo ship.",
	"pending_interaction": "The player prompt that stops the current day, for example the yearly budget. The value is empty when there is no prompt.",
	"terminal_state": "True when the game ended because of bankruptcy or a scenario result. When true, the simulation stops.",
	"active_disaster_type": "The ID of the active disaster. The value is 0 when no disaster is active.",
	"pending_disaster_type": "The ID of the disaster that starts after the next simulation day. The value is 0 when no disaster waits.",
	"pending_disaster_point": "The tile where the pending disaster starts.",
	"unsupported_disaster_type": "The ID of a disaster that did not start because the game does not support it yet. The value is 0 when there is no such disaster.",
	"disaster_map_counter": "Countdown for the active disaster. Each disaster tick decreases it by one.",
	"disaster_hurricane_counter": "Countdown for the hurricane wind and floods. Each disaster tick decreases it by one.",
	"midi_playback_active": "True when music plays. The monthly music choice uses a random number only when this value is false.",
	"vehicle_crashes_enabled": "False when the player hides the vehicle layer. Airplanes and helicopters then leave the map and do not crash.",
	"traffic_news_deadline_msec": "The engine time in ms before which the traffic helicopter cannot give a new traffic report. 0 when there is no wait.",
}
# speed controller rows. the controller decides when a base tick runs a day
const CONTROLLER_FIELDS := {
	"subtick_counter": "Base tick counter from 0 to 7. The game speed selects the counter values that start a day.",
	"simulation_ready": "True when the next base tick runs a day.",
	"interaction_blocked": "True when a player prompt stops the simulation.",
	"terminal_blocked": "True when the game ended. The simulation then stops.",
	"fire_elapsed_msec": "Time in ms since the last fire disaster tick. During a fire or a firestorm, a disaster tick waits for 1000 ms.",
}
# the scenario goals in the order of ScenarioState.evaluate_goals. a limit goal fails above its value
const SCENARIO_GOALS := [
	["city_size", "city_size", "city_size_goal", false], ["residential", "residential", "residential_goal", false],
	["commercial", "commercial", "commercial_goal", false], ["industrial", "industrial", "industrial_goal", false],
	["cash", "cash_after_bonds", "cash_goal", false], ["land_value", "land_value", "land_value_goal", false],
	["life_expectancy", "life_expectancy", "life_expectancy_goal", false], ["education", "education", "education_goal", false],
	["pollution", "pollution", "pollution_limit", true], ["crime", "crime", "crime_limit", true],
	["traffic", "traffic", "traffic_limit", true],
]
const MILITARY_BASES := ["None", "Declined", "Army", "Air Force", "Navy", "Missile Silos"]
# tile counts of the last building scan, reused until the building plane changes
static var _tile_count_key: Array = []
static var _tile_counts := PackedInt32Array()
static var _tile_constants := _make_tile_constants()
const RANDOM_FIELDS := {
	"random": "The state of the main random number generator.",
	"game_random": "The state of the second random number generator.",
	"lfsr_random": "The state of the linear feedback shift register (LFSR) random number generator.",
}


static func collect(kind: String, city: CityState, engine: SimulationEngine = null, include_empty := false,
	controller: GameSpeedController = null) -> Array[DebugTableRecord]:
	var result: Array[DebugTableRecord] = []

	if city == null or not city.is_valid():
		return result

	match kind:
		"XMIC":
			var sites := city.microsim_sites()

			for id in city.microsim_count():
				var record := city.microsim(id)
				var tile := record.tile_id if record != null else 0
				if tile == BuildingTileIds.EMPTY and not include_empty:
					continue

				var fields: Array[DebugTableRecord] = []
				fields.append(_field("tile_id", tile, "Type"))
				var labels: Array = STAT_LABELS.get(tile, ["Type-specific byte", "Type-specific statistic", "Type-specific statistic", "Type-specific statistic"])

				for index in 4:
					fields.append(_field("stat_%d" % index, record.statistic(index) if record != null else 0,
						labels[index]))

				var value: String = "Empty" if tile == BuildingTileIds.EMPTY else FACILITIES.get(tile, "Facility 0x%02X" % tile)
				var label := city.label(OverlayData.facility_id(id))
				var site: CityRecords.Site = sites.get(id)
				var detail := "-" if label.is_empty() or label == value else label
				var row := DebugTableRecord.new()
				row.id = str(id)
				row.name = "Record %d" % id
				row.value = value
				row.raw = "0x%02X" % tile
				row.position = "Not on map" if site == null else "(%d, %d) %d×%d" % [site.x, site.y, site.width, site.height]
				row.site = site
				row.detail = detail
				# sort values per visible column, excluding the locate icon column
				row.sort = [id, value, tile, _site_sort(site), detail]
				row.empty = tile == BuildingTileIds.EMPTY
				row.fields = fields
				result.append(row)
		"Objects":
			for id in city.thing_count():
				var record := city.thing(id)

				if record.type == 0 and not include_empty:
					continue

				var table := DebugObjectFields.table_cells(id, record, city)
				var site := null if record.type == 0 or city.index_of(record.x, record.y) < 0 \
					else CityRecords.Site.new(record.x, record.y, 1, 1)
				var sort: Array = [id]

				for key: String in DebugObjectFields.COLUMNS:
					# translated columns sort by their visible text; the rest by stored value
					sort.append(table.cells[sort.size()] if key in DebugObjectFields.TRANSLATED else record.get(key))

				var row := DebugTableRecord.new()
				row.id = str(id)
				row.name = "Object %d" % id
				row.value = DebugObjectFields.type_name(record.type)
				row.raw = "(%d, %d, %d)" % [record.x, record.y, record.z]
				row.cells = table.cells
				row.tooltips = table.tooltips
				row.empty = record.type == 0
				row.site = site
				row.sort = sort
				var stored := DebugTableRecord.new()
				stored.cells = table.raw
				stored.tooltips = table.tooltips
				row.fields = [stored]
				result.append(row)

		"Tiles":
			var counts := tile_counts(city)

			for id in counts.size():
				var count := counts[id]

				var saved := city.document.misc_i32(Sc2MiscLayout.TILE_COUNTS + id * 4)

				if count == 0 and saved == 0 and not include_empty:
					continue

				var first := city.buildings.find(id) if count > 0 else -1
				var site := null if first < 0 else CityRecords.Site.new(first / city.map_size, first % city.map_size, 1, 1)
				var name := QueryStrings.tile_name(id)
				var row := DebugTableRecord.new()
				row.id = str(id)
				row.cells = ["%d (0x%02X)" % [id, id], _tile_constants[id], name, str(count), str(saved)]
				row.sort = [id, _tile_constants[id], name, count, saved]
				row.site = site
				row.empty = count == 0 and saved == 0

				if saved != count:
					row.warning = _count_difference(city, count, saved)

				result.append(row)

		"State":
			if engine != null:
				for key: String in ENGINE_FIELDS:
					result.append(_state_field(key, engine.get(key), ENGINE_FIELDS[key]))

				result.append_array(_engine_detail_rows(city, engine))

				if controller != null:
					result.append_array(_controller_rows(controller))

				result.append_array(_next_day_rows(city, engine))
				result.append_array(_scenario_rows(city, engine.scenario))

				# the random states stay last
				for key: String in RANDOM_FIELDS:
					var random: RefCounted = engine.get(key)

					if random != null:
						result.append(_state_field(key + ".state", random.get("state"), RANDOM_FIELDS[key]))

	return result


# records the game can use in a record table, or -1 for a table without a limit.
# the game never uses record 0 of XMIC or XTHG
static func record_limit(kind: String, city: CityState) -> int:
	if city == null:
		return -1

	match kind:
		"XMIC":
			return city.microsim_count() - 1
		"Objects":
			return city.thing_count() - 1

	return -1


# the number of tiles with each building id outside military zones. the result is shared; do not change it
static func tile_counts(city: CityState) -> PackedInt32Array:
	var key: Array = [city.get_instance_id(), city.chunk_revision("XBLD"), city.chunk_revision("XZON")]

	if key == _tile_count_key:
		return _tile_counts

	var counts := CityTileCounts.count(city)
	_tile_count_key = key
	_tile_counts = counts

	return counts


static func _count_difference(city: CityState, count: int, saved: int) -> String:
	var text := "The saved count is %d, but the map has %d.\n" % [saved, count]

	if CityTileCounts.exact(city):
		return text + "This SC2X city counts the map again at the start of each month. The next recount removes the difference."

	text += ("This city uses the original SimCity 2000 counts. Each tile change adds or subtracts one, and some changes skip " +
		"the count, so it drifts. Game rules use the saved count.")

	if city.map_size == 128 and saved >= 0x8000 and saved <= 0xffff:
		text += "\nThe count went below zero and wrapped as a 16-bit value. It is %d." % (saved - 0x10000)

	return text


# the first constant name for each building id. aliases follow the tile names
static func _make_tile_constants() -> PackedStringArray:
	var names := PackedStringArray()
	names.resize(Tiles.COUNT)
	var script: Script = Tiles
	var constants := script.get_script_constant_map()

	for key: String in constants:
		var value: Variant = constants[key]

		if value is int and value >= 0 and value < names.size() and names[value].is_empty():
			names[value] = key

	return names


# engine values that need a name or a calculation to be useful
static func _engine_detail_rows(city: CityState, engine: SimulationEngine) -> Array[DebugTableRecord]:
	var rows: Array[DebugTableRecord] = []
	var status := engine.city_status_resource_id
	var status_text := "Not set" if status < 0 else "%d: %s" % [status, CityStatusMessages.text(status)] if status > 0 else "0: None"
	rows.append(_state_field("city_status_resource_id", status_text,
		"The monthly status message from the weather and disaster day. The status bar shows this message."))
	var wait := maxi(engine.traffic_news_deadline_msec - Time.get_ticks_msec(), 0)
	rows.append(_state_field("traffic_news_wait_msec", wait, "Time in ms until the traffic helicopter can give a new traffic report."))
	var base := engine.pending_military_base_type
	var base_name: String = MILITARY_BASES[base] if base >= 0 and base < MILITARY_BASES.size() else "Unknown"
	rows.append(_state_field("pending_military_base_type", "%d: %s" % [base, base_name],
		"The military base type that the military notice shows. The value is 0 when no notice waits."))
	var site := engine.pending_military_site
	rows.append(_state_field("pending_military_site",
		"(%d, %d) %d×%d" % [site.position.x, site.position.y, site.size.x, site.size.y] if site.has_area() else "None",
		"The land that the game reserves for the base after the player closes the military notice."))
	var schedule := engine.pending_day_schedule
	var remaining := "None"

	if schedule != null:
		# the budget prompt stops the day before its first action. the military prompts stop it after milestones
		if engine.pending_interaction != "annual_budget":
			schedule = SimulationDaySchedule._schedule_after(engine, schedule, "milestones")

		remaining = "City day %d: %s" % [schedule.city_days, _action_list(city, schedule.actions)]

	rows.append(_state_field("pending_day_schedule", remaining,
		"The day that waits for the player prompt, and the actions that run after the player answers."))

	return rows


static func _controller_rows(controller: GameSpeedController) -> Array[DebugTableRecord]:
	var rows: Array[DebugTableRecord] = []

	for key: String in CONTROLLER_FIELDS:
		var value: Variant = controller.get(key)
		rows.append(_state_field("speed_controller." + key, int(value) if value is float else value, CONTROLLER_FIELDS[key]))

	var ticks: Variant = "Paused" if controller.speed == GameSpeedController.Speed.PAUSED else "Stopped" \
		if controller.interaction_blocked or controller.terminal_blocked else 1 if controller.simulation_ready else null

	for count in range(1, 9):
		if ticks == null and controller._is_day_due((controller.subtick_counter + count) & 7):
			ticks = count

	if ticks == null:
		ticks = "Unknown"

	rows.append(_state_field("speed_controller.base_ticks_to_next_day", ticks,
		"Number of 200 ms base ticks until the next day starts at the current speed."))

	return rows


# the day that the next day tick runs. a day that waits for a prompt shows in pending_day_schedule
static func _next_day_rows(city: CityState, engine: SimulationEngine) -> Array[DebugTableRecord]:
	var schedule := SimulationClock.state_for_day(engine.clock.city_days + 1)
	var partition := "None"

	if "growth" in schedule.actions:
		partition = "%d/16 (step %d, substep %d)" % [schedule.month_day - 2, schedule.growth_step, schedule.growth_substep]

	return [
		_state_field("next_day.city_days", schedule.city_days, "The city age in days after the next day."),
		_state_field("next_day.month_day", schedule.month_day + 1, "The day of the month for the next day, from 1 to 25."),
		_state_field("next_day.actions", _action_list(city, schedule.actions),
			"The actions that the next day runs. On a city with per-tile maps, power also runs pollution_coverage."),
		_state_field("next_day.growth_partition", partition, "The growth scan part that the next day runs. None on a day without growth."),
	]


# scenario goals with the current values. a row with an unmet goal has a warning
static func _scenario_rows(city: CityState, scenario: ScenarioState) -> Array[DebugTableRecord]:
	var rows: Array[DebugTableRecord] = []
	var active := scenario != null and scenario.is_valid()
	rows.append(_state_field("scenario.active", active, "True when the city has a scenario with goals and a time limit."))

	if not active:
		return rows

	rows.append(_state_field("scenario.months_left", scenario.time_limit_months,
		"Months until the scenario ends. The milestones day decreases it by one while a goal is not met."))
	var goals := scenario.evaluate_goals(city)

	if not goals.ok:
		return rows

	var targets: Array = SCENARIO_GOALS.duplicate()

	for pair in [["first_building", "first_building_tiles", "first_building_tile_count", "first_building_id"],
		["second_building", "second_building_tiles", "second_building_tile_count", "second_building_id"]]:
		if int(scenario.get(pair[3])) != BuildingTileIds.EMPTY:
			targets.append([pair[0], pair[1], pair[2], false])

	for goal: Array in targets:
		var required := int(scenario.get(goal[2]))
		var actual := int(goals.values.get(goal[1], 0))
		var text := "%d / %s" % [actual, ("no limit" if required <= 0 else "limit %d" % required) if goal[3] else str(required)]
		var row := _state_field("scenario.goal." + goal[0], text, ("The current value and the maximum for the scenario to succeed."
			if goal[3] else "The current value and the minimum for the scenario to succeed."))

		if goal[0] in goals.unmet:
			row.warning = "This goal is not met."

		rows.append(row)

	return rows


# schedule action names. power also runs pollution_coverage on a city with per-tile maps
static func _action_list(city: CityState, actions: PackedStringArray) -> String:
	var names := Array(actions)

	if "power" in names and city.document.full_resolution_maps():
		names.insert(names.find("power") + 1, "pollution_coverage")

	return ", ".join(names) if not names.is_empty() else "None"


# values sort in groups: numbers, then points, then other values as text.
# the hex column has no value for types other than numbers
static func _state_field(key: String, value: Variant, detail: String) -> DebugTableRecord:
	var result := _field(key, value, detail)
	var number: Variant = value if value is int else null
	var sort_value: Array = [0, value] if value is int else [1, value.x, value.y] if value is Vector2i else [2, str(value)]
	result.sort = [key, sort_value, number, detail]

	return result


static func _site_sort(site: CityRecords.Site) -> Variant:
	return null if site == null else [site.x, site.y, site.width * site.height]


static func _field(key: String, value: Variant, detail: String) -> DebugTableRecord:
	var result := DebugTableRecord.field(key, str(value),
		("-0x%X" % -value if value < 0 else "0x%X" % value) if value is int else "", detail)
	result.id = key

	return result
