class_name MovingThingSpawner
extends RefCounted

@warning_ignore_start("integer_division")

const Tiles = preload("res://src/tools/shared/building_tile_ids.gd")

const MAP_SIZE := 128
const RECORD_SIZE := 12
const FIRST_RECORD := 1
const LAST_RECORD := 39
const TEXT_LABEL_BASE := 201
const TYPE_AIRPLANE := 1
const TYPE_HELICOPTER := 2
const TYPE_SHIP := 3
const TYPE_MONSTER := 5
const TYPE_SAILBOAT := 9
const TYPE_TRAIN_ENGINE := 10
const TYPE_TRAIN_CAR := 11
const TYPE_MAXIS_MAN := 16
const CARDINAL_DIRECTIONS := [
	Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0),
]
const TRAIN_SEARCH_OFFSETS := [
	Vector2i(0, -2), Vector2i(2, 0), Vector2i(0, 2), Vector2i(-2, 0),
]
const TRAIN_DIRECTION_ORDERS := [
	[0, 3, 1, 2],
	[0, 1, 3, 2],
]


class Result extends RefCounted:
	var spawned := false
	var record := 0
	var point := Vector2i.ZERO
	var target := Vector2i.ZERO
	var goal := 0


static func count_type(things: PackedByteArray, thing_type: int) -> int:
	var count := 0

	for record in range(FIRST_RECORD, ThingData.count(things)):
		if ThingData.read(things, record * RECORD_SIZE) == thing_type:
			count += 1

	return count


static func spawn_helicopter(
	things: PackedByteArray, text: PackedByteArray, point: Vector2i, random: SimRandom,
	map_edge: int = 128,
) -> Result:
	var index := _index(point, map_edge)

	if (
		index < 0
		or OverlayData.blocks_thing(OverlayData.read(text, index))
		or count_type(things, TYPE_MONSTER) != 0
		or count_type(things, TYPE_HELICOPTER) >= 1 * maxi(1, (map_edge * map_edge) / 16384)
	):
		var result := Result.new()
		result.spawned = false

		return result

	var record := _first_free_record(things)

	if record == 0:
		var result := Result.new()
		result.spawned = false

		return result

	var offset := record * RECORD_SIZE
	ThingData.write(things, offset, TYPE_HELICOPTER)
	ThingData.write(things, offset + 1, 2)
	ThingData.write(things, offset + 2, 0)
	ThingData.write(things, offset + 3, point.x)
	ThingData.write(things, offset + 4, point.y)
	ThingData.write(things, offset + 5, 0)
	ThingData.write(things, offset + 6, 8)
	ThingData.write(things, offset + 7, 8)
	ThingData.write(things, offset + 8, random.next_u15() % map_edge)
	ThingData.write(things, offset + 9, random.next_u15() % map_edge)
	ThingData.write(things, offset + 10, OverlayData.read(text, index))
	OverlayData.write(text, index, OverlayData.thing_id(record))

	var result := Result.new()
	result.spawned = true
	result.record = record
	result.point = point

	return result


