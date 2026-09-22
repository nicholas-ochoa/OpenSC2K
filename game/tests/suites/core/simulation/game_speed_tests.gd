extends "res://tests/support/core_test_suite.gd"

## Simulation: game speed checks.

@warning_ignore_start("integer_division")

const Budget = preload("res://src/simulation/economy/budget_phase.gd")
const DisasterStart = preload("res://src/simulation/disasters/disaster_start_phase.gd")
const Simulation = preload("res://src/simulation/core/simulation_engine.gd")
const GameSpeed = preload("res://src/simulation/core/game_speed_controller.gd")


func test_game_speed_controller(reference_root: String) -> void:
	var paused_document := _load_fixture(reference_root.path_join("CITIES/STARTER.SC2"))
	var paused_city := CityModel.from_document(paused_document)
	_check(paused_city.simulation_speed() == 1, "STARTER stores the paused simulation speed")
	_check(paused_city.set_age_in_days(0), "Speed fixture resets the city day")
	var paused_engine := Simulation.new(paused_city, 1, 7, 13)
	var paused := GameSpeed.new(paused_engine)
	_check(paused.speed == GameSpeed.Speed.PAUSED, "Speed controller loads the saved speed")
	var paused_result := paused.advance_time(1600.0, 1600)
	_check(paused_result.ok and paused_result.base_ticks == 8, "Pause retains the 200 ms base timer")
	_check(
		paused_result.day_results.is_empty() and paused_result.moving_results.is_empty(),
		"Pause stops days and moving things",
	)
	_check(paused.simulation_ready and paused_city.age_in_days() == 0, "Pause retains a pending day")
	_check(not paused.set_speed(0) and not paused.set_speed(6), "Speed rejects invalid values")
	_check(paused.set_speed(GameSpeed.Speed.TURTLE), "Speed changes to Turtle")
	_check(paused_city.simulation_speed() == 2, "Speed changes update the saved MISC field")
	var resumed := paused.advance_time(0.0, 1600)
	_check(
		resumed.ok and resumed.day_results.size() == 1 and paused_city.age_in_days() == 1,
		"Turtle consumes a day that became ready during pause",
	)
	var turtle_early := paused.advance_time(799.0, 2399)
	_check(
		turtle_early.base_ticks == 3
		and turtle_early.moving_results.size() == 3
		and turtle_early.day_results.is_empty(),
		"Turtle waits for four base ticks",
	)
	var turtle_due := paused.advance_time(1.0, 2400)
	_check(
		turtle_due.base_ticks == 1
		and turtle_due.moving_results.size() == 1
		and turtle_due.day_results.size() == 1
		and paused_city.age_in_days() == 2,
		"Turtle advances one day every 800 ms",
	)

	var llama_city := CityModel.from_document(_load_fixture(reference_root.path_join("DEFAULT.SC2")))
	_check(llama_city.set_age_in_days(0), "Llama fixture resets the city day")
	_check(llama_city.set_simulation_speed(3), "Llama fixture stores its speed")
	var llama := GameSpeed.new(Simulation.new(llama_city, 1, 7, 13))
	var llama_early := llama.advance_time(399.0, 399)
	_check(
		llama_early.base_ticks == 1 and llama_early.day_results.is_empty(),
		"Llama waits for two base ticks",
	)
	var llama_due := llama.advance_time(1.0, 400)
	_check(
		llama_due.day_results.size() == 1 and llama_city.age_in_days() == 1,
		"Llama advances one day every 400 ms",
	)

	var cheetah_city := CityModel.from_document(_load_fixture(reference_root.path_join("DEFAULT.SC2")))
	_check(cheetah_city.set_age_in_days(0), "Cheetah fixture resets the city day")
	_check(cheetah_city.set_simulation_speed(4), "Cheetah fixture stores its speed")
	var cheetah := GameSpeed.new(Simulation.new(cheetah_city, 1, 7, 13))
	var cheetah_due := cheetah.advance_time(200.0, 200)
	_check(
		cheetah_due.moving_results.size() == 1
		and cheetah_due.day_results.size() == 1
		and cheetah_city.age_in_days() == 1,
		"Cheetah advances moving things and one day every 200 ms",
	)
	var cheetah_suspended := cheetah.advance_time(200.0, 400, true)
	_check(
		cheetah_suspended.base_ticks == 1
		and cheetah_suspended.moving_results.is_empty()
		and cheetah_suspended.day_results.is_empty()
		and cheetah.simulation_ready,
		"A map drag keeps timer phase but suspends simulation work",
	)
	var cheetah_resumed := cheetah.advance_time(0.0, 400)
	_check(
		cheetah_resumed.day_results.size() == 1 and cheetah_city.age_in_days() == 2,
		"Simulation consumes the ready day after a map drag",
	)

	var swallow_city := CityModel.from_document(_load_fixture(reference_root.path_join("DEFAULT.SC2")))
	_check(swallow_city.set_age_in_days(0), "Swallow fixture resets the city day")
	_check(swallow_city.set_simulation_speed(5), "Swallow fixture stores its speed")
	var swallow := GameSpeed.new(Simulation.new(swallow_city, 1, 7, 13))
	var swallow_due := swallow.advance_time(200.0, 200)
	_check(
		swallow_due.day_results.size() == 1 and swallow_city.age_in_days() == 1,
		"African Swallow advances on the 200 ms timer",
	)
	var swallow_idle := swallow.advance_time(0.0, 200)
	_check(
		swallow_idle.moving_results.is_empty()
		and swallow_idle.day_results.size() == 1
		and swallow_city.age_in_days() == 2,
		"African Swallow advances again on the next idle cycle",
	)

	var island_city := CityModel.from_document(
		_load_fixture(reference_root.path_join("CITIES/ISLAND.SC2"))
	)
	var island_start_day := island_city.age_in_days()
	_check(island_city.set_simulation_speed(4), "Island unpause fixture selects Cheetah")
	var island_controller := GameSpeed.new(Simulation.new(island_city, 1, 7, 13))
	var island_ticks_ok := true

	for tick in 25:
		var island_tick := island_controller.advance_time(200.0, (tick + 1) * 200)

		if not island_tick.ok:
			island_ticks_ok = false
			break

	_check(
		island_ticks_ok and island_city.age_in_days() >= island_start_day + 25,
		"Island runs 25 Cheetah ticks after unpause without a script or simulation error",
	)

	var refresh_city := CityModel.from_document(_load_fixture(reference_root.path_join("DEFAULT.SC2")))
	_check(refresh_city.set_age_in_days(22), "Controller refresh fixture selects day 22")
	_check(refresh_city.set_simulation_speed(4), "Controller refresh fixture stores Cheetah speed")
	_check(refresh_city.document.set_misc_u32(0x001c, 1), "Controller refresh fixture selects Easy")
	_check(refresh_city.document.set_misc_u32(0x1000, 1), "Controller refresh fixture disables disasters")
	var refresh_controller := GameSpeed.new(Simulation.new(refresh_city, 1, 7, 13))
	var statistics_refresh := refresh_controller.advance_time(200.0, 200)
	_check(
		statistics_refresh.ok
		and statistics_refresh.refresh_requests == ["population", "industries", "graphs"],
		"Controller forwards the day-23 statistics refresh requests",
	)
	var map_refresh := refresh_controller.advance_time(200.0, 400)
	_check(
		map_refresh.ok
		and map_refresh.refresh_requests == ["toolbar", "map", "simnation", "weather_disaster"],
		"Controller deduplicates and forwards the day-24 refresh requests",
	)

	var music_city := CityModel.from_document(
		_load_fixture(reference_root.path_join("DEFAULT.SC2"))
	)
	_check(
		music_city.set_age_in_days(20)
		and music_city.set_simulation_speed(GameSpeed.Speed.TURTLE)
		and music_city.set_music_enabled(false),
		"Controller MIDI fixture selects an inactive day-21 gate",
	)
	var music_controller := GameSpeed.new(Simulation.new(music_city, 3, 7, 13))
	music_controller.simulation_ready = true
	var music_tick := music_controller.advance_time(0.0, 0)
	_check(
		music_tick.ok
		and music_tick.day_results.size() == 1
		and music_tick.music_track_requests == PackedInt32Array([10014]),
		"Controller forwards a monthly MIDI track request",
	)

	var budget_city := CityModel.from_document(_load_fixture(reference_root.path_join("DEFAULT.SC2")))
	_check(budget_city.set_age_in_days(24), "Controller budget fixture selects day 24")
	_check(budget_city.set_simulation_speed(4), "Controller budget fixture stores Cheetah speed")
	_check(budget_city.set_funds(100000), "Controller budget fixture sets ordinance funds")
	_check(budget_city.document.set_misc_u32(0x0fa0, 0), "Controller budget fixture clears ordinances")
	_check(budget_city.document.set_misc_u32(0x1000, 0), "Controller budget fixture enables random events")
	var budget_controller := GameSpeed.new(Simulation.new(budget_city, 3, 7, 13))
	var budget_tick := budget_controller.advance_time(200.0, 200)
	_check(
		budget_tick.ok
		and budget_tick.day_results.size() == 1
		and budget_tick.news_items.size() == 1
		and budget_tick.news_items[0].type == 0x29
		and budget_tick.news_items[0].argument == 14,
		"Controller forwards monthly ordinance news",
	)

	var annual_city := CityModel.from_document(_load_fixture(reference_root.path_join("DEFAULT.SC2")))
	_check(annual_city.set_age_in_days(299), "Controller annual fixture selects the last day")
	_check(annual_city.set_simulation_speed(4), "Controller annual fixture stores Cheetah speed")
	_check(annual_city.document.set_misc_u32(0x0e3c, 1), "Controller annual fixture sets year end")
	_check(annual_city.document.set_misc_u32(0x0ff0, 0), "Controller annual fixture disables Auto Budget")
	var annual_controller := GameSpeed.new(Simulation.new(annual_city, 1, 7, 13))
	var annual_request := annual_controller.advance_time(200.0, 200)
	_check(
		annual_request.ok
		and annual_request.interaction_requests.size() == 1
		and annual_controller.interaction_blocked,
		"Controller blocks on the annual budget interaction",
	)
	var blocked_tick := annual_controller.advance_time(200.0, 400)
	_check(
		blocked_tick.ok
		and blocked_tick.base_ticks == 1
		and blocked_tick.day_results.is_empty()
		and blocked_tick.moving_results.is_empty(),
		"Annual budget interaction retains timer phase and suspends work",
	)
	var annual_resolution := annual_controller.resolve_annual_budget(
		annual_request.interaction_requests[0].funding_values, false
	)
	_check(
		annual_resolution.ok
		and not annual_controller.interaction_blocked
		and annual_resolution.day_results.size() == 1,
		"Controller resumes after annual budget resolution",
	)

	var military_city := CityModel.from_document(_load_fixture(reference_root.path_join("DEFAULT.SC2")))
	_check(military_city.set_age_in_days(21), "Controller military fixture selects day 21")
	_check(military_city.set_simulation_speed(4), "Controller military fixture stores Cheetah speed")
	_check(military_city.document.set_misc_u32(0x0020, 3), "Controller military fixture sets progression")
	_check(military_city.document.set_misc_u32(0x102c, 60001), "Controller military fixture sets population")
	var military_controller := GameSpeed.new(Simulation.new(military_city, 1, 7, 13))
	var military_request := military_controller.advance_time(200.0, 200)
	_check(
		military_request.ok
		and military_request.interaction_requests.size() == 1
		and military_controller.interaction_blocked,
		"Controller blocks on the military proposal interaction",
	)
	var military_resolution := military_controller.resolve_military_proposal(false)
	_check(
		military_resolution.ok
		and not military_controller.interaction_blocked
		and military_resolution.day_results.size() == 1
		and military_resolution.pending_actions.is_empty(),
		"Controller resumes after the military decision",
	)

	var monster_city := CityModel.from_document(_load_fixture(reference_root.path_join("SCENARIO/ATLANTA.SCN")))
	_check(monster_city.set_age_in_days(0), "Controller monster scenario fixture resets the day")
	_check(monster_city.set_simulation_speed(4), "Controller monster scenario fixture stores Cheetah speed")
	var monster_controller := GameSpeed.new(Simulation.new(monster_city, 1, 7, 13))
	var monster_start := monster_controller.advance_time(200.0, 200)
	_check(
		monster_start.ok
		and monster_start.day_results.size() == 1
		and (SoundEvent.count_plain(monster_start.sound_events, DisasterStart.SOUND_SIREN) > 0)
		and not monster_start.view_center_requests.is_empty(),
		"Controller forwards scenario monster start effects",
	)
	var monster_tick := monster_controller.advance_time(200.0, 400)
	_check(
		monster_tick.ok
		and monster_tick.moving_results.size() == 1
		and monster_tick.disaster_results.size() == 1
		and monster_city.age_in_days() == 1,
		"Controller updates an active monster without advancing the calendar",
	)

	var terminal_city := CityModel.from_document(_load_fixture(reference_root.path_join("DEFAULT.SC2")))
	_check(terminal_city.set_age_in_days(21), "Terminal fixture selects day 21")
	_check(terminal_city.set_simulation_speed(4), "Terminal fixture stores Cheetah speed")
	_check(terminal_city.document.set_misc_u32(0x0020, 10), "Terminal fixture exhausts milestones")
	_check(terminal_city.set_funds(-100001), "Terminal fixture sets bankrupt funds")
	var terminal_controller := GameSpeed.new(Simulation.new(terminal_city, 1, 7, 13))
	var terminal_tick := terminal_controller.advance_time(200.0, 200)
	_check(
		terminal_tick.ok
		and terminal_tick.game_over_events.size() == 1
		and terminal_tick.game_over_events[0].type == "bankruptcy"
		and terminal_controller.terminal_blocked,
		"Controller exposes bankruptcy and enters terminal state",
	)
	var terminal_wait := terminal_controller.advance_time(200.0, 400)
	_check(
		terminal_wait.ok
		and terminal_wait.base_ticks == 1
		and terminal_wait.day_results.is_empty()
		and terminal_wait.moving_results.is_empty(),
		"Terminal state keeps timer phase and stops simulation work",
	)
