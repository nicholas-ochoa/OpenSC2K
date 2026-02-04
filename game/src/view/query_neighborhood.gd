class_name QueryNeighborhood
extends RefCounted
# bounded, display-only snapshot using the same tile painter as the city
const Renderer = preload("res://src/view/city_isometric_renderer.gd")
const SIZE := Vector2i(256, 240)
const RADIUS := 6

static func render(city: CityState, point: Vector2i, palette: Sc2Palette, sprites: Sc2SpriteArchive) -> Image:
	if city == null or city.index_of(point.x, point.y) < 0 or palette == null or sprites == null or not sprites.is_valid():
		return null
	var config := Renderer.view_configuration(Renderer.VIEW_LARGE).duplicate()
	var center := Vector2.ZERO
	for corner in Renderer.tile_polygon(city, point.x, point.y):
		center += corner / 4.0
	var origin := int(config.side_margin) + city.map_size * int(config.half_width)
	var bounds := Rect2i(Vector2i(center) - SIZE / 2 - Vector2i(0, 24), SIZE)
	config.top_margin = int(config.top_margin) - bounds.position.y
	var image := Image.create(SIZE.x, SIZE.y, false, Image.FORMAT_RGBA8)
	var selected_image := Image.create(SIZE.x, SIZE.y, false, Image.FORMAT_RGBA8)
	var cache := {}
	var site := Rect2i(point, Vector2i.ONE)
	var tile := city.building_id(point.x, point.y)
	var area := DemolishCommand._building_area(tile)
	if area > 1:
		var found := DemolishCommand._find_building_site(city.buildings, city.zones, point, tile, area, city.compass_rotation(), city.map_size)
		if found.has_area():
			site = found
	var first := (point - Vector2i.ONE * RADIUS).max(Vector2i.ZERO)
	var last := (point + Vector2i.ONE * RADIUS).min(Vector2i.ONE * (city.map_size - 1))
	for diagonal in range(first.x + first.y, last.x + last.y + 1):
		for y in range(maxi(first.y, diagonal - last.x), mini(last.y, diagonal - first.x) + 1):
			var x := diagonal - y
			var draws := CityGpuDrawList.new()
			Renderer._draw_tile(draws, city, palette, sprites, cache, config, origin - bounds.position.x, x, y, 0, false, true)
			var selected := site.has_point(Vector2i(x, y))
			for draw: Dictionary in draws.draws:
				var source: Image = draw.image
				image.blend_rect(source, draw.source, draw.position)
				if selected:
					selected_image.blend_rect(source, draw.source, draw.position)
	return frame_selection(apply_opacity(image, selected_image), selected_image.get_used_rect())


static func apply_opacity(image: Image, selected_image: Image) -> Image:
	var pixels := image.get_data()
	for offset in range(0, pixels.size(), 4):
		pixels[offset + 3] = roundi(pixels[offset + 3] * 0.25)
	var faded := Image.create_from_data(image.get_width(), image.get_height(), false, Image.FORMAT_RGBA8, pixels)
	# keep the queried structure legible even behind a faded foreground building
	faded.blend_rect(selected_image, Rect2i(Vector2i.ZERO, selected_image.get_size()), Vector2i.ZERO)
	return faded


static func frame_selection(image: Image, selected: Rect2i) -> Image:
	if not selected.has_area():
		return image
	# center the selected artwork. the ui draws this snapshot at exactly 300%
	var centered := Image.create(SIZE.x, SIZE.y, false, Image.FORMAT_RGBA8)
	centered.blit_rect(image, Rect2i(Vector2i.ZERO, SIZE), SIZE / 2 - selected.get_center())
	return centered
