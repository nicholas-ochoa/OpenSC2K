extends SceneTree

const DocumentState = preload("res://tests/support/document_state.gd")
const TOOLS := [Vector2i(6, 0), Vector2i(7, 0), Vector2i(3, 0), Vector2i(7, 1), Vector2i(4, 0)]

var checks := 0
var failures := 0


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)


func _initialize() -> void:
	_test_subway_pipe_crossings()
	# the native route tests cover the slope, crossing, and connection rules
	for edge in [128, 256, 384, 512]:
		_test_transactions(edge)
		_test_underground_grading(edge)
	print("Network terrain: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _test_subway_pipe_crossings() -> void:
	var start := Vector2i(20, 20)
	var city := CityState.from_document(EmptyCityTemplate.create(128))
	city.set_funds(100000)
	for fixture in [[0x10, 1, 0x20], [0x11, 0, 0x1f], [0x10, 0, 0x10], [0x11, 1, 0x11], [0x1e, 1, 0x1e]]:
		var step: Vector2i = NetworkCommand.DIRECTIONS[fixture[1]]
		var crossing := start + step
		city.set_underground_id(crossing.x, crossing.y, fixture[0])
		var before: Array = DocumentState.capture(city.document)
		var preview_city := NetworkPlacementPreview.snapshot_city(city)
		var preview := NetworkPlacementPreview.apply_preview(preview_city, 7, 1, start, start + step * 2)
		var result := NetworkCommand.apply(city, 7, 1, start, start + step * 2)
		var count := 3 if fixture[2] >= 0x1f else 1
		check(
			result.ok and result.points.size() == count and city.underground_id(crossing.x, crossing.y) == fixture[2],
			"Subway placement preserves the pipe and uses the correct crossing",
		)
		check(result.cost == count * int(ToolCatalog.tool(7, 1).cost), "Subway charges only for placed tiles")
		check(
			preview.ok and DocumentState.capture(preview_city.document) == DocumentState.capture(city.document),
			"Subway crossing preview matches placement",
		)
		check(NetworkCommand.undo(city, result).ok and DocumentState.capture(city.document) == before, "Subway crossing has exact Undo")
		city.set_underground_id(crossing.x, crossing.y, 0)


func _test_transactions(edge: int) -> void:
	var city := CityState.from_document(EmptyCityTemplate.create(edge))
	city.set_funds(100000)
	var start := Vector2i(edge - 12, edge - 12)
	city.set_terrain_id(start.x, start.y + 1, 1)
	for mode in 5:
		var before: Array = DocumentState.capture(city.document)
		var tool: Vector2i = TOOLS[mode]
		var preview_city := NetworkPlacementPreview.snapshot_city(city)
		var preview := NetworkPlacementPreview.apply_preview(preview_city, tool.x, tool.y, start, start + Vector2i(0, 2))
		var result := NetworkCommand.apply(city, tool.x, tool.y, start, start + Vector2i(0, 2))
		check(result.ok and result.points.size() == 1, "Placement keeps valid prefix mode %d edge %d" % [mode, edge])
		check(result.cost == int(ToolCatalog.tool(tool.x, tool.y).cost), "Charge only the valid prefix")
		check(
			preview.ok and DocumentState.capture(preview_city.document) == DocumentState.capture(city.document),
			"Preview and placement bytes agree",
		)
		var loaded := Sc2File.new()
		check(loaded.parse(city.document.serialize().data), "Saved corrected route reloads")
		check(
			NetworkCommand.undo(city, result).ok and DocumentState.capture(city.document) == before,
			"Exact terrain, flags, costs and network Undo",
		)


func _test_underground_grading(edge: int) -> void:
	var city := CityState.from_document(EmptyCityTemplate.create(edge))
	city.set_funds(100000)
	var start := Vector2i(edge - 12, edge - 12)
	for mode in [NetworkCommand.MODE_SUBWAY, NetworkCommand.MODE_PIPE]:
		var tool: Vector2i = TOOLS[mode]
		for shape in (range(5, 13) if edge == 128 else [9]):
			for direction in (range(4) if edge == 128 else [0]):
				city.set_terrain_id(start.x, start.y, shape)
				var before: Array = DocumentState.capture(city.document)
				var finish: Vector2i = start + NetworkCommand.DIRECTIONS[direction]
				var result := NetworkCommand.apply(city, tool.x, tool.y, start, finish)
				check(result.ok, "Underground compound terrain is placeable")
				if not result.ok:
					continue
				var expected: int = 13 if shape < 9 else [[2, 1, 2, 1], [2, 3, 2, 3], [4, 3, 4, 3], [4, 1, 4, 1]][shape - 9][direction]
				check(city.terrain_id(start.x, start.y) == expected, "Underground terrain matches the selected axis")
				check(
					result.graded_tiles == 1 and result.cost == result.points.size() * int(ToolCatalog.tool(tool.x, tool.y).cost) + 25,
					"Underground grading costs 25 per adjusted tile",
				)
				check(
					NetworkCommand.undo(city, result).ok and DocumentState.capture(city.document) == before,
					"Underground grading has exact Undo",
				)
