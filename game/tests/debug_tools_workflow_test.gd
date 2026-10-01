extends SceneTree
## The debug checks and editors in the running application: the file format,
## the save round trip, record and MISC edits with undo, the chunk browser, the
## MISC tab, the disaster preview, the missing artwork check, the growth inputs
## of the Tile Inspector, the tile grid, the scenario tab, and day and phase
## steps.

const AppFixture = preload("res://tests/support/app_fixture.gd")
const GameSpeed = preload("res://src/simulation/core/game_speed_controller.gd")
const Layer = DebugTileLayers.Layer
# a check waits for a worker thread
const WAIT_MSEC := 20000


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var main := (load("res://main.tscn") as PackedScene).instantiate() as CityApplication
	AppFixture.configure(main)
	root.add_child(main)
	await process_frame
	assert(main.asset_state.assets_ready)
	main.city_files._load_city_unchecked(GeneratedCityFixture.path(128))
	main.frame.select_speed(GameSpeed.Speed.PAUSED)
	main.debug_tools.set_debug_mode(true, false)
	var city := main.document_state.city
	var original := city.document.serialize().data

	_check_file_format(main)
	await _check_save(main)
	_check_edits(main, city)
	_check_chunks(main)
	_check_misc_tab(main)
	_check_scenario_tab(main)
	_check_disaster_preview(main)
	await _check_artwork(main)
	await _check_growth_and_grid(main, city)
	assert(city.document.serialize().data == original, "Checks, previews and undone edits do not change the city")
	await _check_steps(main)
	main.debug_tools.set_debug_mode(false, false)
	main.queue_free()
	await process_frame
	print("PASS: file format, save check, edits and undo, chunk browser, MISC tab, scenario tab, disaster preview, " +
		"artwork check, growth inputs, tile grid and simulation steps")
	quit()


func _check_file_format(main: CityApplication) -> void:
	var file: Dictionary = main.debug.debug_metrics().file
	assert(file.format == "SC2" and file.map_size == 128, str(file))
	assert(main.city_menu_bar.city_label.tooltip_text.contains("File format: SC2."))
	main.debug_overlay.toggle()
	assert(main.debug_overlay.file_format_label.text == "File: SC2")
	main.debug_overlay.toggle()


func _check_save(main: CityApplication) -> void:
	var source_path := main.document_state.current_document.source_path
	assert(main.debug_tools.checks.verify_save().begins_with("Checking the save round trip"))
	await _wait_until(func() -> bool: return not main.debug_tools.checks.is_busy())
	var report := main.debug_tools.checks.save_report
	assert(report != null and report.ok(), report.text() if report != null else "no report")
	assert(report.stable and report.rows.size() == main.document_state.current_document.chunks.size())
	assert(not FileAccess.file_exists(report.path), "The temporary save is deleted")
	assert(main.document_state.current_document.source_path == source_path, "The open city keeps its file")


func _check_edits(main: CityApplication, city: CityState) -> void:
	var edits := main.debug_tools.edits
	var funds := city.funds()
	assert(edits.set_misc_word(Sc2MiscLayout.FUNDS, "123456", "FUNDS").begins_with("Debug edit"))
	assert(city.funds() == 123456)
	assert(edits.set_misc_word(Sc2MiscLayout.FUNDS + 1, "1").contains("cannot"), "MISC words are aligned")
	assert(edits.set_misc_word(Sc2MiscLayout.FUNDS, "many").begins_with("Enter"))
	assert(edits.set_microsim_field(1, "stat_1", "0x1234").begins_with("Debug edit"))
	assert(city.microsim(1).stat_1 == 0x1234)
	assert(edits.set_microsim_field(1, "stat_0", "300").begins_with("Enter"), "stat_0 is one byte")
	var record := _thing_record(city)

	if record > 0:
		assert(edits.set_thing_field(record, "x", str(city.map_size)).begins_with("Enter"), "Coordinates stay on the map")
		assert(edits.set_thing_field(record, "state", "7").begins_with("Debug edit"))
		assert(city.thing(record).state == 7)
		assert(edits.undo().begins_with("Undid"))

	assert(edits.undo().begins_with("Undid") and city.microsim(1).stat_1 != 0x1234)
	assert(edits.undo().begins_with("Undid") and city.funds() == funds)
	assert(edits.undo() == "There is no debug edit to undo.")
	assert(DebugEdits.parse_number("12 / 0x0C") == 12 and DebugEdits.parse_number("-0x10") == -16)
	assert(DebugEdits.parse_number("$1,000") == 1000 and DebugEdits.parse_number("x") == null)


