class_name CityMenuBar
extends PanelContainer

signal file_menu_requested(id: int)
signal speed_menu_requested(id: int)
signal options_menu_requested(id: int)
signal view_menu_requested(id: int)
signal disaster_menu_requested(id: int)
signal windows_menu_requested(id: int)
signal newspaper_menu_requested(id: int)
signal help_menu_requested(id: int)

const MENU_AUTO_BUDGET := 0x8004
const MENU_AUTO_GOTO := 0x8005
const MENU_SOUND_EFFECTS := 0x8006
const MENU_MUSIC := 0x8007
const MENU_NO_DISASTERS := 0x800e
const MENU_VIEW_CITY_MAP := 0x8100
const MENU_VIEW_BUILDINGS := 0x8101
const MENU_VIEW_NETWORKS := 0x8102
const MENU_VIEW_WATER := 0x8103
const MENU_VIEW_TREES := 0x8104
const MENU_VIEW_ZONES := 0x8105
const MENU_VIEW_SIGNS := 0x8106
const MENU_VIEW_PIPES := 0x8107
const MENU_SCURK_PLACE_PRINT := 0x8200

var file_menu: MenuButton
var speed_menu: MenuButton
var options_menu: MenuButton
var view_menu: MenuButton
var disasters_menu: MenuButton
var city_label: Label
var population_label: Label
var date_label: Label
var money_label: Label
var fps_label: Label


func _ready() -> void:
	custom_minimum_size = Vector2(0, 25)
	add_theme_stylebox_override(
		"panel", _classic_box(Color("c0c0c0"), Color("ffffff"), 0)
	)
	var menu_row := HBoxContainer.new()
	menu_row.add_theme_constant_override("separation", 0)
	add_child(menu_row)

	file_menu = _add_menu(menu_row, "File", [
		["New City...", 0], ["Open City...", 1], ["Save City As...", 2],
		["Load Tile Set...", 3], ["Restore Original Tile Set", 4],
		["SCURK Place & Print...", MENU_SCURK_PLACE_PRINT],
		["Main Menu", 5], ["Exit", 6],
	], _on_file_menu)
	speed_menu = _add_menu(menu_row, "Speed", [
		["Pause", 0], ["Turtle", 1], ["Llama", 2], ["Cheetah", 3],
		["African Swallow", 4],
	], _on_speed_menu)
	for speed_id in range(5):
		var speed_index := speed_menu.get_popup().get_item_index(speed_id)
		speed_menu.get_popup().set_item_as_checkable(speed_index, true)

	options_menu = _add_menu(menu_row, "Options", [
		["Auto-Budget", MENU_AUTO_BUDGET], ["Auto-Goto", MENU_AUTO_GOTO],
		["Sound Effects", MENU_SOUND_EFFECTS], ["Music", MENU_MUSIC],
	], _on_options_menu)
	for option_id in [MENU_AUTO_BUDGET, MENU_AUTO_GOTO, MENU_SOUND_EFFECTS, MENU_MUSIC]:
		var option_index := options_menu.get_popup().get_item_index(option_id)
		options_menu.get_popup().set_item_as_checkable(option_index, true)
	options_menu.disabled = true

	view_menu = _add_menu(menu_row, "View", [
		["City View", 0], ["Underground View", 1],
		["City Map...", MENU_VIEW_CITY_MAP],
	], _on_view_menu)
	view_menu.get_popup().add_separator()
	for view_item in [
		["Show Buildings", MENU_VIEW_BUILDINGS],
		["Show Networks", MENU_VIEW_NETWORKS],
		["Show Water", MENU_VIEW_WATER],
		["Show Trees", MENU_VIEW_TREES],
		["Show Zones", MENU_VIEW_ZONES],
		["Show Signs", MENU_VIEW_SIGNS],
	]:
		view_menu.get_popup().add_check_item(view_item[0], view_item[1])

	disasters_menu = _add_menu(menu_row, "Disasters", [
		["Fire", 1], ["Flood", 2], ["Riot", 3], ["Toxic Spill", 4],
		["Air Crash", 5], ["Earthquake", 6], ["Tornado", 7], ["Monster", 8],
		["Meltdown", 9], ["Microwave", 10], ["Volcano", 11], ["Firestorm", 12],
		["Mass Riots", 13], ["Mass Floods", 14], ["Pollution", 15],
		["Hurricane", 16], ["Helicopter Crash", 17], ["Plane Crash", 18],
	], _on_disaster_menu)
	disasters_menu.get_popup().add_separator()
	disasters_menu.get_popup().add_check_item("No Disasters", MENU_NO_DISASTERS)
	var implemented_disasters := {
		1: true, 2: true, 3: true, 4: true, 5: true, 6: true,
		7: true, 8: true, 9: true, 10: true, 11: true, 12: true,
		13: true, 14: true, 15: true, 16: true, 17: true, 18: true,
	}
	for item_index in disasters_menu.get_popup().item_count:
		var disaster_id := disasters_menu.get_popup().get_item_id(item_index)
		if disaster_id > 0 and disaster_id != MENU_NO_DISASTERS:
			disasters_menu.get_popup().set_item_disabled(
				item_index, not implemented_disasters.has(disaster_id)
			)
	disasters_menu.tooltip_text = (
		"Air Crash and Helicopter Crash do nothing when selected, as in the original Windows game."
	)

	_add_menu(menu_row, "Windows", [
		["Budget", 0], ["Ordinances", 1], ["Population", 2],
		["City Industry", 3], ["Graphs", 4], ["Neighbors", 5],
		["City Map", 6],
	], _on_windows_menu)
	_add_menu(
		menu_row,
		"Newspaper",
		[["Show Latest Reports", 0]],
		_on_newspaper_menu,
	)
	_add_menu(menu_row, "Help", [["City Window Help", 0]], _on_help_menu)

	var menu_spacer := Control.new()
	menu_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	menu_row.add_child(menu_spacer)
	menu_row.add_child(VSeparator.new())

	var city_field := MarginContainer.new()
	city_field.name = "CityNameField"
	city_field.custom_minimum_size = Vector2(174, 0)
	city_field.add_theme_constant_override("margin_left", 9)
	city_field.add_theme_constant_override("margin_right", 4)
	menu_row.add_child(city_field)
	city_label = Label.new()
	city_label.text = "No city loaded"
	city_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	city_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	city_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	city_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	city_label.tooltip_text = city_label.text
	city_field.add_child(city_label)
	menu_row.add_child(VSeparator.new())

	population_label = _metric_label("Population: --", 148)
	population_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	menu_row.add_child(population_label)
	menu_row.add_child(VSeparator.new())

	date_label = Label.new()
	date_label.text = "--/--/----"
	date_label.custom_minimum_size = Vector2(92, 0)
	date_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	date_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	date_label.tooltip_text = "Current city date"
	menu_row.add_child(date_label)
	menu_row.add_child(VSeparator.new())

	money_label = Label.new()
	money_label.text = "$--"
	money_label.custom_minimum_size = Vector2(92, 0)
	money_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	money_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	money_label.tooltip_text = "Current city funds"
	menu_row.add_child(money_label)
	menu_row.add_child(VSeparator.new())

	fps_label = Label.new()
	fps_label.text = "FPS: --"
	fps_label.custom_minimum_size = Vector2(72, 0)
	fps_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fps_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	fps_label.tooltip_text = "Current rendered frames per second"
	menu_row.add_child(fps_label)


