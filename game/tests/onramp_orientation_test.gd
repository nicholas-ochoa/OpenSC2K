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
		for entry in CASES:
			var city := CityState.from_document(EmptyCityTemplate.create(edge))
			var point := Vector2i(edge - 12, edge - 12)
			var highway: Vector2i = point + OnrampCommand.DIRECTIONS[entry[0]]
			var road: Vector2i = point + OnrampCommand.DIRECTIONS[entry[1]]
			city.set_building_id(highway.x, highway.y, 0x49)
			city.set_building_id(road.x, road.y, 0x1d)
			city.set_funds(100)
			var before: PackedByteArray = city.document.serialize().data
			var command := OnrampCommand.apply(city, 6, 3, point)
			check(command.ok and city.building_id(point.x, point.y) == entry[2], "Correct ramp for %s" % [entry])
			check(city.is_flipped(point.x, point.y) == (entry[1] % 2 == 0), "Correct mirror")
			check(city.funds() == 75 and city.building_id(road.x, road.y) == 0x2b, "Cost and adjacent road")

			for ccw in [false, true]:
				var rotated := CityState.from_document(city.document.duplicate_document())
				var rotated_point := point
				var rotated_highway := highway
				var rotated_road := road

				for turn in 4:
					check(CityRotationCommand.apply(rotated, ccw).ok, "Rotate ramp")
					rotated_point = CityRotationCommand.rotate_point(rotated_point, edge, ccw)
					rotated_highway = CityRotationCommand.rotate_point(rotated_highway, edge, ccw)
					rotated_road = CityRotationCommand.rotate_point(rotated_road, edge, ccw)
					var hd := OnrampCommand.DIRECTIONS.find(rotated_highway - rotated_point)
					var rd := OnrampCommand.DIRECTIONS.find(rotated_road - rotated_point)
					check(rotated.building_id(rotated_point.x, rotated_point.y) == OnrampCommand._ramp_tile(1 << hd, rd), "Rotation agrees with placement")
					check(rotated.is_flipped(rotated_point.x, rotated_point.y) == (rd % 2 == 0), "Rotated mirror agrees with placement")

			check(OnrampCommand.undo(city, command).ok and city.document.serialize().data == before, "Exact ramp Undo")

	print("On-ramp orientation: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
