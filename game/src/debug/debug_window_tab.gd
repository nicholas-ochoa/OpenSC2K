class_name DebugWindowTab
extends VBoxContainer
## A tab of the Debug window that builds its own controls. The window calls
## `refresh` while the tab is visible, four times a second, and with `force`
## when the tab opens.

# the application node, which has the state and controllers
var host: Control
var status := Callable()


func setup(application: Control, status_callback: Callable) -> void:
	host = application
	status = status_callback


func refresh(_force := false) -> void:
	pass


# the application, or null for a test host
func application() -> CityApplication:
	return host as CityApplication


func report(message: String) -> void:
	if status.is_valid():
		status.call(message)


static func make_button(parent: Control, caption: String, tooltip: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = caption
	button.tooltip_text = tooltip
	button.pressed.connect(action)
	parent.add_child(button)

	return button


static func make_table(titles: Array, expand_column: int) -> Tree:
	var table := Tree.new()
	table.columns = titles.size()
	table.column_titles_visible = true
	table.hide_root = true
	table.size_flags_vertical = Control.SIZE_EXPAND_FILL

	for column in titles.size():
		table.set_column_title(column, titles[column])
		table.set_column_expand(column, column == expand_column)
		table.set_column_custom_minimum_width(column, 90)

	return table
