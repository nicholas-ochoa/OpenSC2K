class_name IndustryWindowControl
extends Control

signal tax_rates_changed

class Snapshot extends RefCounted:
	var ok: bool = false
	var error: String = ""
	var ratios: PackedInt64Array
	var tax_rates: PackedInt32Array
	var demands: PackedInt32Array
	var industrial_tax: int


enum Mode {
	RATIOS,
	TAX_RATES,
	DEMAND,
}

const INDUSTRY_COUNT := Sc2IndustryLayout.COUNT
const INDUSTRY_STRIDE := Sc2IndustryLayout.RECORD_SIZE
const MISC_INDUSTRIES := Sc2MiscLayout.INDUSTRIES
const MISC_BUDGETS := Sc2MiscLayout.BUDGETS
const BUDGET_RECORD_SIZE := Sc2BudgetLayout.RECORD_SIZE
const BUDGET_INDUSTRIAL := Sc2BudgetLayout.INDUSTRIAL
const BUDGET_FUNDING := Sc2BudgetLayout.FUNDING
const INITIAL_MAXIMUMS := [70, 30, 100]
const INDUSTRY_NAMES: Array[String] = [
	"Steel/Mining", "Textiles", "Petrochemical", "Food", "Construction", "Automotive",
	"Aerospace", "Finance", "Media", "Electronics", "Tourism",
]

var city: CityState
var mode := Mode.RATIOS
var icon_strip: Texture2D
var dragging_tax := false


func _init() -> void:
	theme_changed.connect(queue_redraw)
	custom_minimum_size = Vector2(600, 340)
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# a UI scale change on the main window moves the screen pixel grid
	ready.connect(func() -> void: get_tree().root.size_changed.connect(queue_redraw))
	tooltip_text = "In Tax Rates view, drag a bar to set its surcharge. Hold Alt to set all industries."


func set_city(value: CityState) -> void:
	city = value
	queue_redraw()


func set_mode(value: int) -> void:
	if value < Mode.RATIOS or value > Mode.DEMAND:
		return

	mode = value
	dragging_tax = false
	queue_redraw()


func set_icon_strip(value: Image) -> void:
	icon_strip = null if value == null or value.is_empty() else ImageTexture.create_from_image(value)
	queue_redraw()


func refresh() -> void:
	queue_redraw()


static func snapshot(value_city: CityState) -> Snapshot:
	if value_city == null or not value_city.is_valid():
		var result := Snapshot.new()
		result.ok = false
		result.error = "city is invalid"

		return result

	var ratios := PackedInt64Array()
	var tax_rates := PackedInt32Array()
	var demands := PackedInt32Array()

	for industry in INDUSTRY_COUNT:
		var offset := MISC_INDUSTRIES + industry * INDUSTRY_STRIDE
		demands.append(_to_i16(value_city.document.misc_u32(offset)))
		tax_rates.append(_to_i16(value_city.document.misc_u32(offset + Sc2IndustryLayout.TAX_RATE)))
		ratios.append(value_city.document.misc_u32(offset + Sc2IndustryLayout.RATIO))

	var industrial_tax_offset := (
		MISC_BUDGETS + BUDGET_INDUSTRIAL * BUDGET_RECORD_SIZE + BUDGET_FUNDING
	)

	var result := Snapshot.new()
	result.ok = true
	result.ratios = ratios
	result.tax_rates = tax_rates
	result.demands = demands
	result.industrial_tax = value_city.document.misc_i32(industrial_tax_offset)
	result.error = ""

	return result


static func values_for_mode(data: Snapshot, selected_mode: int) -> Array[int]:
	var values: Array[int] = []

	if not data.ok:
		return values

	if selected_mode == Mode.RATIOS:
		values.assign(Array(data.ratios))
	elif selected_mode == Mode.TAX_RATES:
		values.assign(Array(data.tax_rates))
	else:
		values.assign(Array(data.demands))

	return values


static func maximum_for_mode(data: Snapshot, selected_mode: int) -> int:
	if selected_mode < Mode.RATIOS or selected_mode > Mode.DEMAND:
		return 1

	var maximum := int(INITIAL_MAXIMUMS[selected_mode])

	for value in values_for_mode(data, selected_mode):
		maximum = maxi(maximum, int(value))

	return maximum


func _gui_input(event: InputEvent) -> void:
	if mode != Mode.TAX_RATES or city == null or not city.is_valid():
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		dragging_tax = event.pressed

		if event.pressed:
			_apply_tax_pointer(event.position, event.alt_pressed)

		accept_event()


func _input(event: InputEvent) -> void:
	if not dragging_tax:
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if not event.pressed:
			dragging_tax = false
	elif event is InputEventMouseMotion:
		_apply_tax_pointer(get_local_mouse_position(), event.alt_pressed)


