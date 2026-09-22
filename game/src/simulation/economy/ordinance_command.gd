class_name OrdinanceCommand
extends RefCounted

@warning_ignore_start("integer_division")

const MISC_SIZE := Sc2MiscLayout.SIZE
const MISC_CITY_DAYS := Sc2MiscLayout.CITY_DAYS
const MISC_BUDGETS := Sc2MiscLayout.BUDGETS
const MISC_YEAR_END := Sc2MiscLayout.YEAR_END
const MISC_ORDINANCES := Sc2MiscLayout.ORDINANCES
const MISC_ARCOLOGY_POPULATION := Sc2MiscLayout.ARCOLOGY_POPULATION
const MISC_NORMAL_POPULATION := Sc2MiscLayout.NORMAL_POPULATION

const BUDGET_RECORD_SIZE := Sc2BudgetLayout.RECORD_SIZE
const BUDGET_CURRENT := Sc2BudgetLayout.CURRENT
const BUDGET_YEAR_TO_DATE := Sc2BudgetLayout.YEAR_TO_DATE
const BUDGET_RESIDENTIAL := Sc2BudgetLayout.RESIDENTIAL
const BUDGET_ORDINANCES := Sc2BudgetLayout.ORDINANCES

const ORDINANCE_COUNT := OrdinanceIds.COUNT
const DISPLAY_CURRENT_DIVISOR := 75
const DISPLAY_ANNUAL_DIVISOR := 900

const NAMES := [
	"1% Sales Tax",
	"1% Income Tax",
	"Legalized Gambling",
	"Parking Fines",
	"Volunteer Fire Dept.",
	"Public Smoking Ban",
	"Free Clinics",
	"Junior Sports",
	"Pro-Reading Campaign",
	"Anti-Drug Campaign",
	"CPR Training",
	"Neighborhood Watch",
	"Tourist Advertising",
	"Business Advertising",
	"City Beautification",
	"Annual Carnival",
	"Energy Conservation",
	"Nuclear Free Zone",
	"Homeless Shelter",
	"Pollution Controls",
]

const CATEGORY_NAMES := [
	"Finance",
	"Safety & Health",
	"Education",
	"Promotional",
	"Other",
]


static func costs_for_misc(misc: PackedByteArray) -> PackedInt32Array:
	var costs := PackedInt32Array()

	if misc.size() != MISC_SIZE:
		return costs

	var residential := BinaryData.read_i32_be(misc, _budget_offset(BUDGET_RESIDENTIAL))
	var commercial := BinaryData.read_i32_be(misc, _budget_offset(Sc2BudgetLayout.COMMERCIAL))
	var industrial := BinaryData.read_i32_be(misc, _budget_offset(Sc2BudgetLayout.INDUSTRIAL))
	var population := _to_i32(
		BinaryData.read_u32_be(misc, MISC_ARCOLOGY_POPULATION)
		+ BinaryData.read_u32_be(misc, MISC_NORMAL_POPULATION)
	)
	costs = PackedInt32Array([
		commercial,
		residential,
		_to_i32(commercial * 2),
		_divide_toward_zero(residential, 2),
		_divide_toward_zero(residential, -3),
		_divide_toward_zero(commercial, -6),
		-_divide_toward_zero(residential, 2),
		-_divide_toward_zero(residential, 4),
		_divide_toward_zero(residential, -6),
		_divide_toward_zero(residential, -5),
		_divide_toward_zero(residential, -6),
		_divide_toward_zero(residential, -3),
		-commercial,
		-industrial,
		-_divide_toward_zero(residential, 4),
		_divide_toward_zero(commercial, -3),
		-population,
		0,
		-_divide_toward_zero(residential, 2),
		-industrial,
	])

	return costs


static func current_cost_for_misc(misc: PackedByteArray) -> int:
	if misc.size() != MISC_SIZE:
		return 0

	var costs := costs_for_misc(misc)
	var flags := BinaryData.read_u32_be(misc, MISC_ORDINANCES)
	var total := 0

	for ordinance_id in ORDINANCE_COUNT:
		if flags & (1 << ordinance_id):
			total = _to_i32(total + costs[ordinance_id])

	return total


class Result extends RefCounted:
	var ok := false
	var error := ""
	var changed := false
	var flags := 0
	var current_raw := 0
	var raw_costs := PackedInt32Array()
	var item_amounts := PackedInt32Array()
	var category_amounts := PackedInt32Array()
	var year_to_date_amount := 0
	var estimated_amount := 0
	var month := 0


static func failed(message: String) -> Result:
	var result := Result.new()
	result.error = message

	return result


