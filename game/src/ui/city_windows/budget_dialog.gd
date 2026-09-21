class_name BudgetDialog
extends ConfirmationDialog
# proposed funding, budget reports, and original advisor access

@warning_ignore_start("integer_division")

signal apply_requested
signal cancel_requested
signal issue_bond_requested
signal repay_bond_requested
signal bond_confirmation_resolved(action: String, confirmed: bool)
signal advisor_requested(index: int)
signal sound_requested(sound_ids: Array[int])
signal ordinances_changed
signal update_failed(message: String)

const Budget = preload("res://src/simulation/economy/budget_phase.gd")
const Bonds = preload("res://src/simulation/economy/bond_command.gd")
const BUDGET_NAMES := BudgetReport.NAMES
# drawn width of the action icons, independent of the imported artwork size
const ICON_WIDTH := 20

var notice_label: Label
var controls: Array[SpinBox] = []
var auto_budget_check: CheckBox
var bond_summary_label: Label
var issue_bond_button: Button
var repay_bond_button: Button
var bond_dialog: ConfirmationDialog
var pending_bond_action := ""
var city: CityState
var report: BudgetReport
var group_controls: Array[SpinBox] = []
var group_hints: Array[Label] = []
var ytd_labels: Array[Label] = []
var estimate_labels: Array[Label] = []
var detail_nodes: Array[Control] = []
var detail_toggle: CheckBox
var tabs: TabContainer
var history_category: OptionButton
var history_table: Tree
var bond_table: Tree
var ordinance_control: OrdinanceWindowControl
var advisor_dialog: AcceptDialog
var total_labels: Array[Label] = []
var total_captions: Array[Label] = []
var refreshing := false
var action_buttons: Array[Button] = []
var group_edits: Dictionary[int, float] = {}
var previous_funding := PackedInt32Array()


func _ready() -> void:
	hide()
	theme = AppUiTheme.current()
	confirmed.connect(apply_requested.emit)
	canceled.connect(cancel_requested.emit)
	notice_label = $Margin/Content/Notice
	auto_budget_check = $Margin/Content/AutoBudget
	tabs = $Margin/Content/Tabs
	detail_toggle = $Margin/Content/Tabs/Overview/DetailToggle
	bond_summary_label = $"Margin/Content/Tabs/Bonds/Summary"
	issue_bond_button = $Margin/Content/Tabs/Bonds/Actions/Issue
	repay_bond_button = $Margin/Content/Tabs/Bonds/Actions/Repay
	bond_dialog = $BondConfirmation
	advisor_dialog = $Advisor
	history_category = $"Margin/Content/Tabs/Monthly history/Category"
	history_table = $"Margin/Content/Tabs/Monthly history/Table"
	bond_table = $Margin/Content/Tabs/Bonds/Table
	ordinance_control = $Margin/Content/Tabs/Ordinances/OrdinanceWindowControl
	ordinance_control.ordinances_changed.connect(_ordinances_changed)
	ordinance_control.update_failed.connect(update_failed.emit)
	ordinance_control.close_requested.connect(func() -> void: tabs.current_tab = 0)
	issue_bond_button.pressed.connect(issue_bond_requested.emit)
	repay_bond_button.pressed.connect(repay_bond_requested.emit)
	$Margin/Content/Tabs/Bonds/Actions/Advice.pressed.connect(advisor_requested.emit.bind(2))
	bond_dialog.confirmed.connect(_resolve_bond_confirmation.bind(true))
	bond_dialog.canceled.connect(_resolve_bond_confirmation.bind(false))
	detail_toggle.toggled.connect(_show_details)
	history_category.item_selected.connect(func(_index: int) -> void: _refresh_history())
	_build_rows()
	var bond_advice: Button = $Margin/Content/Tabs/Bonds/Actions/Advice
	bond_advice.text = ""
	bond_advice.icon = preload("res://src/ui/city_windows/icons/budget_advisor.svg")
	bond_advice.tooltip_text = "Ask the bond advisor"
	action_buttons.append(bond_advice)
	_style_actions()
	AppUiTheme.current().changed.connect(_style_actions)

	for caption in ["Year to date", "Year-end cash flow", "Current funds", "Year-end funds"]:
		var column := VBoxContainer.new()
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		$Margin/Content/Totals.add_child(column)
		var heading := _label(caption)
		column.add_child(heading)
		total_captions.append(heading)
		var amount := _label("$0")
		amount.add_theme_font_size_override("font_size", 18)
		column.add_child(amount)
		total_labels.append(amount)

	for caption: String in BudgetReport.GROUP_NAMES:
		history_category.add_item(caption)

	_setup_table(bond_table, ["Bond", "Principal", "Interest rate", "Annual interest"])


