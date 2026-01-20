class_name OrdinanceWindowControl
extends VBoxContainer

signal ordinances_changed
signal update_failed(message: String)
signal close_requested

const Ordinances = preload("res://src/simulation/ordinance_command.gd")

# describes the implemented simulation, not real-world policy effects
const EFFECTS := [
  "Raises revenue. Adds one point to the commercial tax rate used by demand, which reduces commercial demand.",
  "Raises revenue. Adds one point to the residential tax rate used by demand, which reduces residential demand.",
  "Raises revenue. Adds 16 to the local crime calculation before smoothing.",
  "Raises revenue. No additional traffic or demand effect is implemented.",
  "Costs money. Adds fire coverage around developed residential, commercial and industrial tiles.",
  "Costs money. Adds five years to the newborn life-expectancy input.",
  "Costs money. Adds health capacity based on the residential budget base.",
  "Costs money. No additional health or education effect is implemented.",
  "Costs money. Prevents the education loss applied when population moves between age groups.",
  "Costs money. Adds five years to the newborn life-expectancy input.",
  "Costs money. Adds five years to the newborn life-expectancy input.",
  "Costs money. Adds police coverage around developed residential, commercial and industrial tiles, reducing crime.",
  "Costs money. Reduces the effective commercial tax rate by one point, increasing commercial demand.",
  "Costs money. Reduces the effective industrial tax rate by one point, increasing industrial demand.",
  "Costs money. Reduces the effective residential tax rate by one point, increasing residential demand.",
  "Costs money. Reduces the effective commercial tax rate by one point, increasing commercial demand.",
  "Costs money. Adds one twelfth to available power-grid capacity, allowing more consumers to be supplied.",
  "Costs money. Prevents new nuclear power plants from being selected.",
  "Costs money. Reduces the effective commercial tax rate by one point, increasing commercial demand.",
  "Costs money. Reduces pollution and demand from polluting industries. Adds one point to the effective industrial tax rate, reducing industrial demand."
]

const LEFT_CATEGORIES := [0, 2, 4]
const RIGHT_CATEGORIES := [1, 3]

var city: CityState
var ordinance_checks: Array[CheckBox] = []
var ordinance_amounts: Array[LineEdit] = []
var category_amounts: Array[LineEdit] = []
var year_to_date_amount: LineEdit
var estimated_amount: LineEdit
var refreshing := false


func _ready() -> void:
	name = "OrdinanceWindowControl"
	add_theme_constant_override("separation", 8)
	for ordinance_id in Ordinances.ORDINANCE_COUNT:
		ordinance_checks.append(null)
		ordinance_amounts.append(null)
	for category in Ordinances.CATEGORY_NAMES.size():
		category_amounts.append(null)

	var columns := HBoxContainer.new()
	columns.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 12)
	add_child(columns)

	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 8)
	columns.add_child(left)
	for category in LEFT_CATEGORIES:
		_add_group(left, category)

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 8)
	columns.add_child(right)
	for category in RIGHT_CATEGORIES:
		_add_group(right, category)
	_add_summary(right)

	var totals := GridContainer.new()
	totals.columns = 4
	totals.add_theme_constant_override("h_separation", 8)
	add_child(totals)
	var ytd_caption := Label.new()
	ytd_caption.text = "YTD Total $"
	ytd_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	ytd_caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	totals.add_child(ytd_caption)
	year_to_date_amount = _amount_field("YearToDateAmount", 100)
	totals.add_child(year_to_date_amount)
	var estimate_caption := Label.new()
	estimate_caption.text = "Estimated Total $"
	estimate_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	estimate_caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	totals.add_child(estimate_caption)
	estimated_amount = _amount_field("EstimatedAmount", 100)
	totals.add_child(estimated_amount)

	var button_row := HBoxContainer.new()
	button_row.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(button_row)
	var ok_button := Button.new()
	ok_button.name = "OrdinanceOK"
	ok_button.text = "OK"
	ok_button.custom_minimum_size = Vector2(110, 30)
	ok_button.pressed.connect(close_requested.emit)
	button_row.add_child(ok_button)
	_refresh_controls()


func set_city(value: CityState) -> Dictionary:
	city = value
	var result := Ordinances.synchronize_current(city)
	_refresh_controls()
	return result


func refresh() -> void:
	_refresh_controls()


