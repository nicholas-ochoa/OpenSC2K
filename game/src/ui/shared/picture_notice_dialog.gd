class_name PictureNoticeDialog
extends AcceptDialog

var picture_view: TextureRect
var message_label: Label


func _ready() -> void:
	hide()
	theme = AppUiTheme.current()
	get_label().visible = false
	picture_view = $Layout/PictureFrame/Picture
	message_label = $Layout/Message


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
	picture_view.texture = null if picture == null else PixelArtTexture.wrap(ImageTexture.create_from_image(picture))


func show_message(message_text: String, normalize_newlines := false) -> void:
	message_label.text = (
		_normalized_text(message_text) if normalize_newlines else message_text
	)
	popup_centered()


func _normalized_text(value: String) -> String:
	return value.replace("\r\n", "\n").replace("\r", "\n")
