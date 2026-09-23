class_name BudgetPhase
extends RefCounted

@warning_ignore_start("integer_division")

const Tiles = preload("res://src/tools/shared/building_tile_ids.gd")

const Ordinances = preload("res://src/simulation/economy/ordinance_command.gd")

const MISC_SIZE := Sc2MiscLayout.SIZE
const MISC_FUNDS := Sc2MiscLayout.FUNDS
const MISC_BONDS := Sc2MiscLayout.BONDS
const MISC_TILE_COUNTS := Sc2MiscLayout.TILE_COUNTS
const MISC_BUDGETS := Sc2MiscLayout.BUDGETS
const MISC_YEAR_END := Sc2MiscLayout.YEAR_END
const MISC_ORDINANCES := Sc2MiscLayout.ORDINANCES
const MISC_SUBWAY_COUNT := Sc2MiscLayout.SUBWAY_COUNT
const MISC_AUTO_BUDGET := Sc2MiscLayout.AUTO_BUDGET
const MISC_NO_DISASTERS := Sc2MiscLayout.NO_DISASTERS
const MISC_ARCOLOGY_POPULATION := Sc2MiscLayout.ARCOLOGY_POPULATION
const MISC_NORMAL_POPULATION := Sc2MiscLayout.NORMAL_POPULATION

const BUDGET_COUNT := Sc2BudgetLayout.COUNT
const BUDGET_RECORD_SIZE := Sc2BudgetLayout.RECORD_SIZE
const BUDGET_CURRENT := Sc2BudgetLayout.CURRENT
const BUDGET_FUNDING := Sc2BudgetLayout.FUNDING
const BUDGET_YEAR_TO_DATE := Sc2BudgetLayout.YEAR_TO_DATE
const BUDGET_MONTHS := Sc2BudgetLayout.MONTHS

const BUDGET_RESIDENTIAL := Sc2BudgetLayout.RESIDENTIAL
const BUDGET_ORDINANCES := Sc2BudgetLayout.ORDINANCES
const BUDGET_BONDS := Sc2BudgetLayout.BONDS
const BUDGET_POLICE := Sc2BudgetLayout.POLICE
const BUDGET_FIRE := Sc2BudgetLayout.FIRE
const BUDGET_ROAD := Sc2BudgetLayout.ROAD

const ANNUAL_DIVISOR_FACTORS := [
	75, 75, 75, 75, -100, -1, -1, -2, -4, -1, -1000, -500, -400, -250, -250, -250,
]

const SERVICE_TILE_IDS := {
	BUDGET_POLICE: Tiles.POLICE_STATION,
	BUDGET_FIRE: Tiles.FIRE_STATION,
	Sc2BudgetLayout.HEALTH: Tiles.HOSPITAL,
	Sc2BudgetLayout.SCHOOL: Tiles.SCHOOL,
	Sc2BudgetLayout.COLLEGE: Tiles.COLLEGE,
}

const NEWS_ORDINANCE := 0x29


class Result extends PhaseResult:
	var month := 0
	var settled_year := false
	var funds_before := 0
	var funds_after := 0
	var auto_budget_disabled := false
	var requires_annual_budget := false
	var current_costs := PackedInt32Array()
	var annual_microsim_update_pending := false


# settle the year and do the monthly work, without the annual facility update
static func run(city: CityState, random: SimRandom, annual_budget_approved := false) -> Result:
	var settlement := settle_year(city, annual_budget_approved)

	if not settlement.ok or settlement.requires_annual_budget:
		return settlement

	return run_month(city, random, settlement)


