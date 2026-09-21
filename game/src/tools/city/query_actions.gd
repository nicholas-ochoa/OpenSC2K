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
const CATEGORY_UNCOUNTED := 0
const CATEGORY_TRANSPORTATION := 1
const CATEGORY_POWER := 2
const CATEGORY_WATER := 3
const CATEGORY_RESIDENTIAL := 4
const CATEGORY_COMMERCIAL := 5
const CATEGORY_INDUSTRIAL := 6
const CATEGORY_PORTS := 7
const CATEGORY_EDUCATION := 8
const CATEGORY_HEALTH := 9
const CATEGORY_RECREATION := 10
const CATEGORY_ARCOLOGIES := 11
const MISC_TILE_COUNTS := 0x01f0
const FIRST_MICROSIM_LABEL := 51
const LAST_MICROSIM_LABEL := 200

# a building belongs to the first row whose tile bound is above its id
const CATEGORY_BY_TILE_BOUND := [
	[Tiles.POWER_LINE_FIRST, CATEGORY_RECREATION],
	[Tiles.FIRST_ROAD, CATEGORY_POWER],
	[Tiles.DEVELOPED_FIRST, CATEGORY_TRANSPORTATION],
	[Tiles.COMMERCIAL_1X1_FIRST, CATEGORY_RESIDENTIAL],
	[Tiles.INDUSTRIAL_1X1_FIRST, CATEGORY_COMMERCIAL],
	[Tiles.CONSTRUCTION_1X1_FIRST, CATEGORY_INDUSTRIAL],
	[Tiles.RESIDENTIAL_2X2_FIRST, CATEGORY_UNCOUNTED],
	[Tiles.COMMERCIAL_2X2_FIRST, CATEGORY_RESIDENTIAL],
	[Tiles.INDUSTRIAL_2X2_FIRST, CATEGORY_COMMERCIAL],
	[Tiles.CONSTRUCTION_2X2_FIRST, CATEGORY_INDUSTRIAL],
	[Tiles.RESIDENTIAL_3X3_FIRST, CATEGORY_UNCOUNTED],
	[Tiles.COMMERCIAL_3X3_FIRST, CATEGORY_RESIDENTIAL],
	[Tiles.INDUSTRIAL_3X3_FIRST, CATEGORY_COMMERCIAL],
	[Tiles.CONSTRUCTION_3X3_FIRST, CATEGORY_INDUSTRIAL],
	[Tiles.HYDRO_POWER_1, CATEGORY_UNCOUNTED],
	[Tiles.CITY_HALL, CATEGORY_POWER],
	[Tiles.MUSEUM, CATEGORY_HEALTH],
	[Tiles.BIG_PARK, CATEGORY_EDUCATION],
	[Tiles.SCHOOL, CATEGORY_RECREATION],
	[Tiles.STADIUM, CATEGORY_EDUCATION],
	[Tiles.PRISON, CATEGORY_RECREATION],
	[Tiles.COLLEGE, CATEGORY_HEALTH],
	[Tiles.ZOO, CATEGORY_EDUCATION],
	[Tiles.WATER_PUMP, CATEGORY_RECREATION],
	[Tiles.RUNWAY, CATEGORY_WATER],
	[Tiles.SUBWAY_STATION, CATEGORY_PORTS],
	[Tiles.WATER_TOWER, CATEGORY_TRANSPORTATION],
	[Tiles.BUS_DEPOT, CATEGORY_WATER],
	[Tiles.PARKING_LOT_1, CATEGORY_TRANSPORTATION],
	[Tiles.MAYOR_HOUSE, CATEGORY_PORTS],
	[Tiles.WATER_TREATMENT, CATEGORY_UNCOUNTED],
	[Tiles.LIBRARY, CATEGORY_WATER],
	[Tiles.HANGAR_2, CATEGORY_EDUCATION],
	[Tiles.CHURCH, CATEGORY_PORTS],
	[Tiles.MARINA, CATEGORY_RESIDENTIAL],
	[Tiles.MISSILE_SILO, CATEGORY_RECREATION],
	[Tiles.DESALINIZATION, CATEGORY_PORTS],
	[Tiles.PLYMOUTH_ARCOLOGY, CATEGORY_WATER],
	[Tiles.LLAMA_DOME, CATEGORY_ARCOLOGIES],
	[Tiles.EMPTY, CATEGORY_RECREATION],
]

const ANALYSIS_HEADER := "LAND USE\t\tACRES\t% of CITY"
const CATEGORY_NAMES: Array[String] = [
	"", "Transportation", "Power", "Water", "Residential", "Commercial", "Industrial",
	"Ports/Airports", "Education", "Health/Safety", "Recreation", "Arcologies",
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


static func city_analysis(city: CityState) -> Analysis:
	if city == null or not city.is_valid():
		return Analysis.failure("city is invalid")

	var misc_chunk := city.document.find_chunk("MISC")

	if (
		misc_chunk == null
		or misc_chunk.decoded_payload.size() < MISC_TILE_COUNTS + Tiles.COUNT * 4
	):
		return Analysis.failure("MISC tile counts are missing or invalid")

	var counts := PackedInt32Array()
	counts.resize(CATEGORY_COUNT)

	for building in range(FIRST_BUILDING, Tiles.COUNT):
		var building_count := city.document.misc_i32(MISC_TILE_COUNTS + building * 4)

		for bound_row: Array in CATEGORY_BY_TILE_BOUND:
			if building >= int(bound_row[0]):
				continue

			counts[int(bound_row[1])] += building_count
			break

	var total := 0

	for category_id in range(1, CATEGORY_COUNT):
		total += counts[category_id]

	var categories: Array[Category] = []

	for category_id in range(1, CATEGORY_COUNT):
		categories.append(Category.new(
			category_id, CATEGORY_NAMES[category_id], counts[category_id],
			int((counts[category_id] * 100) / total) if total != 0 else 0
		))

	var result := Analysis.new()
	result.ok = true
	result.header = ANALYSIS_HEADER
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
