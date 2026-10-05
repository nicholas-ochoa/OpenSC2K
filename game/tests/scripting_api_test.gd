extends SceneTree
## The game API of scripts beyond the basics: the budget, ordinances and
## bonds, data maps, graphs, signs, moving objects, the city name, the view,
## disasters, message windows, sounds and storage, with their events.

const AppFixture = preload("res://tests/support/app_fixture.gd")
const GameSpeed = preload("res://src/simulation/core/game_speed_controller.gd")
const Budget = preload("res://src/simulation/economy/budget_phase.gd")


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
	_eval(main, "globalThis.seen = []; game.on('*', (e) => seen.push(e.type))")

	_check_budget(main, city)
	_check_city_data(main, city)
	_check_city_edits(main, city)
	_check_view_and_simulation(main, city)
	_check_ui_and_storage(main)
	main.queue_free()
	await process_frame
	print("PASS: script budget, ordinances, bonds, data maps, graphs, signs, things, name, view, disasters, windows and storage")
	quit()


# runs console input and returns the text of the newest console line
func _eval(main: CityApplication, source: String) -> String:
	main.console_window.commands.execute(source)
	var entries := ConsoleLog.entries_since(0)

	return entries[-1].text if not entries.is_empty() else ""


func _check_budget(main: CityApplication, city: CityState) -> void:
	var taxes := Budget.funding_values(city)
	assert(_eval(main, "budget.taxes.residential") == str(taxes[Sc2BudgetLayout.RESIDENTIAL]))
	_eval(main, "budget.set({ taxes: { residential: 11, industrial: 5 }, funding: { police: 80 } })")
	var values := Budget.funding_values(city)
	assert(values[Sc2BudgetLayout.RESIDENTIAL] == 11 and values[Sc2BudgetLayout.INDUSTRIAL] == 5 and values[Sc2BudgetLayout.POLICE] == 80,
		"A script sets the taxes and the funding")
	assert(values[Sc2BudgetLayout.COMMERCIAL] == taxes[Sc2BudgetLayout.COMMERCIAL], "Other values stay")
	assert(_eval(main, "seen.includes('budget.changed')") == "true")
	_eval(main, "budget.set({ taxes: { residential: 40 } })")
	assert(_last_error().contains("from 0 to 22"), _last_error())
	_eval(main, "budget.set({ funding: { parks: 10 } })")
	assert(_last_error().contains("Unknown funding entry parks"), _last_error())

	assert(_eval(main, "budget.ordinances().length") == "20")
	_eval(main, "budget.setOrdinance('salesTax', true)")
	assert(_eval(main, "budget.ordinances().find((o) => o.key === 'salesTax').enabled") == "true", "A script enables an ordinance")
	_eval(main, "budget.setOrdinance('Legalized Gambling', false)")
	assert(_eval(main, "budget.ordinances()[2].enabled") == "false", "An ordinance name also selects it")

	var funds := city.funds()
	var bonds := _eval(main, "budget.info().bonds")
	_eval(main, "budget.issueBond()")

	if _last_error().is_empty():
		assert(city.funds() == funds + 10000 and _eval(main, "budget.info().bonds") == str(int(bonds) + 1), "A script issues a bond")
		_eval(main, "budget.repayBond()")
		assert(city.funds() == funds and _eval(main, "budget.info().bonds") == bonds, "A script repays a bond")
	else:
		assert(_last_error().contains("was not issued"), "A refused bond explains why: " + _last_error())


func _check_city_data(main: CityApplication, city: CityState) -> void:
	var chunk := city.document.find_chunk("XPLT")
	var at := CityDataGrid.index(chunk.decoded_payload, city.map_size, 70, 33)
	assert(_eval(main, "city.data('pollution', 70, 33)") == str(chunk.decoded_payload[at]), "A data map value at a tile")
	assert(_eval(main, "city.tile(70, 33).data.pollution") == str(chunk.decoded_payload[at]), "A tile has its data map values")
	assert(_eval(main, "const map = city.dataMap('pollution'); map.at(70, 33) === city.data('pollution', 70, 33) && map.values.length === map.size * map.size")
		== "true", "A data map reads the same values")
	_eval(main, "city.data('smell', 1, 1)")
	assert(_last_error().contains("The data map must be one of"), _last_error())

	assert(_eval(main, "city.graphs.length") == "16")
	assert(_eval(main, "city.graph('Residents').length") == "12" and _eval(main, "city.graph('Crime', 'century').length") == "20")
	var series := city.graph_series(1)
	assert(_eval(main, "city.graph('Residents').at(-1)") == str(series.year[0]), "The newest value comes last")
	assert(_eval(main, "Array.isArray(city.things())") == "true")


