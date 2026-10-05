class_name QueryActions
extends RefCounted
## Query dialog actions: facility names and the City Hall analysis.


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

	if city.facility_overlay_id(point.x, point.y) != overlay_id:
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


# the land use of the city from the MISC tile counts. See
# native/core/sim/src/sim/tools/query/actions.rs
static func city_analysis(city: CityState) -> Analysis:
	if city == null or not city.is_valid():
		return Analysis.failure("city is invalid")

	var fields: Dictionary = NativeSimulationBridge.run("query.analysis", city, null, null, null).result

	if not fields.ok:
		return Analysis.failure(fields.error)

	var names: PackedStringArray = fields.names
	var counts: PackedInt32Array = fields.counts
	var percents: PackedInt32Array = fields.percents
	var categories: Array[Category] = []

	for category_id in range(1, counts.size()):
		categories.append(Category.new(category_id, names[category_id], counts[category_id], percents[category_id]))

	var result := Analysis.new()
	result.ok = true
	result.header = fields.header
	result.counts = counts
	result.total = fields.total
	result.categories = categories

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
