class_name BondCommand
extends RefCounted

const CityValue = preload("res://src/simulation/economy/city_value_phase.gd")

const MISC_SIZE := 4800
const MISC_FUNDS := 0x0014
const MISC_BONDS := 0x0018
const MISC_CITY_VALUE := 0x0024
const MISC_FEDERAL_RATE := 0x0058
const MISC_BOND_RATES := 0x0610
const MISC_BUDGETS := 0x077c
const BUDGET_RECORD_SIZE := 0x006c
const BUDGET_BONDS := 4
const BUDGET_CURRENT := 0x00
const BUDGET_FUNDING := 0x04

const BOND_VALUE := 10000
const MAX_BONDS := 50
const CREDIT_LIMIT := 6

const CONFIRMATION_UNSELECTED := -1
const CONFIRMATION_CANCELLED := 0
const CONFIRMATION_CONFIRMED := 1


static func issue(city: CityState, confirmation := CONFIRMATION_UNSELECTED) -> Dictionary:
	if not _valid_confirmation(confirmation):
		return {"ok": false, "error": "confirmation choice is invalid"}

	var validated := _misc_data(city)

	if not validated.ok:
		return validated

	var misc_chunk = validated.chunk
	var misc: PackedByteArray = validated.misc.duplicate()
	var bond_count := _read_u32(misc, MISC_BONDS)

	if bond_count > MAX_BONDS:
		return {"ok": false, "error": "saved bond count exceeds fifty"}

	# the budget handler rebuilds the city value before every issue attempt
	var city_value_result := CityValue.calculate(city)

	if not city_value_result.ok:
		return city_value_result

	var city_value := int(city_value_result.city_value)
	_write_i32(misc, MISC_CITY_VALUE, city_value)
	var denominator := (city_value + 1) & 0xffffffff

	if denominator == 0:
		return {"ok": false, "error": "city value makes the credit calculation invalid"}

	var numerator := (bond_count * 2500) & 0xffffffff
	var credit_value := _to_i16(int(IntegerMath.div_trunc(numerator, denominator)))

	if credit_value >= CREDIT_LIMIT:
		if not misc_chunk.set_decoded_payload(misc):
			return {"ok": false, "error": "cannot store the rebuilt city value"}

		return _result(
			"credit_denied", false, false, bond_count, _read_i32(misc, MISC_FUNDS),
			{"city_value": city_value, "credit_value": credit_value}
		)

	if bond_count == MAX_BONDS:
		if not misc_chunk.set_decoded_payload(misc):
			return {"ok": false, "error": "cannot store the rebuilt city value"}

		return _result(
			"maximum_bonds", false, false, bond_count, _read_i32(misc, MISC_FUNDS),
			{"city_value": city_value, "credit_value": credit_value}
		)

	var rate := _to_i16(_read_u16_low(misc, MISC_FEDERAL_RATE) + 1)

	if confirmation == CONFIRMATION_UNSELECTED:
		if not misc_chunk.set_decoded_payload(misc):
			return {"ok": false, "error": "cannot store the rebuilt city value"}

		return _result(
			"confirmation_required", true, false, bond_count,
			_read_i32(misc, MISC_FUNDS),
			{"city_value": city_value, "credit_value": credit_value, "rate": rate}
		)

	if confirmation == CONFIRMATION_CANCELLED:
		if not misc_chunk.set_decoded_payload(misc):
			return {"ok": false, "error": "cannot store the rebuilt city value"}

		return _result(
			"cancelled", false, false, bond_count, _read_i32(misc, MISC_FUNDS),
			{"city_value": city_value, "credit_value": credit_value, "rate": rate}
		)

	var interest_sum := _interest_sum(misc, bond_count)
	_normalize_bond_rates(misc)
	_write_u32(misc, MISC_BOND_RATES + bond_count * 4, rate & 0xffff)
	interest_sum = _to_i32(interest_sum + rate)
	bond_count += 1
	var funds := _to_i32(_read_i32(misc, MISC_FUNDS) + BOND_VALUE)
	_write_i32(misc, MISC_FUNDS, funds)
	_write_u32(misc, MISC_BONDS, bond_count)
	_write_i32(misc, _bond_budget_offset() + BUDGET_CURRENT, bond_count)
	_write_i32(
		misc,
		_bond_budget_offset() + BUDGET_FUNDING,
		_divide_toward_zero(_to_i32(interest_sum * 10000), bond_count)
	)

	if not misc_chunk.set_decoded_payload(misc):
		return {"ok": false, "error": "cannot store the issued bond"}

	return _result(
		"issued", false, true, bond_count, funds,
		{"city_value": city_value, "credit_value": credit_value, "rate": rate}
	)