# first part of the January budget. the original runs the annual facility
# update after this part and before run_month
static func settle_year(city: CityState, annual_budget_approved := false) -> Result:
	if city == null or not city.is_valid():
		return _failed("city is invalid")

	var misc_chunk := city.document.find_chunk("MISC")

	if misc_chunk == null or misc_chunk.decoded_payload.size() != MISC_SIZE:
		return _failed("MISC is missing or has the wrong size")

	var span := SimulationTimingSpan.new(city.simulation_slice)
	span.mark("prepare data")
	var misc: PackedByteArray = misc_chunk.decoded_payload.duplicate()
	var month := _month(city)
	var funds_before := BinaryData.read_i32_be(misc, MISC_FUNDS)
	var funds := funds_before
	var settled_year := false

	if (
		BinaryData.read_u32_be(misc, MISC_YEAR_END) != 0
		and month == 0
		and BinaryData.read_u32_be(misc, MISC_AUTO_BUDGET) == 0
		and not annual_budget_approved
	):
		var interactive := Result.new()
		interactive.ok = true
		interactive.month = month
		interactive.requires_annual_budget = true
		interactive.complete = false
		interactive.timing = span.finish()

		return interactive

	span.mark("annual settlement")
	if BinaryData.read_u32_be(misc, MISC_YEAR_END) != 0 and month == 0:
		settled_year = true

		for budget_id in BUDGET_COUNT:
			var budget_offset := _budget_offset(budget_id)
			var factor: int = ANNUAL_DIVISOR_FACTORS[budget_id]

			if factor != 0:
				var year_to_date := BinaryData.read_i32_be(misc, budget_offset + BUDGET_YEAR_TO_DATE)
				funds = _to_i32(
					funds + _divide_toward_zero(year_to_date, factor * CityCalendar.MONTHS_PER_YEAR)
				)

			BinaryData.write_u32_be(misc, budget_offset + BUDGET_YEAR_TO_DATE, 0)

		BinaryData.write_u32_be(misc, MISC_YEAR_END, 0)
		BinaryData.write_u32_be(misc, MISC_FUNDS, funds)

		if not misc_chunk.set_decoded_payload(misc):
			return _failed("cannot store the annual settlement")

	var result := Result.new()
	result.ok = true
	result.month = month
	result.settled_year = settled_year
	result.funds_before = funds_before
	result.funds_after = funds
	result.annual_microsim_update_pending = settled_year
	result.complete = not settled_year
	result.timing = span.finish()

	return result


