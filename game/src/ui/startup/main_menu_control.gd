class_name MainMenuControl
extends ColorRect

const ClassicStyle = preload("res://src/ui/shared/classic_ui_style.gd")

signal import_assets_requested
signal continue_requested
signal new_city_requested
signal open_city_requested
signal scenario_requested
signal settings_requested
signal scurk_requested
signal scurk_place_requested
signal about_requested
signal exit_requested

const BUTTON_LABELS := [
	"Continue City",
	"Start New City",
	"Open City...",
	"Play Scenario...",
	"SCURK Paint the Town",
	"SCURK Place & Print",
	"Settings...",
	"About OpenSC2K...",
	"Exit",
]

var assets_ready := true
var game_buttons: Array[Button] = []
var import_button: Button
var import_border: StyleBoxFlat
var flash_time := 0.0
var city_background: MainMenuCityBackground
var continue_button: Button
var new_city_button: Button
var scurk_place_button: Button


func _ready() -> void:
	AppUiTheme.bind_canvas(self, "map_canvas")
	theme = ClassicStyle.create_theme()
	AppUiTheme.bind_frosted_panel($Center/Panel, $GlassBackgroundCopy)

	city_background = $CityBackground
	var content: VBoxContainer = $Center/Panel/Content
	import_button = content.get_node("ImportAssets")
	_refresh_import_style()
	theme_changed.connect(_refresh_import_style)
	import_button.pressed.connect(import_assets_requested.emit)

	for index in BUTTON_LABELS.size():
		var button_name: String = BUTTON_LABELS[index].trim_suffix("...").replace(" ", "")
		var button: Button = content.get_node(button_name)
		button.pressed.connect(_emit_action.bind(index))

		if index < 6:
			game_buttons.append(button)

		if index == 0:
			continue_button = button
		elif index == 1:
			new_city_button = button
		elif index == 5:
			scurk_place_button = button


func show_menu(can_continue: bool) -> void:
	if continue_button != null:
		continue_button.visible = can_continue

	if scurk_place_button != null:
		scurk_place_button.disabled = not can_continue or not assets_ready

	# let the panel shrink when continue city is hidden
	var panel := new_city_button.get_parent().get_parent() as PanelContainer
	panel.reset_size()
	show()

	if not assets_ready:
		import_button.grab_focus()
	elif can_continue and continue_button != null:
		continue_button.grab_focus()
	elif new_city_button != null:
		new_city_button.grab_focus()


func _emit_action(index: int) -> void:
	if index < 6 and not assets_ready:
		return

	match index:
		0:
			continue_requested.emit()
		1:
			new_city_requested.emit()
		2:
			open_city_requested.emit()
		3:
			scenario_requested.emit()
		4:
			scurk_requested.emit()
		5:
			scurk_place_requested.emit()
		6:
			settings_requested.emit()
		7:
			about_requested.emit()
		8:
			exit_requested.emit()


func set_assets_ready(value: bool) -> void:
	assets_ready = value

	for button in game_buttons:
		button.disabled = not value

	import_button.visible = not value
	set_process(not value)


func _process(delta: float) -> void:
	if assets_ready or import_border == null:
		return

	flash_time += delta
	import_border.border_color = Color("ffb000") if fmod(flash_time, 1.2) < 0.6 else Color("805800")


func _refresh_import_style() -> void:
	if import_button == null:
		return
	import_border = AppUiTheme.current().get_stylebox("normal", "Button").duplicate() as StyleBoxFlat
	import_button.add_theme_stylebox_override("normal", import_border)
