extends Node

const CanvasScene = preload("res://src/ui/shared/frosted_tooltip_canvas.tscn")

var _popup: PopupPanel
var _layer: CanvasLayer
var _surface: PanelContainer
var _canvas_mask := 0
var _enabled := false
var _refreshing := false


func _ready() -> void:
	_popup = get_parent() as PopupPanel
	_canvas_mask = _popup.canvas_cull_mask
	if _popup.is_embedded():
		# draw above embedded windows so the blur includes dialog contents
		var viewport := _popup.get_parent().get_viewport()
		while not viewport.gui_embed_subwindows and viewport.get_parent() != null:
			viewport = viewport.get_parent().get_viewport()
		_layer = CanvasScene.instantiate() as CanvasLayer
		_layer.custom_viewport = viewport
		_surface = _layer.get_node("Surface")
		_surface.theme = AppUiTheme.current()
		for child in _popup.get_children():
			if child is Control:
				var content := child.duplicate(0) as Control
				content.mouse_filter = Control.MOUSE_FILTER_IGNORE
				_surface.add_child(content)
		add_child(_layer)
		FrostedTooltipPanel.bind(_surface)
	_popup.visibility_changed.connect(_refresh_visibility)
	_popup.size_changed.connect(_sync_geometry)
	AppUiTheme.current().changed.connect(_refresh_theme)
	_refresh_theme()


func _exit_tree() -> void:
	if is_instance_valid(_popup):
		_popup.canvas_cull_mask = _canvas_mask


func _refresh_theme() -> void:
	if _refreshing:
		return
	_refreshing = true
	_enabled = _layer != null and AppUiTheme.translucent_menus
	var style := AppUiTheme.current().get_stylebox("panel", "TooltipPanel").duplicate() as StyleBoxFlat
	if _enabled:
		_surface.add_theme_stylebox_override("panel", style)
	else:
		style.bg_color.a = 1.0
	_popup.add_theme_stylebox_override("panel", style)
	# keep popup input and layout while the overlay draws its contents
	_popup.canvas_cull_mask = 0 if _enabled else _canvas_mask
	_refreshing = false
	_refresh_visibility()


func _refresh_visibility() -> void:
	if _layer != null:
		_layer.visible = _enabled and _popup.visible
	set_process(_enabled and _popup.visible)
	_sync_geometry()


func _process(_delta: float) -> void:
	_sync_geometry()


func _sync_geometry() -> void:
	if _surface == null:
		return
	var scale_factor := _popup.content_scale_factor
	_surface.position = Vector2(_popup.position)
	_surface.scale = Vector2.ONE * scale_factor
	_surface.size = Vector2(_popup.size) / scale_factor