# second part of the budget: the Auto Budget check after a settlement, the
# monthly history, the next costs, and the random ordinance
static func run_month(city: CityState, random: SimRandom, settlement: Result) -> Result:
	if city == null or not city.is_valid():
		return _failed("city is invalid")

	if random == null:
		return _failed("a compatible random generator is required")

	if settlement == null or not settlement.ok:
		return _failed("the annual settlement is missing")

	var misc_chunk := city.document.find_chunk("MISC")

	if misc_chunk == null or misc_chunk.decoded_payload.size() != MISC_SIZE:
		return _failed("MISC is missing or has the wrong size")

	var span := SimulationTimingSpan.new(city.simulation_slice)
	span.mark("prepare data")
	var misc: PackedByteArray = misc_chunk.decoded_payload.duplicate()
	var month := _month(city)
	var auto_budget_disabled := false

	# the annual facility update can change funds before this check
	if (
		settlement.settled_year
		and BinaryData.read_i32_be(misc, MISC_FUNDS) < 0
		and BinaryData.read_u32_be(misc, MISC_AUTO_BUDGET) != 0
	):
		BinaryData.write_u32_be(misc, MISC_AUTO_BUDGET, 0)
		auto_budget_disabled = true

	span.mark("monthly history")
	for budget_id in BUDGET_COUNT:
		var budget_offset := _budget_offset(budget_id)
		var current := BinaryData.read_i32_be(misc, budget_offset + BUDGET_CURRENT)
		var funding := BinaryData.read_i32_be(misc, budget_offset + BUDGET_FUNDING)
		var month_offset := budget_offset + BUDGET_MONTHS + month * Sc2BudgetLayout.MONTH_RECORD_SIZE
		BinaryData.write_u32_be(misc, month_offset, current)
		BinaryData.write_u32_be(misc, month_offset + Sc2BudgetLayout.MONTH_FUNDING, funding)
		var year_to_date := BinaryData.read_i32_be(misc, budget_offset + BUDGET_YEAR_TO_DATE)
		var funded_cost := _to_i32(current * funding)
		BinaryData.write_u32_be(
			misc,
			budget_offset + BUDGET_YEAR_TO_DATE,
			_to_i32(year_to_date + funded_cost)
		)

	if month == CityCalendar.MONTHS_PER_YEAR - 1:
		BinaryData.write_u32_be(misc, MISC_YEAR_END, 1)

	BinaryData.write_u32_be(misc, _budget_offset(BUDGET_BONDS), BinaryData.read_i32_be(misc, MISC_BONDS))

	span.mark("service and network costs")
	for budget_id in SERVICE_TILE_IDS:
		var divisor := 16 if budget_id == Sc2BudgetLayout.COLLEGE else 9
		BinaryData.write_u32_be(
			misc,
			_budget_offset(budget_id),
			_divide_toward_zero(_tile_count(misc, SERVICE_TILE_IDS[budget_id]), divisor)
		)

	for budget_id in range(BUDGET_ROAD, Sc2BudgetLayout.TUNNEL + 1):
		BinaryData.write_u32_be(misc, _budget_offset(budget_id), 0)

	for tile_id in range(Tiles.FIRST_ROAD, Tiles.DEVELOPED_FIRST):
		var count := _tile_count(misc, tile_id)

		if (
			(tile_id >= Tiles.ROAD_STRAIGHT_1 and tile_id <= Tiles.ROAD_CROSSROADS)
			or (tile_id >= Tiles.TUNNEL_ENTRANCE_1 and tile_id <= Tiles.ROAD_RAIL_CROSSING_2)
			or tile_id == Tiles.HIGHWAY_ROAD_CROSSING_1
			or tile_id == Tiles.HIGHWAY_ROAD_CROSSING_2
			or (tile_id >= Tiles.HIGHWAY_ONRAMP_1 and tile_id <= Tiles.HIGHWAY_ONRAMP_4)
		):
			_add_current(misc, BUDGET_ROAD, count)

		if (
			(tile_id >= Tiles.RAIL_STRAIGHT_1 and tile_id <= Tiles.RAIL_SLOPE_8)
			or (tile_id >= Tiles.ROAD_RAIL_CROSSING_1 and tile_id <= Tiles.RAIL_POWER_CROSSING_2)
			or (tile_id >= Tiles.RAIL_SUBWAY_ENTRANCE_1 and tile_id <= Tiles.RAIL_SUBWAY_ENTRANCE_4)
			or tile_id == Tiles.HIGHWAY_RAIL_CROSSING_1
			or tile_id == Tiles.HIGHWAY_RAIL_CROSSING_2
		):
			_add_current(misc, Sc2BudgetLayout.RAIL, count)

		if (tile_id >= Tiles.SUSPENSION_BRIDGE_1 and tile_id <= Tiles.POWER_BRIDGE) or tile_id == Tiles.HIGHWAY_BRIDGE or tile_id == Tiles.REINFORCED_HIGHWAY_BRIDGE:
			_add_current(misc, Sc2BudgetLayout.BRIDGE, count)

		if (tile_id >= Tiles.HIGHWAY_SLOPE_1 and tile_id <= Tiles.REINFORCED_HIGHWAY_BRIDGE) or (tile_id >= Tiles.HIGHWAY_STRAIGHT_1 and tile_id <= Tiles.HIGHWAY_POWER_CROSSING_2):
			_add_current(misc, Sc2BudgetLayout.HIGHWAY, count)

		if tile_id >= Tiles.TUNNEL_ENTRANCE_1 and tile_id <= Tiles.TUNNEL_ENTRANCE_4:
			_add_current(misc, Sc2BudgetLayout.TUNNEL, count)

	BinaryData.write_u32_be(
		misc,
		_budget_offset(Sc2BudgetLayout.SUBWAY),
		_tile_count(misc, Tiles.SUBWAY_STATION) + BinaryData.read_u32_be(misc, MISC_SUBWAY_COUNT)
	)
	_add_current(misc, Sc2BudgetLayout.RAIL, _tile_count(misc, Tiles.RAIL_STATION))
	_add_current(
		misc,
		BUDGET_ROAD,
		_divide_toward_zero(_tile_count(misc, Tiles.BUS_DEPOT), 4) * 250
	)
	BinaryData.write_u32_be(
		misc,
		_budget_offset(BUDGET_ORDINANCES),
		Ordinances.current_cost_for_misc(misc),
	)

	span.mark("ordinance events")
	var news_items: Array[NewsEvent] = []

	if (
		BinaryData.read_u32_be(misc, MISC_NO_DISASTERS) == 0
		and (random.next_u15() & 7) == 0
		and (random.next_u15() & 0xffff) + 50000 < BinaryData.read_i32_be(misc, MISC_FUNDS)
	):
		var ordinance_id: int = random.next_u15() % 20
		BinaryData.write_u32_be(
			misc,
			MISC_ORDINANCES,
			BinaryData.read_u32_be(misc, MISC_ORDINANCES) | (1 << ordinance_id)
		)
		news_items.append(NewsEvent.new(NEWS_ORDINANCE, ordinance_id))

	span.mark("store budget")
	if not misc_chunk.set_decoded_payload(misc):
		return _failed("cannot store the monthly budget update")

	var current_costs := PackedInt32Array()

	for budget_id in BUDGET_COUNT:
		current_costs.append(BinaryData.read_i32_be(misc, _budget_offset(budget_id)))

	var result := Result.new()
	result.ok = true
	result.month = month
	result.settled_year = settlement.settled_year
	result.funds_before = settlement.funds_before
	result.funds_after = BinaryData.read_i32_be(misc, MISC_FUNDS)
	result.auto_budget_disabled = auto_budget_disabled
	result.current_costs = current_costs
	result.news_items = news_items
	result.annual_microsim_update_pending = settlement.settled_year
	result.complete = not settlement.settled_year
	result.timing = span.finish()

	for label in settlement.timing.steps:
		result.timing.steps[label] = int(result.timing.steps.get(label, 0)) + settlement.timing.steps[label]

	result.timing.work_usec += settlement.timing.work_usec

	return result

