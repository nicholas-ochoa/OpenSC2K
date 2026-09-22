extends "res://tests/support/core_test_suite.gd"

## Simulation: clock engine checks.

@warning_ignore_start("integer_division")

const Clock = preload("res://src/simulation/core/simulation_clock.gd")
const WeatherDisaster = preload("res://src/simulation/disasters/weather_disaster_phase.gd")
const SimNation = preload("res://src/simulation/civic/simnation_phase.gd")
const Budget = preload("res://src/simulation/economy/budget_phase.gd")
const MilitaryProposal = preload("res://src/simulation/civic/military_proposal_phase.gd")
const DisasterStart = preload("res://src/simulation/disasters/disaster_start_phase.gd")
const Growth = preload("res://src/simulation/growth/phase/constants.gd")
const Simulation = preload("res://src/simulation/core/simulation_engine.gd")
const GameSpeed = preload("res://src/simulation/core/game_speed_controller.gd")


func test_simulation_clock() -> void:
	var clock := Clock.new(0)
	var phases: Array[SimulationSchedule] = []

	for unused in 25:
		phases.append(clock.advance_day())

	_check(phases[0].month_day == 1, "First simulation tick advances to day 1")
	_check(phases[0].actions == PackedStringArray(["power"]), "Day 1 schedules power")

	for month_day in range(3, 19):
		var phase := phases[month_day - 1]
		_check(phase.actions == PackedStringArray(["growth"]), "Day %d schedules growth" % month_day)
		_check(
			phase.growth_step == int((month_day - 3) / 4) % 4,
			"Day %d has the correct growth step" % month_day
		)
		_check(
			phase.growth_substep == (month_day + 1) % 4,
			"Day %d has the correct growth substep" % month_day
		)

	_check(phases[18].actions == PackedStringArray(["traffic"]), "Day 19 schedules traffic")
	_check(phases[19].actions == PackedStringArray(["water"]), "Day 20 schedules water")
	_check(phases[24].month_day == 0, "The 25th tick starts the next month")
	_check(
		phases[24].actions == PackedStringArray(["budget", "month_start"]),
		"Month start schedules budget work"
	)


