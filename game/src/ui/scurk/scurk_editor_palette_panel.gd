class_name ScurkEditorPalettePanel
extends PanelContainer

signal palette_index_selected(index: int, background: bool)
signal palette_index_hovered(index: int)
signal shade_ramp_changed(indices: PackedInt32Array)
signal navigation_changed(state: Dictionary)
signal texture_selected(index: int)

var palette: Sc2Palette
var palette_control: ScurkPaletteControl
var foreground_color: ColorRect
var foreground_color_label: Label
var background_color: ColorRect
var background_color_label: Label
var texture_control: ScurkTextureControl
var cycle_colors_check: CheckBox
var increment_cycle_button: Button
var palette_view: OptionButton
var ramp_clear_button: Button


func _ready() -> void:
	build()


func build() -> void:
	if palette_control != null:
		return

	palette_control = $Margin/Column/Colors
	texture_control = $Margin/Column/Textures
	foreground_color = $Margin/Column/Foreground/Swatch
	foreground_color_label = $Margin/Column/Foreground/Label
	background_color = $Margin/Column/Background/Swatch
	background_color_label = $Margin/Column/Background/Label
	cycle_colors_check = $Margin/Column/Cycle/Enabled
	increment_cycle_button = $Margin/Column/Cycle/Step
	palette_view = $Margin/Column/ColorsHeader/View
	ramp_clear_button = $Margin/Column/ColorsHeader/ClearRamp
	palette_control.index_selected.connect(palette_index_selected.emit)
	palette_control.index_hovered.connect(palette_index_hovered.emit)
	palette_control.ramp_changed.connect(shade_ramp_changed.emit)
	palette_control.navigation_changed.connect(navigation_changed.emit)
	palette_view.item_selected.connect(palette_control.set_view_mode)
	ramp_clear_button.pressed.connect(palette_control.clear_ramp)
	texture_control.texture_selected.connect(texture_selected.emit)
	for title in ["All colors", "Used colors", "Recent colors", "Favorites", "Shade ramp"]:
		palette_view.add_item(title)


func set_cycle_tick(tick: int) -> void:
	palette_control.set_cycle_tick(tick)
	texture_control.set_cycle_tick(tick)
	if palette == null or not palette.is_valid():
		return

	var indices := palette.scurk_animation_index_map(tick)
	foreground_color.color = palette.color(indices[palette_control.foreground_index])
	background_color.color = palette.color(indices[palette_control.background_index])


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
	set_cycle_tick(palette_control.palette_cycle_ticks)


func set_selected_texture(index: int) -> void:
	texture_control.set_selected(index)


func selected_texture_index() -> int:
	return texture_control.selected_index


func set_used_pixels(pixels: PackedInt32Array) -> void:
	palette_control.set_used_pixels(pixels)


func remember_index(index: int) -> void:
	palette_control.remember_index(index)


func export_state() -> Dictionary:
	return palette_control.export_state()


func import_state(state: Dictionary) -> void:
	palette_control.import_state(state)