func _check_chunks(main: CityApplication) -> void:
	var tab := _tab(main, "Chunks") as CityDebugChunksTab
	assert(main.debug_tools.mark_chunks().begins_with("Marked"))
	var document := main.document_state.current_document
	var misc := document.find_chunk("MISC")
	var before := misc.decoded_payload.duplicate()
	assert(main.debug_tools.edits.set_misc_word(Sc2MiscLayout.BONDS, "777").begins_with("Debug edit"))
	tab.refresh(true)
	assert(tab._rows.has("MISC") and tab._rows["MISC"].get_text(4) != "0", "The edit shows as changed bytes")
	assert(tab._rows["XBLD"].get_text(4) == "0")
	tab._selected = "MISC"
	tab.offset_input.value = Sc2MiscLayout.BONDS
	tab._show_page()
	assert(tab.hex.text.contains(CityDebugChunksTab.CHANGED_COLOR), "The hex view marks the changed bytes")
	tab.offset_input.value = 0
	tab._next_change()
	var found := int(tab.offset_input.value)
	assert(found >= Sc2MiscLayout.BONDS and found < Sc2MiscLayout.BONDS + 4, "Next change finds the edited word")
	tab.offset_input.value = Sc2MiscLayout.SIZE - 1
	tab._previous_change()
	assert(int(tab.offset_input.value) >= Sc2MiscLayout.BONDS and int(tab.offset_input.value) < Sc2MiscLayout.BONDS + 4)
	assert(main.debug_tools.edits.undo().begins_with("Undid") and misc.decoded_payload == before)
	var text := CityDebugChunksTab.page_text(PackedByteArray([0x41, 0x5b, 0]), 0, 3, { 1: true })
	assert(text.begins_with("00000000  41 [bgcolor") and text.ends_with("A.."), text)
	tab.free()


func _check_misc_tab(main: CityApplication) -> void:
	var fields := CityDebugMiscTab.fields(Sc2MiscLayout.SIZE)
	var words := 0

	for field: Array in fields:
		words += int(field[2])

	assert(words * Sc2MiscLayout.WORD_SIZE == Sc2MiscLayout.SIZE, "The fields cover every MISC word once")
	assert(fields.any(func(field: Array) -> bool: return field[0] == "FUNDS" and field[1] == Sc2MiscLayout.FUNDS and field[2] == 1))
	var tab := _tab(main, "MISC") as CityDebugMiscTab
	tab.refresh(true)
	assert(tab._rows.size() == Sc2MiscLayout.SIZE / Sc2MiscLayout.WORD_SIZE)
	assert(tab._rows[Sc2MiscLayout.FUNDS].get_text(CityDebugMiscTab.VALUE_COLUMN) == str(main.document_state.city.funds()))
	assert(tab._city_rows["File format"].get_text(CityDebugMiscTab.VALUE_COLUMN) == "SC2")
	tab.free()


func _check_scenario_tab(main: CityApplication) -> void:
	var tab := _tab(main, "Scenario") as CityDebugScenarioTab
	tab.refresh(true)
	assert(tab.heading.text == "This city has no active scenario.")
	var scenario := ScenarioState.new()
	scenario.residential_goal = 500
	scenario.pollution_limit = 0
	var goals := ScenarioState.Goals.new()
	goals.ok = true
	goals.unmet = PackedStringArray(["residential"])
	goals.values = { "residential": 200, "city_size": 0 }
	var rows := CityDebugScenarioTab.goal_rows(scenario, goals)
	var by_goal := {}

	for row: Array in rows:
		by_goal[row[0]] = row

	assert(by_goal.Residential == ["Residential", 200, "at least 500", "Not met"])
	assert(by_goal.Pollution[3] == "Off" and by_goal["City Size"][3] == "Off")
	tab.free()


func _check_disaster_preview(main: CityApplication) -> void:
	main.map_view.center_on_tile(Vector2i(64, 64))
	var engine := main.simulation_state.simulation_engine
	var states := [engine.random.state, engine.game_random.state, engine.lfsr_random.state, engine.active_disaster_type]
	var message := main.debug_tools.checks.preview_disaster(1, 6)
	assert([engine.random.state, engine.game_random.state, engine.lfsr_random.state, engine.active_disaster_type] == states,
		"The preview keeps the random states and starts no disaster")

	if message.begins_with("Fire at"):
		assert(main.debug_tools.state.tile_layer == Layer.DISASTER_PREVIEW)
		assert(main.debug_tools.tile_views.has_external(Layer.DISASTER_PREVIEW))
		assert(main.debug_tools.render_views.line_sets.has("check"))
	else:
		assert(message.begins_with("The disaster"), message)


