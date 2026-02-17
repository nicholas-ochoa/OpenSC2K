class_name CityDesktopPresentation
extends Node
# own cursor display only over an active drawing surface

var graphics: DesktopGraphics
var map_view: CityMapControl
var editor: ScurkEditorControl
var place_print: ScurkPlacePrintControl
var print_dialog: ScurkPrintControl
var presenter: DesktopCursorPresenter
var icon_key := ""
var icon_image: Image
var _project_icon: Image
var _pointer_position := Vector2.ZERO


func _ready() -> void:
	_pointer_position = get_viewport().get_mouse_position()
	presenter = DesktopCursorPresenter.new()
	add_child(presenter)
	var texture := load(ProjectSettings.get_setting("application/config/icon", "")) as Texture2D
	_project_icon = texture.get_image() if texture != null else null


func set_graphics(value: DesktopGraphics) -> void:
	graphics = value
	presenter.set_graphics(value)
	icon_key = ""


func _input(event: InputEvent) -> void:
	if event is InputEventMouse:
		_pointer_position = event.position


func _process(_delta: float) -> void:
	_update_icon()
	var window := get_window()
	var exclusive := window.get_last_exclusive_window()
	if not window.has_focus() or (exclusive != null and exclusive != window):
		presenter.clear_cursor()
		return
	var viewport := get_viewport()
	var hovered := viewport.gui_get_hovered_control()
	var selection := cursor_selection(hovered, DisplayServer.screen_get_size(window.current_screen).x)
	if selection.is_empty():
		presenter.clear_cursor()
		return
	presenter.present(selection.app, selection.group, _pointer_position,
		selection.get("shape", hovered.get_cursor_shape(hovered.get_local_mouse_position())))


func cursor_selection(hovered: Control, display_width: int) -> Dictionary:
	if hovered == null or not hovered.is_visible_in_tree():
		return {}
	if hovered == map_view and map_view.city != null:
		var role := map_view.desktop_cursor_role if map_view.edit_enabled else 0
		if map_view.is_panning():
			role = 10 # godot middle-button panning uses the supplied hand artwork
		elif map_view.shift_query_enabled and not map_view.shift_line_enabled and not map_view.shift_rectangle_enabled and Input.is_key_pressed(KEY_SHIFT):
			role = 23
		if role == 0:
			return {}
		var app := map_view.desktop_cursor_app
		return {"app": app, "group": (31000 if app == "scurk" else DesktopCursorRules.city_family(display_width)) + role}
	if hovered is ScurkPixelCanvas and hovered.sprite_width > 0:
		return {"app": "scurk", "group": DesktopCursorRules.paint_tool(hovered.tool)}
	if hovered is ScurkObjectList and hovered.drop_target and get_viewport().gui_is_dragging():
		var data: Variant = get_viewport().gui_get_drag_data()
		if hovered._can_drop_data(hovered.get_local_mouse_position(), data):
			return {"app": "scurk", "group": 30004 if data.large_ids.size() == 1 else 30005,
				"shape": Input.CURSOR_CAN_DROP}
	return {}


func _update_icon() -> void:
	var app := "city"
	var group := 2
	if print_dialog != null and print_dialog.visible:
		app = "scurk"
		group = 3
	elif editor != null and editor.visible:
		app = "scurk"
		group = 4 if editor.pick_copy_control.visible else 2
	elif place_print != null and place_print.visible:
		app = "scurk"
		group = 1
	var key := "%s:%d" % [app, group]
	if icon_key == key:
		return
	icon_key = key
	icon_image = graphics.icon(app, group, 32) if graphics != null else null
	if icon_image == null:
		icon_image = _project_icon
	if icon_image != null:
		DisplayServer.set_icon(icon_image)


func _exit_tree() -> void:
	if _project_icon != null:
		DisplayServer.set_icon(_project_icon)
