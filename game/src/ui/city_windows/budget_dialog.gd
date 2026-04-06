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
	# the scene is visible for editor layout work. open it only on request in game
	hide()
	theme = theme.duplicate() if theme != null else ThemeDB.get_default_theme().duplicate()
	theme.set_color("font_color", "Label", Color.WHITE)
	confirmed.connect(apply_requested.emit)
	canceled.connect(cancel_requested.emit)
	notice_label = get_node("Margin/Content/Notice")
	auto_budget_check = get_node("Margin/Content/AutoBudget")
	bond_summary_label = get_node("Margin/Content/Bonds/Summary")
	issue_bond_button = get_node("Margin/Content/Bonds/Issue")
	repay_bond_button = get_node("Margin/Content/Bonds/Repay")
	bond_dialog = get_node("BondConfirmation")
	auto_budget_check.theme = ThemeDB.get_default_theme().duplicate()

	for column in $Margin/Content/Columns.get_children():
		for row in column.get_children():
			var control := row.get_node("SpinBox1") as SpinBox
			control.get_line_edit().tooltip_text = control.tooltip_text
			controls.append(control)

	issue_bond_button.pressed.connect(issue_bond_requested.emit)
	repay_bond_button.pressed.connect(repay_bond_requested.emit)
	bond_dialog.confirmed.connect(_resolve_bond_confirmation.bind(true))
	bond_dialog.canceled.connect(_resolve_bond_confirmation.bind(false))


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
