class_name ScenarioIntroDialog
extends AcceptDialog

var picture_view: TextureRect
var text_view: Label
var text_scroll: ScrollContainer


func _ready() -> void:
	# visible in the editor, closed at startup
	hide()
	theme = AppUiTheme.current()
	get_label().visible = false
	picture_view = $Layout/PictureFrame/Picture
	text_scroll = $Layout/TextScroll
	text_view = $Layout/TextScroll/Text


func set_briefing(scenario_name: String, picture: Image, description: String) -> void:
	title = "Scenario: %s" % scenario_name
	picture_view.texture = (
		ImageTexture.create_from_image(picture) if picture != null else null
	)
	var briefing := description.replace("\r\n", "\n").replace("\r", "\n").strip_edges()
	text_view.text = briefing.trim_prefix("Extended Description:").strip_edges()
	text_scroll.scroll_vertical = 0


func show_briefing(scenario_name: String, picture: Image, description: String) -> void:
	set_briefing(scenario_name, picture, description)
	popup_centered()
