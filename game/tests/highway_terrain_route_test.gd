extends SceneTree
const DocumentState = preload("res://tests/support/document_state.gd")

var checks := 0
var failures := 0


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)


func _initialize() -> void:
	for direction in 4:
		_test_direct_bridge(direction)
	for edge in [128, 256, 384, 512]:
		for direction in (range(4) if edge == 128 else [[128, 256, 384, 512].find(edge)]):
			_test_crossing(edge, direction)
	print("Highway terrain route: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _test_direct_bridge(direction: int) -> void:
	var city := CityState.from_document(EmptyCityTemplate.create(128))
	city.set_funds(100000)
	var start := Vector2i(20, 20)
	var step: Vector2i = HighwayCommand.DIRECTIONS[direction]
	var side := Vector2i(1, 0) if direction % 2 == 0 else Vector2i(0, 1)
	var water_start: Vector2i = start + [Vector2i.ZERO, Vector2i(1, 0), Vector2i(0, 1), Vector2i.ZERO][direction]
	for distance in 5:
		for width in 2:
			var point := water_start + step * distance + side * width
			city.set_terrain_id(point.x, point.y, 0x10)
			city.set_tile_flag(point.x, point.y, 0x04, true)
	var data := NetworkState.city_payloads(city)
	var plan := HighwayBridges.plan_bridge_from_start(data.XBLD, data.XTER, data.ALTM, start, 0)
	check(HighwayBridges.bridge_terrain_code(data.XTER, start) == [0xc030, 0x9060, 0x30c0, 0x6090][direction], "Highway shoreline cells use the original order direction %d" % direction)
	check(plan.ok and plan.direction == direction and plan.span_length == 3, "Highway bridge faces the opposite bank direction %d" % direction)
	var before: Array = DocumentState.capture(city.document)
	var preview_city := NetworkPlacementPreview.snapshot_city(city)
	var preview := HighwayCommand.apply(preview_city, 6, 1, start, start, HighwayCommand.CONNECTION_UNSELECTED, HighwayCommand.BRIDGE_HIGHWAY)
	var result := HighwayCommand.apply(city, 6, 1, start, start, HighwayCommand.CONNECTION_UNSELECTED, HighwayCommand.BRIDGE_HIGHWAY)
	check(result.ok and result.bridge_built and result.bridge_exit == start + step * 6, "Direct highway bridge reaches the expected bank")
	check(result.cost == 3 * int(HighwayCommand.BRIDGE_COSTS[HighwayCommand.BRIDGE_HIGHWAY]), "Direct highway bridge charges the correct span")
	check(preview.ok and DocumentState.capture(preview_city.document) == DocumentState.capture(city.document), "Direct highway bridge preview matches placement")
	check(HighwayCommand.undo(city, result).ok and DocumentState.capture(city.document) == before, "Direct highway bridge has exact Undo")


func _test_crossing(edge: int, direction: int) -> void:
	var city := CityState.from_document(EmptyCityTemplate.create(edge))
	city.set_funds(100000)
	city.document.set_misc_u32(0x08, direction)
	var start := Vector2i(edge - 16, edge - 16)
	var step: Vector2i = HighwayCommand.DIRECTIONS[direction]
	var side: Vector2i = HighwayCommand.DIRECTIONS[(direction + 1) % 4]
	var finish := start + step * 6 + side * 4
	var crossing := start + step * (4 if direction % 2 == 0 else 2)
	for base in [0x0e, 0x1d, 0x2c]:
		var tile_id: int = base + (1 if direction % 2 == 0 else 0)
		for offset in [Vector2i.ZERO, Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1)]:
			var point: Vector2i = crossing + offset
			city.set_building_id(point.x, point.y, tile_id)
		var before: Array = DocumentState.capture(city.document)
		var preview := NetworkPlacementPreview.snapshot_city(city)
		var preview_result := HighwayCommand.apply(preview, 6, 1, start, finish)
		var result := HighwayCommand.apply(city, 6, 1, start, finish)
		check(result.ok, "Highway crossing builds")
		if not result.ok:
			continue
		check(result.sections.has(crossing + step * 2) and not result.sections.has(crossing + side * 2), "Keep incoming axis through crossing %x direction %d edge %d" % [tile_id, direction, edge])
		check(preview_result.ok and DocumentState.capture(preview.document) == DocumentState.capture(city.document), "Highway preview has identical bytes")
		check(result.cost == result.sections.size() * 100, "Highway section prices remain unchanged")
		check(HighwayCommand.undo(city, result).ok and DocumentState.capture(city.document) == before, "Crossing route has exact Undo")
