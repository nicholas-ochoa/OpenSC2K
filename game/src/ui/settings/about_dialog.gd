class_name AboutDialog
extends AcceptDialog

var artwork: Control
var picture: TextureRect
var project_text: Label


func _ready() -> void:
	title = "About OpenSC2K"
	get_label().autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialog_text = (
		"OpenSC2K is an open-source reimplementation of SimCity 2000 for Windows 95."
	)
	min_size = Vector2i(560, 250)
	exclusive = true
	artwork = CenterContainer.new()
	artwork.custom_minimum_size = Vector2(480, 299)
	artwork.visible = false
	var panel := Control.new()
	panel.custom_minimum_size = Vector2(480, 299)
	artwork.add_child(panel)
	picture = TextureRect.new()
	picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(picture)
	project_text = Label.new()
	project_text.position = Vector2(245, 94)
	project_text.size = Vector2(223, 190)
	project_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	project_text.add_theme_font_size_override("font_size", 14)
	project_text.add_theme_color_override("font_color", Color("101010"))
	project_text.text = dialog_text
	panel.add_child(project_text)
	get_label().get_parent().add_child(artwork)


func set_control_graphics(graphics: CityUiGraphics) -> void:
	var image: Image = null if graphics == null else graphics.presentation.get("ABOUT.BMP")
	picture.texture = null if image == null else ImageTexture.create_from_image(image)
	artwork.visible = image != null
	get_label().visible = image == null
	min_size = Vector2i(560, 350 if image != null else 250)
	reset_size()