static func _failed(message: String) -> Result:
	var result := Result.new()
	result.error = message

	return result


static func requires_annual_budget(city: CityState) -> bool:
	if city == null or not city.is_valid():
		return false

	return (
		city.age_in_days() % CityCalendar.DAYS_PER_YEAR == 0
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
) -> Result:
	if city == null or not city.is_valid():
		return _failed("city is invalid")

	if values.size() != BUDGET_COUNT:
		return _failed("sixteen budget funding values are required")

	var misc_chunk := city.document.find_chunk("MISC")

	if misc_chunk == null or misc_chunk.decoded_payload.size() != MISC_SIZE:
		return _failed("MISC is missing or has the wrong size")

	var misc: PackedByteArray = misc_chunk.decoded_payload.duplicate()

	for budget_id in BUDGET_COUNT:
		BinaryData.write_u32_be(misc, _budget_offset(budget_id) + BUDGET_FUNDING, values[budget_id])

	BinaryData.write_u32_be(misc, MISC_AUTO_BUDGET, 1 if auto_budget else 0)

	if not misc_chunk.set_decoded_payload(misc):
		return _failed("cannot store budget funding values")

	var result := Result.new()
	result.ok = true
	result.error = ""

	return result


static func _month(city: CityState) -> int:
	return int((city.age_in_days() % CityCalendar.DAYS_PER_YEAR) / CityCalendar.DAYS_PER_MONTH)


static func _budget_offset(budget_id: int) -> int:
	return MISC_BUDGETS + budget_id * BUDGET_RECORD_SIZE


static func _tile_count(misc: PackedByteArray, tile_id: int) -> int:
	return BinaryData.read_i32_be(misc, MISC_TILE_COUNTS + tile_id * 4)


static func _add_current(misc: PackedByteArray, budget_id: int, value: int) -> void:
	var offset := _budget_offset(budget_id)
	BinaryData.write_u32_be(misc, offset, _to_i32(BinaryData.read_i32_be(misc, offset) + value))


static func _divide_toward_zero(value: int, divisor: int) -> int:
	if divisor == 0:
		return 0

	var quotient := int(absi(value) / absi(divisor))

	return -quotient if (value < 0) != (divisor < 0) else quotient


static func _to_i32(value: int) -> int:
	var unsigned := value & 0xffffffff

	return unsigned - 0x100000000 if unsigned & 0x80000000 else unsigned
