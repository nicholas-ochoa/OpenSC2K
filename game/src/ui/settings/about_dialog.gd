class_name AboutDialog
extends AcceptDialog

var artwork: Control
var picture: TextureRect
var project_text: Label


func _ready() -> void:
	get_label().autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	artwork = $Artwork
	picture = $Artwork/Panel/Picture
	project_text = $Artwork/Panel/ProjectText


func set_control_graphics(graphics: CityUiGraphics) -> void:
	var image: Image = null if graphics == null else graphics.presentation.get("ABOUT.BMP")
	picture.texture = null if image == null else ImageTexture.create_from_image(image)
	artwork.visible = image != null
	get_label().visible = image == null
	min_size = Vector2i(560, 350 if image != null else 250)
	reset_size()