func _check_city_edits(main: CityApplication, city: CityState) -> void:
	_eval(main, "city.rename('Script Springs')")
	assert(city.city_name() == "Script Springs" and _eval(main, "seen.includes('city.renamed')") == "true", "A script renames the city")

	var tile := Vector2i(-1, -1)

	for x in range(10, city.map_size - 10):
		if city.text_overlay_id(x, 50) == 0:
			tile = Vector2i(x, 50)
			break

	_eval(main, "city.setSign(%d, %d, 'Hello mayor')" % [tile.x, tile.y])
	assert(_eval(main, "city.sign(%d, %d)" % [tile.x, tile.y]) == "\"Hello mayor\"", "A script places a sign")
	_eval(main, "city.setSign(%d, %d, '')" % [tile.x, tile.y])
	assert(_eval(main, "city.sign(%d, %d)" % [tile.x, tile.y]) == "null", "An empty text removes the sign")


func _check_view_and_simulation(main: CityApplication, city: CityState) -> void:
	var zoom := main.map_view.zoom_percent()
	_eval(main, "view.zoomIn()")
	assert(main.map_view.zoom_percent() > zoom, "A script zooms in")
	_eval(main, "view.zoomOut()")
	assert(main.map_view.zoom_percent() == zoom)

	var rotation := city.compass_rotation()
	_eval(main, "view.rotate()")
	assert(city.compass_rotation() != rotation, "A script turns the map")
	_eval(main, "view.rotate(false)")
	assert(city.compass_rotation() == rotation)

	assert(_eval(main, "view.modes.length") == str(CityViewMode.KEYS.size()), "A typed GDScript array reaches the script")
	_eval(main, "view.mode = 'pollution'")
	assert(main.view_state.overlay_mode == CityViewMode.Mode.POLLUTION and _eval(main, "seen.includes('view.mode')") == "true")
	_eval(main, "view.mode = 'city'")

	_eval(main, "sim.noDisasters = true")
	assert(city.no_disasters_enabled() and _eval(main, "sim.noDisasters") == "true", "A script turns random disasters off")
	_eval(main, "sim.noDisasters = false")
	assert(_eval(main, "sim.endDisaster()") == "false", "Without a disaster there is nothing to end")
	_eval(main, "sim.startDisaster('Fire', 64, 64)")
	assert(_eval(main, "sim.endDisaster()") == "true" and main.simulation_state.simulation_engine.active_disaster_type == 0,
		"A script ends a disaster")

	var target := city.age_in_days() + 30
	_eval(main, "sim.runUntil({ year: city.date.year + 1, month: city.date.month, day: city.date.day }, 'Turtle')")
	assert(main.simulation_state.speed_controller.speed == GameSpeed.Speed.TURTLE
		and main.simulation_state.speed_controller.pause_at_day > target, "A script runs the city to a date")

	# the pause on the date sends sim.speed, as a speed change by the player does
	_eval(main, "globalThis.speeds = []; game.on('sim.speed', (e) => speeds.push(e.speed))")
	main.simulation_state.speed_controller.set_speed(GameSpeed.Speed.PAUSED)
	var paused := SimulationTickResult.new()
	paused.ok = true
	paused.paused_on_target_day = true
	main.frame.consume_simulation_result(paused)
	assert(_eval(main, "speeds.join()") == "\"Paused\"", "The pause on the date sends sim.speed")
	main.frame.select_speed(GameSpeed.Speed.PAUSED)


func _check_ui_and_storage(main: CityApplication) -> void:
	_eval(main, "ui.alert('The budget is balanced.', 'Advisor')")
	var dialog := main.scripting.api.ui_api.last_alert
	assert(dialog != null and dialog.visible and dialog.title == "Advisor", "A script shows a message window")
	dialog.hide()
	_eval(main, "ui.playSound(500)")
	assert(_last_error().is_empty() or not _last_error().contains("sound"))

	_eval(main, "game.storage.set('grant', { amount: 500, years: [2050, 2051] })")
	assert(_eval(main, "game.storage.get('grant').years[1]") == "2051", "Storage keeps a value")
	assert(_eval(main, "game.storage.get('missing', 'fallback')") == "\"fallback\"")
	var stored: Variant = JSON.parse_string(FileAccess.get_file_as_string(ScriptingUiApi.storage_path()))
	assert(stored is Dictionary and int(stored.grant.amount) == 500, "Storage writes its file")
	assert(_eval(main, "game.storage.remove('grant') && game.storage.keys().length") == "0")


# the newest script error in the console, or an empty text
func _last_error() -> String:
	var entries := ConsoleLog.entries_since(0)

	for index in range(entries.size() - 1, -1, -1):
		if entries[index].level == ConsoleLog.Level.INPUT:
			return entries[index + 1].text if index + 1 < entries.size() and entries[index + 1].level == ConsoleLog.Level.ERROR_OUTPUT else ""

	return ""
