extends SceneTree

var checks := 0
var failures := 0


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)


func _initialize() -> void:
	for edge in Sc2File.MAP_SIZES:
		for direction in 4:
			_test_crossing(edge, direction)
	print("Highway terrain route: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


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
		var before: PackedByteArray = city.document.serialize().data
		var preview := NetworkPlacementPreview.snapshot_city(city)
		var preview_result := HighwayCommand.apply(preview, 6, 1, start, finish)
		var result := HighwayCommand.apply(city, 6, 1, start, finish)
		check(result.get("ok", false), "Highway crossing builds")
		if not result.get("ok", false):
			continue
		check(result.sections.has(crossing + step * 2) and not result.sections.has(crossing + side * 2), "Keep incoming axis through crossing %x direction %d edge %d" % [tile_id, direction, edge])
		check(preview_result.get("ok", false) and preview.document.serialize().data == city.document.serialize().data, "Highway preview has identical bytes")
		check(result.cost == result.sections.size() * 100, "Highway section prices remain unchanged")
		check(HighwayCommand.undo(city, result).get("ok", false) and city.document.serialize().data == before, "Crossing route has exact Undo")
