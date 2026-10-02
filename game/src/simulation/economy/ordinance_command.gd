class_name OrdinanceCommand
extends RefCounted
## The ordinance window commands. The native simulation library holds the
## rules; see native/simulation/src/sim/economy/ordinances.rs.


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
	return NativeEconomy.ordinance_costs(misc)


static func current_cost_for_misc(misc: PackedByteArray) -> int:
	return NativeEconomy.ordinance_current_cost(misc)


static func failed(message: String) -> Result:
	var result := Result.new()
	result.error = message

	return result


static func snapshot(city: CityState) -> Result:
	if city == null or not city.is_valid():
		return failed("city is invalid")

	var misc := _misc(city)

	return NativeSimulationBridge.decode(NativeEconomy.ordinance_snapshot(misc))


static func synchronize_current(city: CityState) -> Result:
	if city == null or not city.is_valid():
		return failed("city is invalid")

	var response := NativeEconomy.ordinance_synchronize(_misc(city))

	return _apply(city, response, "cannot store the ordinance budget total")


static func set_enabled(city: CityState, ordinance_id: int, enabled: bool) -> Result:
	if city == null or not city.is_valid():
		return failed("city is invalid")

	var response := NativeEconomy.ordinance_set_enabled(_misc(city), ordinance_id, enabled)

	return _apply(city, response, "cannot store the ordinance selection")


static func compact_amount(value: int) -> String:
	var absolute := absi(value)

	if absolute < 9999:
		return str(value)

	if absolute < 9999999:
		return "%dk" % _divide_toward_zero(value + 501, 1000)

	return "%dm" % _divide_toward_zero(value + 501000, 1000000)


# an empty array when MISC is missing. the native command reports its size
static func _misc(city: CityState) -> PackedByteArray:
	var misc_chunk := city.document.find_chunk("MISC")

	return misc_chunk.decoded_payload if misc_chunk != null else PackedByteArray()


# store the MISC copy that a native command changed
static func _apply(city: CityState, response: Dictionary, store_error: String) -> Result:
	var result: Result = NativeSimulationBridge.decode(response.result)
	var changed: PackedByteArray = response.misc

	if result.ok and not changed.is_empty() and not city.document.find_chunk("MISC").set_decoded_payload(changed, true):
		return failed(store_error)

	return result


static func _divide_toward_zero(value: int, divisor: int) -> int:
	if divisor == 0:
		return 0

	var quotient := int(absi(value) / absi(divisor))

	return -quotient if (value < 0) != (divisor < 0) else quotient


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