static func spawn_airplane(
	things: PackedByteArray,
	text: PackedByteArray,
	point: Vector2i,
	runway_axis: int,
	random: SimRandom,
	map_edge: int = 128,
) -> Result:
	var source_index := _index(point, map_edge)

	if (
		source_index < 0
		or OverlayData.blocks_thing(OverlayData.read(text, source_index))
		or count_type(things, TYPE_MONSTER) != 0
		or count_type(things, TYPE_AIRPLANE) >= 2 * maxi(1, (map_edge * map_edge) / 16384)
	):
		var result := Result.new()
		result.spawned = false

		return result

	var record := _first_free_record(things)

	if record == 0:
		var result := Result.new()
		result.spawned = false

		return result

	var offset := record * RECORD_SIZE
	ThingData.write(things, offset, TYPE_AIRPLANE)
	ThingData.write(things, offset + 6, 8)
	ThingData.write(things, offset + 7, 8)
	var attached := point
	# preserve original entry margins at 128 and above. small maps use the same
	# proportions so each edge coordinate stays inside the map
	var entry_low := mini(10, maxi(1, (10 * map_edge) / 128))
	var entry_high := mini(18, maxi(1, (18 * map_edge) / 128))
	var entry_span := map_edge - entry_low - entry_high

	if random.next_u15() % 10 < 5:
		match random.next_u15() & 3:
			0:
				attached = Vector2i(0, random.next_u15() % entry_span + entry_low)
				ThingData.write(things, offset + 1, 3)
			1:
				attached = Vector2i(random.next_u15() % entry_span + entry_low, 0)
				ThingData.write(things, offset + 1, 5)
			2:
				attached = Vector2i((map_edge - 1), random.next_u15() % entry_span + entry_low)
				ThingData.write(things, offset + 1, 7)
			3:
				attached = Vector2i(random.next_u15() % entry_span + entry_low, (map_edge - 1))
				ThingData.write(things, offset + 1, 1)

		ThingData.write(things, offset + 2, runway_axis * 0x10 + 3)
		ThingData.write(things, offset + 5, 0x10)

		if runway_axis == 0:
			ThingData.write(things, offset + 8, point.x)
			ThingData.write(things, offset + 9, point.y + 0x10)
		else:
			ThingData.write(things, offset + 8, (point.x - 0x10))
			ThingData.write(things, offset + 9, point.y)
	else:
		ThingData.write(things, offset + 1, runway_axis)
		ThingData.write(things, offset + 2, 0)
		ThingData.write(things, offset + 5, 0)
		ThingData.write(things, offset + 8, 0x14)
		ThingData.write(things, offset + 9, 0x14)

	ThingData.write(things, offset + 3, attached.x)
	ThingData.write(things, offset + 4, attached.y)
	var attached_index := _index(attached, map_edge)
	ThingData.write(things, offset + 10, OverlayData.read(text, attached_index))
	OverlayData.write(text, attached_index, OverlayData.thing_id(record))

	var result := Result.new()
	result.spawned = true
	result.record = record
	result.point = attached

	return result


static func spawn_ship(
	terrain: PackedByteArray,
	things: PackedByteArray,
	text: PackedByteArray,
	target: Vector2i,
	random: SimRandom,
	map_edge: int = 128,
) -> Result:
	if count_type(things, TYPE_SHIP) >= 1 * maxi(1, (map_edge * map_edge) / 16384):
		var result := Result.new()
		result.spawned = false

		return result

	var start := Vector2i(-1, -1)

	match random.next_u15() & 3:
		0:
			for y in map_edge:
				if terrain[2 * map_edge + y] == TerrainTileIds.DEEP_WATER_FLAT:
					start = Vector2i(2, y)
		1:
			for y in map_edge:
				if terrain[(map_edge - 2) * map_edge + y] == TerrainTileIds.DEEP_WATER_FLAT:
					start = Vector2i((map_edge - 2), y)
		2:
			for x in map_edge:
				if terrain[x * map_edge + 2] == TerrainTileIds.DEEP_WATER_FLAT:
					start = Vector2i(x, 2)
		3:
			for x in map_edge:
				if terrain[x * map_edge + (map_edge - 2)] == TerrainTileIds.DEEP_WATER_FLAT:
					start = Vector2i(x, (map_edge - 2))

	if start.x < 0:
		var result := Result.new()
		result.spawned = false

		return result

	var start_index := _index(start, map_edge)

	if OverlayData.blocks_thing(OverlayData.read(text, start_index)):
		var result := Result.new()
		result.spawned = false

		return result

	var record := _first_free_record(things)

	if record == 0:
		var result := Result.new()
		result.spawned = false

		return result

	var offset := record * RECORD_SIZE
	ThingData.write(things, offset, TYPE_SHIP)
	ThingData.write(things, offset + 1, MovingThingMotion.direction_between(start, target))
	ThingData.write(things, offset + 2, 0)
	ThingData.write(things, offset + 3, start.x)
	ThingData.write(things, offset + 4, start.y)
	ThingData.write(things, offset + 5, 1)
	ThingData.write(things, offset + 6, 8)
	ThingData.write(things, offset + 7, 8)
	ThingData.write(things, offset + 10, OverlayData.read(text, start_index))
	OverlayData.write(text, start_index, OverlayData.thing_id(record))
	ThingData.set_ship_home(things, record, start)

	var result := Result.new()
	result.spawned = true
	result.record = record
	result.point = start
	result.target = target

	return result


