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
	AppUiTheme.bind_canvas($Background, "map_canvas")
	menu_bar = %MenuBar
	toolbar = %Toolbar
	map_view = %MapView
	status_bar = %StatusBar
	$Page/Content/MapSpace.item_rect_changed.connect(_sync_camera_rect)
	$Page.visibility_changed.connect(_sync_camera_rect)
	_sync_camera_rect.call_deferred()


func set_editor_controls_visible(value: bool) -> void:
	$Page.visible = value


func _sync_camera_rect() -> void:
	var map_space: Control = $Page/Content/MapSpace
	map_view.camera_view_rect = (
		Rect2(map_space.global_position - map_view.global_position, map_space.size)
		if $Page.visible else Rect2()
	)
