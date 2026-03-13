class_name ScenarioIntroDialog
extends AcceptDialog

var picture_view: TextureRect
var text_view: TextEdit


func _ready() -> void:
	theme = ClassicUiStyle.create_dialog_theme()
	get_label().visible = false
	picture_view = $Layout/PictureFrame/Picture
	text_view = $Layout/Text


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
