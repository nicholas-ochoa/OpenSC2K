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
signal debug_menu_requested(id: int)

const ShortcutMenu = preload("res://src/ui/scurk/scurk_context_menu.gd")
const MENU_SETTINGS := 0x8302
const MENU_SCENARIO_GOALS := 8
const MENU_SAVE_CITY := 7
const MENU_EXPORT_CITY_PNG := 8
const MENU_RENAME_CITY := 9
const MENU_UPGRADE_SC2X := 0x8303
const MENU_CHECK_FOR_UPDATES := 0x8304
const MENU_OPEN_AUTOSAVES := 0x8305
const MENU_CONSOLE := 0x8306
const MENU_ABOUT := 0
const MENU_AUTO_BUDGET := 0x8004
const MENU_AUTO_GOTO := 0x8005
const MENU_SOUND_EFFECTS := 0x8006
const MENU_MUSIC := 0x8007
const MENU_NO_DISASTERS := 0x800e
const MENU_NEWSPAPER_SUBSCRIPTION := 0x8017
const MENU_NEWSPAPER_EXTRAS := 0x8018
const MENU_VIEW_CITY_MAP := 0x8100
const MENU_VIEW_BUILDINGS := 0x8101
const MENU_VIEW_NETWORKS := 0x8102
const MENU_VIEW_WATER := 0x8103
const MENU_VIEW_TREES := 0x8104
const MENU_VIEW_ZONES := 0x8105
const MENU_VIEW_SIGNS := 0x8106
const MENU_VIEW_PIPES := 0x8107
const MENU_VIEW_WATER_MAINS := 0x8108
const MENU_VIEW_VEHICLES := 0x8109
const MENU_VIEW_DATA_SEPARATOR := 0x810a
const MENU_VIEW_SUBWAYS := 0x810b
const MENU_VIEW_TUNNELS := 0x810c
const MENU_SCURK_PLACE_PRINT := 0x8200
# the name of each disaster type. the debug tools list all of them
const DISASTER_ITEMS := [
	["Fire", 1], ["Flood", 2], ["Riot", 3], ["Toxic Spill", 4],
	["Air Crash", 5], ["Earthquake", 6], ["Tornado", 7], ["Monster", 8],
	["Meltdown", 9], ["Microwave", 10], ["Volcano", 11], ["Firestorm", 12],
	["Mass Riots", 13], ["Mass Floods", 14], ["Pollution", 15],
	["Hurricane", 16], ["Helicopter Crash", 17], ["Plane Crash", 18],
]
# the Disasters menu of SIMCITY.EXE. Air Crash starts the falling plane of
# type 18
const DISASTERS_MENU_ITEMS := [
	["Fire", 1], ["Flood", 2], ["Air Crash", 18], ["Tornado", 7], ["Earthquake", 6], ["Monster", 8],
	["Hurricane", 16], ["Rioters", 3],
]
# the disasters of the hidden SIMCITY.EXE Debug menu, and the pollution
# disaster that only the simulation starts there. they follow a separator
const DEBUG_DISASTER_ITEMS := [
	["Melt Down", 9], ["Microwave", 10], ["Volcano", 11], ["Fire Storm", 12], ["Mass Riots", 13],
	["Major Flood", 14], ["Toxic Spill", 4], ["Pollution", 15],
]

