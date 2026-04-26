extends SceneTree

# Supplied executable 0x4419ae..0x441a9b: highway direction, road direction, XBLD.
const CASES := [[1, 0, 0x5f], [3, 0, 0x5e], [0, 1, 0x5d], [2, 1, 0x60],
	[1, 2, 0x60], [3, 2, 0x5d], [0, 3, 0x5e], [2, 3, 0x5f]]
var failures := 0
var checks := 0


func check(ok: bool, label: String) -> void:
	checks += 1

	if not ok:
		failures += 1
		push_error(label)


func _initialize() -> void:
	for edge in [128, 256, 384, 512]:
		var city := CityState.from_document(EmptyCityTemplate.create(edge))
		city.set_funds(1000)
		var points: Array[Vector2i] = []
		for index in CASES.size():
			var entry: Array = CASES[index]
			var point := Vector2i(edge - 12 - (index % 4) * 12, edge - 12 - IntegerMath.div_trunc(index, 4) * 12)
			points.append(point)
			var highway: Vector2i = point + OnrampCommand.DIRECTIONS[entry[0]]
			var road: Vector2i = point + OnrampCommand.DIRECTIONS[entry[1]]
			city.set_building_id(highway.x, highway.y, 0x49)
			city.set_building_id(road.x, road.y, 0x1d)

		var before: PackedByteArray = city.document.serialize().data
		var commands: Array[Dictionary] = []
		for index in CASES.size():
			var entry: Array = CASES[index]
			var point := points[index]
			var road: Vector2i = point + OnrampCommand.DIRECTIONS[entry[1]]
			var funds := city.funds()
			var command := OnrampCommand.apply(city, 6, 3, point)
			commands.append(command)
			check(command.ok and city.building_id(point.x, point.y) == entry[2], "Correct ramp for %s" % [entry])
			check(city.is_flipped(point.x, point.y) == (entry[1] % 2 == 0), "Correct mirror")
			check(city.funds() == funds - 25 and city.building_id(road.x, road.y) == 0x2b, "Cost and adjacent road")

		# One city contains every orientation. Rotate all cases together.
		for ccw in [false, true]:
			var rotated := CityState.from_document(city.document.duplicate_document())
			for turn in 4:
				check(CityRotationCommand.apply(rotated, ccw).ok, "Rotate ramps")
				for index in CASES.size():
					var entry: Array = CASES[index]
					var rotated_point := points[index]
					var rotated_highway: Vector2i = rotated_point + OnrampCommand.DIRECTIONS[entry[0]]
					var rotated_road: Vector2i = rotated_point + OnrampCommand.DIRECTIONS[entry[1]]

					for step in turn + 1:
						rotated_point = CityRotationCommand.rotate_point(rotated_point, edge, ccw)
						rotated_highway = CityRotationCommand.rotate_point(rotated_highway, edge, ccw)
						rotated_road = CityRotationCommand.rotate_point(rotated_road, edge, ccw)
					var hd := OnrampCommand.DIRECTIONS.find(rotated_highway - rotated_point)
					var rd := OnrampCommand.DIRECTIONS.find(rotated_road - rotated_point)
					check(rotated.building_id(rotated_point.x, rotated_point.y) == OnrampCommand._ramp_tile(1 << hd, rd), "Rotation agrees with placement")
					check(rotated.is_flipped(rotated_point.x, rotated_point.y) == (rd % 2 == 0), "Rotated mirror agrees with placement")

		commands.reverse()
		for command in commands:
			check(OnrampCommand.undo(city, command).ok, "Ramp Undo")
		check(city.document.serialize().data == before, "All ramp edits undo exactly")

	print("On-ramp orientation: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
