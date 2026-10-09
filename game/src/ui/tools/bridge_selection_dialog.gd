class_name BridgeSelectionDialog
extends ConfirmationDialog

signal choice_requested(index: int)


@warning_ignore_start("integer_division")

const Tiles = preload("res://src/tools/shared/building_tile_ids.gd")
const Numbers = preload("res://src/ui/shared/display_number_format.gd")
const PREVIEW_SIZE := Vector2i(240, 140)
# the largest bridge art in a preview
const PREVIEW_ART_SIZE := Vector2i(228, 128)
# pixels of an HD preview for each interface pixel
const ARTWORK_DENSITY := 4

var choice_buttons: Array[Button] = []
var preview_controls: Array[TextureRect] = []
var choice_labels: Array[Label] = []
var preview_palette: Sc2Palette
var preview_sprites: Sc2SpriteArchive
# HD previews by [request type, bridge type, palette, sprites]
var _artwork_previews: Dictionary = {}


func _ready() -> void:
	hide()
	theme = AppUiTheme.current()
	get_ok_button().visible = false

	for child in $Choices.get_children():
		var button := child as Button
		button.pressed.connect(choice_requested.emit.bind(choice_buttons.size()))
		choice_buttons.append(button)
		preview_controls.append(button.get_node("Column/Preview"))
		choice_labels.append(button.get_node("Column/Caption"))


func set_choices(
	span_length: int,
	request_type: String,
	choices: Array[BridgeChoice],
	free_mode: bool,
) -> void:
	var span_units := (
		"2 by 2 water sections" if request_type == "highway" else "water tiles"
	)
	dialog_text = tr("Select a bridge for %d %s.") % [span_length, tr(span_units)]
	var cost_unit := (
		"2 by 2 water section" if request_type == "highway" else "water tile"
	)

	for choice_index in choice_buttons.size():
		var choice_button := choice_buttons[choice_index]
		choice_button.visible = choice_index < choices.size()

		if not choice_button.visible:
			continue

		var choice: BridgeChoice = choices[choice_index]
		choice_button.text = (
			"%s\nFree in Place & Print" % choice.name
			if free_mode
			else tr("%s\n$%s total\n$%s for each %s") % [
				tr(choice.name),
				Numbers.format(int(choice.cost)),
				Numbers.format(int(choice.cost_per_tile)),
				tr(cost_unit),
			]
		)
		choice_button.tooltip_text = "Build %s" % choice.name
		var preview := preview_image(request_type, int(choice.type))
		preview_controls[choice_index].texture = preview if preview is HdArtworkTexture else PixelArtTexture.wrap(preview)
		preview_controls[choice_index].texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		choice_labels[choice_index].text = choice_button.text


func show_choices(
	span_length: int,
	request_type: String,
	choices: Array[BridgeChoice],
	free_mode: bool,
) -> void:
	set_choices(span_length, request_type, choices, free_mode)
	popup_centered()


func preview_image(request_type: String, bridge_type: int) -> Texture2D:
	if preview_palette == null or preview_sprites == null:
		return null

	var tiles: Array[PreviewTile] = []
	var highway := request_type == "highway"
	var count := 8 if highway else 12

	# use the same native grid as the city renderer. include a water apron
	for x in range(-2, count + 2):
		for y in range(-2, 4 if highway else 3):
			_append_preview_tile(tiles, 1270, _preview_baseline(x, y))

	if highway and bridge_type == HighwayCommand.BRIDGE_REINFORCED:
		for section in 4:
			_append_preview_tile(tiles, 1000 + (Tiles.REINFORCED_HIGHWAY_BRIDGE if section % 2 == 0 else Tiles.HIGHWAY_BRIDGE),
				_preview_baseline(section * 2, 0)
					+ Vector2i(0, CityIsometricRenderer.HALF_HEIGHT * 2), true)
	else:
		for x in count:
			for y in (2 if highway else 1):
				var tile := Tiles.HIGHWAY_STRAIGHT_2 if highway else NativeCityTools.bridge_tile(bridge_type, count + 2, x + 1, 1)
				_append_preview_tile(tiles, 1000 + tile, _preview_baseline(x, y), not highway)

	if not highway:
		# these are the two graded road banks written for an eastward span
		for bank in [Vector2i(-1, 3), Vector2i(count, 1)]:
			var baseline := _preview_baseline(bank.x, 0)
			var terrain_sprite := CityIsometricRenderer.terrain_sprite_id(bank.y, false)
			_append_preview_tile(tiles, terrain_sprite, baseline)
			_append_preview_tile(tiles, 1000 + Tiles.ROAD_STRAIGHT_1 + int(NetworkCommand.NETWORK_SLOPE_SHAPES[bank.y]), baseline)

	var bounds := Rect2i()

	for tile in tiles:
		bounds = bounds.merge(Rect2i(tile.position, tile.image.get_size()))

	if not preview_sprites.high_resolution.is_empty():
		return _artwork_preview(request_type, bridge_type, tiles, bounds)

	var assembled := Image.create(maxi(1, bounds.size.x), maxi(1, bounds.size.y), false, Image.FORMAT_RGBA8)
	assembled.fill(Color.TRANSPARENT)

	for tile in tiles:
		assembled.blend_rect(tile.image, Rect2i(Vector2i.ZERO, tile.image.get_size()), tile.position - bounds.position)

	var factor := minf(1.0, minf(float(PREVIEW_ART_SIZE.x) / assembled.get_width(),
		float(PREVIEW_ART_SIZE.y) / assembled.get_height()))

	if factor < 1.0:
		assembled.resize(
			maxi(1, roundi(assembled.get_width() * factor)),
			maxi(1, roundi(assembled.get_height() * factor)),
			Image.INTERPOLATE_NEAREST,
		)

	var output := Image.create(PREVIEW_SIZE.x, PREVIEW_SIZE.y, false, Image.FORMAT_RGBA8)
	output.fill(Color.TRANSPARENT)
	output.blend_rect(assembled, Rect2i(Vector2i.ZERO, assembled.get_size()), (output.get_size() - assembled.get_size()) / 2)

	return ImageTexture.create_from_image(output)


