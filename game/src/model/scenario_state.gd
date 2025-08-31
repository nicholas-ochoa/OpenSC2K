class_name ScenarioState
extends RefCounted

const LEGACY_SIZE := 52
const EXTENDED_SIZE := 56
const TEMPLATE_HEADER := 0x80000000
const TEMPLATE_TYPE_SIZES := {
	"DBYT": 1,
	"DWRD": 2,
	"DLNG": 4,
}

var document: Sc2File
var load_error := ""
var format_size := 0
var disaster_type := 0
var disaster_x := 0
var disaster_y := 0
var time_limit_months := 0
var city_size_goal := 0
var residential_goal := 0
var commercial_goal := 0
var industrial_goal := 0
var cash_goal := 0
var land_value_goal := 0
var life_expectancy_goal := 0
var education_goal := 0
var pollution_limit := 0
var crime_limit := 0
var traffic_limit := 0
var first_building_id := 0
var second_building_id := 0
var first_building_tile_count := 0
var second_building_tile_count := 0


static func from_document(source: Sc2File) -> ScenarioState:
	var scenario := ScenarioState.new()
	scenario.document = source
	if source == null or not source.is_valid():
		scenario.load_error = "The source document is not valid"
		return scenario
	var chunk := source.find_chunk("SCEN")
	if chunk == null:
		scenario.load_error = "SCEN chunk is missing"
		return scenario
	var data := chunk.decoded_payload
	if data.size() != LEGACY_SIZE and data.size() != EXTENDED_SIZE:
		scenario.load_error = "SCEN has %d bytes; expected 52 or 56" % data.size()
		return scenario
	if _read_u32_be(data, 0) != 0x80000000:
		scenario.load_error = "SCEN header is not 0x80000000"
		return scenario

	scenario.format_size = data.size()
	scenario.disaster_type = _read_u16_be(data, 0x04)
	scenario.disaster_x = data[0x06]
	scenario.disaster_y = data[0x07]
	scenario.time_limit_months = _read_u16_be(data, 0x08)
	scenario.city_size_goal = _read_u32_be(data, 0x0a)
	scenario.residential_goal = _read_i32_be(data, 0x0e)
	scenario.commercial_goal = _read_i32_be(data, 0x12)
	scenario.industrial_goal = _read_i32_be(data, 0x16)
	scenario.cash_goal = _read_i32_be(data, 0x1a)
	scenario.land_value_goal = _read_i32_be(data, 0x1e)

	var limit_offset := 0x22
	if data.size() == EXTENDED_SIZE:
		scenario.life_expectancy_goal = _read_u16_be(data, 0x22)
		scenario.education_goal = _read_u16_be(data, 0x24)
		limit_offset = 0x26
	scenario.pollution_limit = _read_u32_be(data, limit_offset)
	scenario.crime_limit = _read_u32_be(data, limit_offset + 4)
	scenario.traffic_limit = _read_u32_be(data, limit_offset + 8)
	scenario.first_building_id = data[limit_offset + 12]
	scenario.second_building_id = data[limit_offset + 13]
	scenario.first_building_tile_count = _read_u16_be(data, limit_offset + 14)
	scenario.second_building_tile_count = _read_u16_be(data, limit_offset + 16)
	return scenario


func is_valid() -> bool:
	return load_error.is_empty()


func selection_description() -> String:
	return _text_chunk(0x80000000)


func opening_description() -> String:
	return _text_chunk(0x81000000)


func picture_indices() -> Dictionary:
	var chunk := document.find_chunk("PICT")
	if chunk == null:
		return _failure("PICT chunk is missing")
	var data := chunk.decoded_payload
	if data.size() < 8 or _read_u32_be(data, 0) != 0x80000000:
		return _failure("PICT header is invalid")
	# pict dimensions are little-endian even though scen and form values are big-endian
	var width := _read_u16_le(data, 4)
	var height := _read_u16_le(data, 6)
	if width <= 0 or height <= 0:
		return _failure("PICT dimensions are empty")

	var pixels := PackedByteArray()
	pixels.resize(width * height)
	var position := 8
	var remaining := data.size() - position
	var has_row_terminators := remaining == height * (width + 1)
	if remaining != width * height and not has_row_terminators:
		return _failure("PICT byte count does not match its dimensions")
	for y in height:
		if position + width > data.size():
			return _failure("PICT row %d is truncated" % y)
		for x in width:
			pixels[y * width + x] = data[position + x]
		position += width
		if has_row_terminators:
			if data[position] != 0x00 and data[position] != 0xff:
				return _failure("PICT row %d has invalid terminator 0x%02x" % [y, data[position]])
			position += 1
	if position != data.size():
		return _failure("PICT has %d unparsed bytes" % (data.size() - position))
	return {"ok": true, "width": width, "height": height, "pixels": pixels, "error": ""}


