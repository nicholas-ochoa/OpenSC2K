extends SceneTree

const RECORD_TABLE_SCENE = preload("res://src/debug/debug_record_table.tscn")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	assert(DebugCityTables.collect("XMIC", null).is_empty())
	_check_state_rows()

	for edge in [128, 512]:
		_check_tile_counts(edge)
		var city := CityState.from_document(EmptyCityTemplate.create(edge))
		var xmic := city.document.find_chunk("XMIC")
		xmic.decoded_payload[8] = 0xd2
		xmic.decoded_payload[9] = 100
		xmic.decoded_payload[10] = 0xff
		xmic.decoded_payload[11] = 0xfe
		var things := city.document.find_chunk("XTHG")
		things.decoded_payload[12] = 1
		ThingData.write(things.decoded_payload, 15, edge - 1)
		ThingData.write(things.decoded_payload, 16, edge - 2)
		assert(city.microsim_site(1) == null)

		for point in [Vector2i(3, 4), Vector2i(4, 4), Vector2i(3, 5), Vector2i(4, 5), Vector2i(6, 7)]:
			assert(city.set_text_overlay_id(point.x, point.y, OverlayData.facility_id(1)))

		var first_site := city.microsim_site(1)
		assert([first_site.x, first_site.y, first_site.width, first_site.height, first_site.tiles] == [3, 4, 4, 4, 5])

		# A moving thing covering a facility tile keeps the facility ID in its label field.
		var covering := things.decoded_payload.duplicate()
		covering[24] = 1
		ThingData.write(covering, 27, 4)
		ThingData.write(covering, 28, 5)
		ThingData.write(covering, 34, OverlayData.facility_id(1))
		assert(things.set_decoded_payload(covering))
		assert(city.set_text_overlay_id(4, 5, OverlayData.thing_id(2)))
		assert(city.set_text_overlay_id(6, 7, 0))
		var covered_site := city.microsim_site(1)
		assert([covered_site.x, covered_site.y, covered_site.width, covered_site.height, covered_site.tiles] == [3, 4, 2, 2, 4])
		assert(city.microsim_sites() == city.microsim_sites())
		# Links from a thing that is not on that tile are stale and ignored.
		ThingData.write(covering, 27, 9)
		assert(things.set_decoded_payload(covering))
		assert(city.microsim_site(1).tiles == 3)
		var before: PackedByteArray = city.document.serialize().data
		var records := DebugCityTables.collect("XMIC", city)
		var police: DebugTableRecord

		for record in records:
			if record.id == "1":
				police = record

		assert(police.value == "Police Station")
		assert(police.raw == "0xD2" and police.position == "(3, 4) 2×2")
		assert(police.fields[2].value == "65534" and police.fields[2].raw == "0xFFFE")
		assert("Funded capacity" in police.fields[2].detail)
		assert(DebugCityTables.collect("XMIC", city, null, true).size() == city.microsim_count())
		var objects := DebugCityTables.collect("Objects", city)
		assert(objects[0].raw == "(%d, %d, 0)" % [edge - 1, edge - 2])
		assert("Airplane" in objects[0].value)
		var engine := SimulationEngine.new(city, 123, 456, 789)
		var state := DebugCityTables.collect("State", city, engine)
		assert(state[-3].name == "random.state" and state[-3].value == "123" and state[-3].fields.is_empty())
		assert(engine.random.state == 123 and engine.lfsr_random.state == 456 and engine.game_random.state == 789)
		assert(city.document.serialize().data == before)

		var host := Host.new()
		host.document_state.city = city
		root.add_child(host)
		var panel := RECORD_TABLE_SCENE.instantiate() as DebugRecordTable
		host.add_child(panel)
		panel.refresh_from_host(host, true)
		_check_object_columns(host)
		# record 0 is never used, so the limits are one less than the stored slots
		assert(DebugCityTables.record_limit("XMIC", city) == city.microsim_count() - 1
			and DebugCityTables.record_limit("Tiles", city) == -1)
		assert(edge != 128 or [DebugCityTables.record_limit("XMIC", city), DebugCityTables.record_limit("Objects", city)] == [149, 39])
		_check_state_sorting(host, engine)
		panel.table.set_expanded("1", true)
		panel.refresh_from_host(host, true)
		assert(panel.table.is_expanded("1"), "A refresh keeps an open record open")
		var located: Array[Rect2i] = []
		panel.locate_requested.connect(func(site: Rect2i) -> void: located.append(site))
		assert(panel.row_cells("1")[3] == "(3, 4) 2×2" and panel.source.row("1").site != null)
		panel.locate_on_map("1")
		assert(located == [Rect2i(3, 4, 2, 2)])
		panel.search.text = "not a facility"
		panel.search.text_changed.emit(panel.search.text)
		assert(not "1" in panel.shown_ids())
		panel.search.text = "65534"
		panel.search.text_changed.emit(panel.search.text)
		assert("1" in panel.shown_ids(), "A search also reads the field rows")
		panel.live.button_pressed = false
		var refreshed := panel._last_refresh
		panel.refresh_from_host(host)
		assert(panel._last_refresh == refreshed)
		host.document_state.city = null
		panel.refresh_from_host(host)
		assert(panel.row_count() == 0)
		var debug := preload("res://src/debug/debug_overlay.tscn").instantiate() as CityDebugOverlay
		debug.setup(host)
		host.add_child(debug)
		var xmic_tab: DebugRecordTable = debug._tabs.get_node("MicroSims")
		host.document_state.city = city
		host.map_view = CityMapControl.new()
		host.map_view.city = city
		debug.toggle()
		xmic_tab.locate_requested.emit(Rect2i(3, 4, 2, 2))
		var map_center := host.map_view.source_center
		host.map_view.center_on_tile(Vector2i(3, 4))
		var corner := host.map_view.source_center
		host.map_view.center_on_tile(Vector2i(4, 5))
		assert(not corner.is_equal_approx(host.map_view.source_center))
		assert(not debug.is_open and map_center.is_equal_approx((corner + host.map_view.source_center) * 0.5))
		host.map_view.free()
		host.document_state.city = null
		debug.toggle()
		debug._process(2.0)
		assert(xmic_tab._last_refresh == -1000, "Inactive record tabs do not collect")
		debug._tabs.current_tab = 2
		assert(xmic_tab._last_refresh >= 0)
		debug.toggle()
		xmic_tab._last_refresh = -1000
		debug._process(2.0)
		assert(xmic_tab._last_refresh == -1000, "Hidden record tabs do not collect")
		host.free()

	_check_sorting()

	print("PASS: debug city tables sort, decode large-map records, retain expansion, filter, freeze and preserve save bytes")
	quit()


