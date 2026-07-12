extends Node


const CanvasScene = preload("res://src/ui/shared/frosted_dialog_canvas.tscn")

@export var content_panels: Array[NodePath] = []

var _dialog: AcceptDialog
var _enabled := false
var _layer: CanvasLayer
var _background_copy: BackBufferCopy
var _glass: ColorRect


func _ready() -> void:
	_dialog = get_parent() as AcceptDialog
	_layer = CanvasScene.instantiate() as CanvasLayer
	# Set the viewport before tree entry so Godot connects and disconnects
	# canvas ordering signals on the same viewport.
	_layer.custom_viewport = _dialog.get_parent().get_viewport()
	_background_copy = _layer.get_node("BackgroundCopy")
	_glass = _layer.get_node("Glass")
	add_child(_layer)
	AppUiTheme.current().changed.connect(_refresh_theme)
	_dialog.visibility_changed.connect(_refresh_visibility)
	_dialog.size_changed.connect(_sync_geometry)
	_refresh_theme()


func _refresh_theme() -> void:
	var viewport := _layer.custom_viewport as Viewport
	_enabled = AppUiTheme.translucent_menus and viewport.gui_embed_subwindows and not _dialog.force_native
	_dialog.transparent = _enabled
	_dialog.begin_bulk_theme_override()

	if _enabled:
		var panel := _style("panel", "AcceptDialog")
		panel.draw_center = false
		_dialog.add_theme_stylebox_override("panel", panel)

		# keep the title and outer frame solid, but open the body behind them
		for state in ["embedded_border", "embedded_unfocused_border"]:
			var frame := _style(state, "Window")
			frame.draw_center = false
			frame.border_color = frame.bg_color
			frame.border_width_left = maxi(frame.border_width_left, ceili(frame.expand_margin_left))
			frame.border_width_top = maxi(frame.border_width_top, ceili(frame.expand_margin_top))
			frame.border_width_right = maxi(frame.border_width_right, ceili(frame.expand_margin_right))
			frame.border_width_bottom = maxi(frame.border_width_bottom, ceili(frame.expand_margin_bottom))
			_dialog.add_theme_stylebox_override(state, frame)
	else:
		for state in ["panel", "embedded_border", "embedded_unfocused_border"]:
			_dialog.remove_theme_stylebox_override(state)

	_dialog.end_bulk_theme_override()

	for path in content_panels:
		var control := get_node(path) as Control
		if _enabled:
			var panel := _style("panel", control.get_class())
			panel.draw_center = false
			control.add_theme_stylebox_override("panel", panel)
		else:
			control.remove_theme_stylebox_override("panel")

	_glass.color = AppUiTheme.current().get_stylebox("panel", "MainMenuPanel").bg_color
	_background_copy.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT if _enabled else BackBufferCopy.COPY_MODE_DISABLED
	_refresh_visibility()


func _refresh_visibility() -> void:
	_layer.visible = _enabled and _dialog.visible
	set_process(_layer.visible)
	_sync_geometry()


func _process(_delta: float) -> void:
	# window dragging has no position_changed signal
	_sync_geometry()


func _sync_geometry() -> void:
	_glass.position = Vector2(_dialog.position)
	_glass.size = Vector2(_dialog.size)


static func _style(state: String, type_name: String) -> StyleBoxFlat:
	var source := AppUiTheme.current()
	if not source.has_stylebox(state, type_name):
		source = ThemeDB.get_default_theme()
	return source.get_stylebox(state, type_name).duplicate() as StyleBoxFlat
