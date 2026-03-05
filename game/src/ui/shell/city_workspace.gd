class_name CityWorkspace
extends Control

const MenuBarView = preload("res://src/ui/shell/city_menu_bar.gd")
const ToolbarView = preload("res://src/ui/shell/city_toolbar.gd")
const MapView = preload("res://src/view/city_map_control.gd")
const StatusBarView = preload("res://src/ui/shell/city_status_bar.tscn")
const ClassicStyle = preload("res://src/ui/shared/classic_ui_style.gd")

var toolbar_art: Image
var menu_bar: CityMenuBar
var toolbar: CityToolbar
var map_view: CityMapControl
var status_bar: CityStatusBar


func _init(source_toolbar_art: Image = null) -> void:
	toolbar_art = source_toolbar_art


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var background := ColorRect.new()
	background.color = Color("c0c0c0")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var page := VBoxContainer.new()
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page.add_theme_constant_override("separation", 0)
	add_child(page)

	menu_bar = MenuBarView.new()
	page.add_child(menu_bar)

	var content := HBoxContainer.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 4)
	page.add_child(content)

	toolbar = ToolbarView.new(toolbar_art)
	content.add_child(toolbar)

	var map_panel := PanelContainer.new()
	map_panel.custom_minimum_size = Vector2(560, 480)
	map_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map_panel.add_theme_stylebox_override(
		"panel", ClassicStyle.create_box(Color("18242c"), Color("404040"), 2)
	)
	content.add_child(map_panel)

	map_view = MapView.new()
	map_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map_panel.add_child(map_view)

	status_bar = StatusBarView.instantiate() as CityStatusBar
	page.add_child(status_bar)
