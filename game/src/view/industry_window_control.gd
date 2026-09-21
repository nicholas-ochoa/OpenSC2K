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


class TaxResult extends RefCounted:
	var ok: bool = false
	var error: String = ""
	var changed: bool = false
	var value: int


enum Mode {
	RATIOS,
	TAX_RATES,
	DEMAND,
}

const INDUSTRY_COUNT := 11
const INDUSTRY_STRIDE := 0x0c
const MISC_INDUSTRIES := 0x016c
const MISC_BUDGETS := 0x077c
const BUDGET_RECORD_SIZE := 0x006c
const BUDGET_INDUSTRIAL := 2
const BUDGET_FUNDING := 0x04
const INITIAL_MAXIMUMS := [70, 30, 100]
const MAXIMUM_INDUSTRY_TAX := 20
const DEFAULT_NAMES := [
	"Steel/Mining",
	"Textiles",
	"Petrochemicals",
	"Food",
	"Construction",
	"Automotive",
	"Aerospace",
	"Finance",
	"Media",
	"Electronics",
	"Tourism",
]

const INDUSTRY_STRINGS: Dictionary[int, String] = {
	422: "Steel/Mining",
	423: "Textiles",
	424: "Petrochemical",
	425: "Food",
	426: "Construction",
	427: "Automotive",
	428: "Aerospace",
	429: "Finance",
	430: "Media",
	431: "Electronics",
	432: "Tourism",
}

var city: CityState
var mode := Mode.RATIOS
var industry_names := PackedStringArray(DEFAULT_NAMES)
var icon_strip: Texture2D
var dragging_tax := false


func _init() -> void:
	theme_changed.connect(queue_redraw)
	custom_minimum_size = Vector2(600, 340)
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
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


func set_industry_names(value: PackedStringArray) -> void:
	if value.size() != INDUSTRY_COUNT:
		return

	industry_names = value.duplicate()
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
		tax_rates.append(_to_i16(value_city.document.misc_u32(offset + 4)))
		ratios.append(value_city.document.misc_u32(offset + 8))

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


static func set_tax_rate(
	value_city: CityState, industry: int, value: int, all_industries := false
) -> TaxResult:
	if value_city == null or not value_city.is_valid():
		var result := TaxResult.new()
		result.ok = false
		result.changed = false
		result.error = "city is invalid"

		return result

	if industry < 0 or industry >= INDUSTRY_COUNT:
		var result := TaxResult.new()
		result.ok = false
		result.changed = false
		result.error = "industry is outside the valid range"

		return result

	var misc_chunk := value_city.document.find_chunk("MISC")

	if misc_chunk == null or misc_chunk.decoded_payload.size() < MISC_INDUSTRIES + INDUSTRY_COUNT * INDUSTRY_STRIDE:
		var result := TaxResult.new()
		result.ok = false
		result.changed = false
		result.error = "MISC is missing or too short"

		return result

	var tax_rate := clampi(value, 0, MAXIMUM_INDUSTRY_TAX)
	var data: PackedByteArray = misc_chunk.decoded_payload.duplicate()
	var changed := false

	for current in INDUSTRY_COUNT:
		if not all_industries and current != industry:
			continue

		var offset := MISC_INDUSTRIES + current * INDUSTRY_STRIDE + 4

		if _read_i32_be(data, offset) == tax_rate:
			continue

		_write_i32_be(data, offset, tax_rate)
		changed = true

	if changed and not misc_chunk.set_decoded_payload(data):
		var result := TaxResult.new()
		result.ok = false
		result.changed = false
		result.error = "cannot store industry tax rates"

		return result

	var result := TaxResult.new()
	result.ok = true
	result.changed = changed
	result.value = tax_rate
	result.error = ""

	return result


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
	var result := set_tax_rate(city, industry, value, apply_all)

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
	var content := Rect2(8, 8, size.x - 16, size.y - 16)
	var icon_width := 48.0
	var names_right := plot.position.x - icon_width - 8.0
	var icons := Rect2(names_right + 5.0, content.position.y, icon_width, content.size.y)
	var row_height := plot.size.y / float(INDUSTRY_COUNT)
	var font := get_theme_default_font()
	var font_size := 13

	draw_rect(plot, get_theme_color("paper", "AppPalette"), true)
	draw_rect(plot, get_theme_color("border", "AppPalette"), false, 1.0)

	for industry in INDUSTRY_COUNT:
		var center_y := plot.position.y + row_height * (float(industry) + 0.5)
		var label := industry_names[industry]
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

	return Rect2(left, 8.0, maxf(1.0, size.x - left - 12.0), maxf(1.0, size.y - 16.0))


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


static func _read_i32_be(data: PackedByteArray, offset: int) -> int:
	var value := (
		(data[offset] << 24)
		| (data[offset + 1] << 16)
		| (data[offset + 2] << 8)
		| data[offset + 3]
	)

	return value - 0x100000000 if value & 0x80000000 else value


static func _write_i32_be(data: PackedByteArray, offset: int, value: int) -> void:
	var encoded := value & 0xffffffff
	data[offset] = (encoded >> 24) & 0xff
	data[offset + 1] = (encoded >> 16) & 0xff
	data[offset + 2] = (encoded >> 8) & 0xff
	data[offset + 3] = encoded & 0xff
