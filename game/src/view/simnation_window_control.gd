class_name SimNationWindowControl
extends Control

const LOGICAL_SIZE := Vector2(204.0, 160.0)
const SPRITE_SIZE := Vector2(128.0, 64.0)
const SPRITE_ROW_COUNT := 6
const NEIGHBOR_COUNT := 4
const MISC_NATIONAL_POPULATION := 0x0050
const MISC_NEIGHBORS := 0x06d8
const NEIGHBOR_STRIDE := 0x10
const MISC_TILE_COUNTS := 0x01f0
const MISC_ARCOLOGY_POPULATION := 0x1020
const MISC_NORMAL_POPULATION := 0x102c
const FIRST_ARCOLOGY := 0xfb
const LAST_ARCOLOGY := 0xfe
const NEIGHBOR_NAME_STRING_BASE := 0x0223
const DEFAULT_NATIONAL_FORMAT := "Nat. Pop: %lu000"
const BACKGROUND_COLOR := Color8(75, 39, 11)
const SPRITE_POSITIONS := [
	Vector2(38.0, 31.0),
	Vector2(-26.0, -1.0),
	Vector2(102.0, -1.0),
	Vector2(102.0, 63.0),
	Vector2(-26.0, 63.0),
]
const LABEL_POSITIONS := [
	Vector2(100.0, 75.0),
	Vector2(40.0, 39.0),
	Vector2(160.0, 39.0),
	Vector2(160.0, 100.0),
	Vector2(40.0, 100.0),
]
const NATIONAL_LABEL_POSITION := Vector2(100.0, 143.0)

var city: CityState
var sprite_sheet: Texture2D
var neighbor_names := {}
var national_format := DEFAULT_NATIONAL_FORMAT
var display_font: SystemFont


func _init() -> void:
	custom_minimum_size = Vector2(408, 320)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	display_font = SystemFont.new()
	display_font.font_names = PackedStringArray(["Times New Roman", "Times", "serif"])
	display_font.font_weight = 700


func set_city(value: CityState) -> void:
	city = value
	queue_redraw()


func set_sprite_sheet(source: Image) -> void:
	var prepared := prepare_sprite_sheet(source)
	sprite_sheet = null if prepared == null else ImageTexture.create_from_image(prepared)
	queue_redraw()


func set_neighbor_names(value: Dictionary) -> void:
	neighbor_names = value.duplicate()
	queue_redraw()


func set_national_format(value: String) -> void:
	national_format = value if not value.is_empty() else DEFAULT_NATIONAL_FORMAT
	queue_redraw()


func refresh() -> void:
	queue_redraw()


static func snapshot(value_city: CityState) -> Dictionary:
	if value_city == null or not value_city.is_valid():
		return {"ok": false, "error": "city is invalid"}

	var neighbors: Array[Dictionary] = []

	for index in NEIGHBOR_COUNT:
		var offset := MISC_NEIGHBORS + index * NEIGHBOR_STRIDE
		var name_index := _to_i16(value_city.document.misc_u32(offset))
		neighbors.append({
			"index": index,
			"name_index": name_index,
			"name_resource_id": (
				0 if name_index == 0 else NEIGHBOR_NAME_STRING_BASE + name_index
			),
			"population": value_city.document.misc_u32(offset + 4),
			"value": value_city.document.misc_u32(offset + 8),
			"fame": value_city.document.misc_u32(offset + 12),
		})

	var arcology_tiles := 0

	for tile_id in range(FIRST_ARCOLOGY, LAST_ARCOLOGY + 1):
		arcology_tiles += value_city.document.misc_i32(MISC_TILE_COUNTS + tile_id * 4)

	var arcology_count := _divide_toward_zero(arcology_tiles, 16)
	var arcology_adjustment := 0

	if arcology_count > 140:
		arcology_adjustment = (arcology_count * 5 - 700) * 4000

	var normal_population := value_city.document.misc_u32(MISC_NORMAL_POPULATION)
	var arcology_population := value_city.document.misc_u32(MISC_ARCOLOGY_POPULATION)

	return {
		"ok": true,
		"city_name": value_city.city_name(),
		"normal_population": normal_population,
		"arcology_population": arcology_population,
		"arcology_count": arcology_count,
		"arcology_adjustment": arcology_adjustment,
		"display_population": normal_population + arcology_population + arcology_adjustment,
		"national_population": value_city.document.misc_u32(MISC_NATIONAL_POPULATION),
		"compass": value_city.compass_rotation(),
		"neighbors": neighbors,
		"error": "",
	}


static func display_neighbor_indices(compass: int) -> PackedInt32Array:
	var rotation := compass & 3

	return PackedInt32Array([
		(rotation + 2) & 3,
		(rotation - 1) & 3,
		rotation,
		(rotation + 1) & 3,
	])


