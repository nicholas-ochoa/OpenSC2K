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
	name = "MainMenu"
	color = Color("102832")
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	city_background = MainMenuCityBackground.new()
	add_child(city_background)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(460, 0)
	var box := ClassicStyle.create_box(
		Color("c0c0c0"), Color("ffffff"), 2, 44, 34
	)
	box.shadow_color = Color(0.0, 0.0, 0.0, 0.55)
	box.shadow_size = 12
	panel.add_theme_stylebox_override("panel", box)
	center.add_child(panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	panel.add_child(column)
	var title := Label.new()
	title.text = "OpenSC2K"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color("000080"))
	title.add_theme_font_size_override("font_size", 42)
	column.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "An open-source SimCity 2000 remake"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_color_override("font_color", Color("303030"))
	subtitle.add_theme_font_size_override("font_size", 16)
	column.add_child(subtitle)
	column.add_child(HSeparator.new())

	import_button = Button.new()
	import_button.text = "Import Assets..."
	import_button.custom_minimum_size.y = 42
	import_button.pressed.connect(func() -> void:
		import_assets_requested.emit())
	import_border = ClassicStyle.create_box(Color("c0c0c0"), Color("ffb000"), 4, 8, 8)
	import_button.add_theme_stylebox_override("normal", import_border)
	import_button.add_theme_stylebox_override("focus", import_border)
	column.add_child(import_button)
	import_button.hide()

	for index in BUTTON_LABELS.size():
		var button := Button.new()
		button.name = BUTTON_LABELS[index].trim_suffix("...").replace(" ", "")
		button.text = BUTTON_LABELS[index]
		button.custom_minimum_size = Vector2(0, 42)
		button.add_theme_font_size_override("font_size", 16)
		button.pressed.connect(_emit_action.bind(index))
		column.add_child(button)

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
