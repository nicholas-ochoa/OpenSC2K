class_name ScurkContextPreview
extends Control

var artwork: Texture2D
var road: Texture2D
var neighbor: Texture2D
var footprint := 1
var show_roads := true
var show_neighbors := true


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


static func indexed_texture(pixels: PackedInt32Array, width: int, height: int, palette: Sc2Palette) -> ImageTexture:
	if width <= 0 or height <= 0 or pixels.size() != width * height or palette == null or not palette.is_valid():
		return null
	for index in pixels:
		if index < -1 or index > 255:
			return null
	var image := Image.create(width, height, false, Image.FORMAT_RGBA8)
	for y in height:
		for x in width:
			var index := pixels[y * width + x]
			image.set_pixel(x, y, palette.color(index) if index >= 0 else Color.TRANSPARENT)
	return ImageTexture.create_from_image(image)


func _draw() -> void:
	var scale := minf(size.x / 320.0, size.y / 240.0)
	var origin := Vector2(size.x * 0.5, size.y * 0.67)
	draw_set_transform(origin, 0, Vector2.ONE * scale)
	for depth in range(-6, 7):
		for x in range(-3, 4):
			var y := depth - x
			if y < -3 or y > 3:
				continue
			var center := Vector2((x - y) * 16, (x + y) * 8)
			var diamond := PackedVector2Array([center + Vector2(0, -8), center + Vector2(16, 0), center + Vector2(0, 8), center + Vector2(-16, 0)])
			draw_colored_polygon(diamond, Color("527638") if (x + y) % 2 == 0 else Color("608441"))
			draw_polyline(diamond + PackedVector2Array([diamond[0]]), Color("43602f"), 0.5)
	for depth in range(-6, 7):
		for x in range(-3, 4):
			var y := depth - x
			if y < -3 or y > 3:
				continue
			var center := Vector2((x - y) * 16, (x + y) * 8)
			if show_roads and y == 2 and road != null:
				_draw_sprite(road, center + Vector2(0, 8))
			if show_neighbors and neighbor != null and y == -2 and x in [-2, 2]:
				_draw_sprite(neighbor, center + Vector2(0, 8))
			if x == 0 and y == 0 and artwork != null:
				_draw_sprite(artwork, Vector2(0, footprint * 8))


func _draw_sprite(texture: Texture2D, base: Vector2) -> void:
	draw_texture(texture, base - Vector2(texture.get_width() * 0.5, texture.get_height()))
