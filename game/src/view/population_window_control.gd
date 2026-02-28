class_name PopulationWindowControl
extends Control

enum Mode {
	POPULATION,
	HEALTH,
	EDUCATION,
}

const COHORT_COUNT := 20
const COHORT_STRIDE := 0x0c
const MISC_WORKFORCE_PERCENT := 0x0044
const MISC_WORKFORCE_LE := 0x0048
const MISC_WORKFORCE_EQ := 0x004c
const MISC_POPULATION_TABLE := 0x007c
const MISC_NORMAL_POPULATION := 0x102c
const CHART_MAXIMUM := 92

var city: CityState
var mode := Mode.POPULATION


func _init() -> void:
	custom_minimum_size = Vector2(600, 330)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_city(value: CityState) -> void:
	city = value
	queue_redraw()


func set_mode(value: int) -> void:
	if value < Mode.POPULATION or value > Mode.EDUCATION:
		return

	mode = value
	queue_redraw()


func refresh() -> void:
	queue_redraw()


static func snapshot(value_city: CityState) -> Dictionary:
	if value_city == null or not value_city.is_valid():
		return {"ok": false, "error": "city is invalid"}

	var cohorts: Array[Dictionary] = []

	for cohort in COHORT_COUNT:
		var offset := MISC_POPULATION_TABLE + cohort * COHORT_STRIDE
		var population := value_city.document.misc_u32(offset)
		var education_points := value_city.document.misc_u32(offset + 4)
		var life_points := value_city.document.misc_u32(offset + 8)
		cohorts.append({
			"age_start": cohort * 5,
			"population": population,
			"education_points": education_points,
			"life_points": life_points,
			"education_quotient": (
				int(education_points / population) if population > 0 else 0
			),
			"life_expectancy": (
				int(life_points / population) if population > 0 else 0
			),
		})

	return {
		"ok": true,
		"cohorts": cohorts,
		"total_population": value_city.document.misc_u32(MISC_NORMAL_POPULATION),
		"workforce_percent": value_city.document.misc_u32(MISC_WORKFORCE_PERCENT),
		"workforce_life_expectancy": value_city.document.misc_u32(MISC_WORKFORCE_LE),
		"workforce_education_quotient": value_city.document.misc_u32(MISC_WORKFORCE_EQ),
		"error": "",
	}


static func chart_values(data: Dictionary, selected_mode: int) -> PackedInt32Array:
	var result := PackedInt32Array()

	if not data.get("ok", false):
		return result

	var total := int(data.get("total_population", 0))

	for cohort in data.get("cohorts", []):
		var population := int(cohort.get("population", 0))
		var value := 0

		if selected_mode == Mode.POPULATION and total > 0:
			value = int(population * 600 / total)

			if population > 0 and value == 0:
				value = 1
		elif selected_mode == Mode.HEALTH and population > 0:
			value = int(cohort.get("life_points", 0) / population)
		elif selected_mode == Mode.EDUCATION and population > 0:
			value = int(cohort.get("education_points", 0) * 15 / (population * 25))

		result.append(value)

	return result


static func indicator_value(data: Dictionary, selected_mode: int) -> int:
	if not data.get("ok", false):
		return 0

	if selected_mode == Mode.POPULATION:
		return int(data.get("workforce_percent", 0))

	if selected_mode == Mode.HEALTH:
		return int(data.get("workforce_life_expectancy", 0))

	return int(data.get("workforce_education_quotient", 0)) * 15 / 25


static func indicator_text(data: Dictionary, selected_mode: int) -> String:
	if selected_mode == Mode.POPULATION:
		return "Workforce: %d%%" % int(data.get("workforce_percent", 0))

	if selected_mode == Mode.HEALTH:
		return "LE = %d yrs" % int(data.get("workforce_life_expectancy", 0))

	return "EQ = %d" % int(data.get("workforce_education_quotient", 0))


static func y_axis_label(selected_mode: int, step: int) -> String:
	if selected_mode == Mode.POPULATION:
		return "%d%%" % int(step * 5 / 2) if step % 2 == 0 else ""

	if selected_mode == Mode.HEALTH:
		return "%d yrs" % (step * 15)

	return "%d eq" % (step * 25)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("ffffff"), true)
	draw_rect(Rect2(Vector2.ZERO, size), Color("404040"), false, 1.0)
	var data := snapshot(city)

	if not data.ok:
		_draw_centered_message("No city is loaded.")

		return

	var font := get_theme_default_font()
	var font_size := 12
	var plot := Rect2(58, 18, maxf(1.0, size.x - 78.0), maxf(1.0, size.y - 62.0))

	for step in 7:
		var y := plot.end.y - plot.size.y * float(step) / 6.0
		draw_line(Vector2(plot.position.x, y), Vector2(plot.end.x, y), Color("dddddd"), 1.0)
		var label := y_axis_label(mode, step)

		if not label.is_empty():
			var label_width := font.get_string_size(
				label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size
			).x
			draw_string(
				font, Vector2(plot.position.x - label_width - 5, y + 4), label,
				HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color("202020")
			)

	draw_line(plot.position, Vector2(plot.position.x, plot.end.y), Color("404040"), 1.0)
	draw_line(Vector2(plot.position.x, plot.end.y), plot.end, Color("404040"), 1.0)

	var values := chart_values(data, mode)
	var slot_width := plot.size.x / float(COHORT_COUNT)

	for cohort in values.size():
		var bar_height := plot.size.y * clampf(
			float(values[cohort]) / float(CHART_MAXIMUM), 0.0, 1.0
		)

		if bar_height > 0.0:
			var bar := Rect2(
				plot.position.x + slot_width * cohort + 1,
				plot.end.y - maxf(1.0, bar_height),
				maxf(1.0, slot_width - 2),
				maxf(1.0, bar_height),
			)
			draw_rect(bar, Color("000080"), true)
			draw_rect(bar, Color("202020"), false, 1.0)

		if cohort % 2 == 0:
			var age_label := str(cohort * 5)
			var x := plot.position.x + slot_width * (cohort + 0.5)
			var width := font.get_string_size(
				age_label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size
			).x
			draw_string(
				font, Vector2(x - width * 0.5, plot.end.y + 16), age_label,
				HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color("202020")
			)

	var indicator := indicator_value(data, mode)
	var indicator_y := plot.end.y - plot.size.y * clampf(
		float(indicator) / float(CHART_MAXIMUM), 0.0, 1.0
	)
	draw_line(
		Vector2(plot.position.x, indicator_y), Vector2(plot.end.x, indicator_y),
		Color("c00000"), 2.0
	)
	var indicator_label := indicator_text(data, mode)
	var indicator_width := font.get_string_size(
		indicator_label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size
	).x
	draw_rect(
		Rect2(plot.end.x - indicator_width - 6, indicator_y - 13, indicator_width + 6, 15),
		Color("ffffff"), true
	)
	draw_string(
		font, Vector2(plot.end.x - indicator_width - 3, indicator_y - 1), indicator_label,
		HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color("800000")
	)


func _draw_centered_message(message: String) -> void:
	var font := get_theme_default_font()
	var font_size := 14
	var width := font.get_string_size(
		message, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size
	).x
	draw_string(
		font, Vector2((size.x - width) * 0.5, size.y * 0.5), message,
		HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color("202020")
	)
