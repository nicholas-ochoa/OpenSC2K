extends SceneTree

@warning_ignore_start("integer_division")

const DocumentState = preload("res://tests/support/document_state.gd")

var checks := 0


func check(condition: bool, label: String) -> void:
	checks += 1
	assert(condition, label)


func _initialize() -> void:
	for edge in [128, 512]:
		for native in [false, true]:
			_test_all(edge, native)
			for subtool in [0, 1]:
				var document := EmptyCityTemplate.create(edge)
				if native:
					document.enable_full_resolution_maps()
				var city := CityState.from_document(document)
				city.set_funds(1000000)
				city.document.set_misc_u32(BuildingCommand.MISC_NORMAL_POPULATION, BuildingCommand.IMMEDIATE_UTILITY_POPULATION_LIMIT + 1) # Skip unrelated placement-time utilities.
				var point := Vector2i(edge - 8, edge - 8)
				check(BuildingCommand.apply(city, 13, subtool, point, SimLfsrRandom.new(1), SimRandom.new(1)).ok, "Place station")
				for turn in (4 if edge == 128 and not native else 1):
					var before: Array = DocumentState.capture(city.document)
					var result := ServiceQueryAnalysis.inspect(city, point)
					check(result.ok, "Inspect station after rotation")
					check(not result.values.is_empty(), "Coverage exists")
					var site: Rect2i = result.site
					for x in range(site.position.x, site.end.x):
						for y in range(site.position.y, site.end.y):
							check(ServiceQueryAnalysis.inspect(city, Vector2i(x, y)).values == result.values, "All footprint tiles select same station")
					var overlay := ServiceQueryOverlay.new()
					overlay.rebuild(city, result)
					check(overlay.polygons.size() == result.values.size(), "Every coverage tile has geometry")
					check(DocumentState.capture(city.document) == before, "Inspection preserves all bytes")
					check(PollutionPhase.run(city).ok, "Run actual data phase")
					var data: PackedByteArray = city.document.find_chunk("XPLC" if subtool == 0 else "XFIR").decoded_payload
					_check_coverage(data, result.values, edge, "Station overlay")
					if edge == 128 and not native and turn < 3:
						CityRotationCommand.apply(city, false)
						point = CityRotationCommand.rotate_point(point, edge, false)
				var budget := PollutionPhase.BUDGET_POLICE if subtool == 0 else PollutionPhase.BUDGET_FIRE
				city.document.set_misc_u32(PollutionPhase.MISC_BUDGETS + budget * PollutionPhase.MISC_BUDGET_RECORD_SIZE + 4, 100)
				var selected := ServiceQueryAnalysis.inspect(city, point)
				var flags := city.tile_flags.duplicate()
				var index := city.index_of(selected.origin.x, selected.origin.y)
				flags[index] |= PollutionPhase.FLAG_POWERED
				city.replace_tile_flags(flags)
				var powered := ServiceQueryAnalysis.inspect(city, point)
				flags[index] &= ~PollutionPhase.FLAG_POWERED
				city.replace_tile_flags(flags)
				var unpowered := ServiceQueryAnalysis.inspect(city, point)
				check(powered.powered and not unpowered.powered, "Power status follows selected station")
				check(int(unpowered.values[unpowered.origin]) < int(powered.values[powered.origin]), "Power loss reduces strength")
				city.document.set_misc_u32(PollutionPhase.MISC_BUDGETS + budget * PollutionPhase.MISC_BUDGET_RECORD_SIZE + 4, 0)
				check(ServiceQueryAnalysis.inspect(city, point).values.is_empty(), "Zero funding has no coverage")
				check(not ServiceQueryAnalysis.inspect(city, Vector2i(-1, 0)).ok, "Reject outside map")
				check(not ServiceQueryAnalysis.inspect(city, Vector2i.ONE * (edge / 2)).ok, "Reject nonstation")
	print("Service Query: %d checks passed" % checks)
	quit()


func _test_all(edge: int, native: bool) -> void:
	var document := EmptyCityTemplate.create(edge)
	if native:
		document.enable_full_resolution_maps()
	var city := CityState.from_document(document)
	city.set_funds(1000000)
	city.document.set_misc_u32(BuildingCommand.MISC_NORMAL_POPULATION, BuildingCommand.IMMEDIATE_UTILITY_POPULATION_LIMIT + 1) # Skip unrelated placement-time utilities.
	var base := Vector2i(edge - 30, edge - 30)
	for subtool in [0, 1]:
		for offset in [Vector2i.ZERO, Vector2i(6, 0)]:
			check(BuildingCommand.apply(city, 13, subtool, base + offset + Vector2i(0, subtool * 6), SimLfsrRandom.new(1), SimRandom.new(1)).ok, "Place overlapping stations")
	var before: Array = DocumentState.capture(city.document)
	var results: Array[Dictionary] = []
	for subtool in [0, 1]:
		var point := base + Vector2i(0, subtool * 6)
		var result := ServiceQueryAnalysis.inspect(city, point, true)
		check(result.ok and result.all_stations and result.station_count == 2, "Shift selects only stations of matching type")
		check(ServiceQueryAnalysis.inspect(city, point + Vector2i(6, 0), true).values == result.values, "Either station gives same combined coverage")
		var overlay := ServiceQueryOverlay.new()
		overlay.rebuild(city, result)
		check(overlay.station_polygons.size() == 18, "Both station footprints are outlined")
		check(overlay.colors[0] == ServiceQueryOverlay.coverage_color(int(result.values.values()[0]), subtool == 1), "Overlay uses service-specific colors")
		results.append(result)
	check(DocumentState.capture(city.document) == before, "All-station inspection preserves city bytes")
	check(PollutionPhase.run(city).ok, "Run combined service simulation")
	for subtool in [0, 1]:
		var data: PackedByteArray = city.document.find_chunk("XPLC" if subtool == 0 else "XFIR").decoded_payload
		_check_coverage(data, results[subtool].values, edge, "Combined coverage")


func _check_coverage(data: PackedByteArray, values: Dictionary, edge: int, label: String) -> void:
	var expected := PackedByteArray()
	expected.resize(edge * edge) # Uncovered cells must remain zero.
	for point: Vector2i in values:
		var value := int(values[point])
		check(point.x >= 0 and point.y >= 0 and point.x < edge and point.y < edge, "Coverage stays in bounds")
		check(value >= 0 and value <= 255, "Coverage fits a byte before packing")
		expected[point.x * edge + point.y] = value
	var actual := data
	if data.size() != edge * edge:
		var source_edge := int(sqrt(data.size()))
		var image := Image.create_from_data(source_edge, source_edge, false, Image.FORMAT_L8, data)
		image.resize(edge, edge, Image.INTERPOLATE_NEAREST)
		actual = image.get_data()
	if actual != expected:
		for index in actual.size():
			if actual[index] != expected[index]:
				check(false, "%s at (%d, %d): simulation=%d overlay=%d" % [label,
					(index / edge), index % edge, actual[index], expected[index]])
				return
	check(actual == expected, label + " matches the whole simulation map, including zeros")
