extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _record(type: int, direction := 0, state := 0, goal := 0) -> Dictionary:
	return {"type": type, "direction": direction, "state": state, "goal": goal,
		"x": 400, "y": 300, "z": 10, "px": 8, "py": 8, "dx": 450, "dy": 350, "label": 0}


func _run() -> void:
	var city := CityState.from_document(EmptyCityTemplate.create(512))
	var before: PackedByteArray = city.document.serialize().data

	for type in [1, 2, 3, 5, 15, 16]:
		for direction in 8:
			assert(DebugObjectFields.direction(_record(type, direction)) == DebugObjectFields.EIGHT[direction])

	for type in [4, 9, 10, 11, 12, 13]:
		for direction in 4:
			assert(DebugObjectFields.direction(_record(type, direction)) == DebugObjectFields.FOUR[direction])

	assert("frame 2" in DebugObjectFields.direction(_record(6, 2)))
	assert("Invalid" in DebugObjectFields.direction(_record(9, 7)))
	assert("ignored" in DebugObjectFields.direction(_record(10, 0x12)))
	assert("Unused" in DebugObjectFields.direction(_record(8, 255)))
	assert("Approaching target; runway axis SW" == DebugObjectFields.state(_record(1, 0, 0x53), city))
	assert("Landing" == DebugObjectFields.state(_record(1, 0, 1), city))
	assert("Crashing" == DebugObjectFields.state(_record(2, 0, 5), city))
	assert("Docked" == DebugObjectFields.state(_record(3, 0, 3), city))
	assert("Distressed" in DebugObjectFields.state(_record(9, 0, 255), city))
	assert("Next car: object 3" in DebugObjectFields.state(_record(10, 0, 3), city))
	assert("Tail car" in DebugObjectFields.state(_record(11), city))
	assert("Air Crash" in DebugObjectFields.state(_record(6, 0, 5), city))
	assert("Fire" in DebugObjectFields.state(_record(6), city))
	assert(DebugObjectFields.goal(_record(5, 0, 0, 1), city) == "Radiation")
	assert(DebugObjectFields.goal(_record(5, 0, 0, 3), city) == "Create wind power")
	assert(DebugObjectFields.goal(_record(6, 0, 0, 255), city) == "Spread damage enabled")
	assert("Follow object 50" in DebugObjectFields.goal(_record(16, 0, 0, OverlayData.thing_id(50)), city))
	assert("Fixed disaster target (450, 350)" == DebugObjectFields.goal(_record(16, 0, 0, 241), city))
	assert("Unused" in DebugObjectFields.goal(_record(1, 0, 0, 143), city))
	assert("Unrecognized" in DebugObjectFields.state(_record(2, 0, 99), city))
	assert(DebugObjectFields.type_name(255) == "Unknown object type")

	for type in range(17):
		var fields := DebugObjectFields.fields(_record(type), city)
		assert(fields.size() == 12)
		assert(fields[0].value == str(type) and fields[0].raw == "0x%02X" % type)
		assert(fields[0].translation == QueryInfo.THING_NAMES[type])
		assert("Next grid X" in fields[6].detail if type in [10, 11, 12, 13] else true)

	assert(city.document.serialize().data == before)
	var panel := preload("res://src/debug/debug_record_table.tscn").instantiate() as DebugRecordTable
	panel.kind = "Objects"
	root.add_child(panel)
	assert(panel.table.columns == 6)
	assert(panel.table.get_column_title(2) == "State")
	assert(panel.table.get_column_title(4) == "Direction" and panel.table.get_column_title(5) == "Goal")
	var things := city.document.find_chunk("XTHG")
	things.decoded_payload[12] = 1
	things.decoded_payload[13] = 3
	things.decoded_payload[14] = 0x53
	panel.update_records(DebugCityTables.collect("Objects", city))
	var row: TreeItem = panel.rows["1"]
	assert(row.get_text(1) == "Airplane\n1 / 0x01")
	assert(row.get_text(4) == "SE\n3 / 0x03")
	assert("83 / 0x53" in row.get_text(2))
	assert("SW" in row.get_child(2).get_text(1))
	row.collapsed = false
	panel.update_records(DebugCityTables.collect("Objects", city))
	assert(not row.collapsed)
	panel.search.text = "runway axis SW"
	panel.search.text_changed.emit(panel.search.text)
	assert(row.visible)
	panel.free()
	print("PASS: type-specific XTHG directions, packed states, targets, field meanings and numeric table columns")
	quit()
