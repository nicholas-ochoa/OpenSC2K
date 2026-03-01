class_name BudgetPhase
extends RefCounted

const Ordinances = preload("res://src/simulation/economy/ordinance_command.gd")

const MISC_SIZE := 4800
const MISC_FUNDS := 0x0014
const MISC_BONDS := 0x0018
const MISC_TILE_COUNTS := 0x01f0
const MISC_BUDGETS := 0x077c
const MISC_YEAR_END := 0x0e3c
const MISC_ORDINANCES := 0x0fa0
const MISC_SUBWAY_COUNT := 0x0fe8
const MISC_AUTO_BUDGET := 0x0ff0
const MISC_NO_DISASTERS := 0x1000
const MISC_ARCOLOGY_POPULATION := 0x1020
const MISC_NORMAL_POPULATION := 0x102c

const BUDGET_COUNT := 16
const BUDGET_RECORD_SIZE := 0x006c
const BUDGET_CURRENT := 0x00
const BUDGET_FUNDING := 0x04
const BUDGET_YEAR_TO_DATE := 0x08
const BUDGET_MONTHS := 0x0c

const BUDGET_RESIDENTIAL := 0
const BUDGET_COMMERCIAL := 1
const BUDGET_INDUSTRIAL := 2
const BUDGET_ORDINANCES := 3
const BUDGET_BONDS := 4
const BUDGET_POLICE := 5
const BUDGET_FIRE := 6
const BUDGET_HEALTH := 7
const BUDGET_SCHOOL := 8
const BUDGET_COLLEGE := 9
const BUDGET_ROAD := 10
const BUDGET_HIGHWAY := 11
const BUDGET_BRIDGE := 12
const BUDGET_RAIL := 13
const BUDGET_SUBWAY := 14
const BUDGET_TUNNEL := 15

const ANNUAL_DIVISOR_FACTORS := [
	75, 75, 75, 75, -100, -1, -1, -2, -4, -1, -1000, -500, -400, -250, -250, -250,
]

const SERVICE_TILE_IDS := {
	BUDGET_POLICE: 0xd2,
	BUDGET_FIRE: 0xd3,
	BUDGET_HEALTH: 0xd1,
	BUDGET_SCHOOL: 0xd6,
	BUDGET_COLLEGE: 0xd9,
}

const NEWS_ORDINANCE := 0x29


