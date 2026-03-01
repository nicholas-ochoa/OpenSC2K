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
var sprite_status_label: Label


func _ready() -> void:
	build()


func build() -> void:
	if pixel_canvas != null:
		return

	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 5)
	_build_canvas_row()
	_build_status_label()


func _build_canvas_row() -> void:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 6)
	add_child(row)

	var scroll := ScrollContainer.new()
	pixel_scroll = scroll
	scroll.name = "PixelScroll"
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	row.add_child(scroll)
	var canvas_center := CenterContainer.new()
	canvas_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	canvas_center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(canvas_center)
	pixel_canvas = PixelCanvas.new()
	pixel_canvas.name = "PixelCanvas"
	canvas_center.add_child(pixel_canvas)

	previews_panel = PanelContainer.new()
	previews_panel.custom_minimum_size = Vector2(218, 0)
	previews_panel.tooltip_text = (
		"Display-only previews of the complete Drawing Area at all three city views."
	)
	row.add_child(previews_panel)
	var previews_page := VBoxContainer.new()
	previews_page.add_theme_constant_override("separation", 4)
	previews_panel.add_child(previews_page)
	var heading := Label.new()
	heading.text = "View Windows"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_color_override("font_color", Color("dce8ff"))
	previews_page.add_child(heading)
	var previews_layout := HBoxContainer.new()
	previews_layout.alignment = BoxContainer.ALIGNMENT_CENTER
	previews_layout.add_theme_constant_override("separation", 6)
	previews_page.add_child(previews_layout)
	_add_view_preview(previews_layout, "Large", VIEW_LARGE)
	var smaller_previews := VBoxContainer.new()
	smaller_previews.add_theme_constant_override("separation", 6)
	previews_layout.add_child(smaller_previews)
	_add_view_preview(smaller_previews, "Medium", VIEW_MEDIUM)
	_add_view_preview(smaller_previews, "Small", VIEW_SMALL)
	var note := Label.new()
	note.text = "Display only"
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.add_theme_color_override("font_color", Color("c8c8c8"))
	previews_page.add_child(note)


func _build_status_label() -> void:
	sprite_status_label = Label.new()
	sprite_status_label.text = "No sprite is selected."
	sprite_status_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	add_child(sprite_status_label)


func _add_view_preview(parent: Control, label_text: String, view: int) -> void:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	parent.add_child(column)
	var label := Label.new()
	label.text = label_text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(label)
	var preview := ViewPreview.new()
	preview.name = "%sViewPreview" % label_text
	preview.clear_preview(view)
	column.add_child(preview)
	view_previews.append(preview)
	view_preview_panels.append(column)
