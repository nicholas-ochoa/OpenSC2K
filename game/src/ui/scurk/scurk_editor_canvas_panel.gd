class_name ScurkEditorCanvasPanel
extends VBoxContainer

signal zoom_changed(value: int)
signal context_requested
signal terrain_visibility_changed(enabled: bool)

var zoom_pending := 0
var zoom_running := false
var zoom_anchor := Vector2.ZERO
var zoom_pixel := Vector2.ZERO

const PixelCanvas = preload("res://src/view/scurk_pixel_canvas.gd")
const ViewPreview = preload("res://src/view/scurk_view_preview.gd")

const VIEW_LARGE := ScurkSpriteIds.View.LARGE
const VIEW_MEDIUM := ScurkSpriteIds.View.MEDIUM
const VIEW_SMALL := ScurkSpriteIds.View.SMALL
const PREVIEW_VIEWS := [VIEW_LARGE, VIEW_MEDIUM, VIEW_SMALL, VIEW_LARGE]

var pixel_scroll: ScrollContainer
var previews_panel: PanelContainer
var pixel_canvas: ScurkPixelCanvas
var view_previews: Array[ScurkViewPreview] = []
var view_preview_panels: Array[Control] = []
var show_views_button: Button
var preview_checks: Array[CheckBox] = []
var preview_available: Array[bool] = []


func _ready() -> void:
	build()


func build() -> void:
	if pixel_canvas != null:
		return

	pixel_scroll = $Row/PixelScroll
	pixel_canvas = $Row/PixelScroll/Center/PixelCanvas
	previews_panel = $Row/Previews
	$Footer/Row/Clipping/Terrain.toggled.connect(terrain_visibility_changed.emit)
	$Footer/Row/Views/Context.pressed.connect(context_requested.emit)
	show_views_button = $Footer/Row/Views/ShowViews
	show_views_button.toggled.connect(func(enabled: bool) -> void: previews_panel.visible = enabled)
	for label in ["Large", "Medium", "Small", "LargeDouble"]:
		var prefix := "" if label == "LargeDouble" else ("Original/" if label == "Large" else "Original/Smaller/")
		var column := previews_panel.get_node("Content/Scroll/Views/" + prefix + label) as Control
		var preview := column.get_node("Preview") as ScurkViewPreview
		preview.clear_preview(PREVIEW_VIEWS[view_previews.size()])
		var check := previews_panel.get_node("Content/Toggles/" + label) as CheckBox
		check.toggled.connect(_set_preview_visible.bind(view_previews.size()))
		preview_checks.append(check)
		preview_available.append(true)
		view_previews.append(preview)
		view_preview_panels.append(column)


func set_preview_available(index: int, available: bool) -> void:
	preview_available[index] = available
	preview_checks[index].disabled = not available
	_set_preview_visible(preview_checks[index].button_pressed, index)


func _set_preview_visible(enabled: bool, index: int) -> void:
	view_preview_panels[index].visible = enabled and preview_available[index]


func pan_canvas(delta: Vector2) -> void:
	pixel_scroll.scroll_horizontal -= roundi(delta.x)
	pixel_scroll.scroll_vertical -= roundi(delta.y)


func zoom_at(steps: int, local_position: Vector2) -> void:
	zoom_pending += steps
	zoom_anchor = pixel_canvas.global_position + local_position
	zoom_pixel = (local_position - Vector2(ScurkPixelCanvas.DISPLAY_MARGIN, 0)) / pixel_canvas.zoom
	if zoom_running:
		return
	zoom_running = true
	await get_tree().process_frame
	while zoom_pending != 0:
		var anchor := zoom_anchor
		var pixel := zoom_pixel
		pixel_canvas.set_zoom(pixel_canvas.zoom + zoom_pending)
		zoom_pending = 0
		zoom_changed.emit(pixel_canvas.zoom)
		await get_tree().process_frame
		var shifted := pixel_canvas.global_position + Vector2(ScurkPixelCanvas.DISPLAY_MARGIN, 0) + pixel * pixel_canvas.zoom
		pixel_scroll.scroll_horizontal += roundi(shifted.x - anchor.x)
		pixel_scroll.scroll_vertical += roundi(shifted.y - anchor.y)
	zoom_running = false


func _input(event: InputEvent) -> void:
	if pixel_canvas == null or not is_visible_in_tree() or not (event is InputEventMouse or event is InputEventPanGesture):
		return
	var position: Vector2 = event.position
	if not pixel_canvas.panning and (not pixel_scroll.get_global_rect().has_point(position) or pixel_canvas.get_global_rect().has_point(position)):
		return
	var navigation := pixel_canvas.panning or event is InputEventPanGesture
	if event is InputEventMouseButton:
		navigation = navigation or event.button_index in [MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_LEFT, MOUSE_BUTTON_WHEEL_RIGHT]
		navigation = navigation or (event.button_index == MOUSE_BUTTON_LEFT and Input.is_key_pressed(KEY_SPACE))
	if not navigation:
		return
	var local := event.duplicate()
	local.position = position - pixel_canvas.global_position
	if pixel_canvas._handle_editor_input(local):
		get_viewport().set_input_as_handled()