func _build_rows() -> void:
	var rows: GridContainer = $Margin/Content/Tabs/Overview/Scroll/Rows

	for caption in ["Category", "Rate / funding", "Year to date", "Year-end estimate", ""]:
		rows.add_child(_label(caption))

	controls.resize(Budget.BUDGET_COUNT)

	for group in BudgetReport.GROUPS.size():
		rows.add_child(_label(BudgetReport.GROUP_NAMES[group]))
		var field := VBoxContainer.new()
		rows.add_child(field)
		var spin := _spin(22 if group == 0 else 100)
		spin.visible = group not in [1, 2]
		field.add_child(spin)
		group_controls.append(spin)
		spin.value_changed.connect(_group_changed.bind(group))
		spin.get_line_edit().text_changed.connect(_group_text_changed.bind(group))
		spin.get_line_edit().text_submitted.connect(func(_text: String) -> void: _commit_group_edit(group))
		spin.get_line_edit().focus_exited.connect(_commit_group_edit.bind(group))
		var hint := _label("")
		field.add_child(hint)
		group_hints.append(hint)
		var ytd := _label("$0", true)
		var estimate := _label("$0", true)
		rows.add_child(ytd)
		rows.add_child(estimate)
		ytd_labels.append(ytd)
		estimate_labels.append(estimate)
		var actions := HBoxContainer.new()
		rows.add_child(actions)
		var history := Button.new()
		history.icon = preload("res://src/ui/city_windows/icons/budget_details.svg") if group in [1, 2] else preload("res://src/ui/city_windows/icons/budget_history.svg")
		history.tooltip_text = "Open the %s tab" % ("Ordinances" if group == 1 else "Bonds") if group in [1, 2] else "Show monthly history for %s" % BudgetReport.GROUP_NAMES[group].to_lower()
		history.pressed.connect(_open_details.bind(group))
		actions.add_child(history)
		action_buttons.append(history)
		var advice := Button.new()
		advice.icon = preload("res://src/ui/city_windows/icons/budget_advisor.svg")
		advice.tooltip_text = "Ask the %s advisor" % BudgetReport.GROUP_NAMES[group].to_lower()
		advice.pressed.connect(advisor_requested.emit.bind(group))
		actions.add_child(advice)
		action_buttons.append(advice)

		for id: int in BudgetReport.GROUPS[group]:
			var control := _spin(22 if id < 3 else 100)
			controls[id] = control
			control.value_changed.connect(_individual_changed)

			if group in [1, 2]:
				control.min_value = -2147483648
				control.max_value = 2147483647
				control.editable = false
				control.hide()
				field.add_child(control)
			elif BudgetReport.GROUPS[group].size() == 1:
				control.hide()
				field.add_child(control)
			else:
				var name_label := _label("    " + BudgetReport.NAMES[id])
				for node: Control in [name_label, control, _label(""), _label(""), _label("")]:
					rows.add_child(node)
					detail_nodes.append(node)
					node.hide()


func _spin(maximum: int) -> SpinBox:
	var spin := SpinBox.new()
	spin.max_value = maximum
	spin.rounded = true
	spin.suffix = "%"
	spin.custom_minimum_size.x = 105
	return spin


func _label(text: String, amount := false) -> Label:
	var label := Label.new()
	label.text = text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if amount:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	return label


func set_city(value: CityState) -> void:
	city = value
	ordinance_control.city = value
	ordinance_control.refresh()


func open_budget(values: PackedInt32Array, annual: bool, auto_budget: bool) -> void:
	title = "Annual Budget" if annual else "Budget"
	$Margin/Content/Heading.text = title if city == null else "%s · %s %d" % [city.display_name(), BudgetReport.MONTHS[city.current_month() - 1], city.current_year()]
	notice_label.text = "Review last year’s totals." if annual else "Review income, service funding and the year-end forecast."
	auto_budget_check.button_pressed = auto_budget
	get_cancel_button().disabled = annual
	exclusive = annual
	refreshing = true
	for id in mini(values.size(), controls.size()):
		controls[id].set_value_no_signal(values[id])
	refreshing = false
	detail_toggle.set_pressed_no_signal(false)
	_show_details(false)
	tabs.current_tab = 0
	refresh_report()
	popup_centered(Vector2i(940, 700))


func funding_values() -> PackedInt32Array:
	var values := PackedInt32Array()
	for control in controls:
		values.append(roundi(control.value))
	return values


func auto_budget_enabled() -> bool:
	return auto_budget_check.button_pressed


func _group_changed(value: float, group: int) -> void:
	if refreshing:
		return
	for id: int in BudgetReport.GROUPS[group]:
		controls[id].set_value_no_signal(value)
	_play_tax_change()
	refresh_report()