# the menu item that each bindable action selects: [menu, item id]
const ACTION_ITEMS: Dictionary[String, Array] = {
	"file_new": ["file", 0], "file_open": ["file", 1], "file_save": ["file", MENU_SAVE_CITY],
	"file_save_as": ["file", 2], "file_rename": ["file", MENU_RENAME_CITY],
	"file_export_png": ["file", MENU_EXPORT_CITY_PNG], "file_main_menu": ["file", 5],
	"speed_pause": ["speed", 0], "speed_turtle": ["speed", 1], "speed_llama": ["speed", 2],
	"speed_cheetah": ["speed", 3], "speed_african_swallow": ["speed", 4],
	"option_auto_budget": ["options", MENU_AUTO_BUDGET], "option_auto_goto": ["options", MENU_AUTO_GOTO],
	"option_sound_effects": ["options", MENU_SOUND_EFFECTS], "option_music": ["options", MENU_MUSIC],
	"settings": ["options", MENU_SETTINGS],
	"view_show_buildings": ["view", MENU_VIEW_BUILDINGS], "view_show_networks": ["view", MENU_VIEW_NETWORKS],
	"view_show_water": ["view", MENU_VIEW_WATER], "view_show_trees": ["view", MENU_VIEW_TREES],
	"view_show_zones": ["view", MENU_VIEW_ZONES], "view_show_signs": ["view", MENU_VIEW_SIGNS],
	"view_show_pipes": ["view", MENU_VIEW_PIPES], "view_show_water_mains": ["view", MENU_VIEW_WATER_MAINS],
	"view_show_vehicles": ["view", MENU_VIEW_VEHICLES], "view_show_subways": ["view", MENU_VIEW_SUBWAYS],
	"view_show_tunnels": ["view", MENU_VIEW_TUNNELS],
	"window_budget": ["windows", 0], "window_ordinances": ["windows", 1], "window_population": ["windows", 2],
	"window_industry": ["windows", 3], "window_graphs": ["windows", 4], "window_neighbors": ["windows", 5],
	"window_map": ["windows", 6], "window_debug": ["windows", 7], "window_scenario_goals": ["windows", MENU_SCENARIO_GOALS],
	"window_console": ["windows", MENU_CONSOLE],
}

var bindings := ControlBindings.defaults()
var file_menu: MenuButton
var speed_menu: MenuButton
var options_menu: MenuButton
var view_menu: MenuButton
var disasters_menu: MenuButton
var newspaper_menu: MenuButton
var windows_menu: MenuButton
# shown only in debug mode
var debug_menu: MenuButton
var city_label: Label
var population_label: Label
var date_label: Label
var money_label: Label
var fps_label: Label


