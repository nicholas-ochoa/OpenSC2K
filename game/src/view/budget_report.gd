class_name BudgetReport
extends RefCounted
# read-only budget amounts. keep saved history separate from proposed funding

@warning_ignore_start("integer_division")

const Budget = preload("res://src/simulation/economy/budget_phase.gd")
const GROUP_NAMES := ["Property taxes", "Ordinances", "Bond payments", "Police", "Fire", "Health & welfare", "Education", "Roads & transit"]
const GROUPS := [[0, 1, 2], [3], [4], [5], [6], [7], [8, 9], [10, 11, 12, 13, 14, 15]]
const NAMES := [
	"Residential",
	"Commercial",
	"Industrial",
	"Ordinances",
	"Bonds",
	"Police",
	"Fire",
	"Health",
	"School",
	"College",
	"Road",
	"Highway",
	"Bridge",
	"Rail",
	"Subway",
	"Tunnel",
]
const MONTHS := ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]

var current := PackedInt32Array()
var funding := PackedInt32Array()
var year_to_date := PackedInt64Array()
var estimated := PackedInt64Array()
var estimated_raw := PackedInt64Array()
var history: Array[PackedInt64Array] = []
var history_costs: Array[PackedInt32Array] = []
var history_rates: Array[PackedInt32Array] = []
var actual_months := 0
var funds := 0
var year_end := false
var ytd_cash := 0
var estimated_cash := 0


static func capture(city: CityState, proposed: PackedInt32Array) -> BudgetReport:
	var report := BudgetReport.new()

	if city == null or proposed.size() != Budget.BUDGET_COUNT:
		return report

	report.funding = proposed.duplicate()
	report.funds = city.funds()
	report.year_end = city.document.misc_u32(Budget.MISC_YEAR_END) != 0
	report.actual_months = CityCalendar.MONTHS_PER_YEAR if report.year_end else city.current_month()
	var extended := city.document.is_extended()
	var ytd_scaled := 0
	var estimate_scaled := 0

	for id in Budget.BUDGET_COUNT:
		var offset := Budget.MISC_BUDGETS + id * Budget.BUDGET_RECORD_SIZE
		var cost := city.document.misc_i32(offset)

		var raw_ytd := city.document.misc_i32(offset + Budget.BUDGET_YEAR_TO_DATE)
		# SC2X history retains each cost and rate before the legacy accumulator wraps.
		if extended:
			raw_ytd = 0
			for month in report.actual_months:
				var month_offset := offset + Budget.BUDGET_MONTHS + month * Sc2BudgetLayout.MONTH_RECORD_SIZE
				raw_ytd += city.document.misc_i32(month_offset) * city.document.misc_i32(month_offset + Sc2BudgetLayout.MONTH_FUNDING)
		var funded := budget_integer(cost * proposed[id], extended)
		var raw_estimate := (budget_integer(funded * CityCalendar.MONTHS_PER_YEAR, extended) if report.year_end
			else budget_integer(raw_ytd + funded * (CityCalendar.MONTHS_PER_YEAR - report.actual_months), extended))
		var factor: int = Budget.ANNUAL_DIVISOR_FACTORS[id]
		report.current.append(cost)
		report.year_to_date.append(raw_ytd / (factor * CityCalendar.MONTHS_PER_YEAR))
		report.estimated.append(raw_estimate / (factor * CityCalendar.MONTHS_PER_YEAR))
		report.estimated_raw.append(raw_estimate)
		ytd_scaled = budget_integer(ytd_scaled + raw_ytd / factor, extended)
		estimate_scaled = budget_integer(estimate_scaled + raw_estimate / factor, extended)
		var amounts := PackedInt64Array()
		var costs := PackedInt32Array()
		var rates := PackedInt32Array()
		var running_raw := 0
		var previous_amount := 0

		for month in CityCalendar.MONTHS_PER_YEAR:
			var actual := month < report.actual_months
			var month_cost := (city.document.misc_i32(offset + Budget.BUDGET_MONTHS + month * Sc2BudgetLayout.MONTH_RECORD_SIZE) if actual
				else cost)
			var rate := (city.document.misc_i32(offset + Budget.BUDGET_MONTHS + month * Sc2BudgetLayout.MONTH_RECORD_SIZE
				+ Sc2BudgetLayout.MONTH_FUNDING) if actual else proposed[id])
			costs.append(month_cost)
			rates.append(rate)
			running_raw = budget_integer(running_raw + budget_integer(month_cost * rate, extended), extended)
			var cumulative_amount := running_raw / (factor * CityCalendar.MONTHS_PER_YEAR)
			amounts.append(cumulative_amount - previous_amount)
			previous_amount = cumulative_amount

		report.history.append(amounts)
		report.history_costs.append(costs)
		report.history_rates.append(rates)

	report.ytd_cash = ytd_scaled / CityCalendar.MONTHS_PER_YEAR
	report.estimated_cash = estimate_scaled / CityCalendar.MONTHS_PER_YEAR
	return report


static func group_amount(amounts: PackedInt64Array, group: int) -> int:
	var total := 0

	for id: int in GROUPS[group]:
		total += amounts[id]

	return total


static func currency(value: int) -> String:
	return ("−$" if value < 0 else "$") + DisplayNumberFormat.format(absi(value))


static func wrap_i32(value: int) -> int:
	var low := value & 0xffffffff
	return low - 0x100000000 if low & 0x80000000 else low


static func budget_integer(value: int, extended: bool) -> int:
	return value if extended else wrap_i32(value)