func _group_text_changed(text: String, group: int) -> void:
	if refreshing:
		return

	var number := text.replace("%", "").strip_edges()
	if number.is_valid_float():
		group_edits[group] = clampf(number.to_float(), 0, group_controls[group].max_value)
	else:
		group_edits.erase(group)


func _commit_group_edit(group: int) -> void:
	if group_edits.has(group):
		_group_changed(group_edits[group], group)


func _individual_changed(_value: float) -> void:
	if not refreshing:
		_play_tax_change()
		refresh_report()


func _play_tax_change() -> void:
	var values := funding_values()
	if previous_funding.size() != values.size():
		return
	var difference := 0
	for id in 3:
		difference += values[id] - previous_funding[id]
	if difference != 0:
		var sounds: Array[int] = [512 if difference > 0 else 513]
		sound_requested.emit(sounds)


func _show_details(enabled: bool) -> void:
	for node in detail_nodes:
		node.visible = enabled


func _open_details(group: int) -> void:
	if group == 1:
		tabs.current_tab = 3
	elif group == 2:
		tabs.current_tab = 2
	else:
		history_category.select(group)
		_refresh_history()
		tabs.current_tab = 1


func refresh_report() -> void:
	var values := funding_values()
	previous_funding = values.duplicate()
	group_edits.clear()
	refreshing = true
	for group in BudgetReport.GROUPS.size():
		var ids: Array = BudgetReport.GROUPS[group]
		var first: int = values[ids[0]]
		var mixed := false
		for id: int in ids:
			mixed = mixed or values[id] != first
		group_controls[group].set_value_no_signal(first)
		group_hints[group].text = "Mixed rates" if mixed else ""
		group_hints[group].visible = mixed
		if mixed:
			group_controls[group].get_line_edit().text = "Mixed"
	refreshing = false

	if city == null:
		return

	report = BudgetReport.capture(city, values)
	for group in BudgetReport.GROUPS.size():
		_set_amount(ytd_labels[group], BudgetReport.group_amount(report.year_to_date, group))
		_set_amount(estimate_labels[group], BudgetReport.group_amount(report.estimated, group))
	var totals := [report.ytd_cash, report.estimated_cash, city.funds(), BudgetReport.wrap_i32(city.funds() + (report.ytd_cash if report.year_end else report.estimated_cash))]
	total_captions[3].text = "Funds after settlement" if report.year_end else "Year-end funds"
	total_captions[1].text = "Projected annual flow" if report.year_end else "Year-end cash flow"
	for index in totals.size():
		_set_amount(total_labels[index], totals[index])
	_refresh_history()
	_refresh_bond_table()


func _setup_table(table: Tree, titles: Array) -> void:
	table.theme = AppUiTheme.file_dialog()
	var dark := AppUiTheme.selected == "dark"
	for state in ["title_button_normal", "title_button_hover", "title_button_pressed"]:
		var header := AppUiThemeDefinitions.create_box(Color("4b5563") if dark else Color("e2e8f0"), Color("788699") if dark else Color("b7c3d2"), 1, 6, 5)
		table.add_theme_stylebox_override(state, header)
	table.add_theme_color_override("title_button_color", Color("f8fafc") if dark else Color("253247"))
	table.clear()
	table.columns = titles.size()
	for column in titles.size():
		table.set_column_title(column, titles[column])
		table.set_column_custom_minimum_width(column, 85 if column > 0 else 120)
	table.create_item()


func _refresh_history() -> void:
	if report == null:
		return
	var group := history_category.selected
	var ids: Array = BudgetReport.GROUPS[group]
	var titles: Array = ["Month", "Status"]
	if group == 2:
		titles.append_array(["Principal", "Rate", "Interest"])
	else:
		for id: int in ids:
			titles.append(BudgetReport.NAMES[id])
	titles.append("Running total")
	_setup_table(history_table, titles)
	var cumulative := 0
	for month in 12:
		var row := history_table.create_item(history_table.get_root())
		row.set_text(0, BudgetReport.MONTHS[month])
		row.set_text(1, "Recorded" if month < report.actual_months else "Projected")
		var amount := 0
		if group == 2:
			row.set_text(2, BudgetReport.currency(report.history_costs[4][month] * Bonds.BOND_VALUE))
			row.set_text(3, "%.2f%%" % (report.history_rates[4][month] / 10000.0))
			row.set_text(4, BudgetReport.currency(report.history[4][month]))
			amount = report.history[4][month]
		else:
			for index in ids.size():
				var id: int = ids[index]
				row.set_text(index + 2, BudgetReport.currency(report.history[id][month]))
				row.set_tooltip_text(index + 2, "Rate: %d%%" % report.history_rates[id][month] if id != 3 else "Ordinance income and costs")
				amount += report.history[id][month]
		cumulative += amount
		row.set_text(titles.size() - 1, BudgetReport.currency(cumulative))
		for column in range(2, titles.size()):
			row.set_text_alignment(column, HORIZONTAL_ALIGNMENT_RIGHT)
			if row.get_text(column).begins_with("−"):
				row.set_custom_color(column, _loss_color())


