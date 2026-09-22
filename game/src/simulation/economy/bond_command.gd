class_name BondCommand
extends RefCounted

@warning_ignore_start("integer_division")

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


static func _failed(message: String) -> Result:
	var result := Result.new()
	result.error = message

	return result


static func issue(city: CityState, confirmation := CONFIRMATION_UNSELECTED) -> Result:
	if not _valid_confirmation(confirmation):
		return _failed("confirmation choice is invalid")

	var validated := _misc_data(city)

	if not validated.ok:
		return _failed(validated.error)

	var misc_chunk = validated.chunk
	var misc: PackedByteArray = validated.misc.duplicate()
	var bond_count := BinaryData.read_u32_be(misc, MISC_BONDS)

	if bond_count > MAX_BONDS:
		return _failed("saved bond count exceeds fifty")

	# the budget handler rebuilds the city value before every issue attempt
	var city_value_result := CityValue.calculate(city)

	if not city_value_result.ok:
		return _failed(city_value_result.error)

	var city_value := int(city_value_result.city_value)
	BinaryData.write_u32_be(misc, MISC_CITY_VALUE, city_value)
	var denominator := (city_value + 1) & 0xffffffff

	if denominator == 0:
		return _failed("city value makes the credit calculation invalid")

	var numerator := (bond_count * 2500) & 0xffffffff
	var credit_value := _to_i16(int(numerator / denominator))

	if credit_value >= CREDIT_LIMIT:
		if not misc_chunk.set_decoded_payload(misc):
			return _failed("cannot store the rebuilt city value")

		return _result(
			"credit_denied", false, false, bond_count, BinaryData.read_i32_be(misc, MISC_FUNDS),
			city_value, credit_value
		)

	if bond_count == MAX_BONDS:
		if not misc_chunk.set_decoded_payload(misc):
			return _failed("cannot store the rebuilt city value")

		return _result(
			"maximum_bonds", false, false, bond_count, BinaryData.read_i32_be(misc, MISC_FUNDS),
			city_value, credit_value
		)

	var rate := _to_i16(_read_u16_low(misc, MISC_FEDERAL_RATE) + 1)

	if confirmation == CONFIRMATION_UNSELECTED:
		if not misc_chunk.set_decoded_payload(misc):
			return _failed("cannot store the rebuilt city value")

		return _result(
			"confirmation_required", true, false, bond_count,
			BinaryData.read_i32_be(misc, MISC_FUNDS),
			city_value, credit_value, rate
		)

	if confirmation == CONFIRMATION_CANCELLED:
		if not misc_chunk.set_decoded_payload(misc):
			return _failed("cannot store the rebuilt city value")

		return _result(
			"cancelled", false, false, bond_count, BinaryData.read_i32_be(misc, MISC_FUNDS),
			city_value, credit_value, rate
		)

	var interest_sum := _interest_sum(misc, bond_count)
	_normalize_bond_rates(misc)
	BinaryData.write_u32_be(misc, MISC_BOND_RATES + bond_count * 4, rate & 0xffff)
	interest_sum = _to_i32(interest_sum + rate)
	bond_count += 1
	var funds := _to_i32(BinaryData.read_i32_be(misc, MISC_FUNDS) + BOND_VALUE)
	BinaryData.write_u32_be(misc, MISC_FUNDS, funds)
	BinaryData.write_u32_be(misc, MISC_BONDS, bond_count)
	BinaryData.write_u32_be(misc, _bond_budget_offset() + BUDGET_CURRENT, bond_count)
	BinaryData.write_u32_be(
		misc,
		_bond_budget_offset() + BUDGET_FUNDING,
		_divide_toward_zero(_to_i32(interest_sum * 10000), bond_count)
	)

	if not misc_chunk.set_decoded_payload(misc):
		return _failed("cannot store the issued bond")

	return _result(
		"issued", false, true, bond_count, funds,
		city_value, credit_value, rate
	)


