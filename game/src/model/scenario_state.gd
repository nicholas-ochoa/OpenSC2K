class_name ScenarioState
extends RefCounted

const LEGACY_SIZE := 52
const EXTENDED_SIZE := 56

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
