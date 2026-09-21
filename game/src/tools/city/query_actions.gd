class_name QueryActions
extends RefCounted

@warning_ignore_start("integer_division")

const Tiles = preload("res://src/tools/shared/building_tile_ids.gd")

class RenameResult extends RefCounted:
	var ok := false
	var error := ""
	var overlay_id := 0
	var old_value := ""
	var new_value := ""

	static func failure(message: String) -> RenameResult:
		var result := RenameResult.new()
		result.error = message

		return result


class Category extends RefCounted:
	var id: int
	var name: String
	var acres: int
	var percent: int

	func _init(category_id: int, category_name: String, area: int, share: int) -> void:
		id = category_id
		name = category_name
		acres = area
		percent = share


class Analysis extends RefCounted:
	var ok := false
	var error := ""
	var header := ""
	var counts := PackedInt32Array()
	var total := 0
	var categories: Array[Category] = []

	static func failure(message: String) -> Analysis:
		var result := Analysis.new()
		result.error = message

		return result


const FIRST_BUILDING := Tiles.SMALL_PARK
const CATEGORY_COUNT := 12
const CATEGORY_RESOURCE_BASE := 988
const MISC_TILE_COUNTS := 0x01f0
const FIRST_MICROSIM_LABEL := 51
const LAST_MICROSIM_LABEL := 200

const TILE_UPPER_BOUNDS := [
	Tiles.POWER_LINE_FIRST,
	Tiles.FIRST_ROAD,
	Tiles.DEVELOPED_FIRST,
	Tiles.COMMERCIAL_1X1_FIRST,
	Tiles.INDUSTRIAL_1X1_FIRST,
	Tiles.CONSTRUCTION_1X1_FIRST,
	Tiles.RESIDENTIAL_2X2_FIRST,
	Tiles.COMMERCIAL_2X2_FIRST,
	Tiles.INDUSTRIAL_2X2_FIRST,
	Tiles.CONSTRUCTION_2X2_FIRST,
	Tiles.RESIDENTIAL_3X3_FIRST,
	Tiles.COMMERCIAL_3X3_FIRST,
	Tiles.INDUSTRIAL_3X3_FIRST,
	Tiles.CONSTRUCTION_3X3_FIRST,
	Tiles.HYDRO_POWER_ONE,
	Tiles.CITY_HALL,
	Tiles.MUSEUM,
	Tiles.BIG_PARK,
	Tiles.SCHOOL,
	Tiles.STADIUM,
	Tiles.PRISON,
	Tiles.COLLEGE,
	Tiles.ZOO,
	Tiles.WATER_PUMP,
	Tiles.RUNWAY,
	Tiles.SUBWAY_STATION,
	Tiles.WATER_TOWER,
	Tiles.BUS_DEPOT,
	Tiles.PARKING_LOT_ONE,
	Tiles.MAYOR_HOUSE,
	Tiles.WATER_TREATMENT,
	Tiles.LIBRARY,
	Tiles.HANGAR_TWO,
	Tiles.CHURCH,
	Tiles.MARINA,
	Tiles.MISSILE_SILO,
	Tiles.DESALINIZATION,
	Tiles.PLYMOUTH_ARCOLOGY,
	Tiles.LLAMA_DOME,
	Tiles.EMPTY,
]

const CATEGORY_BY_RANGE := [
	10,
	2,
	1,
	4,
	5,
	6,
	0,
	4,
	5,
	6,
	0,
	4,
	5,
	6,
	0,
	2,
	9,
	8,
	10,
	8,
	10,
	9,
	8,
	10,
	3,
	7,
	1,
	3,
	1,
	7,
	0,
	3,
	8,
	7,
	4,
	10,
	7,
	3,
	11,
	10,
]

const FALLBACK_CATEGORY_NAMES := [
	"",
	"Transportation",
	"Power",
	"Water",
	"Residential",
	"Commercial",
	"Industrial",
	"Ports and airports",
	"Education",
	"Health and safety",
	"Recreation",
	"Arcologies",
]


static func rename_facility(
	city: CityState, info: QueryResult, value: String
) -> RenameResult:
	if city == null or not city.is_valid():
		return RenameResult.failure("city is invalid")

	if info == null or info.kind != "specific":
		return RenameResult.failure("query does not select a facility")

	var overlay_id := int(info.overlay_id)
	var point: Vector2i = info.point

	if not OverlayData.is_facility(overlay_id):
		return RenameResult.failure("facility label is invalid")

	if city.text_overlay_id(point.x, point.y) != overlay_id:
		return RenameResult.failure("queried facility has changed")

	var old_value := city.label(overlay_id)

	if not city.set_label(overlay_id, value):
		return RenameResult.failure("cannot store facility name")

	var result := RenameResult.new()
	result.ok = true
	result.overlay_id = overlay_id
	result.old_value = old_value
	result.new_value = city.label(overlay_id)
	result.error = ""

	return result


static func city_analysis(
	city: CityState, resource_strings: Dictionary = {}
) -> Analysis:
	if city == null or not city.is_valid():
		return Analysis.failure("city is invalid")

	var misc_chunk := city.document.find_chunk("MISC")

	if (
		misc_chunk == null
		or misc_chunk.decoded_payload.size() < MISC_TILE_COUNTS + 0x100 * 4
	):
		return Analysis.failure("MISC tile counts are missing or invalid")

	var counts := PackedInt32Array()
	counts.resize(CATEGORY_COUNT)

	for building in range(FIRST_BUILDING, 0x100):
		var building_count := city.document.misc_i32(MISC_TILE_COUNTS + building * 4)

		for range_index in TILE_UPPER_BOUNDS.size():
			if building >= TILE_UPPER_BOUNDS[range_index]:
				continue

			counts[CATEGORY_BY_RANGE[range_index]] += building_count
			break

	var total := 0

	for category_id in range(1, CATEGORY_COUNT):
		total += counts[category_id]

	var categories: Array[Category] = []

	for category_id in range(1, CATEGORY_COUNT):
		var name: String = FALLBACK_CATEGORY_NAMES[category_id]
		var resource_id := CATEGORY_RESOURCE_BASE + category_id

		if resource_strings.has(resource_id):
			name = str(resource_strings[resource_id]).strip_edges()

		categories.append(Category.new(
			category_id, name, counts[category_id],
			int((counts[category_id] * 100) / total) if total != 0 else 0
		))

	var header := "Category                 Acres   Share"

	if resource_strings.has(CATEGORY_RESOURCE_BASE):
		header = str(resource_strings[CATEGORY_RESOURCE_BASE])

	var result := Analysis.new()
	result.ok = true
	result.header = header
	result.counts = counts
	result.total = total
	result.categories = categories
	result.error = ""

	return result


static func format_city_analysis(analysis: Analysis) -> String:
	if not analysis.ok:
		return "Analysis failed: %s" % analysis.error

	var lines := PackedStringArray([str(analysis.header)])

	for category in analysis.categories:
		lines.append(
			"%s\t%d\t%d%%"
			% [category.name, category.acres, category.percent]
		)

	return "\n".join(lines)
