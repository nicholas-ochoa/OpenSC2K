class_name PictureNoticeDialog
extends AcceptDialog

const ClassicStyle = preload("res://src/ui/shared/classic_ui_style.gd")

var picture_view: TextureRect
var message_label: Label


func _ready() -> void:
	min_size = Vector2i(520, 230)
	exclusive = true
	get_ok_button().text = "OK"
	get_label().visible = false

	var layout := HBoxContainer.new()
	layout.custom_minimum_size = Vector2(470, 130)
	layout.add_theme_constant_override("separation", 14)

	var picture_frame := PanelContainer.new()
	picture_frame.custom_minimum_size = Vector2(171, 116)
	picture_frame.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	picture_frame.add_theme_stylebox_override(
		"panel", ClassicStyle.create_box(Color("ffffff"), Color("808080"), 2)
	)
	layout.add_child(picture_frame)

	picture_view = TextureRect.new()
	picture_view.custom_minimum_size = Vector2(155, 100)
	picture_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture_view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture_view.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	picture_frame.add_child(picture_view)

	message_label = Label.new()
	message_label.custom_minimum_size = Vector2(280, 100)
	message_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	layout.add_child(message_label)

	var content := get_label().get_parent()
	content.add_child(layout)
	content.move_child(layout, 0)


func configure(
	dialog_name: String,
	dialog_title: String,
	image_name: String,
	message_name: String,
	picture: Image,
	message_text: String
) -> void:
	name = dialog_name
	title = dialog_title
	picture_view.name = image_name
	message_label.name = message_name
	set_picture(picture)
	message_label.text = _normalized_text(message_text)


func set_picture(picture: Image) -> void:
	picture_view.texture = null if picture == null else ImageTexture.create_from_image(picture)


func show_message(message_text: String, normalize_newlines := false) -> void:
	message_label.text = (
		_normalized_text(message_text) if normalize_newlines else message_text
	)
	popup_centered()


func _normalized_text(value: String) -> String:
	return value.replace("\r\n", "\n").replace("\r", "\n")