func test_simulation_engine(reference_root: String) -> void:
	var document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))
	var city := CityModel.from_document(document)
	_check(city.set_age_in_days(0), "Simulation engine test resets the city day")
	_check(document.set_misc_u32(0x001c, 1), "Simulation engine fixture selects Easy")
	_check(document.set_misc_u32(0x1000, 1), "Simulation engine fixture disables random disasters")
	var engine := Simulation.new(city, 1, 7)
	engine.midi_playback_active = true
	_check(engine.lfsr_random.state == 7, "Simulation engine accepts an explicit LFSR seed")
	var day_one := engine.advance_day()
	_check(day_one.ok, "Simulation engine advances day one")
	_check(day_one.day == 1 and city.age_in_days() == 1, "Simulation engine stores the new day")
	_check(day_one.applied == PackedStringArray(["power"]), "Simulation engine applies power on day one")
	_check(day_one.pending.is_empty(), "Day one has no unimplemented scheduled phase")
	_check(engine.lfsr_random.state == 7, "Non-growth phases preserve the LFSR state")
	var day_two := engine.advance_day()
	_check(day_two.ok, "Simulation engine advances day two")
	_check(
		day_two.applied == PackedStringArray(["pollution_terrain_land_value"]),
		"Simulation engine applies the combined day-two scan"
	)
	_check(day_two.pending.is_empty(), "Day two has no unimplemented scheduled phase")
	_check(engine.developed_tiles >= 0, "Simulation engine retains the developed-tile count")
	_check(
		SimulationDaySchedule.scanned_data_maps_only(day_two)
		and not SimulationDaySchedule.scanned_data_maps_only(day_one),
		"Only the data-map scan day reports data-map work alone",
	)
	var day_three := engine.advance_day()
	_check(day_three.ok, "Simulation engine advances the first growth day")
	_check(day_three.phase_results.has("growth"), "Simulation engine runs the RCI growth core")
	_check(
		day_three.applied == PackedStringArray(["growth"]) and day_three.pending.is_empty(),
		"Simulation engine completes the full growth partition",
	)
	_check(engine.lfsr_random.state != 7, "Growth continues the engine LFSR sequence")
	_check(
		not SimulationDaySchedule.scanned_data_maps_only(day_three),
		"A growth day does not report data-map work alone",
	)
	var latest := day_three

	while latest.day < 19:
		latest = engine.advance_day()

	_check(latest.applied == PackedStringArray(["traffic"]), "Simulation engine applies traffic on day 19")
	_check(latest.pending.is_empty(), "Day 19 has no unimplemented scheduled phase")
	latest = engine.advance_day()
	_check(latest.applied == PackedStringArray(["water"]), "Simulation engine applies water on day 20")
	_check(latest.pending.is_empty(), "Day 20 has no unimplemented scheduled phase")
	latest = engine.advance_day()
	_check(
		latest.applied == PackedStringArray(["rci_demand", "education_health", "graphs"]),
		"Simulation engine applies demand, demographics, and graphs on day 21",
	)
	_check(
		latest.phase_results.has("rci_aftermath")
		and latest.phase_results.rci_aftermath.weather_trend >= 0,
		"Simulation engine runs monthly ecology, news, inventions, and weather after demand",
	)
	_check(
		latest.phase_results.has("music")
		and latest.phase_results.music.playback_was_active
		and not latest.phase_results.music.selection_attempted
		and latest.phase_results.music.music_track_requests.is_empty(),
		"Active MIDI skips the monthly random gate without a track request",
	)
	_check(
		latest.phase_results.has("simnation")
		and latest.phase_results.simnation.national_population >= 0,
		"Simulation engine runs SimNation before demographics",
	)
	_check(
		latest.phase_results.has("industries")
		and latest.phase_results.industries.mix_bonus >= 0,
		"Simulation engine runs individual industries before demographics",
	)
	_check(latest.pending.is_empty(), "Day 21 has no unimplemented scheduled phase")
	latest = engine.advance_day()
	_check(latest.phase_results.has("milestones"), "Simulation engine runs milestones on day 22")
	_check(
		latest.applied == PackedStringArray(["milestones", "scenario", "bankruptcy"])
		and latest.pending.is_empty(),
		"Simulation engine applies all normal day-22 checks",
	)
	latest = engine.advance_day()
	_check(
		latest.day == 23
		and latest.applied == PackedStringArray(["statistics_windows"])
		and latest.pending.is_empty()
		and latest.phase_results.statistics_windows.refresh_requests
		== ["population", "industries", "graphs"],
		"Simulation engine completes the day-23 statistics refresh",
	)
	latest = engine.advance_day()
	_check(
		latest.day == 24
		and latest.applied == PackedStringArray(["map", "simnation", "weather_disaster"])
		and latest.pending.is_empty()
		and latest.phase_results.weather_disaster.status_index >= -1
		and latest.phase_results.weather_disaster.disaster_type == WeatherDisaster.DISASTER_NONE,
		"Simulation engine completes the map, SimNation, status, and disaster work on day 24",
	)
	latest = engine.advance_day()
	_check(
		latest.applied == PackedStringArray(["budget", "month_start"]),
		"Simulation engine applies budget before month start on day 25",
	)
	_check(latest.pending.is_empty(), "Normal month-start budget work is complete")
	_check(latest.phase_results.has("budget"), "Simulation engine exposes the budget result")

	var silent_document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))
	var silent_city := CityModel.from_document(silent_document)
	_check(
		silent_city.set_age_in_days(20)
		and silent_city.set_simulation_speed(GameSpeed.Speed.TURTLE)
		and silent_city.set_music_enabled(false),
		"Monthly MIDI fixture selects day 21 with music disabled",
	)
	var silent_engine := Simulation.new(silent_city, 3, 7, 13)
	var silent_day := silent_engine.advance_day()
	_check(
		silent_day.ok
		and silent_day.phase_results.music.selection_attempted
		and not silent_day.phase_results.music.playback_was_active
		and silent_day.phase_results.music.music_track_requests
		== PackedInt32Array([10014])
		and not silent_engine.midi_playback_active,
		"Inactive monthly MIDI consumes the process RNG and requests the selected track",
	)

	var annual_document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))
	var annual_city := CityModel.from_document(annual_document)
	_check(annual_city.set_age_in_days(299), "Annual engine fixture selects the last day")
	_check(annual_document.set_misc_u32(0x0e3c, 1), "Annual engine fixture sets year end")
	_check(annual_document.set_misc_u32(0x0ff0, 0), "Annual engine fixture disables auto budget")
	var annual_engine := Simulation.new(annual_city, 1, 7, 13)
	annual_engine.bus_passengers = 11
	annual_engine.rail_passengers = 12
	annual_engine.subway_passengers = 13
	var annual_request := annual_engine.advance_day()
	_check(
		annual_request.ok
		and annual_request.day == 300
		and annual_request.interaction_requests.size() == 1
		and annual_request.interaction_requests[0].type == "annual_budget",
		"Simulation engine defers a manual annual budget",
	)
	var rejected_advance := annual_engine.advance_day()
	_check(
		not rejected_advance.ok and annual_city.age_in_days() == 300,
		"Simulation engine cannot skip a pending annual budget",
	)
	var annual_resolution := annual_engine.resolve_annual_budget(
		annual_request.interaction_requests[0].funding_values, true
	)
	_check(annual_resolution.ok, "Simulation engine resolves the annual budget")
	_check(
		annual_resolution.applied == PackedStringArray(["budget", "month_start"])
		and annual_resolution.pending.is_empty(),
		"Annual resolution completes the budget and microsimulation work",
	)
	_check(annual_document.misc_u32(0x0ff0) == 1, "Annual resolution stores Auto Budget")
	_check(
		annual_resolution.phase_results.has("annual_microsim")
		and annual_resolution.phase_results.annual_microsim.complete,
		"Annual resolution runs the facility-statistics phase",
	)
	_check(
		annual_engine.bus_passengers == 0
		and annual_engine.rail_passengers == 0
		and annual_engine.subway_passengers == 0,
		"Annual resolution clears the engine passenger counters",
	)

	var military_document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))
	_check(_clear_news_records(military_document), "Military engine fixture clears story records")
	var military_city := CityModel.from_document(military_document)
	_check(military_city.set_age_in_days(21), "Military engine fixture selects day 21")
	_check(military_document.set_misc_u32(0x0020, 3), "Military engine fixture sets progression")
	_check(military_document.set_misc_u32(0x102c, 60001), "Military engine fixture sets population")
	_check(military_city.set_funds(-100001), "Military engine fixture sets bankrupt funds")
	var military_engine := Simulation.new(military_city, 1, 7, 13)
	var military_request := military_engine.advance_day()
	_check(
		military_request.ok
		and military_request.day == 22
		and military_request.interaction_requests.size() == 1
		and military_request.interaction_requests[0].type == "military_proposal"
		and military_request.pending == PackedStringArray(["milestones", "scenario", "bankruptcy"]),
		"Simulation engine blocks the remaining day-22 checks on a military proposal",
	)
	_check(
		not military_engine.terminal_state and military_document.misc_u32(0x0020) == 4,
		"The pending proposal stores its milestone but defers bankruptcy",
	)
	var milestone_story := NewsQueue.story_record(
		military_document.find_chunk("MISC").decoded_payload, 0
	)
	_check(
		military_request.phase_results.milestones.news_queue_updated
		and milestone_story.type == 3
		and milestone_story.priority == 1000
		and milestone_story.argument == 3,
		"The engine stores milestone news before its military interaction",
	)
	var rejected_military_advance := military_engine.advance_day()
	_check(
		not rejected_military_advance.ok and military_city.age_in_days() == 22,
		"Simulation engine cannot skip a pending military proposal",
	)
	var military_resolution := military_engine.resolve_military_proposal(false)
	_check(
		military_resolution.ok
		and military_resolution.applied == PackedStringArray(["milestones", "scenario", "bankruptcy"])
		and military_resolution.pending.is_empty()
		and military_resolution.phase_results.military_proposal.base_type == MilitaryProposal.BASE_DECLINED,
		"A military decision resumes and completes the day-22 schedule",
	)
	_check(
		military_engine.terminal_state
		and military_resolution.phase_results.bankruptcy.game_over_events.size() == 1,
		"Deferred bankruptcy runs after the military decision",
	)

	var monster_scenario_document := _load_fixture(reference_root.path_join("SCENARIO/ATLANTA.SCN"))
	var monster_scenario_city := CityModel.from_document(monster_scenario_document)
	_check(monster_scenario_city.set_age_in_days(0), "Monster scenario engine fixture resets the day")
	_check(monster_scenario_document.set_misc_u32(0x0004, 1), "Monster scenario engine fixture selects city mode")
	var monster_scenario_engine := Simulation.new(monster_scenario_city, 1, 7, 13)
	var monster_start := monster_scenario_engine.advance_day()
	_check(
		monster_start.ok
		and monster_start.phase_results.has("disaster_start")
		and monster_start.phase_results.disaster_start.disaster_type == DisasterStart.DISASTER_MONSTER
		and monster_start.phase_results.disaster_start.started
		and monster_scenario_engine.active_disaster_type == DisasterStart.DISASTER_MONSTER,
		"A scenario starts its queued monster after the first calendar tick",
	)
	_check(
		monster_scenario_city.city_mode() == 2
		and monster_scenario_city.disaster_type() == 0,
		"A started scenario disaster clears the trigger and stores disaster mode",
	)
	var blocked_disaster_day := monster_scenario_engine.advance_day()
	_check(
		not blocked_disaster_day.ok and monster_scenario_city.age_in_days() == 1,
		"An active scenario disaster blocks direct calendar advancement",
	)
	var monster_things := _filled_bytes(CityState.THING_COUNT * CityState.THING_RECORD_SIZE, 0)
	_check(monster_scenario_document.find_chunk("XTHG").set_decoded_payload(monster_things), "Monster scenario fixture ends the moving object")
	var ended_monster := monster_scenario_engine.advance_disaster_tick()
	_check(
		ended_monster.ok
		and ended_monster.complete
		and ended_monster.ended_type == DisasterStart.DISASTER_MONSTER
		and monster_scenario_engine.active_disaster_type == 0
		and monster_scenario_city.city_mode() == 1,
		"The disaster controller restores city mode after the monster ends",
	)

	var crash_scenario_document := _load_fixture(reference_root.path_join("SCENARIO/CHARLEST.SCN"))
	var crash_scenario_data: PackedByteArray = (
		crash_scenario_document.find_chunk("SCEN").decoded_payload.duplicate()
	)
	crash_scenario_data[0x04] = 0
	crash_scenario_data[0x05] = DisasterStart.DISASTER_HELICOPTER_CRASH
	_check(
		crash_scenario_document.find_chunk("SCEN").set_decoded_payload(
			crash_scenario_data
		),
		"Crash scenario fixture selects the helicopter crash wrapper",
	)
	var crash_scenario_city := CityModel.from_document(crash_scenario_document)
	_check(crash_scenario_city.set_age_in_days(0), "Crash scenario fixture resets the day")
	var crash_scenario_engine := Simulation.new(crash_scenario_city, 1, 7, 13)
	var crash_start := crash_scenario_engine.advance_day()
	_check(
		crash_start.ok
		and crash_start.applied.has("disaster_start")
		and crash_scenario_engine.active_disaster_type
		== DisasterStart.DISASTER_HELICOPTER_CRASH
		and crash_scenario_city.city_mode() == 2,
		"A scheduled no-op crash wrapper enters disaster mode",
	)
	var crash_end := crash_scenario_engine.advance_disaster_tick()
	_check(
		crash_end.ok
		and crash_end.complete
		and crash_scenario_engine.active_disaster_type == 0
		and crash_scenario_city.city_mode() == 1,
		"A no-op crash wrapper ends on the next eligible disaster tick",
	)