static func repay(city: CityState, confirmation := CONFIRMATION_UNSELECTED) -> Result:
	if not _valid_confirmation(confirmation):
		return _failed("confirmation choice is invalid")

	var validated := _misc_data(city)

	if not validated.ok:
		return _failed(validated.error)

	var misc_chunk = validated.chunk
	var misc: PackedByteArray = validated.misc.duplicate()
	var bond_count := BinaryData.read_u32_be(misc, MISC_BONDS)

	if bond_count > MAX_BONDS:
		return _failed("saved bond count exceeds fifty")

	var funds := BinaryData.read_i32_be(misc, MISC_FUNDS)

	if bond_count == 0:
		return _result("no_bonds", false, false, bond_count, funds)

	if funds < BOND_VALUE:
		return _result("insufficient_funds", false, false, bond_count, funds)

	var oldest_rate := _read_i16_low(misc, MISC_BOND_RATES)

	if confirmation == CONFIRMATION_UNSELECTED:
		return _result(
			"confirmation_required", true, false, bond_count, funds,
			0, 0, oldest_rate
		)

	if confirmation == CONFIRMATION_CANCELLED:
		return _result(
			"cancelled", false, false, bond_count, funds, 0, 0, oldest_rate
		)

	var rates := PackedInt32Array()

	for rate_index in MAX_BONDS:
		rates.append(_read_u16_low(misc, MISC_BOND_RATES + rate_index * 4))

	var interest_sum := _to_i32(_interest_sum(misc, bond_count) - oldest_rate)
	bond_count -= 1

	for rate_index in bond_count:
		rates[rate_index] = rates[rate_index + 1]

	for rate_index in MAX_BONDS:
		BinaryData.write_u32_be(misc, MISC_BOND_RATES + rate_index * 4, rates[rate_index])

	funds = _to_i32(funds - BOND_VALUE)
	BinaryData.write_u32_be(misc, MISC_FUNDS, funds)
	BinaryData.write_u32_be(misc, MISC_BONDS, bond_count)
	BinaryData.write_u32_be(misc, _bond_budget_offset() + BUDGET_CURRENT, bond_count)
	var average_rate := 0

	if bond_count > 0:
		average_rate = _divide_toward_zero(_to_i32(interest_sum * 10000), bond_count)

	BinaryData.write_u32_be(misc, _bond_budget_offset() + BUDGET_FUNDING, average_rate)

	if not misc_chunk.set_decoded_payload(misc):
		return _failed("cannot store the repaid bond")

	return _result(
		"repaid", false, true, bond_count, funds, 0, 0, oldest_rate
	)


static func _result(
	status: String,
	confirmation_required: bool,
	changed: bool,
	bond_count: int,
	funds: int,
	city_value := 0,
	credit_value := 0,
	rate := 0
) -> Result:
	var result := Result.new()
	result.ok = true
	result.status = status
	result.confirmation_required = confirmation_required
	result.changed = changed
	result.bond_count = bond_count
	result.funds = funds
	result.city_value = city_value
	result.credit_value = credit_value
	result.rate = rate

	return result


static func _valid_confirmation(value: int) -> bool:
	return value in [
		CONFIRMATION_UNSELECTED, CONFIRMATION_CANCELLED, CONFIRMATION_CONFIRMED,
	]


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


static func _interest_sum(misc: PackedByteArray, bond_count: int) -> int:
	var result := 0

	for rate_index in bond_count:
		result = _to_i32(result + _read_u16_low(misc, MISC_BOND_RATES + rate_index * 4))

	return result


static func _normalize_bond_rates(misc: PackedByteArray) -> void:
	for rate_index in MAX_BONDS:
		var offset := MISC_BOND_RATES + rate_index * 4
		BinaryData.write_u32_be(misc, offset, _read_u16_low(misc, offset))


static func _bond_budget_offset() -> int:
	return MISC_BUDGETS + BUDGET_BONDS * BUDGET_RECORD_SIZE


static func _divide_toward_zero(value: int, divisor: int) -> int:
	var quotient := int(absi(value) / absi(divisor))

	return -quotient if (value < 0) != (divisor < 0) else quotient


static func _read_u16_low(data: PackedByteArray, offset: int) -> int:
	return (data[offset + 2] << 8) | data[offset + 3]


static func _read_i16_low(data: PackedByteArray, offset: int) -> int:
	return _to_i16(_read_u16_low(data, offset))


static func _to_i16(value: int) -> int:
	var unsigned := value & 0xffff

	return unsigned - 0x10000 if unsigned & 0x8000 else unsigned


static func _to_i32(value: int) -> int:
	var unsigned := value & 0xffffffff

	return unsigned - 0x100000000 if unsigned & 0x80000000 else unsigned
