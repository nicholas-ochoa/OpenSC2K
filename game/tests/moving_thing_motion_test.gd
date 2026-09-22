extends SceneTree

var failures := 0


func _initialize() -> void:
	for direction in 8:
		var target: Vector2i = MovingThingMotion.DIRECTIONS[direction] * 9
		check(MovingThingMotion.direction_between(Vector2i.ZERO, target) == direction, "direction")
		check(MovingThingMotion.direction_quadrant(Vector2i.ZERO, target) == direction, "quadrant")
	check(MovingThingMotion.direction_between(Vector2i.ZERO, Vector2i.ZERO) == 3, "zero direction")
	check(MovingThingMotion.direction_quadrant(Vector2i.ZERO, Vector2i.ZERO) == 4, "zero quadrant")
	check(MovingThingMotion.direction_between(Vector2i.ZERO, Vector2i(1, 3)) == 4, "direction slope")
	check(MovingThingMotion.direction_quadrant(Vector2i.ZERO, Vector2i(1, 3)) == 3, "quadrant slope")
	for edge in [128, 256]:
		var record := 1 if edge == 128 else 241
		var text := PackedByteArray()
		text.resize(edge * edge * (1 if edge == 128 else 2))
		var things := PackedByteArray()
		things.resize(480 if edge == 128 else 512 * 24)
		var origin := Vector2i(10, 10) if edge == 128 else Vector2i(200, 200)
		for direction in 8:
			text.fill(0)
			things.fill(0)
			prepare(text, things, record, origin, edge)
			var next: Vector2i = origin + MovingThingMotion.DIRECTIONS[direction]
			OverlayData.write(text, next.x * edge + next.y, 77)
			check(MovingThingMotion.move(16, text, things, record, direction, edge) == 1, "tile move")
			check(ThingData.read(things, record * 12 + 3) == next.x and ThingData.read(things, record * 12 + 4) == next.y, "coordinates")
			check(OverlayData.read(text, origin.x * edge + origin.y) == 51, "old overlay restored")
			check(OverlayData.read(text, next.x * edge + next.y) == OverlayData.thing_id(record), "new overlay")
			check(ThingData.read(things, record * 12 + 10) == 77, "new underlay saved")
		text.fill(0)
		things.fill(0)
		prepare(text, things, record, origin, edge)
		for step in [1, 2]:
			OverlayData.write(text, (origin.x + step) * edge + origin.y, 251)
		check(MovingThingMotion.move(16, text, things, record, 2, edge) == 1, "blocked tiles skipped")
		check(ThingData.read(things, record * 12 + 3) == origin.x + 3, "skip destination")
		check(OverlayData.read(text, (origin.x + 1) * edge + origin.y) == 251, "blocked overlay retained")
		text.fill(0)
		things.fill(0)
		prepare(text, things, record, Vector2i.ZERO, edge)
		check(MovingThingMotion.move(16, text, things, record, 7, edge) == -1, "map exit")
		check(ThingData.read(things, record * 12) == 0 and OverlayData.read(text, 0) == 0, "exit removes record")
		text.fill(0)
		things.fill(0)
		prepare(text, things, record, origin, edge)
		ThingData.write(things, record * 12 + 6, 0)
		check(MovingThingMotion.move(16, text, things, record, 2, edge) == 0, "subtile limit stays on tile")
		check(ThingData.read(things, record * 12 + 6) == 16, "subtile limit value")
		for caller: GDScript in [AirThingMotion, MaxisManThingTick, DisasterThingActions]:
			for kind in [1, 2, 5, 6, 15, 16]:
				text.fill(0)
				things.fill(0)
				prepare(text, things, record, origin, edge)
				ThingData.write(things, record * 12, kind)
				var accepted: bool = (kind in [1, 2] if caller == AirThingMotion else kind == 16 if caller == MaxisManThingTick else kind in [5, 15])
				var result: int = caller._move_thing_eight_way(kind, text, things, record, 2, edge)
				check((result >= 0) == accepted, "caller type policy")
				if not accepted:
					check(ThingData.read(things, record * 12) == 0 and OverlayData.read(text, origin.x * edge + origin.y) == 0, "unsupported type removed")
	print("Moving motion checks: %d failures" % failures)
	quit(1 if failures else 0)


func prepare(text: PackedByteArray, things: PackedByteArray, record: int, point: Vector2i, edge: int) -> void:
	for pair in [[0, 1], [3, point.x], [4, point.y], [6, 8], [7, 8], [10, 51]]:
		ThingData.write(things, record * 12 + pair[0], pair[1])
	OverlayData.write(text, point.x * edge + point.y, OverlayData.thing_id(record))


func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr(message)