static func spawn_sailboats(
	buildings: PackedByteArray,
	flags: PackedByteArray,
	things: PackedByteArray,
	text: PackedByteArray,
	point: Vector2i,
	lfsr_random: SimLfsrRandom,
	map_edge: int = 128,
) -> int:
	if count_type(things, TYPE_SAILBOAT) >= 4 * maxi(1, (map_edge * map_edge) / 16384):
		return 0

	var spawned := 0

	for direction in CARDINAL_DIRECTIONS:
		var start: Vector2i = point + direction
		var index := _index(start, map_edge)
		var record := _first_free_record(things)

		if (
			record == 0
			or index < 0
			or flags[index] & 0x04 == 0
			or buildings[index] != Tiles.EMPTY
			or OverlayData.read(text, index) != 0
		):
			continue

		var offset := record * RECORD_SIZE
		ThingData.write(things, offset, TYPE_SAILBOAT)
		ThingData.write(things, offset + 1, lfsr_random.next_mod(3))
		ThingData.write(things, offset + 2, 0)
		ThingData.write(things, offset + 3, start.x)
		ThingData.write(things, offset + 4, start.y)
		ThingData.write(things, offset + 5, 0)
		ThingData.write(things, offset + 6, 4)
		ThingData.write(things, offset + 7, 4)
		ThingData.write(things, offset + 10, 0)
		OverlayData.write(text, index, OverlayData.thing_id(record))
		spawned += 1

	return spawned


static func spawn_maxis_man(
	things: PackedByteArray,
	text: PackedByteArray,
	point: Vector2i,
	target: Vector2i,
	goal: int,
	height: int,
	map_edge: int = 128,
) -> Result:
	var index := _index(point, map_edge)
	var target_index := _index(target, map_edge)

	if (
		index < 0
		or target_index < 0
		or OverlayData.blocks_thing(OverlayData.read(text, index))
		or count_type(things, TYPE_MAXIS_MAN) >= 1
		or (ThingData.is_record_target(goal) and (goal < FIRST_RECORD or ThingData.target_record(goal) >= ThingData.count(things)))
	):
		var result := Result.new()
		result.spawned = false

		return result

	var record := _first_free_record(things)

	if record == 0:
		var result := Result.new()
		result.spawned = false

		return result

	var offset := record * RECORD_SIZE
	ThingData.write(things, offset, TYPE_MAXIS_MAN)
	ThingData.write(things, offset + 1, MovingThingMotion.direction_between(point, target))
	ThingData.write(things, offset + 2, 0)
	ThingData.write(things, offset + 3, point.x)
	ThingData.write(things, offset + 4, point.y)
	ThingData.write(things, offset + 5, clampi(height, 0, 0xff))
	ThingData.write(things, offset + 6, 8)
	ThingData.write(things, offset + 7, 8)
	ThingData.write(things, offset + 8, target.x)
	ThingData.write(things, offset + 9, target.y)
	ThingData.write(things, offset + 10, OverlayData.read(text, index))
	ThingData.write(things, offset + 11, goal)
	OverlayData.write(text, index, OverlayData.thing_id(record))

	var result := Result.new()
	result.spawned = true
	result.record = record
	result.point = point
	result.target = target
	result.goal = goal

	return result


static func spawn_train(
	buildings: PackedByteArray,
	things: PackedByteArray,
	text: PackedByteArray,
	station: Vector2i,
	game_random: GameLcgRandom,
	lfsr_random: SimLfsrRandom,
	map_edge: int = 128,
) -> bool:
	for search_offset in TRAIN_SEARCH_OFFSETS:
		var start: Vector2i = station + search_offset

		if _spawn_train_record(buildings, things, text, start, game_random, lfsr_random, map_edge):
			return true

	return false


