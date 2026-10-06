class_name CityLifeAtlas
extends RefCounted
## Pack occupied world squares into one reusable artwork/emission atlas. Empty
## city pixels never need clearing or uploading, and all squares share a draw batch.
@warning_ignore_start("integer_division")

const EDGE := 64
var image: Image
var texture: ImageTexture
var emission: Image
var emission_texture: ImageTexture
var destinations: Array[Rect2i] = []
var sources: Array[Rect2i] = []
var capacity := 0


func compose(bounds: Rect2i, entries: Array[Dictionary], night: bool) -> void:
	var squares: Dictionary[Vector2i, Array] = {}
	for entry in entries:
		var clipped := Rect2i(entry.origin, entry.sprite.get_size()).intersection(bounds)
		if not clipped.has_area():
			continue
		var first := (clipped.position - bounds.position) / EDGE
		var last := (clipped.end - Vector2i.ONE - bounds.position) / EDGE
		for y in range(first.y, last.y + 1):
			for x in range(first.x, last.x + 1):
				var square := Vector2i(x, y)
				if not squares.has(square):
					squares[square] = []
				# Input is already in painter order, including partially faded figures.
				squares[square].append(entry)
	if squares.size() > capacity:
		capacity = maxi(16, nearest_po2(squares.size()))
		var columns := 16 if capacity <= 1024 else 64
		image = Image.create(columns * EDGE, maxi(1, ceili(float(capacity) / columns)) * EDGE, false, Image.FORMAT_RGBA8)
		texture = ImageTexture.create_from_image(image)
	if image == null:
		capacity = 16
		image = Image.create(16 * EDGE, EDGE, false, Image.FORMAT_RGBA8)
		texture = ImageTexture.create_from_image(image)
	if night and (emission == null or emission.get_size() != image.get_size()):
		emission = Image.create(image.get_width(), image.get_height(), false, Image.FORMAT_RGBA8)
		emission_texture = ImageTexture.create_from_image(emission)
	image.fill(Color.TRANSPARENT)
	if night:
		emission.fill(Color.TRANSPARENT)
	destinations.clear()
	sources.clear()
	var columns := image.get_width() / EDGE
	for square in squares:
		var slot := destinations.size()
		var world := Rect2i(bounds.position + square * EDGE, Vector2i.ONE * EDGE).intersection(bounds)
		var target := Rect2i(Vector2i(slot % columns, slot / columns) * EDGE, world.size)
		destinations.append(Rect2i(world.position - bounds.position, world.size))
		sources.append(target)
		for entry: Dictionary in squares[square]:
			CityLifeCanvas.stamp(image, world.position - target.position, entry.sprite, entry.origin,
				entry.occluders, entry.opacity, emission if night else null, entry.lamps, target)
	texture.update(image)
	if night:
		emission_texture.update(emission)
