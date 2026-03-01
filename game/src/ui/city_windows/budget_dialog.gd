class_name BudgetDialog
extends ConfirmationDialog

signal apply_requested
signal cancel_requested
signal issue_bond_requested
signal repay_bond_requested
signal bond_confirmation_resolved(action: String, confirmed: bool)

const Budget = preload("res://src/simulation/economy/budget_phase.gd")
const Bonds = preload("res://src/simulation/economy/bond_command.gd")

const BUDGET_NAMES := [
	"Residential Tax",
	"Commercial Tax",
	"Industrial Tax",
	"Ordinances",
	"Bonds",
	"Police",
	"Fire",
	"Health",
	"School",
	"College",
	"Road",
	"Highway",
	"Bridge",
	"Rail",
	"Subway",
	"Tunnel",
]

var notice_label: Label
var controls: Array[SpinBox] = []
var auto_budget_check: CheckBox
var bond_summary_label: Label
var issue_bond_button: Button
var repay_bond_button: Button
var bond_dialog: ConfirmationDialog
var pending_bond_action := ""


func _ready() -> void:
	theme = theme.duplicate() if theme != null else ThemeDB.get_default_theme().duplicate()
	theme.set_color("font_color", "Label", Color.WHITE)
	title = "Budget"
	min_size = Vector2i(720, 560)
	get_ok_button().text = "Apply"
	confirmed.connect(func() -> void:
		apply_requested.emit())
	canceled.connect(func() -> void:
		cancel_requested.emit())
	var budget_scroll := MarginContainer.new()
	budget_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	budget_scroll.offset_left = 16
	budget_scroll.offset_top = 48
	budget_scroll.offset_right = -16
	budget_scroll.offset_bottom = -58
	add_child(budget_scroll)
	var budget_rows := VBoxContainer.new()
	budget_rows.custom_minimum_size = Vector2(660, 0)
	budget_rows.add_theme_constant_override("separation", 6)
	budget_scroll.add_child(budget_rows)
	notice_label = Label.new()
	notice_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	notice_label.custom_minimum_size = Vector2(640, 42)
	budget_rows.add_child(notice_label)
	auto_budget_check = CheckBox.new()
	auto_budget_check.theme = ThemeDB.get_default_theme().duplicate()

	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		auto_budget_check.add_theme_stylebox_override(state, StyleBoxEmpty.new())
		auto_budget_check.add_theme_color_override("font_" + ("color" if state == "normal" else state + "_color"), Color.WHITE)

	auto_budget_check.text = "Use the same funding automatically next year"
	budget_rows.add_child(auto_budget_check)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 24)
	budget_rows.add_child(columns)
	var left := VBoxContainer.new()
	var right := VBoxContainer.new()

	for column in [left, right]:
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		column.add_theme_constant_override("separation", 5)
		columns.add_child(column)

	for budget_id in BUDGET_NAMES.size():
		_add_budget_row(left if budget_id < 8 else right, budget_id)

	_add_bond_controls(budget_rows)
	_build_bond_dialog()


func open_budget(values: PackedInt32Array, annual: bool, auto_budget: bool) -> void:
	title = "Annual Budget" if annual else "Budget"
	notice_label.text = (
		"Set the tax rates and service funding. Apply this budget to finish the annual settlement."
		if annual
		else "Set the tax rates and service funding. Ordinance and bond values are calculated by the simulation."
	)
	auto_budget_check.button_pressed = auto_budget
	get_cancel_button().disabled = annual
	exclusive = annual

	for budget_id in mini(values.size(), controls.size()):
		controls[budget_id].value = values[budget_id]

	popup_centered()


func funding_values() -> PackedInt32Array:
	var values := PackedInt32Array()

	for control in controls:
		values.append(roundi(control.value))

	return values


func auto_budget_enabled() -> bool:
	return auto_budget_check.button_pressed


func set_bond_state(
	bond_count: int,
	funds: int,
	average_fixed: int,
	oldest_rate: int,
) -> void:
	controls[Budget.BUDGET_BONDS].value = average_fixed

	if bond_count == 0:
		bond_summary_label.text = "No outstanding bonds"
	else:
		bond_summary_label.text = "%d outstanding; oldest %d%%; average %.2f%%" % [
			bond_count, oldest_rate, float(average_fixed) / 10000.0,
		]

	issue_bond_button.disabled = bond_count > Bonds.MAX_BONDS
	repay_bond_button.disabled = bond_count == 0 or funds < Bonds.BOND_VALUE


