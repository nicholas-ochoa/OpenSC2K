extends SceneTree
## Scripts in the running application: console input, the game API of
## city, sim, tools and view, the tool, simulation and disaster events, a
## cancelled tool, script files with console commands, timers, the reset,
## and the QuickJS-ng license in the About dialog.

const AppFixture = preload("res://tests/support/app_fixture.gd")
const GameSpeed = preload("res://src/simulation/core/game_speed_controller.gd")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var main := (load("res://main.tscn") as PackedScene).instantiate() as CityApplication
	AppFixture.configure(main)
	root.add_child(main)
	await process_frame
	assert(main.asset_state.assets_ready)
	assert(not main.scripting.is_running(), "The runtime starts at its first use")
	main.city_files._load_city_unchecked(GeneratedCityFixture.path(128))
	main.frame.select_speed(GameSpeed.Speed.PAUSED)
	var city := main.document_state.city

	_check_console(main)
	_check_city_api(main, city)
	_check_tools(main, city)
	_check_simulation(main)
	await _check_files_and_timers(main)
	_check_about(main)
	main.queue_free()
	await process_frame
	print("PASS: script console, game API, tool, simulation and disaster events, script files, commands, timers and reset")
	quit()


# the text of the newest console entry
func _last_line() -> String:
	var entries := ConsoleLog.entries_since(0)

	return entries[-1].text if not entries.is_empty() else ""


func _eval(main: CityApplication, source: String) -> String:
	main.console_window.commands.execute(source)

	return _last_line()


func _check_console(main: CityApplication) -> void:
	assert(_eval(main, "[1, 2].map((value) => value * 2)") == "[ 2, 4 ]", "Console input runs as JavaScript")
	assert(main.scripting.is_running())
	_eval(main, "missingName + 1")
	assert(_last_line().begins_with("Uncaught ReferenceError"), _last_line())
	_eval(main, "console.log('mayor says hello')")
	assert(_last_line() == "mayor says hello", "console.log writes to the console: " + _last_line())


func _check_city_api(main: CityApplication, city: CityState) -> void:
	assert(_eval(main, "city.loaded") == "true")
	assert(_eval(main, "city.size") == "128")
	assert(_eval(main, "city.funds") == str(city.funds()))
	_eval(main, "city.funds = 123456")
	assert(city.funds() == 123456, "A script sets the funds")
	_eval(main, "city.addFunds(-456)")
	assert(city.funds() == 123000)
	assert(_eval(main, "city.tile(5, 6).x + city.tile({ x: 5, y: 6 }).y") == "11", "A tile takes a point in each form")
	assert(_eval(main, "city.tile(-1, 0)") == "null", "A tile outside the map is null")
	_eval(main, "city.funds = 'many'")
	assert(_last_line().begins_with("Uncaught Error: Funds must be a number."), _last_line())


func _check_tools(main: CityApplication, city: CityState) -> void:
	_eval(main, "globalThis.log = []; game.on('tool.selected', (e) => log.push('selected ' + e.tool.name))")
	_eval(main, "game.on('tool.applied', (e) => log.push(`applied ${e.command} ${e.changed} ${e.cost}`))")
	_eval(main, "game.on('tool.undone', (e) => log.push('undone ' + e.command))")
	assert(_eval(main, "tools.select('Residential', 'Dense Residential').name") == "\"Dense Residential\"")
	assert(main.tool_state.selected_group == CityToolIds.Group.RESIDENTIAL
		and main.tool_state.selected_subtool == CityToolIds.Residential.DENSE, "A script selects a tool")

	var funds := city.funds()
	var site := _clear_site(city)
	assert(site.x >= 0, "The generated city has clear flat land")
	var applied := _eval(main, "tools.apply([%d, %d], [%d, %d]).changed" % [site.x, site.y, site.x + 2, site.y + 1])
	assert(applied == "true", "A script uses the selected tool: " + main.status_label.text)
	assert(city.zone_id(site.x + 1, site.y + 1) != 0 and city.funds() < funds, "The zone tool changed the map and the funds")

	_eval(main, "tools.undo()")
	assert(city.zone_id(site.x + 1, site.y + 1) == 0 and city.funds() == funds, "A script undoes the last edit")
	var log := _eval(main, "log.join('; ')")
	assert(log.contains("selected Dense Residential") and log.contains("applied zone true") and log.contains("undone zone"), log)

	# a listener can stop the player's tool
	_eval(main, "game.on('tool.beforeApply', (e) => { if (e.start.x < 30) e.cancel() })")
	var original := city.document.serialize().data
	var path: Array[Vector2i] = [Vector2i(25, 25)]
	var outcome := main.city_edits.apply_map_selection(Vector2i(25, 25), Vector2i(25, 25), path, false)
	assert(bool(outcome.cancelled) and city.document.serialize().data == original, "A cancelled tool leaves the city unchanged")
	assert(_eval(main, "tools.select('Bulldozer').name") == "\"Demolish\"", "A group name selects its last tool")
	_eval(main, "tools.select('No Such Tool')")
	assert(_last_line().begins_with("Uncaught Error: Unknown tool."), _last_line())


