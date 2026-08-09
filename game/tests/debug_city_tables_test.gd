extends SceneTree

class Host extends Control:
	var debug: Control = self
	var city: CityState
	var simulation_engine: SimulationEngine
	var map_view: CityMapControl


	func debug_metrics() -> Dictionary:
		return {}


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	assert(DebugCityTables.collect("XMIC", null).is_empty())

	for edge in [128, 512]:
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
		assert(city.microsim_site(1).is_empty())

		for point in [Vector2i(3, 4), Vector2i(4, 4), Vector2i(3, 5), Vector2i(4, 5), Vector2i(6, 7)]:
			assert(city.set_text_overlay_id(point.x, point.y, OverlayData.facility_id(1)))

		assert(city.microsim_site(1) == {"x": 3, "y": 4, "width": 4, "height": 4, "tiles": 5})

		# A moving thing covering a facility tile keeps the facility ID in its label field.
		var covering := things.decoded_payload.duplicate()
		covering[24] = 1
		ThingData.write(covering, 27, 4)
		ThingData.write(covering, 28, 5)
		ThingData.write(covering, 34, OverlayData.facility_id(1))
		assert(things.set_decoded_payload(covering))
		assert(city.set_text_overlay_id(4, 5, OverlayData.thing_id(2)))
		assert(city.set_text_overlay_id(6, 7, 0))
		assert(city.microsim_site(1) == {"x": 3, "y": 4, "width": 2, "height": 2, "tiles": 4})
		assert(city.microsim_sites() == city.microsim_sites())
		# Links from a thing that is not on that tile are stale and ignored.
		ThingData.write(covering, 27, 9)
		assert(things.set_decoded_payload(covering))
		assert(city.microsim_site(1).tiles == 3)
		var before: PackedByteArray = city.document.serialize().data
		var records := DebugCityTables.collect("XMIC", city)
		var police: Dictionary = {}

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
		assert(state[0].fields[-3].value == "123")
		assert(engine.random.state == 123 and engine.lfsr_random.state == 456 and engine.game_random.state == 789)
		assert(city.document.serialize().data == before)

		var host := Host.new()
		host.city = city
		root.add_child(host)
		var panel := preload("res://src/debug/debug_record_table.tscn").instantiate() as DebugRecordTable
		host.add_child(panel)
		panel.refresh_from_host(host, true)
		var row: TreeItem = panel.rows["1"]
		row.collapsed = false
		panel.refresh_from_host(host, true)
		assert(panel.rows["1"] == row and not row.collapsed)
		var located: Array[Rect2i] = []
		panel.locate_requested.connect(func(site: Rect2i) -> void: located.append(site))
		assert(row.get_text(3) == "(3, 4) 2×2" and row.get_icon(panel.locate_column) != null)
		panel.locate_on_map(row)
		assert(located == [Rect2i(3, 4, 2, 2)])
		panel.search.text = "not a facility"
		panel.search.text_changed.emit(panel.search.text)
		assert(not row.visible)
		panel.search.text = "65534"
		panel.search.text_changed.emit(panel.search.text)
		assert(row.visible)
		panel.live.button_pressed = false
		var refreshed := panel._last_refresh
		panel.refresh_from_host(host)
		assert(panel._last_refresh == refreshed)
		host.city = null
		panel.refresh_from_host(host)
		assert(panel.rows.is_empty())
		var debug := preload("res://src/debug/debug_overlay.tscn").instantiate() as CityDebugOverlay
		debug.setup(host)
		host.add_child(debug)
		var xmic_tab: DebugRecordTable = debug._tabs.get_node("MicroSims")
		host.city = city
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
		host.city = null
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


func _check_sorting() -> void:
	var panel := preload("res://src/debug/debug_record_table.tscn").instantiate() as DebugRecordTable
	root.add_child(panel)
	var records: Array[Dictionary] = []

	# Record 2 is off-map. Sort 0x2A after 0x10 by value, not by digit count.
	for entry in [[0, "Record 0", 0x2A, {"x": 13, "y": 4}], [2, "Record 2", 0x10, {}], [10, "Record 10", 0xD2, {"x": 3, "y": 9}]]:
		var site: Dictionary = entry[3]
		if not site.is_empty():
			site.merge({"width": 1, "height": 1})
		records.append({"id": str(entry[0]), "name": entry[1], "value": "", "raw": "", "site": site,
			"sort": [entry[0], "", entry[2], DebugCityTables._site_sort(site), ""]})

	panel.update_records(records)
	var order := func() -> Array:
		return panel.table.get_root().get_children().map(func(item: TreeItem) -> String: return item.get_text(0))
	panel.rows["10"].collapsed = false
	panel.table.column_title_clicked.emit(2, MOUSE_BUTTON_LEFT)
	assert(order.call() == ["Record 2", "Record 0", "Record 10"])
	panel.table.column_title_clicked.emit(2, MOUSE_BUTTON_LEFT)
	assert(order.call() == ["Record 10", "Record 0", "Record 2"] and panel.table.get_column_title(2).ends_with("▼"))
	# Rows without a position stay last in both directions; locate column sorts the same way.
	for column in [3, panel.locate_column]:
		panel.sort_by(column)
		assert(order.call() == ["Record 10", "Record 0", "Record 2"])
		panel.sort_by(column, true)
		assert(order.call() == ["Record 0", "Record 10", "Record 2"])
	# Refresh keeps the sort, and new rows land in sorted position.
	records.append({"id": "5", "name": "Record 5", "value": "", "raw": "", "site": {"x": 8, "y": 0, "width": 1, "height": 1},
		"sort": [5, "", 0, [8, 0, 1], ""]})
	panel.update_records(records)
	assert(order.call() == ["Record 0", "Record 5", "Record 10", "Record 2"])
	panel.sort_by(0)
	assert(order.call() == ["Record 0", "Record 2", "Record 5", "Record 10"])
	panel.table.column_title_clicked.emit(0, MOUSE_BUTTON_LEFT)
	panel.table.column_title_clicked.emit(0, MOUSE_BUTTON_LEFT)
	assert(panel.sort_column == -1 and panel.table.get_column_title(0) == "Record / field")
	assert(order.call() == ["Record 0", "Record 2", "Record 10", "Record 5"])
	assert(not panel.rows["10"].collapsed)
	panel.free()