static func snapshot(city: CityState) -> Result:
	if city == null or not city.is_valid():
		return failed("city is invalid")

	var misc_chunk := city.document.find_chunk("MISC")

	if misc_chunk == null or misc_chunk.decoded_payload.size() != MISC_SIZE:
		return failed("MISC is missing or has the wrong size")

	var misc: PackedByteArray = misc_chunk.decoded_payload
	var flags := BinaryData.read_u32_be(misc, MISC_ORDINANCES)
	var raw_costs := costs_for_misc(misc)
	var item_amounts := PackedInt32Array()
	var category_raw := PackedInt32Array([0, 0, 0, 0, 0])
	var current_raw := 0

	for ordinance_id in ORDINANCE_COUNT:
		var enabled := bool(flags & (1 << ordinance_id))
		var raw := raw_costs[ordinance_id] if enabled else 0
		item_amounts.append(_divide_toward_zero(raw, DISPLAY_CURRENT_DIVISOR))
		current_raw = _to_i32(current_raw + raw)
		var category := int(ordinance_id / 4)
		category_raw[category] = _to_i32(category_raw[category] + raw)

	var category_amounts := PackedInt32Array()

	for raw in category_raw:
		category_amounts.append(
			_divide_toward_zero(raw, DISPLAY_CURRENT_DIVISOR)
		)

	var budget_offset := _budget_offset(BUDGET_ORDINANCES)
	var year_to_date_raw := BinaryData.read_i32_be(misc, budget_offset + BUDGET_YEAR_TO_DATE)
	var month := int((BinaryData.read_u32_be(misc, MISC_CITY_DAYS) % CityCalendar.DAYS_PER_YEAR) / CityCalendar.DAYS_PER_MONTH)
	var estimated_raw := _to_i32(current_raw * 12)

	if BinaryData.read_u32_be(misc, MISC_YEAR_END) == 0:
		estimated_raw = _to_i32((11 - month) * current_raw + year_to_date_raw)

	var result := Result.new()
	result.ok = true
	result.error = ""
	result.flags = flags
	result.raw_costs = raw_costs
	result.item_amounts = item_amounts
	result.category_amounts = category_amounts
	result.current_raw = current_raw
	result.year_to_date_amount = _divide_toward_zero(
		year_to_date_raw, DISPLAY_ANNUAL_DIVISOR
	)
	result.estimated_amount = _divide_toward_zero(
		estimated_raw, DISPLAY_ANNUAL_DIVISOR
	)
	result.month = month

	return result


static func synchronize_current(city: CityState) -> Result:
	if city == null or not city.is_valid():
		return failed("city is invalid")

	var misc_chunk := city.document.find_chunk("MISC")

	if misc_chunk == null or misc_chunk.decoded_payload.size() != MISC_SIZE:
		return failed("MISC is missing or has the wrong size")

	var misc: PackedByteArray = misc_chunk.decoded_payload
	var budget_offset := _budget_offset(BUDGET_ORDINANCES)
	var current := current_cost_for_misc(misc)

	if BinaryData.read_i32_be(misc, budget_offset + BUDGET_CURRENT) == current:
		var result := Result.new()
		result.ok = true
		result.changed = false
		result.current_raw = current
		result.error = ""

		return result

	var changed := misc.duplicate()
	BinaryData.write_u32_be(changed, budget_offset + BUDGET_CURRENT, current)

	if not misc_chunk.set_decoded_payload(changed):
		return failed("cannot store the ordinance budget total")

	var result := Result.new()
	result.ok = true
	result.changed = true
	result.current_raw = current
	result.error = ""

	return result


static func set_enabled(city: CityState, ordinance_id: int, enabled: bool) -> Result:
	if city == null or not city.is_valid():
		return failed("city is invalid")

	if ordinance_id < 0 or ordinance_id >= ORDINANCE_COUNT:
		return failed("ordinance is outside the valid range")

	var misc_chunk := city.document.find_chunk("MISC")

	if misc_chunk == null or misc_chunk.decoded_payload.size() != MISC_SIZE:
		return failed("MISC is missing or has the wrong size")

	var misc: PackedByteArray = misc_chunk.decoded_payload
	var old_flags := BinaryData.read_u32_be(misc, MISC_ORDINANCES)
	var mask := 1 << ordinance_id
	var new_flags := old_flags | mask if enabled else old_flags & ~mask
	var changed := misc.duplicate()
	BinaryData.write_u32_be(changed, MISC_ORDINANCES, new_flags)
	var current := current_cost_for_misc(changed)
	BinaryData.write_u32_be(
		changed,
		_budget_offset(BUDGET_ORDINANCES) + BUDGET_CURRENT,
		current,
	)
	var has_change := new_flags != old_flags or changed != misc

	if has_change and not misc_chunk.set_decoded_payload(changed):
		return failed("cannot store the ordinance selection")

	var result := Result.new()
	result.ok = true
	result.changed = has_change
	result.flags = new_flags
	result.current_raw = current
	result.error = ""

	return result


static func compact_amount(value: int) -> String:
	var absolute := absi(value)

	if absolute < 9999:
		return str(value)

	if absolute < 9999999:
		return "%dk" % _divide_toward_zero(value + 501, 1000)

	return "%dm" % _divide_toward_zero(value + 501000, 1000000)


static func _budget_offset(budget_id: int) -> int:
	return MISC_BUDGETS + budget_id * BUDGET_RECORD_SIZE


static func _divide_toward_zero(value: int, divisor: int) -> int:
	if divisor == 0:
		return 0

	var quotient := int(absi(value) / absi(divisor))

	return -quotient if (value < 0) != (divisor < 0) else quotient


static func _to_i32(value: int) -> int:
	var unsigned := value & 0xffffffff

	return unsigned - 0x100000000 if unsigned & 0x80000000 else unsigned