func _check_artwork(main: CityApplication) -> void:
	assert(main.debug_tools.checks.check_missing_artwork().begins_with("Checking the artwork"))
	await _wait_until(func() -> bool: return not main.debug_tools.checks.is_busy())
	await _wait_until(_shows_layer.bind(main, Layer.MISSING_ARTWORK))
	assert(main.map_view.debug_view.legend_summary.begins_with("Every tile"), main.map_view.debug_view.legend_summary)
	main.debug_tools.on_debug_menu(CityDebugMenu.LAYER_BASE + Layer.NONE)


func _check_growth_and_grid(main: CityApplication, city: CityState) -> void:
	var zoned := Vector2i(-1, -1)

	for x in range(8, 120):
		for y in range(8, 120):
			if (city.zone_id(x, y) & Sc2ZoneLayout.TYPE_MASK) in [1, 2] and city.building_id(x, y) >= BuildingTileIds.DEVELOPED_FIRST:
				zoned = Vector2i(x, y)
				break

		if zoned.x >= 0:
			break

	assert(zoned.x >= 0, "The fixture has a residential building")
	main.debug_tools.on_debug_menu(CityDebugMenu.MENU_TILE_INSPECTOR)
	main.debug_tools.pin_inspector(zoned)
	var text := main.debug_tools._inspector_text(zoned)

	for caption in ["Growth", "  Visit", "  Power", "  Trip", "  Demand", "  Land value", "  Advance"]:
		assert(text.contains("\n" + caption), "%s in %s" % [caption, text])

	main.debug_tools.unpin_inspector()
	assert(main.debug_tools._inspector_text(zoned).contains("Click to pin the tile"))
	main.debug_tools.on_debug_menu(CityDebugMenu.MENU_TILE_GRID)
	assert(main.debug_tools.state.tile_grid and main.map_view.debug_view.tile_layer.grid)
	main.map_view.zoom_factor = 2.0
	main.map_view.center_on_tile(zoned)
	await _wait_until(func() -> bool:
		return main.debug_tools.tile_views.value_labels.any(func(label: Array) -> bool: return str(label[1]).contains(",")))
	assert(main.map_view.debug_view.tile_layer.mesh != null)
	main.debug_tools.on_debug_menu(CityDebugMenu.MENU_TILE_GRID)
	assert(not main.debug_tools.state.tile_grid)
	main.map_view.zoom_factor = 1.0


func _check_steps(main: CityApplication) -> void:
	var steps := main.debug_tools.steps
	var city := main.document_state.city
	main.frame.select_speed(GameSpeed.Speed.TURTLE)
	assert(steps.step_day().begins_with("Pause the game"))
	main.frame.select_speed(GameSpeed.Speed.PAUSED)
	var age := city.age_in_days()
	assert(steps.step_day().contains("ran in"), "A day step runs")
	assert(city.age_in_days() == age + 1 and steps.entries.size() == 1)
	assert(steps.entries[0].changed_tiles >= 0)

	# step phases until a day stays open, then a speed change finishes it
	for _attempt in 25:
		steps.step_phase()

		if steps.open_day != null:
			break

	assert(steps.open_day != null, "A day with several actions stays open")
	assert(steps.next_actions().begins_with("Open day"))
	var open_age := city.age_in_days()
	main.frame.select_speed(GameSpeed.Speed.TURTLE)
	assert(steps.open_day == null and city.age_in_days() == open_age, "A speed change runs the rest of the open day")
	main.frame.select_speed(GameSpeed.Speed.PAUSED)
	var tab := _tab(main, "Steps") as CityDebugStepsTab
	tab.refresh(true)
	assert(tab.table.get_root().get_child_count() == steps.entries.size())
	tab.free()


func _tab(main: CityApplication, tab_name: String) -> DebugWindowTab:
	var tab: DebugWindowTab = {"Chunks": CityDebugChunksTab, "MISC": CityDebugMiscTab, "Scenario": CityDebugScenarioTab,
		"Steps": CityDebugStepsTab}[tab_name].new()
	tab.setup(main, func(_message: String) -> void: pass)

	return tab


func _shows_layer(main: CityApplication, layer: Layer) -> bool:
	return main.debug_tools.tile_views.values != null and main.map_view.debug_view.tile_layer.layer == layer


func _thing_record(city: CityState) -> int:
	for record in range(1, city.thing_count()):
		if city.thing(record).type != 0:
			return record

	return -1


func _wait_until(condition: Callable) -> void:
	var deadline := Time.get_ticks_msec() + WAIT_MSEC

	while Time.get_ticks_msec() < deadline:
		if condition.call():
			return

		await process_frame

	assert(false, "A debug check did not finish")
