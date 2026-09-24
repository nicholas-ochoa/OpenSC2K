class_name PopulationWindowControl
extends Control

@warning_ignore_start("integer_division")

class Cohort extends RefCounted:
	var age_start: int
	var population: int
	var education_points: int
	var life_points: int
	var education_quotient: int
	var life_expectancy: int


class Snapshot extends RefCounted:
	var ok: bool = false
	var error: String = ""
	var cohorts: Array[Cohort] = []
	var total_population: int
	var workforce_percent: int
	var workforce_life_expectancy: int
	var workforce_education_quotient: int


enum Mode {
	POPULATION,
	HEALTH,
	EDUCATION,
}

const COHORT_COUNT := 20
const COHORT_STRIDE := 0x0c
const MISC_POPULATION_TABLE := Sc2MiscLayout.POPULATION_TABLE
const MISC_NORMAL_POPULATION := Sc2MiscLayout.NORMAL_POPULATION
const CHART_MAXIMUM := 92

var city: CityState
var mode := Mode.POPULATION


func _init() -> void:
	theme_changed.connect(queue_redraw)
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


static func snapshot(value_city: CityState) -> Snapshot:
	if value_city == null or not value_city.is_valid():
		var result := Snapshot.new()
		result.ok = false
		result.error = "city is invalid"

		return result

	var cohorts: Array[Cohort] = []

	for cohort in COHORT_COUNT:
		var offset := MISC_POPULATION_TABLE + cohort * COHORT_STRIDE
		var population := value_city.document.misc_u32(offset)
		var education_points := value_city.document.misc_u32(offset + 4)
		var life_points := value_city.document.misc_u32(offset + 8)
		var entry := Cohort.new()
		entry.age_start = cohort * 5
		entry.population = population
		entry.education_points = education_points
		entry.life_points = life_points
		entry.education_quotient = (
			int(education_points / population) if population > 0 else 0
		)
		entry.life_expectancy = (
			int(life_points / population) if population > 0 else 0
		)
		cohorts.append(entry)

	var result := Snapshot.new()
	result.ok = true
	result.cohorts = cohorts
	result.total_population = value_city.document.misc_u32(MISC_NORMAL_POPULATION)
	result.workforce_percent = value_city.document.misc_u32(Sc2MiscLayout.WORKFORCE_PERCENT)
	result.workforce_life_expectancy = value_city.document.misc_u32(Sc2MiscLayout.WORKFORCE_LIFE_EXPECTANCY)
	result.workforce_education_quotient = value_city.document.misc_u32(Sc2MiscLayout.WORKFORCE_EDUCATION)
	result.error = ""

	return result


static func chart_values(data: Snapshot, selected_mode: int) -> PackedInt32Array:
	var result := PackedInt32Array()

	if not data.ok:
		return result

	var total := int(data.total_population)

	for cohort in data.cohorts:
		var population := int(cohort.population)
		var value := 0

		if selected_mode == Mode.POPULATION and total > 0:
			value = int((population * 600) / total)

			if population > 0 and value == 0:
				value = 1
		elif selected_mode == Mode.HEALTH and population > 0:
			value = int(cohort.life_points / population)
		elif selected_mode == Mode.EDUCATION and population > 0:
			value = int(cohort.education_points * 15 / (population * 25))

		result.append(value)

	return result


static func indicator_value(data: Snapshot, selected_mode: int) -> int:
	if not data.ok:
		return 0

	if selected_mode == Mode.POPULATION:
		return int(data.workforce_percent)

	if selected_mode == Mode.HEALTH:
		return int(data.workforce_life_expectancy)

	return (int(data.workforce_education_quotient) * 15) / 25


static func indicator_text(data: Snapshot, selected_mode: int) -> String:
	if selected_mode == Mode.POPULATION:
		return "Work Force %% = %d" % int(data.workforce_percent)

	if selected_mode == Mode.HEALTH:
		return "Work Force LE = %d" % int(data.workforce_life_expectancy)

	return "Work Force EQ = %d" % int(data.workforce_education_quotient)


