class_name ScurkTextureControl
extends GridContainer

signal texture_selected(index: int)

const MINIMUM_SIZE := Vector2(280, 96)
const BUTTON_SIZE := 32
const BUTTON_GAP := 2

var palette: Sc2Palette
var patterns: Array[PackedInt32Array] = []
var buttons: Array[Button] = []
var textures: Array[ImageTexture] = []
var pattern_names := PackedStringArray():
	set(value):
		pattern_names = value
		_refresh_tooltips()
var selected_color_index := 0
var selected_index := 0
var palette_cycle_ticks := 0
var texture_state: Array = []


func _init() -> void:
	custom_minimum_size = MINIMUM_SIZE
	columns = 7
	add_theme_constant_override("h_separation", BUTTON_GAP)
	add_theme_constant_override("v_separation", BUTTON_GAP)
	resized.connect(_update_columns)


func set_palette(value: Sc2Palette) -> void:
	palette = value
	_refresh_textures()


func set_patterns(value: Array[PackedInt32Array]) -> void:
	for button in buttons:
		remove_child(button)
		button.free()
	buttons.clear()
	textures.clear()
	patterns.clear()
	texture_state.clear()
	var group := ButtonGroup.new()

	for pattern in value:
		var index := patterns.size()
		patterns.append(pattern.duplicate())
		var button := Button.new()
		button.toggle_mode = true
		button.button_group = group
		button.expand_icon = true
		button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
		button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		button.custom_minimum_size = Vector2(BUTTON_SIZE, BUTTON_SIZE)
		button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		button.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		for state in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
			button.add_theme_color_override("icon_%s_color" % state, Color.WHITE)
		button.pressed.connect(_select_button.bind(index))
		var texture := ImageTexture.create_from_image(Image.create(8, 8, false, Image.FORMAT_RGBA8))
		button.icon = PixelArtTexture.wrap(texture)
		textures.append(texture)
		buttons.append(button)
		add_child(button)

	set_selected(selected_index)
	_update_columns()
	_refresh_tooltips()
	_refresh_textures()


func set_selected_color(index: int) -> void:
	selected_color_index = clampi(index, 0, 255)
	_refresh_textures()


func set_selected(index: int) -> void:
	selected_index = clampi(index, 0, maxi(0, patterns.size() - 1))
	if not buttons.is_empty():
		buttons[selected_index].button_pressed = true


func _select_button(index: int) -> void:
	selected_index = index
	texture_selected.emit(index)


func _update_columns() -> void:
	var count := maxi(1, patterns.size())
	var fitting_columns := maxi(1, floori((size.x + BUTTON_GAP) / (BUTTON_SIZE + BUTTON_GAP)))
	columns = mini(count, fitting_columns)


func cell_rect(index: int) -> Rect2:
	return buttons[index].get_rect()


func index_at(position: Vector2) -> int:
	for index in buttons.size():
		if cell_rect(index).has_point(position):
			return index
	return -1


func _refresh_tooltips() -> void:
	for index in buttons.size():
		buttons[index].tooltip_text = _texture_tooltip(index)


func _texture_tooltip(index: int) -> String:
	if index == 0:
		return "Solid color"
	if index == 1:
		return "Dithered color and transparency"
	if index == 2:
		return "Transparent"
	if index < pattern_names.size():
		return pattern_names[index]
	return "Original SCURK texture %d" % (index - 2)


func set_cycle_tick(tick: int) -> void:
	palette_cycle_ticks = tick
	_refresh_textures()


func _refresh_textures() -> void:
	var valid_palette := palette != null and palette.is_valid()
	var animation_map := palette.scurk_animation_index_map(palette_cycle_ticks) if valid_palette else PackedInt32Array()
	var state: Array = [selected_color_index,
		hash(palette.colors) if valid_palette else 0, hash(animation_map)]
	if texture_state == state:
		return
	texture_state = state
	for index in patterns.size():
		var pattern := patterns[index]
		var image := Image.create(8, 8, false, Image.FORMAT_RGBA8)
		if pattern.size() == 64:
			for y in 8:
				for x in 8:
					var palette_index := ScurkPaintOptions.resolve_texture_value(pattern[y * 8 + x], selected_color_index)
					var color := Color.TRANSPARENT if palette_index < 0 else (palette.color(animation_map[palette_index]) if valid_palette else Color.MAGENTA)
					image.set_pixel(x, y, color)
		textures[index].update(image)
