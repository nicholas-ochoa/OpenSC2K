class_name CityWorkspace
extends Control

var toolbar_art: Image
var menu_bar: CityMenuBar
var toolbar: CityToolbar
var map_view: CityMapControl
var status_bar: CityStatusBar


func _enter_tree() -> void:
	# parent enters first, so imported icons are available when the toolbar builds
	toolbar = %Toolbar
	toolbar.toolbar_art = toolbar_art


func _ready() -> void:
	AppUiTheme.bind_canvas($Background)
	menu_bar = %MenuBar
	toolbar = %Toolbar
	map_view = %MapView
	status_bar = %StatusBar
