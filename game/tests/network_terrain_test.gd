extends SceneTree

var checks := 0
var failures := 0
const TOOLS := [Vector2i(6, 0), Vector2i(7, 0), Vector2i(3, 0), Vector2i(7, 1), Vector2i(4, 0)]


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)


func _initialize() -> void:
	for edge in [128, 256, 384, 512]:
		_test_routes(edge)
		_test_surface_connections(edge)
		_test_reused_crossings(edge)
		_test_transactions(edge)
		_test_underground_grading(edge)
	print("Network terrain: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _fixture(edge: int) -> Dictionary:
	var city := CityState.from_document(EmptyCityTemplate.create(edge))
	return NetworkCommand._city_payloads(city)


func _route(data: Dictionary, start: Vector2i, finish: Vector2i, mode: int, edge: int) -> Array[Vector2i]:
	return NetworkCommand._plan_route(data.XBLD, data.XTER, data.XZON, data.XUND, data.XBIT, data.ALTM, start, finish, mode, edge)


func _test_routes(edge: int) -> void:
	var data := _fixture(edge)
	var start := Vector2i(edge - 12, edge - 12)
	for mode in 5:
		for direction in 4:
			var step: Vector2i = NetworkCommand.DIRECTIONS[direction]
			var next := start + step
			var index := next.x * edge + next.y
			data.XTER[index] = 1 if direction % 2 == 0 else 2
			check(_route(data, start, start + step * 2, mode, edge) == [start], "Reject sideways slope mode %d direction %d edge %d" % [mode, direction, edge])
			data.XTER[index] = 2 if direction % 2 == 0 else 1
			check(_route(data, start, start + step * 2, mode, edge).size() == 3, "Allow aligned slope mode %d direction %d" % [mode, direction])
			data.XTER[index] = 0
			data.XTER[start.x * edge + start.y] = 13
			check(_route(data, start, next, mode, edge) == [start], "Reject raised flat to lower flat mode %d direction %d" % [mode, direction])
			data.XTER[start.x * edge + start.y] = 0

	# Rail cannot turn directly onto a non-flat tile. Roads may do so.
	data.XTER[(start.x + 1) * edge + start.y + 1] = 2
	check(_route(data, start, start + Vector2i(2, 1), NetworkCommand.MODE_RAIL, edge) == [start, start + Vector2i(1, 0)], "Rail stops before turn onto grade")
	check(_route(data, start, start + Vector2i(2, 1), NetworkCommand.MODE_ROAD, edge).size() == 3, "Road retains permitted turn onto grade")
	data.XTER[(start.x + 1) * edge + start.y + 1] = 0

	# The original checks the raw land height for a rail continuing on slopes.
	data.XTER[start.x * edge + start.y] = 1
	data.XTER[(start.x + 1) * edge + start.y] = 1
	var next_index := (start.x + 1) * edge + start.y
	NetworkCommand._set_land_altitude(data.ALTM, next_index, NetworkCommand._land_altitude(data.ALTM, next_index) + 1)
	check(_route(data, start, start + Vector2i(2, 0), NetworkCommand.MODE_RAIL, edge) == [start], "Rail rejects unequal slope bases")
	check(_route(data, start, start + Vector2i(2, 0), NetworkCommand.MODE_ROAD, edge).size() == 3, "Road retains original non-rail slope rule")


func _test_surface_connections(edge: int) -> void:
	var data := _fixture(edge)
	var point := Vector2i(edge - 12, edge - 12)
	var center := point.x * edge + point.y
	for mode in 3:
		var base: int = [0x1d, 0x2c, 0x0e][mode]
		for direction in 4:
			var step: Vector2i = NetworkCommand.DIRECTIONS[direction]
			var near := point + step
			var near_index := near.x * edge + near.y
			# Build a straight line perpendicular to the neighbor's approach.
			var cross: Vector2i = NetworkCommand.DIRECTIONS[(direction + 1) % 4]
			var left := point + cross
			var right := point - cross
			for cell in [point, near, left, right]:
				data.XBLD[cell.x * edge + cell.y] = base
				data.XBIT[cell.x * edge + cell.y] |= 0x80
			data.XTER[near_index] = 1 if direction % 2 == 0 else 2
			data.XBLD[near_index] = base + 2 if direction % 2 == 0 else base + 3
			NetworkCommand._retile_surface(data.XBLD, data.XTER, data.XZON, data.XBIT, data.MISC, point, mode, data.XTXT, edge)
			check(data.XBLD[center] == base + (1 if direction % 2 == 0 else 0), "No false side junction mode %d direction %d edge %d" % [mode, direction, edge])
			for cell in [point, near, left, right]:
				data.XBLD[cell.x * edge + cell.y] = 0
				data.XBIT[cell.x * edge + cell.y] = 0
			data.XTER[near_index] = 0


func _test_transactions(edge: int) -> void:
	var city := CityState.from_document(EmptyCityTemplate.create(edge))
	city.set_funds(100000)
	var start := Vector2i(edge - 12, edge - 12)
	city.set_terrain_id(start.x, start.y + 1, 1)
	for mode in 5:
		var before: PackedByteArray = city.document.serialize().data
		var tool: Vector2i = TOOLS[mode]
		var preview_city := NetworkPlacementPreview.snapshot_city(city)
		var preview := NetworkPlacementPreview.apply_preview(preview_city, tool.x, tool.y, start, start + Vector2i(0, 2))
		var result := NetworkCommand.apply(city, tool.x, tool.y, start, start + Vector2i(0, 2))
		check(result.get("ok", false) and result.get("points", []).size() == 1, "Placement keeps valid prefix mode %d edge %d" % [mode, edge])
		check(result.get("cost", -1) == int(ToolCatalog.tool(tool.x, tool.y).cost), "Charge only the valid prefix")
		check(preview.get("ok", false) and preview_city.document.serialize().data == city.document.serialize().data, "Preview and placement bytes agree")
		var loaded := Sc2File.new()
		check(loaded.parse(city.document.serialize().data), "Saved corrected route reloads")
		check(NetworkCommand.undo(city, result).get("ok", false) and city.document.serialize().data == before, "Exact terrain, flags, costs and network Undo")


func _test_reused_crossings(edge: int) -> void:
	var data := _fixture(edge)
	var start := Vector2i(edge - 12, edge - 12)
	# Reusing a crossing is free, but each network still follows its fixed axis.
	for fixture in [[0, 0x43, 0], [0, 0x44, 1], [1, 0x45, 1], [1, 0x46, 0], [2, 0x47, 1], [2, 0x48, 0], [3, 0x1f, 0], [3, 0x20, 1], [4, 0x1f, 1], [4, 0x20, 0]]:
		var mode: int = fixture[0]
		var axis: int = fixture[2]
		var layer: PackedByteArray = data.XBLD if mode < 3 else data.XUND
		var valid_step: Vector2i = Vector2i(1, 0) if axis == 1 else Vector2i(0, 1)
		var cross_step := Vector2i(valid_step.y, valid_step.x)
		var near := start + cross_step
		layer[near.x * edge + near.y] = fixture[1]
		check(_route(data, start, start + cross_step * 2, mode, edge) == [start], "Reuse rejects wrong crossing axis mode %d tile %x" % [mode, fixture[1]])
		layer[near.x * edge + near.y] = 0
		near = start + valid_step
		layer[near.x * edge + near.y] = fixture[1]
		var route := _route(data, start, start + valid_step * 2 + cross_step, mode, edge)
		check(route.has(start + valid_step * 2), "Reuse keeps straight through crossing mode %d tile %x" % [mode, fixture[1]])
		layer[near.x * edge + near.y] = 0


func _test_underground_grading(edge: int) -> void:
	var city := CityState.from_document(EmptyCityTemplate.create(edge))
	city.set_funds(100000)
	var start := Vector2i(edge - 12, edge - 12)
	for mode in [NetworkCommand.MODE_SUBWAY, NetworkCommand.MODE_PIPE]:
		var tool: Vector2i = TOOLS[mode]
		for shape in range(5, 13):
			for direction in 4:
				city.set_terrain_id(start.x, start.y, shape)
				var before: PackedByteArray = city.document.serialize().data
				var finish: Vector2i = start + NetworkCommand.DIRECTIONS[direction]
				var result := NetworkCommand.apply(city, tool.x, tool.y, start, finish)
				check(result.get("ok", false), "Underground compound terrain is placeable")
				if not result.get("ok", false):
					continue
				var expected: int = 13 if shape < 9 else [[2, 1, 2, 1], [2, 3, 2, 3], [4, 3, 4, 3], [4, 1, 4, 1]][shape - 9][direction]
				check(city.terrain_id(start.x, start.y) == expected, "Underground terrain matches the selected axis")
				check(result.graded_tiles == 1 and result.cost == result.points.size() * int(ToolCatalog.tool(tool.x, tool.y).cost) + 25, "Underground grading costs 25 per adjusted tile")
				check(NetworkCommand.undo(city, result).get("ok", false) and city.document.serialize().data == before, "Underground grading has exact Undo")
