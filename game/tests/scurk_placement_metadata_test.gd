extends SceneTree
## Check SCURK facility budgets, placement flags, and exact history restoration.

const Place = preload("res://src/tools/scurk/scurk_place_command.gd")
const POINT := Vector2i(8, 8)
# Independent saved tile IDs and budget record indexes. Museum has no budget.
const BUDGET_CASES := [[0xd1, 7], [0xd2, 5], [0xd3, 6], [0xd6, 8], [0xd9, 9], [0xd4, -1]]

var checks := 0
var failures := 0


func _initialize() -> void:
	_check_budgets()
	_check_flags()
	_check_water_rules()
	print("SCURK placement metadata: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _check(ok: bool, message: String) -> void:
	checks += 1

	if not ok:
		failures += 1
		push_error(message)


func _city(flag_byte: int) -> CityState:
	var city := CityState.from_document(EmptyCityTemplate.create(16))
	var flags := city.tile_flags.duplicate()
	flags.fill(flag_byte)
	_check(city.replace_tile_flags(flags), "Store generated flags")
	_check(city.set_funds(0), "Remove funds without restricting SCURK placement")

	return city


func _check_budgets() -> void:
	var city := _city(0x1b)
	var random := SimRandom.new(7)

	for category in 16:
		_check(city.document.set_misc_u32(0x077c + category * 0x6c, 100 + category),
			"Seed distinct budget counts")

	var original_budgets := city.document.find_chunk("MISC").decoded_payload.slice(0x077c, 0x0e3c)

	for entry in BUDGET_CASES:
		var before: PackedByteArray = city.document.serialize().data
		var command := Place.apply(city, entry[0], POINT, random)
		_check(command.ok, "Place budget case %02x: %s" % [entry[0], command.error])

		if not command.ok:
			continue

		var expected := original_budgets.duplicate()

		if entry[1] >= 0:
			BinaryData.write_u32_be(expected, entry[1] * 0x6c, 101 + entry[1])

		_check(city.document.find_chunk("MISC").decoded_payload.slice(0x077c, 0x0e3c) == expected,
			"Placement changes only the selected budget count, or none for a museum")
		_check(city.funds() == 0 and random.state == 7, "SCURK retains funds and deterministic facility RNG")
		_check(city.building_id(POINT.x, POINT.y) == entry[0] and command.overlay_id != 0,
			"Placement creates the selected facility and its saved link")

		for index in command.tile_indices:
			_check(city.tile_flags[index] == 0xfb, "Facility enables utilities and preserves lower flag bits")

		_check_history(city, command, random, before, 7)


func _check_flags() -> void:
	# Tile, previous flags, expected flags. Small park keeps its existing landscape rule.
	for row in [[0x06, 0xfb, 0x1b], [0x0d, 0xfb, 0x1b], [0x0e, 0x7b, 0x9b],
		[0xd5, 0xdb, 0x3b], [0xdb, 0x1b, 0x7b], [0xf3, 0x1b, 0xfb]]:
		var city := _city(row[1])
		var random := SimRandom.new(23)
		var before: PackedByteArray = city.document.serialize().data
		var expected_flags := city.tile_flags.duplicate()
		var command := Place.apply(city, row[0], POINT, random)
		_check(command.ok, "Place flag case %02x: %s" % [row[0], command.error])

		if not command.ok:
			continue

		for index in command.tile_indices:
			expected_flags[index] = row[2]

		_check(city.tile_flags == expected_flags, "Flag rule changes only the placed footprint")

		if row[0] == 0xf3:
			_check(random.state != 23, "Mayor house consumes RNG before history checks")

		_check_history(city, command, random, before, 23)


func _check_water_rules() -> void:
	# Tile, flags, terrain, accepts. A piped flag cannot stand in for water.
	for row in [[0xc6, 0x1f, 1, true], [0xc7, 0x20, 1, false],
		[0xc6, 0x04, 0, false], [0xd1, 0x04, 0, false]]:
		var city := _city(row[1])
		_check(city.set_terrain_id(POINT.x, POINT.y, row[2]), "Set hydro terrain")
		var random := SimRandom.new(31)
		var before: PackedByteArray = city.document.serialize().data
		var command := Place.apply(city, row[0], POINT, random)
		_check(command.ok == row[3], "Water and terrain decide site eligibility")

		if command.ok:
			_check(city.tile_flags[city.index_of(POINT.x, POINT.y)] == 0xff,
				"Hydro keeps water and lower flags while it enables utilities")
			_check_history(city, command, random, before, 31)
		else:
			_check(city.document.serialize().data == before and random.state == 31,
				"Rejected site preserves city bytes and RNG")


func _check_history(
	city: CityState, command: EditCommandResult, random: SimRandom,
	before: PackedByteArray, random_before: int
) -> void:
	var placed: PackedByteArray = city.document.serialize().data
	var random_after := random.state
	_check(Place.undo(city, command, random).ok, "Undo SCURK placement")
	_check(city.document.serialize().data == before and random.state == random_before,
		"Undo restores exact city bytes and RNG")
	_check(Place.redo(city, command, random).ok, "Redo SCURK placement")
	_check(city.document.serialize().data == placed and random.state == random_after,
		"Redo restores exact placed bytes and RNG")
	_check(Place.undo(city, command, random).ok, "Restore the reusable fixture")
	_check(city.document.serialize().data == before and random.state == random_before,
		"Final undo restores the fixture")
