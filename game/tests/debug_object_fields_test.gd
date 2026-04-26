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

	for type in range(17):
		var fields := DebugObjectFields.fields(_record(type), city)
		assert(fields.size() == 12)
		assert(fields[0].value == str(type) and fields[0].raw == "0x%02X" % type)
		assert(fields[0].translation == QueryInfo.THING_NAMES[type])

	assert(city.document.serialize().data == before)
	var panel := preload("res://src/debug/debug_record_table.tscn").instantiate() as DebugRecordTable
	panel.kind = "Objects"
	root.add_child(panel)
	var things := city.document.find_chunk("XTHG")
	things.decoded_payload[12] = 1
	things.decoded_payload[13] = 3
	things.decoded_payload[14] = 0x53
	panel.update_records(DebugCityTables.collect("Objects", city))
	var row: TreeItem = panel.rows["1"]
	assert(row.get_text(1).contains("1 / 0x01"))
	assert(row.get_text(4).contains("3 / 0x03"))
	assert("83 / 0x53" in row.get_text(2))
	assert("SW" in row.get_child(2).get_text(1))
	row.collapsed = false
	panel.update_records(DebugCityTables.collect("Objects", city))
	assert(not row.collapsed)
	panel.search.text = DebugObjectFields.state(_record(1, 3, 0x53), city)
	panel.search.text_changed.emit(panel.search.text)
	assert(row.visible)
	panel.free()
	print("PASS: type-specific XTHG directions, packed states, targets, field meanings and numeric table columns")
	quit()