# the tiles tab counts each building id on the whole map and finds its first tile
func _check_tile_counts(edge: int) -> void:
	var city := CityState.from_document(EmptyCityTemplate.create(edge))
	var tiles := [Vector2i(2, 9), Vector2i(2, 3), Vector2i(edge - 1, edge - 1)]

	for point in tiles:
		assert(city.set_building_id(point.x, point.y, BuildingTileIds.POLICE_STATION))

	assert(city.set_building_id(5, 5, BuildingTileIds.LLAMA_DOME))
	var before: PackedByteArray = city.document.serialize().data
	var records := DebugCityTables.collect("Tiles", city)
	var total := 0
	var police: DebugTableRecord

	for record in records:
		total += int(record.sort[4])

		if record.id == str(BuildingTileIds.POLICE_STATION):
			police = record

	assert(total == edge * edge, "Tile counts cover every map tile")
	assert(police.cells[0] == "210 (0xD2)" and police.cells[1] == "POLICE_STATION" and police.cells[4] == "3")
	# police stations are 3×3, so three loose tiles make no whole building
	assert(police.cells[3] == "0" and police.sort[3] == 0)
	assert(police.cells[5] == str(city.document.misc_i32(Sc2MiscLayout.TILE_COUNTS + BuildingTileIds.POLICE_STATION * 4)))
	assert([police.site.x, police.site.y] == [2, 3], "Locate goes to the first tile in scan order")
	assert(DebugCityTables.collect("Tiles", city, null, true).size() == BuildingTileIds.COUNT)
	assert([DebugCityTables.tile_instances(BuildingTileIds.LOWER_CLASS_HOMES_1X1_1, 5),
		DebugCityTables.tile_instances(BuildingTileIds.CHEAP_APARTMENTS_2X2, 9),
		DebugCityTables.tile_instances(BuildingTileIds.POLICE_STATION, 18),
		DebugCityTables.tile_instances(BuildingTileIds.LLAMA_DOME, 32)] == [5, 2, 2, 2], "Instances divide by the footprint")
	assert(city.document.serialize().data == before)

	# an edit changes the building plane, so the next collection counts again
	assert(city.set_building_id(2, 3, BuildingTileIds.EMPTY))

	for record in DebugCityTables.collect("Tiles", city):
		if record.id == str(BuildingTileIds.POLICE_STATION):
			assert(record.cells[4] == "2" and [record.site.x, record.site.y] == [2, 9])

	# military bases have separate counts. the map count skips them too
	assert(city.set_zone_id(2, 9, Sc2ZoneLayout.MILITARY))
	police = _tile_record(city, BuildingTileIds.POLICE_STATION)
	assert(police.cells[4] == "1")

	# set_building_id does not change the saved counts, so the rows differ
	assert(not police.warning.is_empty() and ("SC2X" in police.warning) == CityTileCounts.exact(city),
		"A different saved count explains the counting method of the city")
	var panel := RECORD_TABLE_SCENE.instantiate() as DebugRecordTable
	panel.kind = "Tiles"
	root.add_child(panel)
	panel.update_records(DebugCityTables.collect("Tiles", city))
	assert(panel.has_row(police.id))
	assert(panel.total.text == "%d records" % panel.row_count(), "The total counts the records below the table")
	panel.search.text = "POLICE_STATION"
	panel.search.text_changed.emit(panel.search.text)
	assert(panel.total.text == "1 of %d records shown" % panel.row_count(), "A filter shows the visible part of the total")
	panel.search.text = ""
	panel.search.text_changed.emit("")
	assert(panel.source.row(police.id).warning == police.warning and panel.table.tooltip_of(police.id, -1, 4) == police.warning)

	# a saved count that wrapped below zero shows even when the map has no such tile
	assert(city.document.set_misc_u32(Sc2MiscLayout.TILE_COUNTS + BuildingTileIds.LLAMA_DOME * 4, 0xfffe if edge == 128 else 0xfffffffe))
	var dome := _tile_record(city, BuildingTileIds.LLAMA_DOME)
	assert(dome != null and ("16-bit value. It is -2." in dome.warning) == (edge == 128))
	CityTileCounts.recount(city)
	var exact_records := DebugCityTables.collect("Tiles", city)
	assert(exact_records.all(func(record: DebugTableRecord) -> bool: return record.warning.is_empty()))
	panel.update_records(exact_records)
	assert(panel.source.row(police.id).warning.is_empty() and panel.table.tooltip_of(police.id, -1, 5) == "1",
		"An exact count clears the highlight")

	# the name column takes the free width, so the count columns keep their size
	panel.size = Vector2(1400, 600)
	panel.table.size = Vector2(1400, 500)
	panel.table._fit_visible(0, panel.table.display_count())
	var drawn := panel.table._draw_widths()
	assert(drawn[-1] == panel.table.column_width(drawn.size() - 1) and drawn[3] > panel.table.column_width(3))
	panel.free()


