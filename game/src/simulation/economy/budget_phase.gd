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
# the city council message when negative funds turn off Auto Budget
const NOTICE_FISCAL_CRISIS := 292


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


static func _budget_offset(budget_id: int) -> int:
	return MISC_BUDGETS + budget_id * BUDGET_RECORD_SIZE


static func _tile_count(misc: PackedByteArray, tile_id: int) -> int:
	return BinaryData.read_i32_be(misc, MISC_TILE_COUNTS + tile_id * 4)


static func _divide_toward_zero(value: int, divisor: int) -> int:
	if divisor == 0:
		return 0

	var quotient := int(absi(value) / absi(divisor))

	return -quotient if (value < 0) != (divisor < 0) else quotient


static func _to_i32(value: int) -> int:
	var unsigned := value & 0xffffffff

	return unsigned - 0x100000000 if unsigned & 0x80000000 else unsigned


static func run(city: CityState, random: SimRandom, annual_budget_approved := false) -> Result:
	if city == null or not city.is_valid():
		return _failed("city is invalid")

	return NativeSimulationBridge.run("budget.run", city, random, null, null, {"annual_budget_approved": annual_budget_approved}).result


static func settle_year(city: CityState, annual_budget_approved := false) -> Result:
	if city == null or not city.is_valid():
		return _failed("city is invalid")

	return NativeSimulationBridge.run("budget.settle_year", city, null, null, null, {"annual_budget_approved": annual_budget_approved}).result


static func run_month(city: CityState, random: SimRandom, settlement: Result) -> Result:
	if city == null or not city.is_valid():
		return _failed("city is invalid")

	if random == null:
		return _failed("a compatible random generator is required")

	if settlement == null or not settlement.ok:
		return _failed("the annual settlement is missing")

	var timing := {"has_total": settlement.timing.has_total, "work_usec": settlement.timing.work_usec,
		"steps": settlement.timing.steps}

	return NativeSimulationBridge.run("budget.run_month", city, random, null, null, {"settled_year": settlement.settled_year,
		"funds_before": settlement.funds_before, "settlement_ok": settlement.ok, "settlement_timing": timing}).result


static func set_funding(city: CityState, values: PackedInt32Array, auto_budget: bool) -> Result:
	if city == null or not city.is_valid():
		return _failed("city is invalid")

	return NativeSimulationBridge.run("budget.set_funding", city, null, null, null, {"values": values, "auto_budget": auto_budget}).result


class Result extends PhaseResult:
	var month := 0
	var settled_year := false
	var funds_before := 0
	var funds_after := 0
	var auto_budget_disabled := false
	var requires_annual_budget := false
	var current_costs := PackedInt32Array()
	var annual_microsim_update_pending := false