# the corner of 3 by 2 empty, dry and flat tiles, or (-1, -1)
func _clear_site(city: CityState) -> Vector2i:
	for y in range(8, city.map_size - 8):
		for x in range(8, city.map_size - 8):
			var clear := true

			for tile in [Vector2i(x, y), Vector2i(x + 1, y), Vector2i(x + 2, y), Vector2i(x, y + 1), Vector2i(x + 1, y + 1),
					Vector2i(x + 2, y + 1)]:
				clear = clear and (city.building_id(tile.x, tile.y) == 0 and city.zone_id(tile.x, tile.y) == 0
					and not city.is_water(tile.x, tile.y) and city.terrain_id(tile.x, tile.y) == 0
					and city.land_altitude(tile.x, tile.y) == city.land_altitude(x, y))

			if clear:
				return Vector2i(x, y)

	return Vector2i(-1, -1)


func _check_simulation(main: CityApplication) -> void:
	_eval(main, "globalThis.days = []; game.on('sim.day', (e) => days.push(e)); game.on('sim.speed', (e) => days.push(e.speed))")
	var city := main.document_state.city
	assert(_eval(main, "sim.step()").begins_with("\"Day ran"), _last_line())
	assert(_eval(main, "days.length") == "1")
	assert(_eval(main, "days[0].year * 10000 + days[0].month * 100 + days[0].day")
		== str(city.current_year() * 10000 + city.current_month() * 100 + city.current_day()), "A day event has the city date")
	_eval(main, "sim.speed = 'llama'")
	assert(main.simulation_state.speed_controller.speed == GameSpeed.Speed.LLAMA and _eval(main, "days.at(-1)") == "\"Llama\"")
	_eval(main, "sim.pause()")
	assert(_eval(main, "sim.paused") == "true")

	# a script can stop a disaster, then start one at a tile
	_eval(main, "globalThis.blockFire = game.on('disaster.beforeStart', (e) => { if (e.name === 'Fire') e.cancel() })")
	_eval(main, "sim.startDisaster('Fire')")
	assert(_last_line().contains("a script cancelled it") and main.simulation_state.simulation_engine.active_disaster_type == 0)
	_eval(main, "blockFire(); game.on('disaster.started', (e) => globalThis.started = e.name)")
	assert(_eval(main, "sim.startDisaster('Fire', 64, 64).name") == "\"Fire\"")
	assert(_eval(main, "started + ' ' + sim.disaster.name") == "\"Fire Fire\"", "A disaster start sends its event")
	assert(main.debug.debug_end_disaster().ok)


func _check_files_and_timers(main: CityApplication) -> void:
	var folder := OS.get_temp_dir().path_join("opensc2k_scripting_workflow_%d" % OS.get_process_id())
	DirAccess.make_dir_recursive_absolute(folder)
	var path := folder.path_join("mod.js")
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string("game.command('budget-report', 'Show the funds.', () => 'Funds: ' + city.funds);\n"
		+ "setTimeout(() => game.status('timer ran'), 0);")
	file.close()

	assert(main.scripting.run_file(path), "A script file runs")
	assert(_eval(main, "budget-report") == "Funds: %d" % main.document_state.city.funds(), "A script adds a console command")
	await process_frame
	await process_frame
	assert(main.status_label.text == "timer ran", "A timer runs in a later frame")
	assert(not main.scripting.run_file(folder.path_join("missing.js")), "A missing file is reported")

	main.console_window.commands.execute("reset")
	assert(not main.scripting.is_running() and not main.console_window.commands.has("budget-report"),
		"A reset stops the scripts and removes their commands")
	assert(main.scripting.emit("tool.applied", {}).is_empty(), "No script receives events after a reset")
	DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(folder)


func _check_about(main: CityApplication) -> void:
	var about := (load("res://src/ui/settings/about_dialog.tscn") as PackedScene).instantiate() as AboutDialog
	main.add_child(about)
	var license := FileAccess.get_file_as_string("res://assets/licenses/quickjs/QuickJS-ng-LICENSE.txt").strip_edges()
	var found := false

	for index in about.license_picker.item_count:
		if about.license_picker.get_item_text(index).begins_with("QuickJS-ng"):
			found = about.license_documents[index].contains(license)

	assert(found, "The About dialog shows the QuickJS-ng license")
	about.queue_free()
