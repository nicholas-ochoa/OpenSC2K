class_name ScurkEditorPalettePanel
extends PanelContainer

signal palette_index_selected(index: int)
signal palette_index_hovered(index: int)
signal shade_ramp_changed(indices: PackedInt32Array)
signal navigation_changed(state: Dictionary)
signal texture_selected(index: int)

enum ColorAction { SELECT, FAVORITE, RAMP, CLEAR_RAMP }

var context_color_index := -1
var palette: Sc2Palette
var palette_control: ScurkPaletteControl
var selected_color: ColorRect
var selected_color_label: Label
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
	selected_color = $Margin/Column/SelectedColor/Swatch
	selected_color_label = $Margin/Column/SelectedColor/Label
	cycle_colors_check = $Margin/Column/Cycle/Enabled
	increment_cycle_button = $Margin/Column/Cycle/Step
	palette_view = $Margin/Column/ColorsHeader/View
	ramp_clear_button = $Margin/Column/ColorsHeader/ClearRamp
	palette_control.context_menu_requested.connect(_show_color_menu)
	$ColorMenu.id_pressed.connect(_color_menu_action)
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
	selected_color.color = palette.color(indices[palette_control.selected_color_index])


func configure(
	value_palette: Sc2Palette,
	patterns: Array[PackedInt32Array],
	selected_color_index: int,
	pattern_names := PackedStringArray(),
) -> void:
	set_palette(value_palette)
	texture_control.set_patterns(patterns)
	texture_control.pattern_names = pattern_names.duplicate()
	set_selected_color(selected_color_index)


func set_palette(value: Sc2Palette) -> void:
	palette = value
	palette_control.set_palette(palette)
	texture_control.set_palette(palette)
	set_selected_color(palette_control.selected_color_index)


func set_patterns(patterns: Array[PackedInt32Array]) -> void:
	texture_control.set_patterns(patterns)


func set_selected_color(index: int) -> void:
	index = clampi(index, 0, 255)
	palette_control.set_selected_color(index)
	texture_control.set_selected_color(index)
	selected_color.color = palette.color(index) if palette != null and palette.is_valid() else Color.MAGENTA
	selected_color_label.text = "Selected color: %d (0x%02X)" % [index, index]
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


func _show_color_menu(index: int, position: Vector2) -> void:
	context_color_index = index
	var menu := $ColorMenu as PopupMenu
	menu.clear()
	menu.add_item("Select color %d" % index, ColorAction.SELECT)
	menu.add_separator()
	menu.add_check_item("Favorite (Ctrl/Cmd-click)", ColorAction.FAVORITE)
	menu.set_item_checked(menu.get_item_index(ColorAction.FAVORITE), palette_control.favorite_indices.has(index))
	menu.add_check_item("Shade ramp step (Shift-click)", ColorAction.RAMP)
	menu.set_item_checked(menu.get_item_index(ColorAction.RAMP), palette_control.ramp_indices.has(index))
	menu.add_item("Clear shade ramp", ColorAction.CLEAR_RAMP)
	menu.set_item_disabled(menu.get_item_index(ColorAction.CLEAR_RAMP), palette_control.ramp_indices.is_empty())
	var transform := palette_control.get_global_transform_with_canvas() if menu.is_embedded() else palette_control.get_screen_transform()
	menu.position = Vector2i(transform * position)
	menu.popup()


func _color_menu_action(action: int) -> void:
	if context_color_index < 0 or context_color_index > 255:
		return
	match action:
		ColorAction.SELECT:
			set_selected_color(context_color_index)
			palette_control.remember_index(context_color_index)
			palette_index_selected.emit(context_color_index)
		ColorAction.FAVORITE:
			palette_control.toggle_favorite(context_color_index)
		ColorAction.RAMP:
			palette_control.toggle_ramp_index(context_color_index)
		ColorAction.CLEAR_RAMP:
			palette_control.clear_ramp()
