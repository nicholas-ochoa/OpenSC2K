class_name IndustryTaxCommand
extends RefCounted


class Result extends RefCounted:
	var ok: bool = false
	var error: String = ""
	var changed: bool = false
	var value: int


const INDUSTRY_COUNT := 11
const INDUSTRY_STRIDE := 0x0c
const MISC_INDUSTRIES := 0x016c
const MAXIMUM_INDUSTRY_TAX := 20


static func set_tax_rate(
	value_city: CityState, industry: int, value: int, all_industries := false
) -> Result:
	if value_city == null or not value_city.is_valid():
		var result := Result.new()
		result.ok = false
		result.changed = false
		result.error = "city is invalid"

		return result

	if industry < 0 or industry >= INDUSTRY_COUNT:
		var result := Result.new()
		result.ok = false
		result.changed = false
		result.error = "industry is outside the valid range"

		return result

	var misc_chunk := value_city.document.find_chunk("MISC")

	if misc_chunk == null or misc_chunk.decoded_payload.size() < MISC_INDUSTRIES + INDUSTRY_COUNT * INDUSTRY_STRIDE:
		var result := Result.new()
		result.ok = false
		result.changed = false
		result.error = "MISC is missing or too short"

		return result

	var tax_rate := clampi(value, 0, MAXIMUM_INDUSTRY_TAX)
	var data: PackedByteArray = misc_chunk.decoded_payload.duplicate()
	var changed := false

	for current in INDUSTRY_COUNT:
		if not all_industries and current != industry:
			continue

		var offset := MISC_INDUSTRIES + current * INDUSTRY_STRIDE + 4

		if _read_i32_be(data, offset) == tax_rate:
			continue

		_write_i32_be(data, offset, tax_rate)
		changed = true

	if changed and not misc_chunk.set_decoded_payload(data):
		var result := Result.new()
		result.ok = false
		result.changed = false
		result.error = "cannot store industry tax rates"

		return result

	var result := Result.new()
	result.ok = true
	result.changed = changed
	result.value = tax_rate
	result.error = ""

	return result


static func _read_i32_be(data: PackedByteArray, offset: int) -> int:
	var value := (
		(data[offset] << 24)
		| (data[offset + 1] << 16)
		| (data[offset + 2] << 8)
		| data[offset + 3]
	)

	return value - 0x100000000 if value & 0x80000000 else value


static func _write_i32_be(data: PackedByteArray, offset: int, value: int) -> void:
	var encoded := value & 0xffffffff
	data[offset] = (encoded >> 24) & 0xff
	data[offset + 1] = (encoded >> 16) & 0xff
	data[offset + 2] = (encoded >> 8) & 0xff
	data[offset + 3] = encoded & 0xff