func _add_menu(
	parent: Control, label: String, items: Array, callback: Callable
) -> MenuButton:
	var menu := MenuButton.new()
	menu.text = label
	menu.flat = true
	menu.custom_minimum_size = Vector2(0, 23)
	parent.add_child(menu)
	for item in items:
		menu.get_popup().add_item(item[0], item[1])
	menu.get_popup().id_pressed.connect(callback)
	return menu


func _metric_label(text_value: String, minimum_width: int) -> Label:
	var label := Label.new()
	label.text = text_value
	label.custom_minimum_size = Vector2(minimum_width, 20)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	return label


func _classic_box(color: Color, border: Color, width: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.border_color = border
	box.set_border_width_all(width)
	box.content_margin_left = 5
	box.content_margin_top = 3
	box.content_margin_right = 5
	box.content_margin_bottom = 3
	return box


func _on_file_menu(id: int) -> void:
	file_menu_requested.emit(id)


func _on_speed_menu(id: int) -> void:
	speed_menu_requested.emit(id)


func _on_options_menu(id: int) -> void:
	options_menu_requested.emit(id)


func _on_view_menu(id: int) -> void:
	view_menu_requested.emit(id)


func _on_disaster_menu(id: int) -> void:
	disaster_menu_requested.emit(id)


func _on_windows_menu(id: int) -> void:
	windows_menu_requested.emit(id)


func _on_newspaper_menu(id: int) -> void:
	newspaper_menu_requested.emit(id)


func _on_help_menu(id: int) -> void:
	help_menu_requested.emit(id)
