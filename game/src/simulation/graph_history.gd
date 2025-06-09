class_name GraphHistory
extends RefCounted

const SERIES_COUNT := 16
const VALUES_PER_SERIES := 52


static func advance(city: CityState, current_values: PackedInt64Array) -> Dictionary:
	if city == null or not city.is_valid():
		return {"ok": false, "error": "city is invalid"}
	if current_values.size() != SERIES_COUNT:
		return {"ok": false, "error": "sixteen current graph values are required"}
	var chunk := city.document.find_chunk("XGRP")
	if chunk == null or chunk.decoded_payload.size() != SERIES_COUNT * VALUES_PER_SERIES * 4:
		return {"ok": false, "error": "XGRP is missing or has the wrong size"}
	var data := chunk.decoded_payload.duplicate()
	var month := int(city.age_in_days() % 300 / 25)
	var elapsed_years := int(city.age_in_days() / 300)
	for series in SERIES_COUNT:
		for index in range(11, 0, -1):
			_copy_value(data, series, index - 1, index)
		_write_value(data, series, 0, current_values[series])
		if month == 0 or month == 6:
			for index in range(31, 12, -1):
				_copy_value(data, series, index - 1, index)
			_copy_value(data, series, 0, 12)
		if month == 0 and elapsed_years % 5 == 0:
			for index in range(51, 32, -1):
				_copy_value(data, series, index - 1, index)
			_copy_value(data, series, 0, 32)
	if not chunk.set_decoded_payload(data):
		return {"ok": false, "error": "cannot store updated XGRP data"}
	return {"ok": true, "month": month, "elapsed_years": elapsed_years, "error": ""}


static func _copy_value(data: PackedByteArray, series: int, source: int, target: int) -> void:
	var base := series * VALUES_PER_SERIES * 4
	for byte_index in 4:
		data[base + target * 4 + byte_index] = data[base + source * 4 + byte_index]


static func _write_value(data: PackedByteArray, series: int, index: int, value: int) -> void:
	var offset := (series * VALUES_PER_SERIES + index) * 4
	data[offset] = (value >> 24) & 0xff
	data[offset + 1] = (value >> 16) & 0xff
	data[offset + 2] = (value >> 8) & 0xff
	data[offset + 3] = value & 0xff
