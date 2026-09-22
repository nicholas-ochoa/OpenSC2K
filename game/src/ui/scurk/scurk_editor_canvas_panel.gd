class_name ScurkEditorCanvasPanel
extends VBoxContainer

const PixelCanvas = preload("res://src/view/scurk_pixel_canvas.gd")
const ViewPreview = preload("res://src/view/scurk_view_preview.gd")

const VIEW_LARGE := 0
const VIEW_MEDIUM := 1
const VIEW_SMALL := 2

var pixel_scroll: ScrollContainer
var previews_panel: PanelContainer
var pixel_canvas: ScurkPixelCanvas
var view_previews: Array[ScurkViewPreview] = []
var view_preview_panels: Array[Control] = []
var show_views_button: Button


func _ready() -> void:
	build()


func build() -> void:
	if pixel_canvas != null:
		return

	pixel_scroll = $Row/PixelScroll
	pixel_canvas = $Row/PixelScroll/Center/PixelCanvas
	previews_panel = $Row/Previews
	show_views_button = $Footer/Row/ShowViews
	show_views_button.toggled.connect(func(enabled: bool) -> void: previews_panel.visible = enabled)
	for label in ["Large", "Medium", "Small"]:
		var column := previews_panel.get_node("Content/" + ("" if label == "Large" else "Smaller/") + label) as Control
		var preview := column.get_node("Preview") as ScurkViewPreview
		preview.clear_preview(view_previews.size())
		view_previews.append(preview)
		view_preview_panels.append(column)
