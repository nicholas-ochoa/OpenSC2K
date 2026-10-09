class_name QueryNeighborhood
extends RefCounted
# bounded, display-only snapshot using the same tile painter as the city

@warning_ignore_start("integer_division")

const Renderer = preload("res://src/view/city_isometric_renderer.gd")
const SIZE := Vector2i(384, 384)
const RADIUS := 16
# pixels of an HD neighborhood for each view pixel
const ARTWORK_FACTOR := 4


static func render(city: CityState, point: Vector2i, palette: Sc2Palette, sprites: Sc2SpriteArchive) -> Image:
	var layers := _render_layers(city, point, palette, sprites)

	if layers == null:
		return null

	return frame_selection(apply_opacity(layers.image, layers.selected), layers.selected.get_used_rect())


# The HD neighborhood: [the area, the selected building], each at `factor`
# pixels for each view pixel and centered on the selection. The preview fades
# the area. Empty when the sprites have no HD art, or when the query shows a
# moving object.
static func render_artwork(city: CityState, point: Vector2i, palette: Sc2Palette, sprites: Sc2SpriteArchive,
		factor := ARTWORK_FACTOR) -> Array[Image]:
	var result: Array[Image] = []

	if sprites == null or sprites.high_resolution.is_empty() or city == null or city.index_of(point.x, point.y) < 0:
		return result

	if Renderer.moving_thing_visual(city, point.x, point.y, Renderer.VIEW_LARGE, 0) != null:
		return result

	# the indexed layers give the bounds and the selection mask
	var layers := _render_layers(city, point, Sc2Palette.index_encoding(), sprites)
	var context := CityGpuBuildContext.new()

	if layers == null or not context.prepare(city, palette, sprites, Renderer.VIEW_LARGE, CityViewMode.Mode.CITY, true, true,
			true, 0, false, true, 0, true, true).is_empty():
		return result

	var painted := IsometricImageRender.paint_artwork(context, layers.bounds, Color.TRANSPARENT, factor)

	if not painted.ok:
		return result

	var area: Image = painted.image
	var mask: Image = layers.selected.duplicate()
	mask.resize(area.get_width(), area.get_height(), Image.INTERPOLATE_NEAREST)
	var selected := Image.create(area.get_width(), area.get_height(), false, Image.FORMAT_RGBA8)
	selected.blit_rect_mask(area, mask, Rect2i(Vector2i.ZERO, area.get_size()), Vector2i.ZERO)
	var used := layers.selected.get_used_rect()

	for image in [area, selected]:
		result.append(frame_selection(image, used, factor))

	return result


static func _render_layers(city: CityState, point: Vector2i, palette: Sc2Palette, sprites: Sc2SpriteArchive) -> Layers:
	if city == null or city.index_of(point.x, point.y) < 0 or palette == null or sprites == null or not sprites.is_valid():
		return null

	var center := Vector2.ZERO

	for corner in Renderer.tile_polygon(city, point.x, point.y):
		center += corner / 4.0

	var bounds := Rect2i(Vector2i(center) - (SIZE / 2) - Vector2i(0, 24), SIZE)
	var image := Image.create(SIZE.x, SIZE.y, false, Image.FORMAT_RGBA8)
	var selected_image := Image.create(SIZE.x, SIZE.y, false, Image.FORMAT_RGBA8)
	var cache := {}
	var context := CityGpuBuildContext.new()

	if not context.prepare(city, palette, sprites, Renderer.VIEW_LARGE, CityViewMode.Mode.CITY, true, true, true, 0, false,
			true).is_empty():
		return null

	var site := Rect2i(point, Vector2i.ONE)
	var tile := city.building_id(point.x, point.y)
	var area := NativeCityTools.building_area(tile)

	if area > 1:
		var found := NativeCityTools.find_building_site(
			city.buildings,
			city.zones,
			point,
			tile,
			area,
			city.compass_rotation(),
			city.map_size,
		)

		if found.has_area():
			site = found

	var first := (point - Vector2i.ONE * RADIUS).max(Vector2i.ZERO)
	var last := (point + Vector2i.ONE * RADIUS).min(Vector2i.ONE * (city.map_size - 1))

	for diagonal in range(first.x + first.y, last.x + last.y + 1):
		for y in range(maxi(first.y, diagonal - last.x), mini(last.y, diagonal - first.x) + 1):
			var x := diagonal - y
			var draws := context.tile_draw_list([Vector2i(x, y)], -bounds.position)
			var selected := site.has_point(Vector2i(x, y))
			for draw: CityGpuDrawList.Draw in draws.draws:
				var source: Image = draw.image
				image.blend_rect(source, draw.source, draw.position)

				if selected:
					selected_image.blend_rect(source, draw.source, draw.position)

	# include the queried moving object in this same preview, at its map position
	var visual := Renderer.moving_thing_visual(city, point.x, point.y, Renderer.VIEW_LARGE, 0)

	if visual != null:
		# the moving object is always the queried one, so it stays fully opaque
		var moving_configuration := Renderer.view_configuration(Renderer.VIEW_LARGE)

		for target in [image, selected_image]:
			Renderer.draw_moving_thing(
				target, city, palette, sprites, cache, visual, moving_configuration, -bounds.position
			)

	var layers := Layers.new()
	layers.image = image
	layers.selected = selected_image
	layers.bounds = bounds

	return layers


static func apply_opacity(image: Image, selected_image: Image) -> Image:
	var pixels := image.get_data()

	for offset in range(0, pixels.size(), 4):
		pixels[offset + 3] = roundi(pixels[offset + 3] * 0.25)

	var faded := Image.create_from_data(image.get_width(), image.get_height(), false, Image.FORMAT_RGBA8, pixels)
	# keep the queried structure legible even behind a faded foreground building
	faded.blend_rect(selected_image, Rect2i(Vector2i.ZERO, selected_image.get_size()), Vector2i.ZERO)

	return faded


# `image` at `factor` pixels for each view pixel, moved so `selected`, in view
# pixels, is at the center.
static func frame_selection(image: Image, selected: Rect2i, factor := 1) -> Image:
	if not selected.has_area():
		return image

	# center the selected artwork. the ui applies the footprint-specific zoom
	var centered := Image.create(SIZE.x * factor, SIZE.y * factor, false, Image.FORMAT_RGBA8)
	centered.blit_rect(image, Rect2i(Vector2i.ZERO, SIZE * factor), ((SIZE / 2) - selected.get_center()) * factor)

	return centered


static func zoom_for_tile(tile_id: int) -> float:
	if tile_id >= BuildingTileIds.PLYMOUTH_ARCOLOGY and tile_id <= BuildingTileIds.LAUNCH_ARCOLOGY:
		return 2.0

	match NativeCityTools.building_area(tile_id):
		4:
			return 2.5
		2, 3:
			return 3.0
		_:
			return 3.5


# The indexed neighborhood before its selection is faded and centered.
class Layers extends RefCounted:
	var image: Image
	var selected: Image
	var bounds := Rect2i()
