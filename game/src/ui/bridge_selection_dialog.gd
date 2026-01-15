class_name BridgeSelectionDialog
extends ConfirmationDialog

const Numbers = preload("res://src/ui/display_number_format.gd")

signal choice_requested(index: int)

var choice_buttons: Array[Button] = []
var preview_palette: Sc2Palette
var preview_sprites: Sc2SpriteArchive


func _ready() -> void:
	title = "Select Bridge"
	dialog_text = "Select a bridge type."
	min_size = Vector2i(760, 350)
	exclusive = true
	get_ok_button().visible = false
	get_cancel_button().text = "Cancel"

	var choices := HBoxContainer.new()
	choices.set_anchors_preset(Control.PRESET_TOP_WIDE)
	choices.offset_left = 16
	choices.offset_top = 72
	choices.offset_right = -16
	choices.offset_bottom = 290
	choices.add_theme_constant_override("separation", 8)
	add_child(choices)
	for choice_index in 3:
		var choice_button := Button.new()
		choice_button.custom_minimum_size = Vector2(230, 210)
		choice_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		choice_button.pressed.connect(choice_requested.emit.bind(choice_index))
		choices.add_child(choice_button)
		choice_buttons.append(choice_button)


func set_choices(
	span_length: int,
	request_type: String,
	choices: Array,
	free_mode: bool,
) -> void:
	var span_units := (
		"2 by 2 water sections" if request_type == "highway" else "water tiles"
	)
	dialog_text = "Select a bridge for %d %s." % [span_length, span_units]
	var cost_unit := (
		"2 by 2 water section" if request_type == "highway" else "water tile"
	)
	for choice_index in choice_buttons.size():
		var choice_button := choice_buttons[choice_index]
		choice_button.visible = choice_index < choices.size()
		if not choice_button.visible:
			continue
		var choice: Dictionary = choices[choice_index]
		choice_button.text = (
			"%s\nFree in Place & Print" % choice.get("name", "Bridge")
			if free_mode
			else "%s\n$%s total\n$%s for each %s" % [
				choice.get("name", "Bridge"),
				Numbers.format(int(choice.get("cost", 0))),
				Numbers.format(int(choice.get("cost_per_tile", 0))),
				cost_unit,
			]
		)
		choice_button.tooltip_text = "Build %s" % choice.get("name", "bridge")
		choice_button.icon = preview_image(request_type, int(choice.get("type", 2)))
		choice_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		choice_button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP



func show_choices(
	span_length: int,
	request_type: String,
	choices: Array,
	free_mode: bool,
) -> void:
	set_choices(span_length, request_type, choices, free_mode)
	popup_centered()


func preview_image(request_type: String, bridge_type: int) -> Texture2D:
	if preview_palette == null or preview_sprites == null:
		return null
	var tiles: Array[Dictionary] = []
	var highway := request_type == "highway"
	var count := 8 if highway else 11
	for x in count:
		for y in (2 if highway else 1):
			_append_preview_tile(tiles, 1270, Vector2i(20 + (x - y) * 16, 44 + (x + y) * 8))
	if highway and bridge_type == HighwayCommand.BRIDGE_REINFORCED:
		for section in 4:
			_append_preview_tile(tiles, 1000 + 0x5d + (14 if section % 2 == 0 else 13), Vector2i(36 + section * 32, 40 + section * 16))
	else:
		for x in count:
			for y in (2 if highway else 1):
				var tile := 0x49 if highway else NetworkCommand._bridge_tile(bridge_type, count, x, 1)
				_append_preview_tile(tiles, 1000 + tile, Vector2i(20 + (x - y) * 16, 30 + (x + y) * 8))
	var bounds := Rect2i()
	for tile in tiles:
		bounds = bounds.merge(Rect2i(tile.position, tile.image.get_size()))
	var assembled := Image.create(maxi(1, bounds.size.x), maxi(1, bounds.size.y), false, Image.FORMAT_RGBA8)
	assembled.fill(Color.TRANSPARENT)
	for tile in tiles:
		assembled.blend_rect(tile.image, Rect2i(Vector2i.ZERO, tile.image.get_size()), tile.position - bounds.position)
	var factor := minf(1.0, minf(228.0 / assembled.get_width(), 128.0 / assembled.get_height()))
	if factor < 1.0:
		assembled.resize(maxi(1, roundi(assembled.get_width() * factor)), maxi(1, roundi(assembled.get_height() * factor)), Image.INTERPOLATE_NEAREST)
	var output := Image.create(240, 140, false, Image.FORMAT_RGBA8)
	output.fill(Color.TRANSPARENT)
	output.blend_rect(assembled, Rect2i(Vector2i.ZERO, assembled.get_size()), (output.get_size() - assembled.get_size()) / 2)
	return ImageTexture.create_from_image(output)


func _append_preview_tile(tiles: Array[Dictionary], sprite_id: int, baseline: Vector2i) -> void:
	var sprite = preview_sprites.find_sprite(sprite_id)
	if sprite == null:
		return
	var rendered: Dictionary = sprite.create_image(preview_palette)
	if rendered.get("ok", false):
		var image: Image = rendered.image
		tiles.append({"image": image, "position": baseline - Vector2i(image.get_width() / 2, image.get_height() - 1)})