static func y_axis_label(selected_mode: int, step: int) -> String:
	if selected_mode == Mode.POPULATION:
		return "%d%%" % int((step * 5) / 2) if step % 2 == 0 else ""

	if selected_mode == Mode.HEALTH:
		return "%d yrs" % (step * 15)

	return "%d eq" % (step * 25)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), get_theme_color("paper", "AppPalette"), true)
	draw_rect(Rect2(Vector2.ZERO, size), get_theme_color("border", "AppPalette"), false, 1.0)
	var data := snapshot(city)

	if not data.ok:
		_draw_centered_message("No city is loaded.")

		return

	var font := get_theme_default_font()
	var font_size := 12
	var plot := Rect2(58, 36, maxf(1.0, size.x - 78.0), maxf(1.0, size.y - 92.0))

	for step in 7:
		var y := plot.end.y - plot.size.y * float(step) / 6.0
		draw_line(Vector2(plot.position.x, y), Vector2(plot.end.x, y), get_theme_color("grid", "AppPalette"), 1.0)
		var label := y_axis_label(mode, step)

		if not label.is_empty():
			var label_width := font.get_string_size(
				label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size
			).x
			draw_string(
				font, Vector2(plot.position.x - label_width - 5, y + 4), label,
				HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, get_theme_color("ink", "AppPalette")
			)

	draw_line(plot.position, Vector2(plot.position.x, plot.end.y), get_theme_color("border", "AppPalette"), 1.0)
	draw_line(Vector2(plot.position.x, plot.end.y), plot.end, get_theme_color("border", "AppPalette"), 1.0)

	var values := chart_values(data, mode)
	var slot_width := plot.size.x / float(COHORT_COUNT)
	var bar_slot := 0

	for cohort in values.size():
		var bar_height := plot.size.y * clampf(
			float(values[cohort]) / float(CHART_MAXIMUM), 0.0, 1.0
		)

		if bar_height > 0.0:
			var bar := Rect2(
				plot.position.x + slot_width * bar_slot + 1,
				plot.end.y - maxf(1.0, bar_height),
				maxf(1.0, slot_width - 2),
				maxf(1.0, bar_height),
			)
			draw_rect(bar, get_theme_color("chart_accent", "AppPalette"), true)
			draw_rect(bar, get_theme_color("ink", "AppPalette"), false, 1.0)

		# The original advances the bar position only for nonzero values.
		if values[cohort] != 0:
			bar_slot += 1

		if cohort % 2 == 0:
			var age_label := str(cohort * 5)
			var x := plot.position.x + slot_width * (cohort + 0.5)
			var width := font.get_string_size(
				age_label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size
			).x
			draw_string(
				font, Vector2(x - width * 0.5, plot.end.y + 16), age_label,
				HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, get_theme_color("ink", "AppPalette")
			)

	# the original marks ages 20 through 55, not a value on the vertical axis
	var workforce_left := plot.position.x + slot_width * 4.0
	var workforce_right := plot.position.x + slot_width * 11.0
	var bracket_y := plot.position.y + 2.0
	var bracket_center := (workforce_left + workforce_right) * 0.5
	var workforce_color := get_theme_color("ink", "AppPalette")
	draw_polyline(PackedVector2Array([
		Vector2(workforce_left, plot.end.y), Vector2(workforce_left, bracket_y),
		Vector2(workforce_right, bracket_y), Vector2(workforce_right, plot.end.y),
	]), workforce_color, 1.0)
	draw_polyline(PackedVector2Array([
		Vector2(bracket_center, bracket_y), Vector2(bracket_center, plot.position.y - 16),
		Vector2(bracket_center + 6, plot.position.y - 16),
	]), workforce_color, 1.0)
	draw_string(
		font, Vector2(bracket_center + 12, plot.position.y - 12), indicator_text(data, mode),
		HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, workforce_color
	)
	var age_title := "Resident Age"
	var age_title_width := font.get_string_size(
		age_title, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size
	).x
	draw_string(
		font, Vector2(plot.get_center().x - age_title_width * 0.5, plot.end.y + 34), age_title,
		HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, get_theme_color("ink", "AppPalette")
	)


func _draw_centered_message(message: String) -> void:
	var font := get_theme_default_font()
	var font_size := 14
	var width := font.get_string_size(
		message, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size
	).x
	draw_string(
		font, Vector2((size.x - width) * 0.5, size.y * 0.5), message,
		HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, get_theme_color("ink", "AppPalette")
	)
