class_name ScurkPrintControl
extends Window

signal preview_options_changed(options: Dictionary)
signal save_pdf_requested(options: Dictionary)

const PreviewView = preload("res://src/ui/scurk_print_preview.gd")
const ClassicStyle = preload("res://src/ui/classic_ui_style.gd")

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
	title = "Prints of the City"
	min_size = PANEL_SIZE
	exclusive = false
	close_requested.connect(hide)
	_build_interface()


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


func _build_interface() -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel_box := ClassicStyle.create_box(
		Color("c0c0c0"), Color("ffffff"), 1, 0, 0
	)
	panel.add_theme_stylebox_override("panel", panel_box)
	add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 8)
	margin.add_child(page)

	var heading := Label.new()
	heading.text = "Prints of the City"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 20)
	page.add_child(heading)

	var selectors := GridContainer.new()
	selectors.columns = 4
	selectors.add_theme_constant_override("h_separation", 8)
	selectors.add_theme_constant_override("v_separation", 6)
	page.add_child(selectors)
	magnification_selector = _add_selector(
		selectors, "Magnification", ["1x - Small", "2x - Medium", "4x - Large"]
	)
	view_selector = _add_selector(selectors, "View", ["Above Ground", "Below Ground"])
	color_selector = _add_selector(selectors, "Output", ["Color", "Black and White"])
	print_what_selector = _add_selector(
		selectors, "Print What", ["Entire City", "Selected Pages"]
	)
	magnification_selector.item_selected.connect(_on_magnification_changed)
	view_selector.item_selected.connect(_on_view_changed)
	color_selector.item_selected.connect(_on_preview_option_changed)
	print_what_selector.item_selected.connect(_on_print_what_changed)

	layers_row = HBoxContainer.new()
	layers_row.add_theme_constant_override("separation", 12)
	page.add_child(layers_row)
	var layers_label := Label.new()
	layers_label.text = "Layers"
	layers_label.custom_minimum_size = Vector2(78, 0)
	layers_row.add_child(layers_label)
	buildings_check = _add_layer_check(layers_row, "Buildings")
	infrastructure_check = _add_layer_check(layers_row, "Infrastructure")
	zones_check = _add_layer_check(layers_row, "Zones")
	signs_check = _add_layer_check(layers_row, "Signs")
	pipes_check = _add_layer_check(layers_row, "Pipes")
	for check in [
		buildings_check, infrastructure_check, zones_check, signs_check, pipes_check,
	]:
		check.toggled.connect(_on_preview_option_changed)

	preview = PreviewView.new()
	preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview.selection_changed.connect(_refresh_page_state)
	page.add_child(preview)

	status_label = Label.new()
	status_label.text = "Select the print options."
	status_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	page.add_child(status_label)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_END
	buttons.add_theme_constant_override("separation", 8)
	page.add_child(buttons)
	select_all_button = Button.new()
	select_all_button.text = "Select All"
	select_all_button.pressed.connect(preview.select_all.bind(true))
	buttons.add_child(select_all_button)
	clear_all_button = Button.new()
	clear_all_button.text = "Clear All"
	clear_all_button.pressed.connect(preview.select_all.bind(false))
	buttons.add_child(clear_all_button)
	save_pdf_button = Button.new()
	save_pdf_button.text = "Save Printable PDF..."
	save_pdf_button.pressed.connect(_request_pdf)
	buttons.add_child(save_pdf_button)
	var close_button := Button.new()
	close_button.text = "Close"
	close_button.pressed.connect(hide)
	buttons.add_child(close_button)


func _add_selector(parent: GridContainer, label_text: String, items: Array) -> OptionButton:
	var label := Label.new()
	label.text = label_text
	parent.add_child(label)
	var selector := OptionButton.new()
	selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for item in items:
		selector.add_item(String(item))
	parent.add_child(selector)
	return selector


func _add_layer_check(parent: HBoxContainer, label: String) -> CheckBox:
	var check := CheckBox.new()
	check.text = label
	check.button_pressed = true
	parent.add_child(check)
	return check


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
