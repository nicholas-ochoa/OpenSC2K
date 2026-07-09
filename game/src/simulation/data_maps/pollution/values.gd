class_name PollutionValues
extends PollutionConstants

# Inline integer division avoids a function call for every cell.
@warning_ignore_start("integer_division")



static func _full_index(x: int, y: int, map_edge: int = 128) -> int:
	return x * map_edge + y


# sign-extend the low word, 0x0000ffff means -1 here
static func pollution_divisor(document: Sc2File) -> int:
	# 0x0046a9a3..0x0046aa02 calculates and compares a signed 16-bit word
	# industryphase saves the low-word -1 as 0x0000ffff, not 0xffffffff
	var value := document.misc_u32(MISC_TREATMENT_SUFFICIENT) - document.misc_u32(MISC_POLLUTION_BONUS) + 4

	if document.misc_u32(MISC_ORDINANCES) & CLEAN_INDUSTRY_ORDINANCE:
		value += 1

	value &= 0xffff

	if value >= 0x8000:
		value -= 0x10000

	return maxi(value, 1)


static func _average_service_grid(
	values: PackedInt32Array, x: int, y: int, x_offset: int,
	map_edge: int = 128,
) -> int:
	var quarter_edge := map_edge / 4
	var center_index := (x + x_offset) * map_edge + y
	var total := values[center_index]
	var divisor := 1
	# keep every neighbor in the selected desirability grid
	var neighbor_row := center_index

	if x > 0:
		total += values[neighbor_row - map_edge]
		divisor += 1

	if x < quarter_edge - 1:
		total += values[neighbor_row + map_edge]
		divisor += 1

	if y > 0:
		total += values[center_index - 1]
		divisor += 1

	if y < quarter_edge - 1:
		total += values[center_index + 1]
		divisor += 1

	return _divide_toward_zero(total, divisor)


static func _budget_funding(city: CityState, budget_id: int) -> int:
	return city.document.misc_i32(
		MISC_BUDGETS + budget_id * MISC_BUDGET_RECORD_SIZE + 4
	)


static func _population_weight(building: int) -> int:
	if building >= 0x70 and building <= 0x89:
		return 1

	if building >= 0x8c and building <= 0x8f:
		return 2

	if building >= 0x90 and building <= 0x93:
		return 3

	if building >= 0x94 and building <= 0x98:
		return 2

	if building >= 0x99 and building <= 0x9d:
		return 3

	if building >= 0x9e and building <= 0xa1:
		return 2

	if building >= 0xa2 and building <= 0xa5:
		return 3

	if building >= 0xa6 and building <= 0xa7:
		return 2

	if building >= 0xa8 and building <= 0xa9:
		return 3

	if building >= 0xae and building <= 0xc3:
		return 4

	return 0


static func _add_service(values: PackedByteArray, x: int, y: int, strength: int, map_edge: int = 128) -> void:
	_add_service_cell(values, x, y, strength, map_edge)
	var cardinal := _divide_toward_zero(strength * 4, 5)

	for point in [Vector2i(x - 1, y), Vector2i(x + 1, y), Vector2i(x, y - 1), Vector2i(x, y + 1)]:
		_add_service_cell(values, point.x, point.y, cardinal, map_edge)

	var diagonal := _divide_toward_zero(cardinal * 3, 4)

	for dx in [-1, 1]:
		for dy in [-1, 1]:
			_add_service_cell(values, x + dx, y + dy, diagonal, map_edge)

	var outer := _divide_toward_zero(diagonal * 2, 3)

	for major in [-2, 2]:
		for minor in [-1, 0, 1]:
			_add_service_cell(values, x + major, y + minor, outer, map_edge)
			_add_service_cell(values, x + minor, y + major, outer, map_edge)

	var fringe := _divide_toward_zero(outer, 2)

	for major in [-3, 3]:
		for minor in [-1, 0, 1]:
			_add_service_cell(values, x + major, y + minor, fringe, map_edge)
			_add_service_cell(values, x + minor, y + major, fringe, map_edge)

	for dx in [-2, 2]:
		for dy in [-2, 2]:
			_add_service_cell(values, x + dx, y + dy, fringe, map_edge)


static func _add_service_cell(
	values: PackedByteArray, x: int, y: int, strength: int,
	map_edge: int = 128,
) -> void:
	var quarter_edge := map_edge / 4

	if x < 0 or x >= quarter_edge or y < 0 or y >= quarter_edge:
		return

	var index := x * quarter_edge + y
	values[index] = clampi(int(values[index]) + strength, 0, 0xff)


static func _divide_toward_zero(value: int, divisor: int) -> int:
	return int(IntegerMath.div_trunc(value, divisor))