func template_fields() -> Dictionary:
	var chunk := document.find_chunk("TMPL") if document != null else null
	if chunk == null:
		return {
			"ok": true,
			"present": false,
			"fields": [],
			"scenario_size": 0,
			"error": "",
		}
	var data := chunk.decoded_payload
	if data.size() < 4 or _read_u32_be(data, 0) != TEMPLATE_HEADER:
		return _failure("TMPL header is invalid")
	var fields: Array[Dictionary] = []
	var position := 4
	var scenario_offset := 4
	while position < data.size():
		var name_length := int(data[position])
		position += 1
		if name_length == 0:
			return _failure("TMPL field %d has an empty name" % fields.size())
		if position + name_length + 4 > data.size():
			return _failure("TMPL field %d is truncated" % fields.size())
		var name := data.slice(position, position + name_length).get_string_from_ascii()
		position += name_length
		var type_code := data.slice(position, position + 4).get_string_from_ascii()
		position += 4
		if not TEMPLATE_TYPE_SIZES.has(type_code):
			return _failure(
				"TMPL field %d has unknown type %s" % [fields.size(), type_code]
			)
		var field_size := int(TEMPLATE_TYPE_SIZES[type_code])
		fields.append({
			"name": name,
			"type_code": type_code,
			"size": field_size,
			"scenario_offset": scenario_offset,
		})
		scenario_offset += field_size
	return {
		"ok": true,
		"present": true,
		"fields": fields,
		"scenario_size": scenario_offset,
		"error": "",
	}


func evaluate_goals(city: CityState) -> Dictionary:
	if city == null or not city.is_valid():
		return {"ok": false, "error": "city is invalid"}
	var unmet := PackedStringArray()
	var values := {
		"city_size": city.document.misc_u32(0x102c),
		"residential": city.document.misc_i32(0x077c),
		"commercial": city.document.misc_i32(0x07e8),
		"industrial": city.document.misc_i32(0x0854),
		"cash_after_bonds": city.funds() - city.document.misc_i32(0x18),
		"land_value": city.document.misc_i32(0x28),
		"life_expectancy": city.document.misc_i32(0x48),
		"education": city.document.misc_i32(0x4c),
		"pollution": city.document.misc_u32(0x34),
		"crime": city.document.misc_u32(0x2c),
		"traffic": city.document.misc_u32(0x30),
	}
	_check_minimum(unmet, "city_size", values.city_size, city_size_goal, true)
	_check_minimum(unmet, "residential", values.residential, residential_goal)
	_check_minimum(unmet, "commercial", values.commercial, commercial_goal)
	_check_minimum(unmet, "industrial", values.industrial, industrial_goal)
	_check_minimum(unmet, "cash", values.cash_after_bonds, cash_goal)
	_check_minimum(unmet, "land_value", values.land_value, land_value_goal)
	_check_minimum(unmet, "life_expectancy", values.life_expectancy, life_expectancy_goal)
	_check_minimum(unmet, "education", values.education, education_goal)
	_check_limit(unmet, "pollution", values.pollution, pollution_limit)
	_check_limit(unmet, "crime", values.crime, crime_limit)
	_check_limit(unmet, "traffic", values.traffic, traffic_limit)

	if first_building_id != 0:
		var first_count := city.document.misc_u32(0x01f0 + first_building_id * 4)
		values["first_building_tiles"] = first_count
		if first_count < first_building_tile_count:
			unmet.append("first_building")
	if second_building_id != 0:
		var second_count := city.document.misc_u32(0x01f0 + second_building_id * 4)
		values["second_building_tiles"] = second_count
		if second_count < second_building_tile_count:
			unmet.append("second_building")
	return {
		"ok": true,
		"met": unmet.is_empty(),
		"unmet": unmet,
		"values": values,
		"error": "",
	}


func set_time_limit_months(value: int) -> bool:
	if not is_valid() or value < 0 or value > 0xffff:
		return false
	var chunk := document.find_chunk("SCEN")
	if chunk == null or chunk.decoded_payload.size() != format_size:
		return false
	var data: PackedByteArray = chunk.decoded_payload.duplicate()
	_write_u16_be(data, 0x08, value)
	if not chunk.set_decoded_payload(data):
		return false
	time_limit_months = value
	return true


static func _check_minimum(
	unmet: PackedStringArray,
	name: String,
	actual: int,
	required: int,
	zero_disables: bool = false
) -> void:
	if (not zero_disables or required != 0) and actual < required:
		unmet.append(name)


static func _check_limit(
	unmet: PackedStringArray, name: String, actual: int, limit: int
) -> void:
	if limit > 0 and actual > limit:
		unmet.append(name)


func _text_chunk(expected_header: int) -> String:
	for chunk in document.chunks:
		if chunk.chunk_id != "TEXT" or chunk.decoded_payload.size() < 4:
			continue
		if _read_u32_be(chunk.decoded_payload, 0) != expected_header:
			continue
		var end := 4
		while end < chunk.decoded_payload.size() and chunk.decoded_payload[end] != 0:
			end += 1
		return chunk.decoded_payload.slice(4, end).get_string_from_ascii()
	return ""


static func _read_u16_be(data: PackedByteArray, offset: int) -> int:
	return (data[offset] << 8) | data[offset + 1]


static func _read_u16_le(data: PackedByteArray, offset: int) -> int:
	return data[offset] | (data[offset + 1] << 8)


static func _write_u16_be(data: PackedByteArray, offset: int, value: int) -> void:
	data[offset] = (value >> 8) & 0xff
	data[offset + 1] = value & 0xff


static func _read_u32_be(data: PackedByteArray, offset: int) -> int:
	return (
		(data[offset] << 24)
		| (data[offset + 1] << 16)
		| (data[offset + 2] << 8)
		| data[offset + 3]
	)


static func _read_i32_be(data: PackedByteArray, offset: int) -> int:
	var value := _read_u32_be(data, offset)
	return value - 0x100000000 if value >= 0x80000000 else value


static func _failure(message: String) -> Dictionary:
	return {"ok": false, "error": message}