static func _spawn_train_record(
	buildings: PackedByteArray,
	things: PackedByteArray,
	text: PackedByteArray,
	start: Vector2i,
	game_random: GameLcgRandom,
	lfsr_random: SimLfsrRandom,
	map_edge: int = 128,
) -> bool:
	if count_type(things, TYPE_TRAIN_ENGINE) >= 5 * maxi(1, (map_edge * map_edge) / 16384):
		return false

	if start.x < 2 or start.x > map_edge - 4 or start.y < 2 or start.y > map_edge - 4:
		return false

	var index := _index(start, map_edge)
	var tile := int(buildings[index])

	if tile < Tiles.RAIL_STRAIGHT_1 or tile > Tiles.RAIL_CURVE_4 or OverlayData.read(text, index) != 0:
		return false

	var initial_direction: int = lfsr_random.next_mod(4)
	var direction := _train_direction(
		buildings, text, start, initial_direction, game_random.next_mod(2), map_edge
	)

	if direction < 0:
		return false

	# The original skips all three allocation checks. If no slot is free,
	# it writes the train into reserved record 0.
	var engine_record := _first_free_record(things)
	ThingData.write(things, engine_record * RECORD_SIZE, TYPE_TRAIN_ENGINE)
	var first_car_record := _first_free_record(things)
	ThingData.write(things, first_car_record * RECORD_SIZE, TYPE_TRAIN_CAR)
	var second_car_record := _first_free_record(things)
	ThingData.write(things, second_car_record * RECORD_SIZE, TYPE_TRAIN_CAR)
	var records: Array[int] = [engine_record, first_car_record, second_car_record]

	for record in records:
		var offset: int = record * RECORD_SIZE
		ThingData.write(things, offset + 1, direction)
		ThingData.write(things, offset + 3, start.x)
		ThingData.write(things, offset + 4, start.y)
		ThingData.write(things, offset + 5, 0)

	var engine_offset := engine_record * RECORD_SIZE
	var first_car_offset := first_car_record * RECORD_SIZE
	var second_car_offset := second_car_record * RECORD_SIZE
	ThingData.write(things, engine_offset + 6, start.x + CARDINAL_DIRECTIONS[direction].x)
	ThingData.write(things, engine_offset + 7, start.y + CARDINAL_DIRECTIONS[direction].y)
	ThingData.write(things, first_car_offset + 6, start.x)
	ThingData.write(things, first_car_offset + 7, start.y)
	ThingData.write(things, second_car_offset + 6, start.x)
	ThingData.write(things, second_car_offset + 7, start.y)
	ThingData.write(things, engine_offset + 10, OverlayData.read(text, index))
	ThingData.write(things, first_car_offset + 10, 0)
	ThingData.write(things, second_car_offset + 10, 0)
	ThingData.write(things, engine_offset + 2, first_car_record)
	ThingData.write(things, first_car_offset + 2, second_car_record)
	OverlayData.write(text, index, OverlayData.thing_id(engine_record))

	return true


static func _train_direction(
	buildings: PackedByteArray,
	text: PackedByteArray,
	point: Vector2i,
	initial_direction: int,
	order_index: int,
	map_edge: int = 128,
) -> int:
	for offset in TRAIN_DIRECTION_ORDERS[order_index & 1]:
		var direction: int = (initial_direction + int(offset)) & 3
		var neighbor: Vector2i = point + CARDINAL_DIRECTIONS[direction]
		var index := _index(neighbor, map_edge)

		if index >= 0 and not OverlayData.blocks_thing(OverlayData.read(text, index)) and _train_route_tile(buildings[index]):
			return direction

	return -1


static func _train_route_tile(tile_value: int) -> bool:
	var tile := int(tile_value)

	return (
		(tile >= Tiles.RAIL_STRAIGHT_1 and tile <= Tiles.RAIL_SLOPE_8)
		or (tile >= Tiles.ROAD_RAIL_CROSSING_1 and tile <= Tiles.RAIL_POWER_CROSSING_2)
		or (tile >= Tiles.RAIL_SUBWAY_ENTRANCE_1 and tile <= Tiles.RAIL_SUBWAY_ENTRANCE_4)
		or tile == Tiles.HIGHWAY_RAIL_CROSSING_1
		or tile == Tiles.HIGHWAY_RAIL_CROSSING_2
		or tile == Tiles.RAIL_BRIDGE
		or tile == Tiles.RAIL_BRIDGE_PYLON
	)


static func _first_free_record(things: PackedByteArray) -> int:
	for record in range(FIRST_RECORD, ThingData.count(things)):
		if ThingData.read(things, record * RECORD_SIZE) == 0:
			return record

	return 0


static func _index(point: Vector2i, map_edge: int = 128) -> int:
	if point.x < 0 or point.x >= map_edge or point.y < 0 or point.y >= map_edge:
		return -1

	return point.x * map_edge + point.y
