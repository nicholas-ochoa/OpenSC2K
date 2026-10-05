class_name ScenarioState
extends RefCounted

const LEGACY_SIZE := 52
const EXTENDED_SIZE := 56
# SC2X version 4 widens the disaster coordinates and the building tile counts
const SCHEMA2_SIZE := 64
const SCHEMA2_TIME_LIMIT := 0x0a
const TEMPLATE_HEADER := 0x80000000
# the SCEN fields that the native library reads and evaluates
const FIELDS: PackedStringArray = [
	"format_size", "disaster_type", "disaster_x", "disaster_y", "time_limit_months", "city_size_goal",
	"residential_goal", "commercial_goal", "industrial_goal", "cash_goal", "land_value_goal",
	"life_expectancy_goal", "education_goal", "pollution_limit", "crime_limit", "traffic_limit",
	"first_building_id", "second_building_id", "first_building_tile_count", "second_building_tile_count",
]
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
var first_building_id := BuildingTileIds.EMPTY
var second_building_id := BuildingTileIds.EMPTY
var first_building_tile_count := 0
var second_building_tile_count := 0


# The scenario of a document. The native simulation library reads SCEN; see
# native/core/sim/src/sim/civic/scenario.rs.
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

	var read: Dictionary = NativeSimulation.scenario_read(chunk.decoded_payload)

	if not read.ok:
		scenario.load_error = read.error

		return scenario

	for field: String in read.fields:
		scenario.set(field, read.fields[field])

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

	if data.size() < 8 or BinaryData.read_u32_be(data, 0) != 0x80000000:
		return PictureIndices.rejected("PICT header is invalid")

	# pict dimensions are little-endian even though scen and form values are big-endian
	var width := data.decode_u16(4)
	var height := data.decode_u16(6)

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
		var absent_template := Template.new()
		absent_template.ok = true
		absent_template.present = false
		absent_template.fields = []
		absent_template.scenario_size = 0
		absent_template.error = ""

		return absent_template

	var data := chunk.decoded_payload

	if data.size() < 4 or BinaryData.read_u32_be(data, 0) != TEMPLATE_HEADER:
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

	var misc := city.document.find_chunk("MISC")

	if misc == null:
		return Goals.rejected("city is invalid")

	var fields := {}

	for field in FIELDS:
		fields[field] = get(field)

	var evaluated: Dictionary = NativeSimulation.scenario_goals(fields, misc.decoded_payload, city.map_size,
		city.document.large_version)
	var result := Goals.new()
	result.ok = true
	result.unmet = evaluated.unmet
	result.met = result.unmet.is_empty()
	result.values.assign(evaluated.values)
	result.error = ""

	return result


# The player progress of each goal, as the scenario status window of sc2kfix
# shows it: label, requirement, current value, and whether the goal is met.
# A goal that the scenario does not use is left out.
func progress_rows(city: CityState) -> Array[ProgressRow]:
	var rows: Array[ProgressRow] = []
	var goals := evaluate_goals(city)

	if not goals.ok:
		return rows

	var money := func(value: int) -> String: return BudgetReport.currency(value)
	var land := func(value: int) -> String: return BudgetReport.currency(value * 1000)
	var number := func(value: int) -> String: return str(value)

	for goal: Array in [
		["city_size", "city_size", city_size_goal, "City population", number, false],
		["residential", "residential", residential_goal, "Residential population", number, false],
		["commercial", "commercial", commercial_goal, "Commercial population", number, false],
		["industrial", "industrial", industrial_goal, "Industrial population", number, false],
		["cash", "cash_after_bonds", cash_goal, "Funds minus bonds", money, false],
		["land_value", "land_value", land_value_goal, "Total land value", land, false],
		["life_expectancy", "life_expectancy", life_expectancy_goal, "Life expectancy", number, false],
		["education", "education", education_goal, "Education quotient", number, false],
		["pollution", "pollution", pollution_limit, "Pollution", number, true],
		["crime", "crime", crime_limit, "Crime", number, true],
		["traffic", "traffic", traffic_limit, "Traffic", number, true],
	]:
		var required: int = goal[2]

		if required <= 0:
			continue

		var format: Callable = goal[4]
		rows.append(ProgressRow.create(goal[3], ("at most " if goal[5] else "at least ") + format.call(required),
			format.call(int(goals.values.get(goal[1], 0))), goal[0] not in goals.unmet))

	for building: Array in [
		["first_building", "first_building_tiles", first_building_id, first_building_tile_count],
		["second_building", "second_building_tiles", second_building_id, second_building_tile_count],
	]:
		if int(building[2]) == BuildingTileIds.EMPTY:
			continue

		rows.append(ProgressRow.create("%s tiles" % QueryStrings.tile_name(int(building[2])), "at least %d" % int(building[3]),
			str(int(goals.values.get(building[1], 0))), building[0] not in goals.unmet))

	return rows


func set_time_limit_months(value: int) -> bool:
	if not is_valid() or value < 0 or value > 0xffff:
		return false

	var chunk := document.find_chunk("SCEN")

	if chunk == null or chunk.decoded_payload.size() != format_size:
		return false

	var data: PackedByteArray = chunk.decoded_payload.duplicate()
	BinaryData.write_u16_be(data, SCHEMA2_TIME_LIMIT if format_size == SCHEMA2_SIZE else 0x08, value)

	if not chunk.set_decoded_payload(data):
		return false

	time_limit_months = value

	return true


static func _signed_16(value: int) -> int:
	value &= 0xffff
	return value - 0x10000 if value & 0x8000 else value


static func _signed_32(value: int) -> int:
	value &= 0xffffffff
	return value - 0x100000000 if value & 0x80000000 else value






func _text_chunk(expected_header: int) -> String:
	for chunk in document.chunks:
		if chunk.chunk_id != "TEXT" or chunk.decoded_payload.size() < 4:
			continue

		if BinaryData.read_u32_be(chunk.decoded_payload, 0) != expected_header:
			continue

		var end := 4

		while end < chunk.decoded_payload.size() and chunk.decoded_payload[end] != 0:
			end += 1

		return chunk.decoded_payload.slice(4, end).get_string_from_ascii()

	return ""


class ProgressRow extends RefCounted:
	var label := ""
	var requirement := ""
	var current := ""
	var met := false

	static func create(label_text: String, requirement_text: String, current_text: String, is_met: bool) -> ProgressRow:
		var row := ProgressRow.new()
		row.label = label_text
		row.requirement = requirement_text
		row.current = current_text
		row.met = is_met

		return row


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
