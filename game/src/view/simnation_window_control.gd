class_name SimNationWindowControl
extends Control

@warning_ignore_start("integer_division")

class Neighbor extends RefCounted:
	var index: int
	var name_index: int
	var population: int
	var value: int
	var fame: int


class Snapshot extends RefCounted:
	var ok: bool = false
	var error: String = ""
	var city_name: String = ""
	var normal_population: int
	var arcology_population: int
	var arcology_count: int
	var arcology_adjustment: int
	var display_population: int
	var national_population: int
	var compass: int
	var neighbors: Array[Neighbor] = []


const LOGICAL_SIZE := Vector2(204.0, 160.0)
const SPRITE_SIZE := Vector2(128.0, 64.0)
const SPRITE_ROW_COUNT := 6
const NEIGHBOR_COUNT := 4
const MISC_NATIONAL_POPULATION := Sc2MiscLayout.NATIONAL_POPULATION
const NEIGHBOR_STRIDE := 0x10
const MISC_TILE_COUNTS := Sc2MiscLayout.TILE_COUNTS
const MISC_ARCOLOGY_POPULATION := Sc2MiscLayout.ARCOLOGY_POPULATION
const MISC_NORMAL_POPULATION := Sc2MiscLayout.NORMAL_POPULATION
const FIRST_ARCOLOGY := BuildingTileIds.PLYMOUTH_ARCOLOGY
const LAST_ARCOLOGY := BuildingTileIds.LAUNCH_ARCOLOGY
const NATIONAL_POPULATION := "Nat. Pop: %d000"
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

const NEIGHBOR_NAMES: Array[String] = [
	"Oak Creek", "Denmont", "Fort Verdegris", "Schwinton", "Mill Valley", "Petaluma",
	"PortVille", "Ashland", "Eubancs", "Aurac", "Tent Pegs", "Cherryton",
	"Blake", "Pioneers", "Fortune", "Phippsville", "Jeromi", "Harpersville",
	"Washers Grove", "Stars County", "Villa", "Serviland", "Newton", "Avon",
	"Dexter", "Sinistrel", "Jenna", "Yestonia", "New Boots", "Hoek Creek",
	"Stimpleton", "Little Rouge", "Krighton", "Cats Corner", "Rimmer", "Lister",
]

var city: CityState
var sprite_sheet: Texture2D


func _init() -> void:
	theme_changed.connect(queue_redraw)
	custom_minimum_size = Vector2(408, 320)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# a UI scale change on the main window moves the screen pixel grid
	ready.connect(func() -> void: get_tree().root.size_changed.connect(queue_redraw))


func set_city(value: CityState) -> void:
	city = value
	queue_redraw()


func set_sprite_sheet(source: Image) -> void:
	var prepared := prepare_sprite_sheet(source)
	sprite_sheet = null if prepared == null else ImageTexture.create_from_image(prepared)
	queue_redraw()


func refresh() -> void:
	queue_redraw()


static func snapshot(value_city: CityState) -> Snapshot:
	if value_city == null or not value_city.is_valid():
		var result := Snapshot.new()
		result.ok = false
		result.error = "city is invalid"

		return result

	var neighbors: Array[Neighbor] = []

	for index in NEIGHBOR_COUNT:
		var offset := Sc2MiscLayout.NEIGHBORS + index * NEIGHBOR_STRIDE
		var name_index := _to_i16(value_city.document.misc_u32(offset))
		var neighbor := Neighbor.new()
		neighbor.index = index
		neighbor.name_index = name_index
		neighbor.population = value_city.document.misc_u32(offset + 4)
		neighbor.value = value_city.document.misc_u32(offset + 8)
		neighbor.fame = value_city.document.misc_u32(offset + 12)
		neighbors.append(neighbor)

	var arcology_tiles := 0

	for tile_id in range(FIRST_ARCOLOGY, LAST_ARCOLOGY + 1):
		arcology_tiles += value_city.document.misc_i32(MISC_TILE_COUNTS + tile_id * 4)

	var arcology_count := _divide_toward_zero(arcology_tiles, 16)
	var arcology_adjustment := 0

	if arcology_count > 140:
		arcology_adjustment = (arcology_count * 5 - 700) * 4000

	var normal_population := value_city.document.misc_u32(MISC_NORMAL_POPULATION)
	var arcology_population := value_city.document.misc_u32(MISC_ARCOLOGY_POPULATION)

	var result := Snapshot.new()
	result.ok = true
	result.city_name = value_city.city_name()
	result.normal_population = normal_population
	result.arcology_population = arcology_population
	result.arcology_count = arcology_count
	result.arcology_adjustment = arcology_adjustment
	result.display_population = normal_population + arcology_population + arcology_adjustment
	result.national_population = value_city.document.misc_u32(MISC_NATIONAL_POPULATION)
	result.compass = value_city.compass_rotation()
	result.neighbors = neighbors
	result.error = ""

	return result


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


static func neighbor_name(name_index: int) -> String:
	if name_index == 0:
		return "Ocean"

	if name_index > 0 and name_index <= NEIGHBOR_NAMES.size():
		return NEIGHBOR_NAMES[name_index - 1]

	return "City %d" % name_index


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
	draw_rect(Rect2(Vector2.ZERO, size), get_theme_color("map_canvas", "AppPalette"), true)
	var data := snapshot(city)

	if not data.ok:
		_draw_centered_message("No city is loaded.")

		return

	var scale := Vector2(size.x / LOGICAL_SIZE.x, size.y / LOGICAL_SIZE.y)
	# the largest layout scale with whole screen pixels for each sprite pixel,
	# centered in the view
	scale = Vector2(ScreenPixels.fit_scale(scale.x), ScreenPixels.fit_scale(scale.y))
	draw_set_transform((size - LOGICAL_SIZE * scale) * 0.5)

	if sprite_sheet != null:
		_draw_settlement(SPRITE_POSITIONS[0], int(data.normal_population), false, scale)
		var displayed := display_neighbor_indices(int(data.compass))

		for position_index in displayed.size():
			var neighbor: Neighbor = data.neighbors[displayed[position_index]]
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
		var neighbor: Neighbor = data.neighbors[displayed[position_index]]
		_draw_record_label(
			neighbor_name(int(neighbor.name_index)),
			int(neighbor.population),
			LABEL_POSITIONS[position_index + 1] * scale,
			font_size,
		)

	_draw_outlined_text(
		NATIONAL_POPULATION % int(data.national_population),
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
	if population != 0:
		_draw_outlined_text(
			str(population),
			position,
			font_size,
		)

		position.y += get_theme_default_font().get_height(font_size)

	_draw_outlined_text(label, position, font_size)


func _draw_outlined_text(text: String, center: Vector2, font_size: int) -> void:
	var display_font := get_theme_default_font()
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
			font_size, Color.BLACK
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
		return -int((-numerator) / denominator)

	return int(numerator / denominator)