func open_bond_confirmation(action: String, rate: int) -> void:
	pending_bond_action = action

	if action == "issue":
		_style_bond_confirmation()
		bond_dialog.title = "Issue Bond"
		bond_dialog.dialog_text = (
			"Current Rates are %d%%.\nDo You Want to Issue the Bond?" % rate
		)
	else:
		_style_bond_confirmation()
		bond_dialog.title = "Repay Bond"
		bond_dialog.dialog_text = (
			"Oldest Bond Rate is %d%%\nDo You Want to Repay the Bond?" % rate
		)

	bond_dialog.popup_centered()


func reset_dialogs() -> void:
	if visible:
		hide()

	pending_bond_action = ""

	if bond_dialog.visible:
		bond_dialog.hide()


func bond_confirmation_visible() -> bool:
	return bond_dialog != null and bond_dialog.visible


func _add_budget_row(rows: VBoxContainer, budget_id: int) -> void:
	var row := HBoxContainer.new()
	var row_label := Label.new()
	row_label.text = BUDGET_NAMES[budget_id]
	row_label.custom_minimum_size = Vector2(150, 0)
	row_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(row_label)
	var control := SpinBox.new()
	control.custom_minimum_size = Vector2(145, 30)
	control.rounded = true
	control.step = 1
	control.min_value = -2147483648
	control.max_value = 2147483647

	if budget_id <= Budget.BUDGET_INDUSTRIAL:
		control.min_value = 0
		control.max_value = 22
		control.suffix = "% tax"
	elif budget_id >= Budget.BUDGET_POLICE:
		control.min_value = 0
		control.max_value = 100
		control.suffix = "% funded"
		var effect := "Service capacity and coverage scale with funding: 100% gives full strength, 50% gives about half, and 0% removes the funded contribution."

		if budget_id >= Budget.BUDGET_ROAD:
			effect = "100% funds normal maintenance. Lower funding increases the risk of network decay; 50% is partial maintenance and 0% leaves the network unfunded."

		control.tooltip_text = effect + " Lower funding reduces annual spending."
		control.get_line_edit().tooltip_text = control.tooltip_text
	else:
		control.editable = false

	if budget_id == Budget.BUDGET_BONDS:
		control.visible = false

	row.add_child(control)
	controls.append(control)
	rows.add_child(row)


func _add_bond_controls(rows: VBoxContainer) -> void:
	var bond_controls := HBoxContainer.new()
	bond_controls.add_theme_constant_override("separation", 8)
	bond_summary_label = Label.new()
	bond_summary_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bond_controls.add_child(bond_summary_label)
	issue_bond_button = Button.new()
	issue_bond_button.text = "Issue $10K Bond"
	issue_bond_button.pressed.connect(func() -> void:
		issue_bond_requested.emit())
	bond_controls.add_child(issue_bond_button)
	repay_bond_button = Button.new()
	repay_bond_button.text = "Repay $10K Bond"
	repay_bond_button.pressed.connect(func() -> void:
		repay_bond_requested.emit())
	bond_controls.add_child(repay_bond_button)
	rows.add_child(bond_controls)


func _build_bond_dialog() -> void:
	bond_dialog = ConfirmationDialog.new()
	bond_dialog.title = "Bond"
	bond_dialog.min_size = Vector2i(500, 210)
	bond_dialog.exclusive = true
	bond_dialog.get_ok_button().text = "Yes"
	bond_dialog.get_cancel_button().text = "No"
	bond_dialog.confirmed.connect(_resolve_bond_confirmation.bind(true))
	bond_dialog.canceled.connect(_resolve_bond_confirmation.bind(false))
	add_child(bond_dialog)


func _resolve_bond_confirmation(confirmed_value: bool) -> void:
	var action := pending_bond_action
	pending_bond_action = ""

	if not action.is_empty():
		bond_confirmation_resolved.emit(action, confirmed_value)


func _style_bond_confirmation() -> void:
	bond_dialog.theme = ThemeDB.get_default_theme().duplicate()
	bond_dialog.get_label().add_theme_color_override("font_color", Color.WHITE)
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color("303030")
	panel.border_color = Color("b0b0b0")
	panel.set_border_width_all(2)
	panel.set_content_margin_all(12)
	bond_dialog.add_theme_stylebox_override("panel", panel)
