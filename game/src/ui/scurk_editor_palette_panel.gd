class_name ScurkEditorPalettePanel
extends VBoxContainer

signal palette_index_selected(index: int, background: bool)
signal texture_selected(index: int)
signal eraser_requested

const PaletteControl = preload("res://src/view/scurk_palette_control.gd")
const TextureControl = preload("res://src/view/scurk_texture_control.gd")

var palette: Sc2Palette
var palette_control: ScurkPaletteControl
var foreground_color: ColorRect
var foreground_color_label: Label
var background_color: ColorRect
var background_color_label: Label
var texture_control: ScurkTextureControl
var pointer_status_label: Label


func _ready() -> void:
	build()


func build() -> void:
	if palette_control != null:
		return
	custom_minimum_size = Vector2(300, 0)
	add_theme_constant_override("separation", 6)

	var heading := Label.new()
	heading.text = "256-Color Palette"
	heading.add_theme_color_override("font_color", Color("000080"))
	add_child(heading)

	palette_control = PaletteControl.new()
	palette_control.name = "Palette"
	palette_control.index_selected.connect(palette_index_selected.emit)
	add_child(palette_control)

	var foreground_row := HBoxContainer.new()
	foreground_row.add_theme_constant_override("separation", 8)
	add_child(foreground_row)
	foreground_color = ColorRect.new()
	foreground_color.custom_minimum_size = Vector2(38, 26)
	foreground_row.add_child(foreground_color)
	foreground_color_label = Label.new()
	foreground_row.add_child(foreground_color_label)

	var background_row := HBoxContainer.new()
	background_row.add_theme_constant_override("separation", 8)
	add_child(background_row)
	background_color = ColorRect.new()
	background_color.custom_minimum_size = Vector2(38, 26)
	background_row.add_child(background_color)
	background_color_label = Label.new()
	background_row.add_child(background_color_label)

	var texture_label := Label.new()
	texture_label.text = "Brush Texture"
	add_child(texture_label)
	var texture_scroll := ScrollContainer.new()
	texture_scroll.custom_minimum_size = Vector2(80, 160)
	texture_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	texture_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	add_child(texture_scroll)
	texture_control = TextureControl.new()
	texture_control.name = "TexturePalette"
	texture_control.texture_selected.connect(texture_selected.emit)
	texture_scroll.add_child(texture_control)

	var transparent_button := Button.new()
	transparent_button.text = "Transparent Eraser"
	transparent_button.tooltip_text = (
		"Erase pixels to transparent with the selected brush size."
	)
	transparent_button.pressed.connect(eraser_requested.emit)
	add_child(transparent_button)

	var help := Label.new()
	help.text = (
		"Left mouse uses the foreground color or texture. Right mouse uses the "
		+ "background color. Edit Large, Medium, and Small separately."
	)
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help.add_theme_color_override("font_color", Color("404040"))
	add_child(help)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(spacer)
	pointer_status_label = Label.new()
	pointer_status_label.text = "Pointer: --"
	add_child(pointer_status_label)


func configure(
	value_palette: Sc2Palette,
	patterns: Array[PackedInt32Array],
	foreground_index: int,
	background_index: int,
	pattern_names := PackedStringArray(),
) -> void:
	palette = value_palette
	palette_control.set_palette(palette)
	texture_control.set_palette(palette)
	texture_control.set_patterns(patterns)
	texture_control.pattern_names = pattern_names.duplicate()
	set_colors(foreground_index, background_index)


func set_patterns(patterns: Array[PackedInt32Array]) -> void:
	texture_control.set_patterns(patterns)


func set_colors(foreground_index: int, background_index: int) -> void:
	var foreground := clampi(foreground_index, 0, 255)
	var background := clampi(background_index, 0, 255)
	palette_control.set_selected_indices(foreground, background)
	texture_control.set_colors(foreground, background)
	foreground_color.color = (
		palette.color(foreground)
		if palette != null and palette.is_valid()
		else Color.MAGENTA
	)
	foreground_color_label.text = "Foreground: %d (0x%02X)" % [
		foreground, foreground,
	]
	background_color.color = (
		palette.color(background)
		if palette != null and palette.is_valid()
		else Color.MAGENTA
	)
	background_color_label.text = "Background: %d (0x%02X)" % [
		background, background,
	]


func set_selected_texture(index: int) -> void:
	texture_control.set_selected(index)


func selected_texture_index() -> int:
	return texture_control.selected_index


func set_pointer(point: Vector2i, index: int) -> void:
	pointer_status_label.text = (
		"Pointer: --"
		if point.x < 0
		else "Pointer: %d, %d — %s" % [
			point.x,
			point.y,
			"transparent" if index < 0 else "index %d" % index,
		]
	)