func _ready() -> void:
	custom_minimum_size = Vector2(0, 31)
	theme_type_variation = "CityMenuBarPanel"
	var menu_row := HBoxContainer.new()
	menu_row.add_theme_constant_override("separation", 0)
	add_child(menu_row)

	file_menu = _add_menu(menu_row, "File", [
		["New City", 0], ["Open City", 1],
		["", -1], ["Save City", MENU_SAVE_CITY], ["Save City As", 2],
		["", -1], ["Rename City", MENU_RENAME_CITY],
		["", -1], ["Export City as PNG", MENU_EXPORT_CITY_PNG], ["Open Autosave Folder", MENU_OPEN_AUTOSAVES],
		["", -1], ["Load Tile Set", 3], ["Restore Original Tile Set", 4],
		["", -1], ["SCURK Place & Print", MENU_SCURK_PLACE_PRINT],
		["", -1], ["Main Menu", 5], ["Exit", 6],
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

	options_menu.get_popup().add_separator()
	options_menu.get_popup().add_item("Settings", MENU_SETTINGS)
	options_menu.disabled = true

	var view_items: Array = []
	var data_view_items: Array = []

	# Keep mode IDs stable when sorting the data views.
	for index in CityViewMode.DISPLAY_MODES.size():
		var mode: CityViewMode.Mode = CityViewMode.DISPLAY_MODES[index]
		var data_index := CityViewMode.DATA_MODES.find(mode)
		var label: String = CityDataView.TITLES[data_index] if data_index >= 0 else (
			"City View" if mode == CityViewMode.Mode.CITY else "Underground View")
		if data_index >= 0:
			data_view_items.append([label, index])
		else:
			view_items.append([label, index])

	# the zones view is the city view with zoned buildings drawn as zones
	data_view_items.append(["Zones", MENU_VIEW_ZONES])

	view_menu = _add_menu(menu_row, "View", view_items, _on_view_menu)
	view_menu.get_popup().add_separator("", MENU_VIEW_DATA_SEPARATOR)
	data_view_items.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	for item in data_view_items:
		view_menu.get_popup().add_item(item[0], item[1])

	for view_id in range(CityViewMode.DISPLAY_MODES.size()) + [MENU_VIEW_ZONES]:
		var item_index := view_menu.get_popup().get_item_index(view_id)
		view_menu.get_popup().set_item_as_radio_checkable(item_index, true)

	view_menu.get_popup().add_separator()

	for view_item in [
		["Show Buildings", MENU_VIEW_BUILDINGS],
		["Show Networks", MENU_VIEW_NETWORKS],
		["Show Water", MENU_VIEW_WATER],
		["Show Trees", MENU_VIEW_TREES],
		["Show Signs", MENU_VIEW_SIGNS],
		["Show Vehicles", MENU_VIEW_VEHICLES],
	]:
		view_menu.get_popup().add_check_item(view_item[0], view_item[1])

	disasters_menu = _add_menu(
		menu_row, "Disasters", DISASTERS_MENU_ITEMS, _on_disaster_menu
	)
	disasters_menu.get_popup().add_separator()

	for item in DEBUG_DISASTER_ITEMS:
		disasters_menu.get_popup().add_item(item[0], item[1])

	disasters_menu.get_popup().add_separator()
	disasters_menu.get_popup().add_check_item("No Disasters", MENU_NO_DISASTERS)

	windows_menu = _add_menu(menu_row, "Windows", [], _on_windows_menu)
	set_scenario_available(false)
	newspaper_menu = _add_menu(
		menu_row,
		"Newspaper",
		[],
		_on_newspaper_menu,
	)
	newspaper_menu.disabled = true
	debug_menu = _add_menu(menu_row, "Debug", [], _on_debug_menu)
	CityDebugMenu.populate(debug_menu.get_popup(), _on_debug_menu)
	debug_menu.visible = DebugMode.enabled
	_add_menu(menu_row, "Help", [["Check for updates", MENU_CHECK_FOR_UPDATES], ["", -1], ["About", MENU_ABOUT]], _on_help_menu)
	refresh_shortcut_hints(bindings)

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

	population_label = _metric_label("Population: --", 210)
	population_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_add_padded_metric(menu_row, population_label, "PopulationField")
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
	money_label.custom_minimum_size = Vector2(115, 0)
	money_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	money_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	money_label.tooltip_text = "Current city funds"
	_add_padded_metric(menu_row, money_label, "MoneyField")
	menu_row.add_child(VSeparator.new())

	fps_label = Label.new()
	fps_label.text = "FPS: --"
	fps_label.custom_minimum_size = Vector2(72, 0)
	fps_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fps_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	fps_label.tooltip_text = "Current rendered frames per second"
	menu_row.add_child(fps_label)


func _add_padded_metric(parent: Control, label: Label, field_name: String) -> void:
	var field := MarginContainer.new()
	field.name = field_name
	field.add_theme_constant_override("margin_right", 10)
	parent.add_child(field)
	field.add_child(label)


func _add_menu(
	parent: Control, label: String, items: Array, callback: Callable
) -> MenuButton:
	var menu := MenuButton.new()
	menu.text = label
	menu.flat = true
	menu.switch_on_hover = true
	menu.custom_minimum_size = Vector2(0, 23)
	parent.add_child(menu)

	for item in items:
		if str(item[0]).is_empty():
			menu.get_popup().add_separator()
		else:
			menu.get_popup().add_item(item[0], item[1])

	menu.get_popup().set_script(ShortcutMenu)
	(menu.get_popup() as ScurkContextMenu).bind()
	menu.get_popup().id_pressed.connect(callback)

	return menu


func _menu(menu_name: String) -> MenuButton:
	match menu_name:
		"file":
			return file_menu
		"speed":
			return speed_menu
		"options":
			return options_menu
		"view":
			return view_menu
		"windows":
			return windows_menu

	return null


# show the first key of each action beside its menu item
func refresh_shortcut_hints(value: ControlBindings) -> void:
	bindings = value

	for menu: MenuButton in [file_menu, speed_menu, options_menu, view_menu, windows_menu]:
		if menu == null:
			continue

		var popup := menu.get_popup() as ScurkContextMenu
		popup.hints.clear()
		popup.shortcuts.clear()
		popup.shortcut_handler = handle_shortcut

	for action in ACTION_ITEMS:
		var menu := _menu(ACTION_ITEMS[action][0])
		var binding := bindings.first_key(action)

		if menu == null or binding == null:
			continue

		var popup := menu.get_popup() as ScurkContextMenu
		var index := popup.get_item_index(ACTION_ITEMS[action][1])

		if index >= 0:
			popup.hints[index] = binding.display_text()


func has_action(action: String) -> bool:
	return ACTION_ITEMS.has(action)


# Select the menu item of an action, the same as a click. Returns false when
# the menu or the item is not available.
func trigger(action: String) -> bool:
	if not ACTION_ITEMS.has(action):
		return false

	var menu := _menu(ACTION_ITEMS[action][0])

	if menu == null or menu.disabled or not is_visible_in_tree():
		return false

	var popup := menu.get_popup()
	var index := popup.get_item_index(ACTION_ITEMS[action][1])

	if index < 0 or popup.is_item_disabled(index):
		return false

	popup.id_pressed.emit(ACTION_ITEMS[action][1])

	return true


func handle_shortcut(event: InputEventKey) -> bool:
	if not event.pressed or event.echo:
		return false

	var action := bindings.action_for(event, [ControlActions.KIND_PRESS])

	return has_action(action) and trigger(action)


func set_scenario_available(available: bool) -> void:
	var popup := windows_menu.get_popup() as ScurkContextMenu
	popup.reset_hints()
	popup.clear()

	for item in [
		["Budget", 0], ["Ordinances", 1], ["Population", 2],
		["Industry", 3], ["Graphs", 4], ["Neighbors", 5], ["Map", 6],
	]:
		popup.add_item(item[0], item[1])

	if available:
		popup.add_item("Show Scenario Goals", MENU_SCENARIO_GOALS)

	popup.add_separator()
	popup.add_item("Console", MENU_CONSOLE)
	popup.add_item("Debug", 7)
	refresh_shortcut_hints(bindings)


func _metric_label(text_value: String, minimum_width: int) -> Label:
	var label := Label.new()
	label.text = text_value
	label.custom_minimum_size = Vector2(minimum_width, 20)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS

	return label


# `tooltip` can add facts such as the file format. empty shows the name
func set_city_name(display_name: String, tooltip := "") -> void:
	city_label.text = display_name
	city_label.tooltip_text = tooltip if not tooltip.is_empty() else display_name


# the original menu shows the two newspaper options above the available papers,
# and marks the paper that the player opened last
func set_newspapers(titles: PackedStringArray, subscribed := false, extras := false, selected := -1) -> void:
	var popup := newspaper_menu.get_popup()
	popup.clear()
	newspaper_menu.disabled = titles.is_empty()

	if titles.is_empty():
		return

	popup.add_check_item("Subscription", MENU_NEWSPAPER_SUBSCRIPTION)
	popup.set_item_checked(popup.get_item_index(MENU_NEWSPAPER_SUBSCRIPTION), subscribed)
	popup.add_check_item("Extra!!!", MENU_NEWSPAPER_EXTRAS)
	popup.set_item_checked(popup.get_item_index(MENU_NEWSPAPER_EXTRAS), extras)
	popup.add_separator()

	for index in titles.size():
		popup.add_radio_check_item(titles[index], index)
		popup.set_item_checked(popup.get_item_index(index), index == selected)


func set_population(display_value: String, available := true) -> void:
	population_label.text = tr("Population: %s") % display_value
	population_label.set_meta(
		"status_tooltip_text",
		(
			tr("Current city population: %s") % display_value
			if available
			else "Current city population is not available."
		),
	)
	_sync_overflow_tooltip(population_label)


func set_date(display_date: String) -> void:
	date_label.text = display_date
	date_label.tooltip_text = tr("Current city date: %s") % display_date


func set_money(display_money: String) -> void:
	money_label.text = display_money
	money_label.tooltip_text = tr("Current city funds: %s") % display_money


func set_fps(frames_per_second: int) -> void:
	fps_label.text = tr("FPS: %d") % frames_per_second


static func disaster_name(disaster_id: int) -> String:
	for item in DISASTER_ITEMS:
		if int(item[1]) == disaster_id:
			return str(item[0])

	return "None" if disaster_id == 0 else "Disaster"


func refresh_population_tooltip() -> void:
	_sync_overflow_tooltip(population_label)


func _sync_overflow_tooltip(label: Label) -> void:
	var font := label.get_theme_font("font")
	var font_size := label.get_theme_font_size("font_size")
	var text_width := font.get_string_size(
		label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size
	).x
	label.tooltip_text = (
		str(label.get_meta("status_tooltip_text", label.text))
		if text_width > maxf(0.0, label.size.x - 4.0)
		else ""
	)


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


func _on_debug_menu(id: int) -> void:
	debug_menu_requested.emit(id)