static func run(city: CityState, random, annual_budget_approved := false) -> Dictionary:
	if city == null or not city.is_valid():
		return {"ok": false, "error": "city is invalid"}

	if random == null or not random.has_method("next_u15"):
		return {"ok": false, "error": "a compatible random generator is required"}

	var misc_chunk := city.document.find_chunk("MISC")

	if misc_chunk == null or misc_chunk.decoded_payload.size() != MISC_SIZE:
		return {"ok": false, "error": "MISC is missing or has the wrong size"}

	var misc: PackedByteArray = misc_chunk.decoded_payload.duplicate()
	var month := int(IntegerMath.div_trunc(city.age_in_days() % 300, 25))
	var funds_before := _read_i32(misc, MISC_FUNDS)
	var funds := funds_before
	var settled_year := false
	var auto_budget_disabled := false

	if (
		_read_u32(misc, MISC_YEAR_END) != 0
		and month == 0
		and _read_u32(misc, MISC_AUTO_BUDGET) == 0
		and not annual_budget_approved
	):
		return {
			"ok": true,
			"error": "",
			"month": month,
			"requires_annual_budget": true,
			"complete": false,
			"news_items": [],
		}

	if _read_u32(misc, MISC_YEAR_END) != 0 and month == 0:
		settled_year = true

		for budget_id in BUDGET_COUNT:
			var budget_offset := _budget_offset(budget_id)
			var factor: int = ANNUAL_DIVISOR_FACTORS[budget_id]

			if factor != 0:
				var year_to_date := _read_i32(misc, budget_offset + BUDGET_YEAR_TO_DATE)
				funds = _to_i32(
					funds + _divide_toward_zero(year_to_date, factor * 12)
				)

			_write_i32(misc, budget_offset + BUDGET_YEAR_TO_DATE, 0)

		_write_u32(misc, MISC_YEAR_END, 0)
		_write_i32(misc, MISC_FUNDS, funds)

		if funds < 0 and _read_u32(misc, MISC_AUTO_BUDGET) != 0:
			_write_u32(misc, MISC_AUTO_BUDGET, 0)
			auto_budget_disabled = true

	for budget_id in BUDGET_COUNT:
		var budget_offset := _budget_offset(budget_id)
		var current := _read_i32(misc, budget_offset + BUDGET_CURRENT)
		var funding := _read_i32(misc, budget_offset + BUDGET_FUNDING)
		var month_offset := budget_offset + BUDGET_MONTHS + month * 8
		_write_i32(misc, month_offset, current)
		_write_i32(misc, month_offset + 4, funding)
		var year_to_date := _read_i32(misc, budget_offset + BUDGET_YEAR_TO_DATE)
		var funded_cost := _to_i32(current * funding)
		_write_i32(
			misc,
			budget_offset + BUDGET_YEAR_TO_DATE,
			_to_i32(year_to_date + funded_cost)
		)

	if month == 11:
		_write_u32(misc, MISC_YEAR_END, 1)

	_write_i32(misc, _budget_offset(BUDGET_BONDS), _read_i32(misc, MISC_BONDS))

	for budget_id in SERVICE_TILE_IDS:
		var divisor := 16 if budget_id == BUDGET_COLLEGE else 9
		_write_i32(
			misc,
			_budget_offset(budget_id),
			_divide_toward_zero(_tile_count(misc, SERVICE_TILE_IDS[budget_id]), divisor)
		)

	for budget_id in range(BUDGET_ROAD, BUDGET_TUNNEL + 1):
		_write_i32(misc, _budget_offset(budget_id), 0)

	for tile_id in range(0x1d, 0x70):
		var count := _tile_count(misc, tile_id)

		if (
			(tile_id >= 0x1d and tile_id <= 0x2b)
			or (tile_id >= 0x3f and tile_id <= 0x46)
			or tile_id == 0x4b
			or tile_id == 0x4c
			or (tile_id >= 0x5d and tile_id <= 0x60)
		):
			_add_current(misc, BUDGET_ROAD, count)

		if (
			(tile_id >= 0x2c and tile_id <= 0x3e)
			or (tile_id >= 0x45 and tile_id <= 0x48)
			or (tile_id >= 0x6c and tile_id <= 0x6f)
			or tile_id == 0x4d
			or tile_id == 0x4e
		):
			_add_current(misc, BUDGET_RAIL, count)

		if (tile_id >= 0x51 and tile_id <= 0x5c) or tile_id == 0x6a or tile_id == 0x6b:
			_add_current(misc, BUDGET_BRIDGE, count)

		if (tile_id >= 0x61 and tile_id <= 0x6b) or (tile_id >= 0x49 and tile_id <= 0x50):
			_add_current(misc, BUDGET_HIGHWAY, count)

		if tile_id >= 0x3f and tile_id <= 0x42:
			_add_current(misc, BUDGET_TUNNEL, count)

	_write_i32(
		misc,
		_budget_offset(BUDGET_SUBWAY),
		_tile_count(misc, 0xe9) + _read_u32(misc, MISC_SUBWAY_COUNT)
	)
	_add_current(misc, BUDGET_RAIL, _tile_count(misc, 0xed))
	_add_current(
		misc,
		BUDGET_ROAD,
		_divide_toward_zero(_tile_count(misc, 0xec), 4) * 250
	)
	_write_i32(
		misc,
		_budget_offset(BUDGET_ORDINANCES),
		Ordinances.current_cost_for_misc(misc),
	)

	var news_items: Array[Dictionary] = []

	if (
		_read_u32(misc, MISC_NO_DISASTERS) == 0
		and (random.next_u15() & 7) == 0
		and (random.next_u15() & 0xffff) + 50000 < _read_i32(misc, MISC_FUNDS)
	):
		var ordinance_id: int = random.next_u15() % 20
		_write_u32(
			misc,
			MISC_ORDINANCES,
			_read_u32(misc, MISC_ORDINANCES) | (1 << ordinance_id)
		)
		news_items.append({"type": NEWS_ORDINANCE, "argument": ordinance_id})

	if not misc_chunk.set_decoded_payload(misc):
		return {"ok": false, "error": "cannot store the monthly budget update"}

	var current_costs := PackedInt32Array()

	for budget_id in BUDGET_COUNT:
		current_costs.append(_read_i32(misc, _budget_offset(budget_id)))

	return {
		"ok": true,
		"error": "",
		"month": month,
		"settled_year": settled_year,
		"funds_before": funds_before,
		"funds_after": _read_i32(misc, MISC_FUNDS),
		"auto_budget_disabled": auto_budget_disabled,
		"requires_annual_budget": false,
		"current_costs": current_costs,
		"news_items": news_items,
		"annual_microsim_update_pending": settled_year,
		"complete": not settled_year,
	}


