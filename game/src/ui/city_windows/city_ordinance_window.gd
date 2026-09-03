class_name CityOrdinanceWindow
extends Window

signal ordinances_changed
signal update_failed(message: String)

const OrdinanceView = preload("res://src/view/ordinance_window_control.gd")

var ordinance_control: OrdinanceWindowControl


func _ready() -> void:
	# visible in the editor, closed at startup
	hide()
	close_requested.connect(hide)
	theme = AppUiTheme.current()

	ordinance_control = get_node("Background/Margin/OrdinanceWindowControl")
	ordinance_control.ordinances_changed.connect(ordinances_changed.emit)
	ordinance_control.update_failed.connect(update_failed.emit)
	ordinance_control.close_requested.connect(hide)


func open_city(value: CityState) -> OrdinanceCommand.Result:
	if value == null or ordinance_control == null:
		return OrdinanceCommand.failed("city is not available")

	var result := ordinance_control.set_city(value)

	if result.ok:
		popup_centered(Vector2i(800, 640))

	return result


func refresh_city() -> void:
	if visible and ordinance_control != null:
		ordinance_control.refresh()
