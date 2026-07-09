extends SceneTree
class QuietRandom extends SimRandom:


	func next_u15() -> int:
		return 1


class QuietLfsrRandom extends SimLfsrRandom:


	func next_mod(_limit: int) -> int:
		return 1


func _initialize() -> void:
	for direction in 8:
		var delta: Vector2i = ShipThingTick.DIRECTIONS[direction]
		var point := Vector2i(0 if delta.x < 0 else 127 if delta.x > 0 else 64, 0 if delta.y < 0 else 127 if delta.y > 0 else 64)
		var text := PackedByteArray()
		text.resize(CityState.TILE_COUNT)
		var things := PackedByteArray()
		things.resize(CityState.THING_RECORD_SIZE)
		things[0] = 3
		things[3] = point.x
		things[4] = point.y
		things[6] = 12 if delta.x > 0 else 0
		things[7] = 12 if delta.y > 0 else 0
		things[10] = 42
		text[point.x * 128 + point.y] = 201
		assert(not ShipThingTick._move(text, things, 0, direction))
		assert(things[0] == 0, "Ship failed to leave at a map edge or corner")
		assert(text[point.x * 128 + point.y] == 42, "Restore the tile's saved text marker")

		for state in [0, 4]:
			things[0] = 3
			things[1] = direction
			things[2] = state
			things[6] = 12 if delta.x > 0 else 0
			things[7] = 12 if delta.y > 0 else 0
			text[point.x * 128 + point.y] = 201
			var blank := PackedByteArray()
			blank.resize(CityState.TILE_COUNT)
			var water := blank.duplicate()
			water.fill(4)
			var counters := {"moved_ships": 0, "removed_ships": 0, "sound_events": []}
			ShipThingTick.update(blank, blank, water, text, things, 0, point, QuietRandom.new(), QuietLfsrRandom.new(), counters)
			assert(things[0] == 0 and counters.removed_ships == 1 and counters.moved_ships == 0)
			assert(text[point.x * 128 + point.y] == 42)

	print("PASS: ship exits in all eight directions")
	quit()