static func requires_annual_budget(city: CityState) -> bool:
	if city == null or not city.is_valid():
		return false

	return (
		city.age_in_days() % 300 == 0
		and city.document.misc_u32(MISC_YEAR_END) != 0
		and city.document.misc_u32(MISC_AUTO_BUDGET) == 0
	)


static func funding_values(city: CityState) -> PackedInt32Array:
	var values := PackedInt32Array()

	if city == null or not city.is_valid():
		return values

	for budget_id in BUDGET_COUNT:
		values.append(city.document.misc_i32(_budget_offset(budget_id) + BUDGET_FUNDING))

	return values


static func set_funding(
	city: CityState, values: PackedInt32Array, auto_budget: bool
) -> Dictionary:
	if city == null or not city.is_valid():
		return {"ok": false, "error": "city is invalid"}

	if values.size() != BUDGET_COUNT:
		return {"ok": false, "error": "sixteen budget funding values are required"}

	var misc_chunk := city.document.find_chunk("MISC")

	if misc_chunk == null or misc_chunk.decoded_payload.size() != MISC_SIZE:
		return {"ok": false, "error": "MISC is missing or has the wrong size"}

	var misc: PackedByteArray = misc_chunk.decoded_payload.duplicate()

	for budget_id in BUDGET_COUNT:
		_write_i32(misc, _budget_offset(budget_id) + BUDGET_FUNDING, values[budget_id])

	_write_u32(misc, MISC_AUTO_BUDGET, 1 if auto_budget else 0)

	if not misc_chunk.set_decoded_payload(misc):
		return {"ok": false, "error": "cannot store budget funding values"}

	return {"ok": true, "error": ""}


static func _budget_offset(budget_id: int) -> int:
	return MISC_BUDGETS + budget_id * BUDGET_RECORD_SIZE


static func _tile_count(misc: PackedByteArray, tile_id: int) -> int:
	return _read_i32(misc, MISC_TILE_COUNTS + tile_id * 4)


static func _add_current(misc: PackedByteArray, budget_id: int, value: int) -> void:
	var offset := _budget_offset(budget_id)
	_write_i32(misc, offset, _to_i32(_read_i32(misc, offset) + value))


static func _divide_toward_zero(value: int, divisor: int) -> int:
	if divisor == 0:
		return 0

	var quotient := int(IntegerMath.div_trunc(absi(value), absi(divisor)))

	return -quotient if (value < 0) != (divisor < 0) else quotient


static func _to_i32(value: int) -> int:
	var unsigned := value & 0xffffffff

	return unsigned - 0x100000000 if unsigned & 0x80000000 else unsigned


static func _read_u32(data: PackedByteArray, offset: int) -> int:
	return (
		(data[offset] << 24)
		| (data[offset + 1] << 16)
		| (data[offset + 2] << 8)
		| data[offset + 3]
	)


static func _read_i32(data: PackedByteArray, offset: int) -> int:
	return _to_i32(_read_u32(data, offset))


static func _write_u32(data: PackedByteArray, offset: int, value: int) -> void:
	data[offset] = (value >> 24) & 0xff
	data[offset + 1] = (value >> 16) & 0xff
	data[offset + 2] = (value >> 8) & 0xff
	data[offset + 3] = value & 0xff


static func _write_i32(data: PackedByteArray, offset: int, value: int) -> void:
	_write_u32(data, offset, value)
