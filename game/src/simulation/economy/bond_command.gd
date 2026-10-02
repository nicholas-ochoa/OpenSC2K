class_name BondCommand
extends RefCounted
## Bond issue and repayment from the budget window. The native simulation
## library holds the rules; see native/simulation/src/sim/economy/bonds.rs.

const CityValue = preload("res://src/simulation/economy/city_value_phase.gd")
const MISC_SIZE := Sc2MiscLayout.SIZE
const MISC_FUNDS := Sc2MiscLayout.FUNDS
const MISC_BONDS := Sc2MiscLayout.BONDS
const MISC_CITY_VALUE := Sc2MiscLayout.CITY_VALUE
const MISC_FEDERAL_RATE := Sc2MiscLayout.NATIONAL_FEDERAL_RATE
const MISC_BOND_RATES := Sc2MiscLayout.BOND_RATES
const MISC_BUDGETS := Sc2MiscLayout.BUDGETS
const BUDGET_RECORD_SIZE := Sc2BudgetLayout.RECORD_SIZE
const BUDGET_BONDS := Sc2BudgetLayout.BONDS
const BUDGET_CURRENT := Sc2BudgetLayout.CURRENT
const BUDGET_FUNDING := Sc2BudgetLayout.FUNDING
const BOND_VALUE := 10000
const MAX_BONDS := 50
const CREDIT_LIMIT := 6
const CONFIRMATION_UNSELECTED := -1
const CONFIRMATION_CANCELLED := 0
const CONFIRMATION_CONFIRMED := 1


static func _failed(message: String) -> Result:
	var result := Result.new()
	result.error = message

	return result


static func issue(city: CityState, confirmation := CONFIRMATION_UNSELECTED) -> Result:
	var validated := _misc_data(city)

	if not validated.ok:
		return _failed(validated.error)

	# the budget handler rebuilds the city value before every issue attempt
	var city_value := CityValue.calculate(city)

	if not city_value.ok:
		return _failed(city_value.error)

	var response := NativeEconomy.bond_issue(validated.misc, city_value.city_value, confirmation)

	return _apply(validated.chunk, response, "cannot store the issued bond")


static func repay(city: CityState, confirmation := CONFIRMATION_UNSELECTED) -> Result:
	var validated := _misc_data(city)

	if not validated.ok:
		return _failed(validated.error)

	return _apply(validated.chunk, NativeEconomy.bond_repay(validated.misc, confirmation), "cannot store the repaid bond")


# store the MISC copy that a native command changed
static func _apply(misc_chunk: Sc2Chunk, response: Dictionary, store_error: String) -> Result:
	var result: Result = NativeSimulationBridge.decode(response.result)
	var changed: PackedByteArray = response.misc

	if result.ok and not changed.is_empty() and not misc_chunk.set_decoded_payload(changed, true):
		return _failed(store_error)

	return result


static func _misc_data(city: CityState) -> MiscInput:
	var result := MiscInput.new()

	if city == null or not city.is_valid():
		result.error = "city is invalid"

		return result

	var misc_chunk := city.document.find_chunk("MISC")

	if misc_chunk == null or misc_chunk.decoded_payload.size() != MISC_SIZE:
		result.error = "MISC is missing or has the wrong size"

		return result

	result.ok = true
	result.chunk = misc_chunk
	result.misc = misc_chunk.decoded_payload

	return result


class Result extends RefCounted:
	var ok := false
	var error := ""
	var status := ""
	var confirmation_required := false
	var changed := false
	var bond_count := 0
	var funds := 0
	var city_value := 0
	var credit_value := 0
	var rate := 0


class MiscInput extends RefCounted:
	var ok := false
	var error := ""
	var chunk: Sc2Chunk
	var misc := PackedByteArray()
