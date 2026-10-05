extends SceneTree
## The example mods in examples/mods load and do what their comments say.

const AppFixture = preload("res://tests/support/app_fixture.gd")
const GameSpeed = preload("res://src/simulation/core/game_speed_controller.gd")
const Budget = preload("res://src/simulation/economy/budget_phase.gd")
const EXAMPLES := "res://../examples/mods"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var main := (load("res://main.tscn") as PackedScene).instantiate() as CityApplication
	AppFixture.configure(main)
	root.add_child(main)
	await process_frame
	main.city_files._load_city_unchecked(GeneratedCityFixture.path(128))
	main.frame.select_speed(GameSpeed.Speed.PAUSED)
	var city := main.document_state.city

	for file in ["yearly-grant.js", "disaster-response.js", "city-stats/main.mjs", "protected-zones.mjs", "road-grid.js",
			"tax-advisor.js"]:
		assert(main.scripting.run_file(ProjectSettings.globalize_path(EXAMPLES.path_join(file))), "%s runs" % file)

	_check_grant(main, city)
	_check_disaster_response(main)
	_check_stats(main)
	_check_protected_zones(main, city)
	_check_road_grid(main, city)
	_check_tax_advisor(main, city)
	main.queue_free()
	await process_frame
	print("PASS: example mods")
	quit()


func _command(main: CityApplication, line: String) -> String:
	main.console_window.commands.execute(line)
	var entries := ConsoleLog.entries_since(0)

	return entries[-1].text if not entries.is_empty() else ""


func _check_grant(main: CityApplication, city: CityState) -> void:
	var funds := city.funds()
	main.scripting.emit("sim.year", {"year": 2056})
	assert(city.funds() == funds + 1000, "The grant arrives each year")
	assert(_command(main, "grant 2500") == "The yearly grant is now $2500.")
	main.scripting.emit("sim.year", {"year": 2057})
	assert(city.funds() == funds + 3500, "The new amount is paid")


func _check_disaster_response(main: CityApplication) -> void:
	main.frame.select_speed(GameSpeed.Speed.LLAMA)
	main.console_window.commands.execute("sim.startDisaster('Fire', 64, 64)")
	assert(main.simulation_state.speed_controller.speed == GameSpeed.Speed.PAUSED, "A disaster pauses the game")
	var alert := main.scripting.api.ui_api.last_alert
	assert(alert != null and alert.title == "Emergency", "A message window explains the pause")
	alert.hide()
	main.console_window.commands.execute("sim.endDisaster()")
	assert(ConsoleLog.entries_since(0).any(func(entry: ConsoleLog.Entry) -> bool: return entry.text.begins_with("Fire ended.")))


func _check_stats(main: CityApplication) -> void:
	assert(_command(main, "stats clear") == "The statistics history is empty.")
	main.scripting.emit("sim.month", {"year": 2056, "month": 2})
	var table := _command(main, "stats")
	assert(table.split("\n").size() == 3 and table.split("\n")[0].contains("Month") and table.split("\n")[0].contains("Population"),
		"Each month adds a row: " + table)


func _check_protected_zones(main: CityApplication, city: CityState) -> void:
	assert(_command(main, "protect 10 10 20 20").begins_with("Protected zone 1 protects"))
	main.console_window.commands.execute("tools.select('Bulldozer', 'Demolish')")
	var original := city.document.serialize().data
	main.console_window.commands.execute("tools.apply([15, 15]).cancelled")
	assert(ConsoleLog.entries_since(0)[-1].text == "true" and city.document.serialize().data == original,
		"The bulldozer cannot change a protected zone")
	assert(_command(main, "unprotect") == "All zones are unprotected.")


func _check_road_grid(main: CityApplication, city: CityState) -> void:
	var funds := city.funds()
	var report := _command(main, "grid 30 30 10 10 5")
	assert(report.begins_with("Built 6 roads for $"), report)
	assert(city.funds() == funds - int(report.get_slice("$", 1).trim_suffix(".")), "The grid cost matches the funds")
	assert(main.tool_state.selected_group == CityToolIds.Group.BULLDOZER, "The grid restores the selected tool")


func _check_tax_advisor(main: CityApplication, city: CityState) -> void:
	var before := Budget.funding_values(city)
	var demand := city.rci_demand()
	main.scripting.emit("sim.month", {"year": 2056, "month": 3})
	var after := Budget.funding_values(city)

	for pair in [[Sc2BudgetLayout.RESIDENTIAL, demand.x], [Sc2BudgetLayout.COMMERCIAL, demand.y], [Sc2BudgetLayout.INDUSTRIAL, demand.z]]:
		var rate: int = before[pair[0]]
		var expected := mini(12, rate + 1) if pair[1] > 500 else (maxi(5, rate - 1) if pair[1] < -500 else rate)
		assert(after[pair[0]] == expected, "The advisor moves each tax rate one point toward the demand")
