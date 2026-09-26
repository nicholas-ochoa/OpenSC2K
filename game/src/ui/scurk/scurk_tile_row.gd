class_name ScurkTileRow
extends Button


func _ready() -> void:
	theme_changed.connect(_refresh_font)
	_refresh_font()


func show_tile(tile_id: int, tile_name: String, category: String, thumbnail: Texture2D) -> void:
	$Content/Row/Thumbnail.texture = PixelArtTexture.wrap(thumbnail)
	$Content/Row/Labels/Name.text = tile_name
	$Content/Row/Labels/Category.text = "%03d · %s" % [tile_id, category]
	tooltip_text = "%s\n%03d · %s" % [tile_name, tile_id, category]


func _refresh_font() -> void:
	$Content/Row/Labels/Category.add_theme_font_size_override("font_size", maxi(1, get_theme_font_size("font_size") - 2))