static func sprite_index(population: int, ocean: bool) -> int:
	if population == 0 and ocean:
		return 0

	if population < 2000:
		return 1

	if population < 10000:
		return 2

	if population < 50000:
		return 3

	if population < 100000:
		return 4

	return 5


static func national_population_text(format_string: String, population: int) -> String:
	var text := format_string if not format_string.is_empty() else DEFAULT_NATIONAL_FORMAT
	text = text.replace("%lu", str(population))
	text = text.replace("%ld", str(population))
	text = text.replace("%u", str(population))
	text = text.replace("%d", str(population))

	return text


static func prepare_sprite_sheet(source: Image) -> Image:
	if source == null or source.is_empty():
		return null

	if (
		source.get_width() < int(SPRITE_SIZE.x)
		or source.get_height() < int(SPRITE_SIZE.y * SPRITE_ROW_COUNT)
	):
		return null

	var prepared := source.duplicate()
	prepared.convert(Image.FORMAT_RGBA8)

	for y in int(SPRITE_SIZE.y * SPRITE_ROW_COUNT):
		for x in int(SPRITE_SIZE.x):
			var color: Color = prepared.get_pixel(x, y)

			if color.r == 0.0 and color.g == 0.0 and color.b == 0.0:
				color.a = 0.0
				prepared.set_pixel(x, y, color)

	return prepared


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BACKGROUND_COLOR, true)
	var data := snapshot(city)

	if not data.get("ok", false):
		_draw_centered_message("No city is loaded.")

		return

	var scale := Vector2(size.x / LOGICAL_SIZE.x, size.y / LOGICAL_SIZE.y)

	if sprite_sheet != null:
		_draw_settlement(SPRITE_POSITIONS[0], int(data.normal_population), false, scale)
		var displayed := display_neighbor_indices(int(data.compass))

		for position_index in displayed.size():
			var neighbor: Dictionary = data.neighbors[displayed[position_index]]
			_draw_settlement(
				SPRITE_POSITIONS[position_index + 1],
				int(neighbor.population),
				int(neighbor.name_index) == 0,
				scale,
			)

	var font_size := clampi(roundi(10.0 * minf(scale.x, scale.y)), 10, 28)
	_draw_record_label(
		str(data.city_name), int(data.display_population), LABEL_POSITIONS[0] * scale, font_size
	)
	var displayed := display_neighbor_indices(int(data.compass))

	for position_index in displayed.size():
		var neighbor: Dictionary = data.neighbors[displayed[position_index]]
		var name_index := int(neighbor.name_index)
		var label := "Ocean" if name_index == 0 else str(
			neighbor_names.get(name_index, "City %d" % name_index)
		)
		_draw_record_label(
			label,
			int(neighbor.population),
			LABEL_POSITIONS[position_index + 1] * scale,
			font_size,
		)

	_draw_outlined_text(
		national_population_text(national_format, int(data.national_population)),
		NATIONAL_LABEL_POSITION * scale,
		font_size,
	)


func _draw_settlement(
	logical_position: Vector2, population: int, ocean: bool, scale: Vector2
) -> void:
	var source_index := sprite_index(population, ocean)
	draw_texture_rect_region(
		sprite_sheet,
		Rect2(logical_position * scale, SPRITE_SIZE * scale),
		Rect2(0, source_index * SPRITE_SIZE.y, SPRITE_SIZE.x, SPRITE_SIZE.y),
	)


func _draw_record_label(label: String, population: int, position: Vector2, font_size: int) -> void:
	_draw_outlined_text(label, position, font_size)

	if population != 0:
		_draw_outlined_text(
			str(population),
			position + Vector2(0, display_font.get_height(font_size)),
			font_size,
		)


func _draw_outlined_text(text: String, center: Vector2, font_size: int) -> void:
	var text_width := display_font.get_string_size(
		text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size
	).x
	var baseline := Vector2(
		center.x - text_width * 0.5,
		center.y + display_font.get_ascent(font_size),
	)

	for offset in [Vector2(1, 1), Vector2(1, -1), Vector2(-1, 1), Vector2(-1, -1)]:
		draw_string(
			display_font, baseline + offset, text, HORIZONTAL_ALIGNMENT_LEFT, -1,
			font_size, Color("202020")
		)

	draw_string(
		display_font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE
	)


func _draw_centered_message(message: String) -> void:
	var font := get_theme_default_font()
	var font_size := 14
	var width := font.get_string_size(
		message, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size
	).x
	draw_string(
		font, Vector2((size.x - width) * 0.5, size.y * 0.5), message,
		HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE
	)


static func _to_i16(value: int) -> int:
	var low := value & 0xffff

	return low - 0x10000 if low & 0x8000 else low


static func _divide_toward_zero(numerator: int, denominator: int) -> int:
	if numerator < 0:
		return -int(-numerator / denominator)

	return int(numerator / denominator)