func _apply_tax_pointer(pointer: Vector2, apply_all: bool) -> void:
	var plot := _plot_rect()

	if not plot.has_point(pointer):
		return

	var row_height := plot.size.y / float(INDUSTRY_COUNT)
	var industry := clampi(int((pointer.y - plot.position.y) / row_height), 0, INDUSTRY_COUNT - 1)
	var data := snapshot(city)
	var maximum := maximum_for_mode(data, Mode.TAX_RATES)
	var value := int((pointer.x - plot.position.x) * maximum / plot.size.x)
	var result := IndustryTaxCommand.set_tax_rate(city, industry, value, apply_all)

	if result.ok and result.changed:
		queue_redraw()
		tax_rates_changed.emit()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), get_theme_color("canvas", "AppPalette"), true)
	var data := snapshot(city)

	if not data.ok:
		_draw_centered_message("No city is loaded.")

		return

	var plot := _plot_rect()
	# the icon strip keeps whole screen pixels for each artwork pixel
	var icon_width := ScreenPixels.whole_cells(48.0, icon_strip.get_width()) if icon_strip != null else 48.0
	var names_right := plot.position.x - icon_width - 8.0
	var icons := Rect2(names_right + 5.0, plot.position.y, icon_width, plot.size.y)
	var row_height := plot.size.y / float(INDUSTRY_COUNT)
	var font := get_theme_default_font()
	var font_size := 13

	draw_rect(plot, get_theme_color("paper", "AppPalette"), true)
	draw_rect(plot, get_theme_color("border", "AppPalette"), false, 1.0)

	for industry in INDUSTRY_COUNT:
		var center_y := plot.position.y + row_height * (float(industry) + 0.5)
		var label := INDUSTRY_NAMES[industry]
		var label_width := font.get_string_size(
			label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size
		).x
		draw_string(
			font,
			Vector2(names_right - label_width, center_y + 4),
			label,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			font_size,
			get_theme_color("ink", "AppPalette"),
		)
		draw_line(
			Vector2(names_right + 2, center_y),
			Vector2(plot.position.x, center_y),
			Color("808080"),
			1.0,
		)

	if icon_strip != null:
		draw_texture_rect(icon_strip, icons, false)

	var values := values_for_mode(data, mode)
	var maximum := maximum_for_mode(data, mode)

	for industry in INDUSTRY_COUNT:
		var value := maxi(0, int(values[industry]))
		var width := floorf(plot.size.x * float(value) / float(maximum))
		var row_top := plot.position.y + row_height * industry
		var bar := Rect2(
			plot.position.x,
			row_top + 2,
			width,
			maxf(1.0, row_height - 4),
		)

		if bar.size.x > 0:
			draw_rect(bar, get_theme_color("chart_accent", "AppPalette"), true)
			draw_rect(bar, Color("00007f"), false, 1.0)

		if mode == Mode.TAX_RATES:
			var text := "%d%%" % value
			var text_width := font.get_string_size(
				text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size
			).x
			draw_string(
				font,
				Vector2(plot.end.x - text_width - 4, row_top + row_height - 5),
				text,
				HORIZONTAL_ALIGNMENT_LEFT,
				-1,
				font_size,
				get_theme_color("ink", "AppPalette"),
			)

	if mode == Mode.TAX_RATES:
		var reference := clampf(
			float(data.industrial_tax) / float(maximum), 0.0, 1.0
		)
		var reference_x := plot.position.x + plot.size.x * reference
		draw_dashed_line(
			Vector2(reference_x, plot.position.y),
			Vector2(reference_x, plot.end.y),
			get_theme_color("ink", "AppPalette"),
			1.0,
			3.0,
		)


func _plot_rect() -> Rect2:
	var left := maxf(250.0, size.x * 0.48)
	var height := maxf(1.0, size.y - 16.0)

	# the rows share the icon strip height, on whole screen pixels for each
	# artwork pixel
	if icon_strip != null:
		height = ScreenPixels.whole_cells(height, icon_strip.get_height())

	return Rect2(left, 8.0, maxf(1.0, size.x - left - 12.0), height)


func _draw_centered_message(message: String) -> void:
	var font := get_theme_default_font()
	var font_size := 14
	var width := font.get_string_size(
		message, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size
	).x
	draw_string(
		font,
		Vector2((size.x - width) * 0.5, size.y * 0.5),
		message,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		font_size,
		get_theme_color("ink", "AppPalette"),
	)


static func _to_i16(value: int) -> int:
	var word := value & 0xffff

	return word - 0x10000 if word & 0x8000 else word
