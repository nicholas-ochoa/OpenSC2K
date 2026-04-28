extends SceneTree

class Host extends Control:
	var city: CityState
	var simulation_engine: SimulationEngine


	func _debug_metrics() -> Dictionary:
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
		assert(police.raw.ends_with("(3, 4) 2×2"))
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

	print("PASS: debug city tables decode large-map records, retain expansion, filter, freeze and preserve save bytes")
	quit()