func _tile_record(city: CityState, tile_id: int) -> DebugTableRecord:
	for record in DebugCityTables.collect("Tiles", city):
		if record.id == str(tile_id):
			return record

	return null


# moving-thing columns fit their widest cell and explain their meaning
func _check_object_columns(host: Control) -> void:
	var panel := RECORD_TABLE_SCENE.instantiate() as DebugRecordTable
	panel.kind = "Objects"
	host.add_child(panel)
	panel.size = Vector2(1200, 600)
	panel.refresh_from_host(host, true)
	var table := panel.table
	table.size = Vector2(1200, 500)
	var font := table._font()
	var font_size := table._font_size()
	var cells := panel.row_cells("1")
	assert(panel.total.text.ends_with("Limit: %d" % (host.document_state.city.thing_count() - 1)), "The total shows the record limit")
	table._fit_visible(0, table.display_count())

	for column in table.column_count():
		assert(not str(table.title_tooltips[column]).is_empty())
		var text_width := font.get_string_size(cells[column], HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		assert(table.column_width(column) >= text_width, "Column %d is narrower than its text" % column)

	# an expanded row widens the columns to fit its stored values
	var x_width := table.column_width(6)
	table.set_expanded("1", true)
	table._fit_visible(0, table.display_count())
	assert(table.column_width(6) > x_width)
	panel.free()


# state fields start in name order and sort numbers by value
func _check_state_sorting(host: Control, engine: SimulationEngine) -> void:
	host.simulation_state.simulation_engine = engine
	var panel := RECORD_TABLE_SCENE.instantiate() as DebugRecordTable
	panel.kind = "State"
	host.add_child(panel)
	panel.refresh_from_host(host, true)
	var names := Array(panel.shown_ids()).map(func(id: String) -> String: return panel.row_cells(id)[0])
	var sorted_names := names.duplicate()
	sorted_names.sort_custom(func(a: String, b: String) -> bool: return a.naturalnocasecmp_to(b) < 0)
	assert(names == sorted_names and names[0] == "active_disaster_type")
	panel.table.title_clicked.emit(1)
	var numbers := Array(panel.shown_ids()).map(func(id: String) -> String: return panel.row_cells(id)[1]) \
		.filter(func(text: String) -> bool: return text.is_valid_int()).map(func(text: String) -> int: return text.to_int())
	var sorted_numbers := numbers.duplicate()
	sorted_numbers.sort()
	assert(numbers == sorted_numbers and numbers[-1] == 789, "Expected numeric value order")
	host.simulation_state.simulation_engine = null
	panel.free()


# rows for the next day, the speed controller, a waiting prompt and the scenario goals
func _check_state_rows() -> void:
	var city := CityState.from_document(EmptyCityTemplate.create(128))
	assert(city.document.enable_full_resolution_maps() and city.set_age_in_days(25))
	var engine := SimulationEngine.new(city)
	var controller := GameSpeedController.new(engine)
	assert(controller.set_speed(GameSpeedController.Speed.TURTLE))
	controller.subtick_counter = 1
	var rows := _state_rows(city, engine, controller)
	assert(rows["next_day.city_days"].value == "26" and rows["next_day.month_day"].value == "2")
	assert(rows["next_day.actions"].value == "power, pollution_coverage", "Per-tile maps run pollution with power")
	assert(rows["next_day.growth_partition"].value == "None")
	assert(rows["speed_controller.base_ticks_to_next_day"].value == "3", "Turtle starts a day on every fourth base tick")
	assert(rows["pending_day_schedule"].value == "None" and rows["scenario.active"].value == "false")
	assert(not rows.has("scenario.months_left"))
	assert(controller.set_speed(GameSpeedController.Speed.PAUSED) and city.set_age_in_days(27))
	engine.clock.city_days = 27
	engine.city_status_resource_id = CityStatusMessages.NEED_FIRST
	engine.pending_interaction = "military_proposal"
	engine.pending_day_schedule = SimulationClock.state_for_day(22)
	engine.pending_military_base_type = 3
	engine.pending_military_site = Rect2i(4, 5, 6, 6)
	engine.scenario = ScenarioState.new()
	engine.scenario.document = city.document
	engine.scenario.time_limit_months = 12
	engine.scenario.city_size_goal = 1000
	rows = _state_rows(city, engine, controller)
	assert(rows["next_day.growth_partition"].value == "1/16 (step 0, substep 0)")
	assert(rows["speed_controller.base_ticks_to_next_day"].value == "Paused")
	assert(rows["city_status_resource_id"].value == "265: Power Plant Needed")
	assert(rows["pending_day_schedule"].value == "City day 22: scenario, bankruptcy", "The military prompt resumes after milestones")
	assert(rows["pending_military_base_type"].value == "3: Air Force" and rows["pending_military_site"].value == "(4, 5) 6×6")
	assert(rows["scenario.months_left"].value == "12")
	assert(rows["scenario.goal.city_size"].value == "0 / 1000" and not rows["scenario.goal.city_size"].warning.is_empty())
	assert(rows["scenario.goal.pollution"].value == "0 / no limit" and rows["scenario.goal.pollution"].warning.is_empty())
	assert(not rows.has("scenario.goal.first_building"))


func _state_rows(city: CityState, engine: SimulationEngine, controller: GameSpeedController) -> Dictionary:
	var rows := {}

	for record in DebugCityTables.collect("State", city, engine, false, controller):
		rows[record.name] = record

	return rows


func _check_sorting() -> void:
	var panel := RECORD_TABLE_SCENE.instantiate() as DebugRecordTable
	root.add_child(panel)
	var records: Array[DebugTableRecord] = []

	# Record 2 is off-map. Sort 0x2A after 0x10 by value, not by digit count.
	for entry in [[0, "Record 0", 0x2a, CityRecords.Site.new(13, 4, 1, 1)], [2, "Record 2", 0x10, null],
		[10, "Record 10", 0xd2, CityRecords.Site.new(3, 9, 1, 1)]]:
		var site: CityRecords.Site = entry[3]
		var record := DebugTableRecord.new()
		record.id = str(entry[0])
		record.name = entry[1]
		record.site = site
		record.sort = [entry[0], "", entry[2], DebugCityTables._site_sort(site), ""]
		records.append(record)

	panel.update_records(records)
	var order := func() -> Array:
		return Array(panel.shown_ids()).map(func(id: String) -> String: return panel.row_cells(id)[0])
	panel.table.set_expanded("10", true)
	panel.table.title_clicked.emit(2)
	assert(order.call() == ["Record 2", "Record 0", "Record 10"])
	panel.table.title_clicked.emit(2)
	assert(order.call() == ["Record 10", "Record 0", "Record 2"] and panel.column_title(2).ends_with("▼"))
	# Rows without a position stay last in both directions; locate column sorts the same way.
	for column in [3, panel.locate_column]:
		panel.sort_by(column)
		assert(order.call() == ["Record 10", "Record 0", "Record 2"])
		panel.sort_by(column, true)
		assert(order.call() == ["Record 0", "Record 10", "Record 2"])
	# Refresh keeps the sort, and new rows land in sorted position.
	var added := DebugTableRecord.new()
	added.id = "5"
	added.name = "Record 5"
	added.site = CityRecords.Site.new(8, 0, 1, 1)
	added.sort = [5, "", 0, [8, 0, 1], ""]
	records.append(added)
	panel.update_records(records)
	assert(order.call() == ["Record 0", "Record 5", "Record 10", "Record 2"])
	panel.sort_by(0)
	assert(order.call() == ["Record 0", "Record 2", "Record 5", "Record 10"])
	panel.table.title_clicked.emit(0)
	panel.table.title_clicked.emit(0)
	assert(panel.sort_column == -1 and panel.column_title(0) == "Record / field")
	assert(order.call() == ["Record 0", "Record 2", "Record 10", "Record 5"])
	assert(panel.table.is_expanded("10"))
	assert(panel.table.display_count() == 4 + panel.source.row("10").fields.size(), "An open record shows its fields")
	# the row under the mouse is highlighted until the mouse leaves
	panel.table.size = Vector2(800, 400)
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(20, panel.table._header_height() + panel.table._row_height() * 1.5)
	panel.table._gui_input(motion)
	assert(panel.table._hovered == 1)
	panel.table.mouse_exited.emit()
	assert(panel.table._hovered == -1)

	# a wheel step scrolls an eighth of a page in pixels, as a Tree does; a
	# trackpad step scrolls less
	var many: Array[DebugTableRecord] = []

	for index in 300:
		var record := DebugTableRecord.new()
		record.id = str(index)
		record.name = "Record %d" % index
		many.append(record)

	panel.update_records(many)
	var scroll := panel.table._v_scroll
	assert(scroll.visible and is_equal_approx(scroll.page, panel.table._body_height()))
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	wheel.pressed = true
	wheel.factor = 1.0
	panel.table._gui_input(wheel)
	assert(is_equal_approx(scroll.value, scroll.page / 8.0), "A wheel step is an eighth of a page")
	wheel.factor = 0.25
	panel.table._gui_input(wheel)
	assert(is_equal_approx(scroll.value, scroll.page / 8.0 * 1.25), "A trackpad step follows its factor")
	var pan := InputEventPanGesture.new()
	pan.delta = Vector2(0, -1.25)
	panel.table._gui_input(pan)
	assert(is_equal_approx(scroll.value, 0.0))
	# a row shows from the pixel where the scroll stops
	scroll.value = panel.table._row_height() * 10.5
	var under := panel.table.hit(Vector2(20, panel.table._header_height() + 1))
	assert(under[0] == 10, "Row 10 shows in part under the header")
	panel.free()


class Host extends Control:
	var debug: Control = self
	var document_state := ActiveDocumentState.new()
	var simulation_state := SimulationSessionState.new()
	var map_view: CityMapControl


	func debug_metrics() -> Dictionary:
		return {}
