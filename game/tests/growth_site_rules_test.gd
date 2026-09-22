extends SceneTree
## Check saved corner bits and the distinct power rules at the map edges.

@warning_ignore_start("integer_division")

var checks := 0
var failures := 0


func _initialize() -> void:
	for edge in [16, 128, 256]:
		_check_corners(edge)
		_check_power(edge)
	print("Growth site rules: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _check_corners(edge: int) -> void:
	for area in [1, 2, 3, 4]:
		for point in [Vector2i.ZERO, Vector2i(1, 2), Vector2i(edge - area, edge - area)]:
			for rotation in 4:
				var zones := PackedByteArray()
				zones.resize(edge * edge)
				zones.fill(0xa7)
				var expected := zones.duplicate()
				if area == 1:
					# The last corner write selects the anchor for a one-tile building.
					expected[point.x * edge + point.y] = [0x87, 0x17, 0x27, 0x47][rotation]
				else:
					var corners := [point, point + Vector2i(area - 1, 0),
						point + Vector2i(area - 1, area - 1), point + Vector2i(0, area - 1)]
					for corner in 4:
						var at: Vector2i = corners[corner]
						expected[at.x * edge + at.y] = 7 | (1 << (4 + (corner + rotation) % 4))
				GrowthSiteRules.set_corners(zones, point, area, rotation, edge)
				_check(zones == expected, "Corner rotation preserves zones and all other tiles")


func _check_power(edge: int) -> void:
	var flags := PackedByteArray()
	flags.resize(edge * edge)
	for x in [0, 1, 2, edge - 2, edge - 1]:
		for y in [0, 1, 2, edge - 2, edge - 1]:
			for offset in [Vector2i.ZERO, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN, Vector2i.ONE]:
				flags.fill(0)
				var source: Vector2i = Vector2i(x, y) + offset
				var in_bounds := Rect2i(0, 0, edge, edge).has_point(source)
				if in_bounds:
					flags[source.x * edge + source.y] = 64
				var expected: bool = in_bounds and offset != Vector2i.ONE
				if (offset == Vector2i.LEFT and x == 1) or (offset == Vector2i.UP and y == 1):
					expected = false
				_check(GrowthSiteRules.has_power(flags, x, y, edge) == expected,
					"Power uses the center and permitted cardinal neighbors")
	flags.fill(0)
	for value in 256:
		flags[3 * edge + 3] = value
		_check(GrowthSiteRules.has_power(flags, 3, 3, edge) == (value / 64 % 2 == 1),
			"Only the powered bit supplies power")


func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
