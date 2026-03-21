class_name ScurkPrintControl
extends Window

signal preview_options_changed(options: Dictionary)
signal save_pdf_requested(options: Dictionary)

const PreviewView = preload("res://src/ui/scurk/scurk_print_preview.gd")
const ClassicStyle = preload("res://src/ui/shared/classic_ui_style.gd")

const PANEL_SIZE := Vector2i(760, 680)
const MAGNIFICATIONS := [1, 2, 4]

var city_name := "City"
var magnification_selector: OptionButton
var view_selector: OptionButton
var color_selector: OptionButton
var print_what_selector: OptionButton
var layers_row: HBoxContainer
var buildings_check: CheckBox
var infrastructure_check: CheckBox
var zones_check: CheckBox
var signs_check: CheckBox
var pipes_check: CheckBox
var preview: ScurkPrintPreview
var status_label: Label
var select_all_button: Button
var clear_all_button: Button
var save_pdf_button: Button


func _ready() -> void:
	magnification_selector = get_node("Panel/Margin/Content/GridContainer1/OptionButton1")
	view_selector = get_node("Panel/Margin/Content/GridContainer1/OptionButton2")
	color_selector = get_node("Panel/Margin/Content/GridContainer1/OptionButton3")
	print_what_selector = get_node("Panel/Margin/Content/GridContainer1/OptionButton4")
	layers_row = get_node("Panel/Margin/Content/HBoxContainer1")
	buildings_check = get_node("Panel/Margin/Content/HBoxContainer1/CheckBox1")
	infrastructure_check = get_node("Panel/Margin/Content/HBoxContainer1/CheckBox2")
	zones_check = get_node("Panel/Margin/Content/HBoxContainer1/CheckBox3")
	signs_check = get_node("Panel/Margin/Content/HBoxContainer1/CheckBox4")
	pipes_check = get_node("Panel/Margin/Content/HBoxContainer1/CheckBox5")
	preview = get_node("Panel/Margin/Content/Control1")
	status_label = get_node("Panel/Margin/Content/Label2")
	select_all_button = get_node("Panel/Margin/Content/HBoxContainer2/Button1")
	clear_all_button = get_node("Panel/Margin/Content/HBoxContainer2/Button2")
	save_pdf_button = get_node("Panel/Margin/Content/HBoxContainer2/Button3")
	self.close_requested.connect(hide)
	get_node("Panel/Margin/Content/GridContainer1/OptionButton1").item_selected.connect(_on_magnification_changed)
	get_node("Panel/Margin/Content/GridContainer1/OptionButton2").item_selected.connect(_on_view_changed)
	get_node("Panel/Margin/Content/GridContainer1/OptionButton3").item_selected.connect(_on_preview_option_changed)
	get_node("Panel/Margin/Content/GridContainer1/OptionButton4").item_selected.connect(_on_print_what_changed)
	get_node("Panel/Margin/Content/HBoxContainer1/CheckBox1").toggled.connect(_on_preview_option_changed)
	get_node("Panel/Margin/Content/HBoxContainer1/CheckBox2").toggled.connect(_on_preview_option_changed)
	get_node("Panel/Margin/Content/HBoxContainer1/CheckBox3").toggled.connect(_on_preview_option_changed)
	get_node("Panel/Margin/Content/HBoxContainer1/CheckBox4").toggled.connect(_on_preview_option_changed)
	get_node("Panel/Margin/Content/HBoxContainer1/CheckBox5").toggled.connect(_on_preview_option_changed)
	get_node("Panel/Margin/Content/Control1").selection_changed.connect(_refresh_page_state)
	get_node("Panel/Margin/Content/HBoxContainer2/Button1").pressed.connect(get_node("Panel/Margin/Content/Control1").select_all.bind(true))
	get_node("Panel/Margin/Content/HBoxContainer2/Button2").pressed.connect(get_node("Panel/Margin/Content/Control1").select_all.bind(false))
	get_node("Panel/Margin/Content/HBoxContainer2/Button3").pressed.connect(_request_pdf)
	get_node("Panel/Margin/Content/HBoxContainer2/Button4").pressed.connect(hide)


func configure(
	value_city_name: String,
	view := "city",
	surface_visibility: Dictionary = {},
	show_pipes := true
) -> void:
	city_name = value_city_name if not value_city_name.is_empty() else "City"
	view_selector.select(1 if view == "underground" else 0)
	buildings_check.button_pressed = bool(surface_visibility.get("buildings", true))
	infrastructure_check.button_pressed = bool(surface_visibility.get("networks", true))
	zones_check.button_pressed = bool(surface_visibility.get("zones", true))
	signs_check.button_pressed = bool(surface_visibility.get("signs", true))
	pipes_check.button_pressed = show_pipes
	_sync_view_controls()
	_refresh_page_state()


func show_workspace() -> void:
	popup_centered(PANEL_SIZE)
	request_preview()


func options() -> Dictionary:
	var visibility := {
		"buildings": buildings_check.button_pressed,
		"networks": infrastructure_check.button_pressed,
		"water": true,
		"trees": true,
		"zones": zones_check.button_pressed,
		"signs": signs_check.button_pressed,
	}

	return {
		"magnification": MAGNIFICATIONS[magnification_selector.selected],
		"view": "underground" if view_selector.selected == 1 else "city",
		"color": color_selector.selected == 0,
		"entire_city": print_what_selector.selected == 0,
		"selected_pages": preview.selected_pages.duplicate(),
		"surface_visibility": visibility,
		"show_pipes": pipes_check.button_pressed,
	}


func set_preview_image(image: Image) -> void:
	preview.set_preview_image(image)
	set_status(
		"%s preview. %d of %d pages will be written."
		% [city_name, preview.selected_page_count(), preview.selected_pages.size()]
	)


func set_status(message: String) -> void:
	if status_label != null:
		status_label.text = message
		status_label.tooltip_text = message


func request_preview() -> void:
	set_status("Preparing the city preview...")
	preview_options_changed.emit(options())


func _on_magnification_changed(_index: int) -> void:
	preview.set_magnification(MAGNIFICATIONS[magnification_selector.selected])
	_refresh_page_state()


func _on_view_changed(_index: int) -> void:
	_sync_view_controls()
	request_preview()


func _on_print_what_changed(index: int) -> void:
	preview.set_entire_city(index == 0)
	_refresh_page_state()


func _on_preview_option_changed(_value = null) -> void:
	request_preview()


func _sync_view_controls() -> void:
	var underground := view_selector.selected == 1
	buildings_check.visible = not underground
	infrastructure_check.visible = not underground
	zones_check.visible = not underground
	signs_check.visible = not underground
	pipes_check.visible = underground


func _refresh_page_state() -> void:
	var selected_mode := print_what_selector.selected == 1
	select_all_button.disabled = not selected_mode
	clear_all_button.disabled = not selected_mode
	var selected_count := preview.selected_page_count()
	save_pdf_button.disabled = selected_count == 0
	set_status(
		"%d of %d pages will be written."
		% [selected_count, preview.selected_pages.size()]
	)


func _request_pdf() -> void:
	if preview.selected_page_count() <= 0:
		set_status("Select at least one page.")

		return

	save_pdf_requested.emit(options())
