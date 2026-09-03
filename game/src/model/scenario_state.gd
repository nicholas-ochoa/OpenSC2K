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

class TemplateField extends RefCounted:
	var name := ""
	var type_code := ""
	var size := 0
	var scenario_offset := 0


class PictureIndices extends RefCounted:
	var ok := false
	var error := ""
	var width := 0
	var height := 0
	var pixels := PackedByteArray()

	static func rejected(message: String) -> PictureIndices:
		var result := PictureIndices.new()
		result.error = message

		return result


class PictureImage extends AssetImageResult:
	var width := 0
	var height := 0
	var replacement := false

	static func rejected(message: String) -> PictureImage:
		var result := PictureImage.new()
		result.error = message

		return result


class Template extends RefCounted:
	var ok := false
	var error := ""
	var present := false
	var fields: Array[TemplateField] = []
	var scenario_size := 0

	static func rejected(message: String) -> Template:
		var result := Template.new()
		result.error = message

		return result


class Goals extends RefCounted:
	var ok := false
	var error := ""
	var met := false
	var unmet := PackedStringArray()
	var values: Dictionary[String, int] = {}

	static func rejected(message: String) -> Goals:
		var result := Goals.new()
		result.error = message

		return result


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


func picture_indices() -> PictureIndices:
	var chunk := document.find_chunk("PICT")

	if chunk == null:
		return PictureIndices.rejected("PICT chunk is missing")

	var data := chunk.decoded_payload

	if data.size() < 8 or _read_u32_be(data, 0) != 0x80000000:
		return PictureIndices.rejected("PICT header is invalid")

	# pict dimensions are little-endian even though scen and form values are big-endian
	var width := _read_u16_le(data, 4)
	var height := _read_u16_le(data, 6)

	if width <= 0 or height <= 0:
		return PictureIndices.rejected("PICT dimensions are empty")

	var pixels := PackedByteArray()
	pixels.resize(width * height)
	var position := 8
	var remaining := data.size() - position
	var has_row_terminators := remaining == height * (width + 1)

	if remaining != width * height and not has_row_terminators:
		return PictureIndices.rejected("PICT byte count does not match its dimensions")

	for y in height:
		if position + width > data.size():
			return PictureIndices.rejected("PICT row %d is truncated" % y)

		for x in width:
			pixels[y * width + x] = data[position + x]

		position += width

		if has_row_terminators:
			if data[position] != 0x00 and data[position] != 0xff:
				return PictureIndices.rejected("PICT row %d has invalid terminator 0x%02x" % [y, data[position]])

			position += 1

	if position != data.size():
		return PictureIndices.rejected("PICT has %d unparsed bytes" % (data.size() - position))

	var result := PictureIndices.new()
	result.ok = true
	result.width = width
	result.height = height
	result.pixels = pixels
	result.error = ""

	return result


func picture_image(palette: Sc2Palette) -> PictureImage:
	if palette == null or not palette.is_valid():
		return PictureImage.rejected("PICT palette is invalid")

	var picture := picture_indices()

	if not picture.ok:
		return PictureImage.rejected(picture.error)

	var width: int = picture.width
	var height: int = picture.height
	var pixels: PackedByteArray = picture.pixels
	var image := Image.create(width, height, false, Image.FORMAT_RGBA8)

	# 004745d0 sets the dib orientation to -1. 00474bc0 multiplies the
	# height by that sign before createdibsection, so stored rows are top-down
	for source_y in height:
		for x in width:
			image.set_pixel(x, source_y, palette.color(pixels[source_y * width + x]))

	var result := PictureImage.new()
	result.ok = true
	result.width = width
	result.height = height
	result.image = image
	result.error = ""

	return result


func template_fields() -> Template:
	var chunk := document.find_chunk("TMPL") if document != null else null

	if chunk == null:
		var result := Template.new()
		result.ok = true
		result.present = false
		result.fields = []
		result.scenario_size = 0
		result.error = ""

		return result

	var data := chunk.decoded_payload

	if data.size() < 4 or _read_u32_be(data, 0) != TEMPLATE_HEADER:
		return Template.rejected("TMPL header is invalid")

	var fields: Array[TemplateField] = []
	var position := 4
	var scenario_offset := 4

	while position < data.size():
		var name_length := int(data[position])
		position += 1

		if name_length == 0:
			return Template.rejected("TMPL field %d has an empty name" % fields.size())

		if position + name_length + 4 > data.size():
			return Template.rejected("TMPL field %d is truncated" % fields.size())

		var name := data.slice(position, position + name_length).get_string_from_ascii()
		position += name_length
		var type_code := data.slice(position, position + 4).get_string_from_ascii()
		position += 4

		if not TEMPLATE_TYPE_SIZES.has(type_code):
			return Template.rejected(
				"TMPL field %d has unknown type %s" % [fields.size(), type_code]
			)

		var field_size := int(TEMPLATE_TYPE_SIZES[type_code])
		var field := TemplateField.new()
		field.name = name
		field.type_code = type_code
		field.size = field_size
		field.scenario_offset = scenario_offset
		fields.append(field)
		scenario_offset += field_size

	var result := Template.new()
	result.ok = true
	result.present = true
	result.fields = fields
	result.scenario_size = scenario_offset
	result.error = ""

	return result


func evaluate_goals(city: CityState) -> Goals:
	if city == null or not city.is_valid():
		return Goals.rejected("city is invalid")

	var unmet := PackedStringArray()
	var values: Dictionary[String, int] = {
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

	var result := Goals.new()
	result.ok = true
	result.met = unmet.is_empty()
	result.unmet = unmet
	result.values = values
	result.error = ""

	return result


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