# The preview with HD art, at ARTWORK_DENSITY pixels for each interface pixel.
func _artwork_preview(request_type: String, bridge_type: int, tiles: Array[PreviewTile], bounds: Rect2i) -> Texture2D:
	var key := [request_type, bridge_type, preview_palette, preview_sprites]

	if _artwork_previews.has(key):
		return _artwork_previews[key]

	# the indexed preview fits PREVIEW_ART_SIZE; the HD art fills the same place
	var fit := minf(1.0, minf(float(PREVIEW_ART_SIZE.x) / bounds.size.x, float(PREVIEW_ART_SIZE.y) / bounds.size.y))
	var density := fit * ARTWORK_DENSITY
	var assembled := Image.create(maxi(1, roundi(bounds.size.x * density)), maxi(1, roundi(bounds.size.y * density)), false,
		Image.FORMAT_RGBA8)
	assembled.fill(Color.TRANSPARENT)

	for tile in tiles:
		var art: HdSprite = preview_sprites.high_resolution.get(tile.sprite_id)
		var size := tile.image.get_size()
		var top := tile.position.y

		if art != null:
			# HD art can be taller than its sprite. It keeps the bottom edge
			top += size.y - art.height
			size.y = art.height

		var target := Vector2i((Vector2(size) * density).round()).max(Vector2i.ONE)
		var image: Image

		if art != null:
			image = HdSprite.scaled(art.image, target)

			if tile.flip:
				image.flip_x()
		else:
			image = tile.image.duplicate()
			image.resize(target.x, target.y, Image.INTERPOLATE_NEAREST)

		var position := Vector2i((Vector2(Vector2i(tile.position.x, top) - bounds.position) * density).round())
		assembled.blend_rect(image, Rect2i(Vector2i.ZERO, image.get_size()), position)

	var output := Image.create(PREVIEW_SIZE.x * ARTWORK_DENSITY, PREVIEW_SIZE.y * ARTWORK_DENSITY, false, Image.FORMAT_RGBA8)
	output.fill(Color.TRANSPARENT)
	output.blend_rect(assembled, Rect2i(Vector2i.ZERO, assembled.get_size()), (output.get_size() - assembled.get_size()) / 2)
	var texture := HdArtworkTexture.create(output, PREVIEW_SIZE)
	_artwork_previews[key] = texture

	return texture


func _append_preview_tile(tiles: Array[PreviewTile], sprite_id: int, baseline: Vector2i, flip := false) -> void:
	var sprite = preview_sprites.find_sprite(sprite_id)

	if sprite == null:
		return

	var rendered := sprite.create_image(preview_palette)

	if rendered.ok:
		var image: Image = rendered.image

		if flip:
			image.flip_x()

		var tile := PreviewTile.new(image, baseline - Vector2i(image.get_width() / 2, image.get_height() - 1))
		tile.sprite_id = sprite_id
		tile.flip = flip
		tiles.append(tile)


static func _preview_baseline(x: int, y: int) -> Vector2i:
	return Vector2i((x - y) * CityIsometricRenderer.HALF_WIDTH, (x + y) * CityIsometricRenderer.HALF_HEIGHT)


class PreviewTile extends RefCounted:
	var image: Image
	var position: Vector2i
	var sprite_id := -1
	var flip := false

	func _init(pixels: Image, origin: Vector2i) -> void:
		image = pixels
		position = origin
