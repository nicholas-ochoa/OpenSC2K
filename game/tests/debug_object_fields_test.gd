extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _record(type: int, direction := 0, state := 0, goal := 0) -> ThingRecord:
	return ThingRecord.from_fields({"type": type, "direction": direction, "state": state, "goal": goal,
		"x": 400, "y": 300, "z": 10, "px": 8, "py": 8, "dx": 450, "dy": 350, "label": 0})


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
	assert(panel.has_row("1"))
	var row := panel.row_cells("1")
	var raw := panel.row_cells("1", 0)
	assert(panel.source.row("1").fields.size() == 1 and panel.table.column_count() == DebugObjectFields.COLUMNS.size() + 2)
	# Column 1 is the locate icon; data columns follow it. Only record rows locate
	assert(panel.locate_column == 1 and row[1] == "" and raw[1] == "" and panel.source.row("1").site != null)
	var located: Array[Rect2i] = []
	panel.locate_requested.connect(func(site: Rect2i) -> void: located.append(site))
	panel.locate_on_map("1")
	assert(located == [Rect2i(0, 0, 1, 1)])
	assert(row[2] == QueryInfo.THING_NAMES[1] and raw[2] == "1 / 0x01")
	assert(row[4] == "SE" and raw[4] == "3 / 0x03")
	assert(row[3] == DebugObjectFields.state(_record(1, 3, 0x53), city) and raw[3] == "83 / 0x53")
	assert(row[5] == "Unused" and "Unused" in panel.table.tooltip_of("1", -1, 5))
	for cells: Array[String] in [row, raw]:
		for column in panel.table.column_count():
			assert(not "\n" in cells[column])
	panel.table.set_expanded("1", true)
	panel.update_records(DebugCityTables.collect("Objects", city))
	assert(panel.table.is_expanded("1"))
	panel.search.text = DebugObjectFields.state(_record(1, 3, 0x53), city)
	panel.search.text_changed.emit(panel.search.text)
	assert("1" in panel.shown_ids())
	panel.free()
	print("PASS: type-specific XTHG directions, packed states, targets, field meanings and one-line translated and raw table columns")
	quit()