func _refresh_bond_table() -> void:
	if city == null:
		return
	_setup_table(bond_table, ["Bond", "Principal", "Interest rate", "Annual interest"])
	var count := mini(city.document.misc_u32(Bonds.MISC_BONDS), Bonds.MAX_BONDS)
	for index in count:
		var rate := city.document.misc_u32(Bonds.MISC_BOND_RATES + index * 4) & 0xffff
		var row := bond_table.create_item(bond_table.get_root())
		row.set_text(0, "%d%s" % [index + 1, " (oldest)" if index == 0 else ""])
		row.set_text(1, BudgetReport.currency(Bonds.BOND_VALUE))
		row.set_text(2, "%d%%" % rate)
		row.set_text(3, BudgetReport.currency(-rate * 100))
		if rate > 0:
			row.set_custom_color(3, _loss_color())
	var federal := BudgetAdvice._signed_word(city.document.misc_u32(Bonds.MISC_FEDERAL_RATE))
	var value := CityValuePhase.calculate(city)
	var city_value := value.city_value if value.ok else city.document.misc_u32(Bonds.MISC_CITY_VALUE)
	var credit := clampi(BudgetAdvice._signed_word(((count * 25000) & 0xffffffff) / maxi((city_value + 1) & 0xffffffff, 1)), 0, 6)
	bond_summary_label.text = "Outstanding: %s   ·   Credit: %s   ·   Bank rate: %d%%   ·   Next bond: %d%%   ·   City value: %s" % [BudgetReport.currency(count * Bonds.BOND_VALUE), ["AAA", "AA", "A", "B", "C", "D", "F"][credit], federal, federal + 1, BudgetReport.currency(city_value * 1000)]


func set_bond_state(bond_count: int, funds: int, average_fixed: int, _oldest_rate: int) -> void:
	controls[Budget.BUDGET_BONDS].set_value_no_signal(average_fixed)
	issue_bond_button.disabled = bond_count >= Bonds.MAX_BONDS
	repay_bond_button.disabled = bond_count == 0 or funds < Bonds.BOND_VALUE
	refresh_report()


func show_advice(index: int, advice: int, assets: OriginalGameAssets) -> void:
	advisor_dialog.title = "%s advisor" % BudgetReport.GROUP_NAMES[index]
	var portrait: TextureRect = $Advisor/Content/Portrait
	portrait.texture = null
	if assets != null and assets.city_ui_graphics != null and assets.city_ui_graphics.portraits.has(197 + index):
		portrait.texture = ImageTexture.create_from_image(assets.city_ui_graphics.portraits[197 + index])
	portrait.visible = portrait.texture != null
	$Advisor/Content/Advice.text = BudgetAdvice.ADVICE[advice]
	advisor_dialog.popup_centered()


func _ordinances_changed() -> void:
	refresh_report()
	ordinances_changed.emit()


func open_bond_confirmation(action: String, rate: int) -> void:
	pending_bond_action = action
	bond_dialog.theme = AppUiTheme.current()
	bond_dialog.title = "Issue Bond" if action == "issue" else "Repay Bond"
	bond_dialog.dialog_text = "Issue a $10,000 bond at %d%%?" % rate if action == "issue" else "Repay the oldest $10,000 bond at %d%%?" % rate
	bond_dialog.popup_centered()


func reset_dialogs() -> void:
	hide()
	pending_bond_action = ""
	bond_dialog.hide()
	advisor_dialog.hide()
	city = null
	report = null
	ordinance_control.city = null


func bond_confirmation_visible() -> bool:
	return bond_dialog != null and bond_dialog.visible


func _resolve_bond_confirmation(confirmed_value: bool) -> void:
	var action := pending_bond_action
	pending_bond_action = ""
	if not action.is_empty():
		bond_confirmation_resolved.emit(action, confirmed_value)


func _loss_color() -> Color:
	return Color("ff8585") if AppUiTheme.selected == "dark" else Color("b42318")


func _set_amount(label: Label, amount: int) -> void:
	label.text = BudgetReport.currency(amount)
	if amount < 0:
		label.add_theme_color_override("font_color", _loss_color())
	else:
		label.remove_theme_color_override("font_color")


# icon-only actions keep the normal button look. the artwork imports at four
# times its drawn size, so a scaled interface stays sharp
func _style_actions() -> void:
	for button in action_buttons:
		button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		button.add_theme_constant_override("icon_max_width", ICON_WIDTH)

	if report != null:
		refresh_report()
