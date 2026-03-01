class_name ScenarioIntroDialog
extends AcceptDialog

const ClassicStyle = preload("res://src/ui/shared/classic_ui_style.gd")

var picture_view: TextureRect
var text_view: TextEdit


func _ready() -> void:
	theme = ClassicUiStyle.create_dialog_theme()
	title = "Scenario"
	min_size = Vector2i(760, 520)
	exclusive = true
	get_ok_button().text = "Begin Scenario"
	get_label().visible = false

	var content := HBoxContainer.new()
	content.custom_minimum_size = Vector2(700, 400)
	content.add_theme_constant_override("separation", 16)
	var picture_frame := PanelContainer.new()
	picture_frame.custom_minimum_size = Vector2(276, 276)
	picture_frame.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	picture_frame.add_theme_stylebox_override(
		"panel", ClassicStyle.create_box(Color("ffffff"), Color("808080"), 2)
	)
	content.add_child(picture_frame)
	picture_view = TextureRect.new()
	picture_view.custom_minimum_size = Vector2(260, 260)
	picture_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture_view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture_view.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	picture_frame.add_child(picture_view)

	text_view = TextEdit.new()
	text_view.editable = false
	text_view.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	text_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	text_view.add_theme_color_override("font_color", Color("101010"))
	text_view.add_theme_color_override("font_readonly_color", Color("101010"))

	for state in ["normal", "focus", "read_only"]:
		text_view.add_theme_stylebox_override(
			state, ClassicStyle.create_box(Color("ffffff"), Color("808080"), 1)
		)

	content.add_child(text_view)

	var content_parent := get_label().get_parent()
	content_parent.add_child(content)
	content_parent.move_child(content, 0)


func set_briefing(scenario_name: String, picture: Image, description: String) -> void:
	title = "Scenario: %s" % scenario_name
	picture_view.texture = (
		ImageTexture.create_from_image(picture) if picture != null else null
	)
	text_view.text = description.replace("\r\n", "\n").replace("\r", "\n")
	text_view.scroll_vertical = 0


func show_briefing(scenario_name: String, picture: Image, description: String) -> void:
	set_briefing(scenario_name, picture, description)
	popup_centered()