static func repay(city: CityState, confirmation := CONFIRMATION_UNSELECTED) -> Dictionary:
	if not _valid_confirmation(confirmation):
		return {"ok": false, "error": "confirmation choice is invalid"}

	var validated := _misc_data(city)

	if not validated.ok:
		return validated

	var misc_chunk = validated.chunk
	var misc: PackedByteArray = validated.misc.duplicate()
	var bond_count := _read_u32(misc, MISC_BONDS)

	if bond_count > MAX_BONDS:
		return {"ok": false, "error": "saved bond count exceeds fifty"}

	var funds := _read_i32(misc, MISC_FUNDS)

	if bond_count == 0:
		return _result("no_bonds", false, false, bond_count, funds)

	if funds < BOND_VALUE:
		return _result("insufficient_funds", false, false, bond_count, funds)

	var oldest_rate := _read_i16_low(misc, MISC_BOND_RATES)

	if confirmation == CONFIRMATION_UNSELECTED:
		return _result(
			"confirmation_required", true, false, bond_count, funds,
			{"rate": oldest_rate}
		)

	if confirmation == CONFIRMATION_CANCELLED:
		return _result(
			"cancelled", false, false, bond_count, funds, {"rate": oldest_rate}
		)

	var rates := PackedInt32Array()

	for rate_index in MAX_BONDS:
		rates.append(_read_u16_low(misc, MISC_BOND_RATES + rate_index * 4))

	var interest_sum := _to_i32(_interest_sum(misc, bond_count) - oldest_rate)
	bond_count -= 1

	for rate_index in bond_count:
		rates[rate_index] = rates[rate_index + 1]

	for rate_index in MAX_BONDS:
		_write_u32(misc, MISC_BOND_RATES + rate_index * 4, rates[rate_index])

	funds = _to_i32(funds - BOND_VALUE)
	_write_i32(misc, MISC_FUNDS, funds)
	_write_u32(misc, MISC_BONDS, bond_count)
	_write_i32(misc, _bond_budget_offset() + BUDGET_CURRENT, bond_count)
	var average_rate := 0

	if bond_count > 0:
		average_rate = _divide_toward_zero(_to_i32(interest_sum * 10000), bond_count)

	_write_i32(misc, _bond_budget_offset() + BUDGET_FUNDING, average_rate)

	if not misc_chunk.set_decoded_payload(misc):
		return {"ok": false, "error": "cannot store the repaid bond"}

	return _result(
		"repaid", false, true, bond_count, funds, {"rate": oldest_rate}
	)


static func _result(
	status: String,
	confirmation_required: bool,
	changed: bool,
	bond_count: int,
	funds: int,
	extra := {}
) -> Dictionary:
	var result := {
		"ok": true,
		"error": "",
		"status": status,
		"confirmation_required": confirmation_required,
		"changed": changed,
		"bond_count": bond_count,
		"funds": funds,
	}
	result.merge(extra)

	return result


static func _valid_confirmation(value: int) -> bool:
	return value in [
		CONFIRMATION_UNSELECTED, CONFIRMATION_CANCELLED, CONFIRMATION_CONFIRMED,
	]


static func _misc_data(city: CityState) -> Dictionary:
	if city == null or not city.is_valid():
		return {"ok": false, "error": "city is invalid"}

	var misc_chunk := city.document.find_chunk("MISC")

	if misc_chunk == null or misc_chunk.decoded_payload.size() != MISC_SIZE:
		return {"ok": false, "error": "MISC is missing or has the wrong size"}

	return {
		"ok": true,
		"error": "",
		"chunk": misc_chunk,
		"misc": misc_chunk.decoded_payload,
	}


static func _interest_sum(misc: PackedByteArray, bond_count: int) -> int:
	var result := 0

	for rate_index in bond_count:
		result = _to_i32(result + _read_u16_low(misc, MISC_BOND_RATES + rate_index * 4))

	return result


static func _normalize_bond_rates(misc: PackedByteArray) -> void:
	for rate_index in MAX_BONDS:
		var offset := MISC_BOND_RATES + rate_index * 4
		_write_u32(misc, offset, _read_u16_low(misc, offset))


static func _bond_budget_offset() -> int:
	return MISC_BUDGETS + BUDGET_BONDS * BUDGET_RECORD_SIZE


static func _divide_toward_zero(value: int, divisor: int) -> int:
	var quotient := int(IntegerMath.div_trunc(absi(value), absi(divisor)))

	return -quotient if (value < 0) != (divisor < 0) else quotient


static func _read_u16_low(data: PackedByteArray, offset: int) -> int:
	return (data[offset + 2] << 8) | data[offset + 3]


static func _read_i16_low(data: PackedByteArray, offset: int) -> int:
	return _to_i16(_read_u16_low(data, offset))


static func _to_i16(value: int) -> int:
	var unsigned := value & 0xffff

	return unsigned - 0x10000 if unsigned & 0x8000 else unsigned


static func _read_u32(data: PackedByteArray, offset: int) -> int:
	return (
		(data[offset] << 24)
		| (data[offset + 1] << 16)
		| (data[offset + 2] << 8)
		| data[offset + 3]
	)


static func _read_i32(data: PackedByteArray, offset: int) -> int:
	return _to_i32(_read_u32(data, offset))


static func _to_i32(value: int) -> int:
	var unsigned := value & 0xffffffff

	return unsigned - 0x100000000 if unsigned & 0x80000000 else unsigned


static func _write_u32(data: PackedByteArray, offset: int, value: int) -> void:
	data[offset] = (value >> 24) & 0xff
	data[offset + 1] = (value >> 16) & 0xff
	data[offset + 2] = (value >> 8) & 0xff
	data[offset + 3] = value & 0xff


static func _write_i32(data: PackedByteArray, offset: int, value: int) -> void:
	_write_u32(data, offset, value)