func _add_group(parent: VBoxContainer, category: int) -> void:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _group_box())
	parent.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 3)
	panel.add_child(column)
	var heading := Label.new()
	heading.text = Ordinances.CATEGORY_NAMES[category]
	heading.add_theme_color_override("font_color", Color.WHITE)
	heading.add_theme_font_size_override("font_size", 14)
	column.add_child(heading)
	var rows := GridContainer.new()
	rows.columns = 2
	rows.add_theme_constant_override("h_separation", 6)
	rows.add_theme_constant_override("v_separation", 1)
	column.add_child(rows)
	for ordinance_id in range(category * 4, category * 4 + 4):
		var check := CheckBox.new()
		check.name = "Ordinance%d" % ordinance_id
		check.text = Ordinances.NAMES[ordinance_id]
		check.tooltip_text = EFFECTS[ordinance_id] + "\nThe adjacent amount shows the estimated annual budget effect."
		check.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		check.custom_minimum_size = Vector2(0, 27)
		check.toggled.connect(_on_ordinance_toggled.bind(ordinance_id))
		rows.add_child(check)
		ordinance_checks[ordinance_id] = check
		var amount := _amount_field("OrdinanceAmount%d" % ordinance_id, 78)
		rows.add_child(amount)
		ordinance_amounts[ordinance_id] = amount


func _add_summary(parent: VBoxContainer) -> void:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _group_box())
	parent.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 3)
	panel.add_child(column)
	var heading := Label.new()
	heading.text = "Estimated Annual Cost"
	heading.add_theme_color_override("font_color", Color.WHITE)
	heading.add_theme_font_size_override("font_size", 14)
	column.add_child(heading)
	var rows := GridContainer.new()
	rows.columns = 2
	rows.add_theme_constant_override("h_separation", 6)
	rows.add_theme_constant_override("v_separation", 1)
	column.add_child(rows)
	for category in Ordinances.CATEGORY_NAMES.size():
		var caption := Label.new()
		caption.text = Ordinances.CATEGORY_NAMES[category]
		caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rows.add_child(caption)
		var amount := _amount_field("CategoryAmount%d" % category, 100)
		rows.add_child(amount)
		category_amounts[category] = amount


func _amount_field(node_name: String, minimum_width: float) -> LineEdit:
	var field := LineEdit.new()
	field.name = node_name
	field.custom_minimum_size = Vector2(minimum_width, 25)
	field.editable = false
	field.focus_mode = Control.FOCUS_NONE
	field.alignment = HORIZONTAL_ALIGNMENT_RIGHT
	field.tooltip_text = "Estimated annual amount"
	return field


func _group_box() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color("303030")
	box.border_color = Color("808080")
	box.set_border_width_all(1)
	box.set_content_margin_all(7)
	return box


func _on_ordinance_toggled(enabled: bool, ordinance_id: int) -> void:
	if refreshing:
		return
	var result := Ordinances.set_enabled(city, ordinance_id, enabled)
	if not result.get("ok", false):
		_refresh_controls()
		update_failed.emit(str(result.get("error", "cannot change the ordinance")))
		return
	_refresh_controls()
	if result.get("changed", false):
		ordinances_changed.emit()


func _refresh_controls() -> void:
	if not is_node_ready():
		return
	var data := Ordinances.snapshot(city)
	refreshing = true
	var valid: bool = data.get("ok", false)
	var flags := int(data.get("flags", 0))
	var item_values: PackedInt32Array = data.get(
		"item_amounts", PackedInt32Array()
	)
	for ordinance_id in Ordinances.ORDINANCE_COUNT:
		var check := ordinance_checks[ordinance_id]
		var amount := ordinance_amounts[ordinance_id]
		check.disabled = not valid
		check.button_pressed = valid and bool(flags & (1 << ordinance_id))
		amount.text = (
			Ordinances.compact_amount(item_values[ordinance_id])
			if valid and ordinance_id < item_values.size()
			else ""
		)
	var category_values: PackedInt32Array = data.get(
		"category_amounts", PackedInt32Array()
	)
	for category in Ordinances.CATEGORY_NAMES.size():
		category_amounts[category].text = (
			Ordinances.compact_amount(category_values[category])
			if valid and category < category_values.size()
			else ""
		)
	year_to_date_amount.text = (
		Ordinances.compact_amount(int(data.get("year_to_date_amount", 0)))
		if valid
		else ""
	)
	estimated_amount.text = (
		Ordinances.compact_amount(int(data.get("estimated_amount", 0)))
		if valid
		else ""
	)
	refreshing = false
