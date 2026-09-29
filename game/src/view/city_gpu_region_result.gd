class_name CityGpuRegionResult
extends CityRegionResult
## A native region mesh and its packed draw records. Foreground commands are
## made only for the draws that a query returns.

const RECORD_SIZE := CityGpuBuildContext.RECORD_SIZE

var gpu_arrays: Array = []
var tile_builds := 0
var tile_reuses := 0
var background := Color.TRANSPARENT
var atlas_revision := -1
var atlas_edge := 0
var atlas_image: Image
var sign_foregrounds: Dictionary[int, CitySignForegroundPatch] = {}
var mesh: ArrayMesh
var atlas_texture: ImageTexture
# Meshes and bounds stay fixed after publication. Views share this descriptor.
var source_entry: CityMapSource.MeshEntry
# Uncut draws in painter order: x, y, width, height, image, sprite, flip, depth
# order, region order, train ignore, foreground reference, deck thickness, deck
# reference and depth requirement. Image indexes `draw_images`.
var draw_records := PackedInt64Array()
var draw_images: Array[Image] = []
var draws: NativeCityRegionDraws
# Screen pixels per native pixel for foreground queries.
var command_scale := 1

var _commands: Array[CityStaticCommand] = []


func draw_count() -> int:
	return draw_records.size() / RECORD_SIZE


func occlusion_indices(screen_bounds: Rect2i) -> PackedInt32Array:
	return draws.candidates(screen_bounds, command_scale, true) if draws != null else PackedInt32Array()


func occlusion_command(index: int) -> CityStaticCommand:
	if _commands.is_empty():
		_commands.resize(draw_count())

	var command := _commands[index]

	if command == null:
		var at := index * RECORD_SIZE
		command = CityStaticCommand.new(draw_records[at + 5], draw_records[at + 6] != 0)
		command.position = Vector2i(draw_records[at], draw_records[at + 1])
		command.size = Vector2i(draw_records[at + 2], draw_records[at + 3])
		command.depth_order = draw_records[at + 7]
		command.region_order = draw_records[at + 8]
		command.train_ignore = draw_records[at + 9] != 0
		command.train_foreground_reference_sprite_id = draw_records[at + 10]
		command.train_deck_thickness = draw_records[at + 11]
		command.train_deck_reference_sprite_id = draw_records[at + 12]
		command.train_foreground_requires_depth = draw_records[at + 13] != 0
		_commands[index] = command

	return command


# Every foreground command in painter order. Tests and CPU comparisons use it.
func foreground_commands() -> Array[CityStaticCommand]:
	var result: Array[CityStaticCommand] = []

	for index in draw_count():
		if draw_records[index * RECORD_SIZE + 7] >= 0:
			result.append(occlusion_command(index))

	return result


# Native bounds of the foreground commands that differ from `before`.
func changed_foreground_from(before: CityGpuRegionResult) -> Array[Rect2i]:
	var result: Array[Rect2i] = []
	result.assign(draws.changed_foreground(before.draws))

	return result


# Rasterize the uncut draws that meet `area` in painter order, as LA8 pixels.
func paint(area: Rect2i, factor := 1) -> Image:
	assert(factor in [1, 2, 4])
	var image := Image.create(area.size.x * factor, area.size.y * factor, false, Image.FORMAT_RGBA8)
	image.fill(background)

	if draws != null:
		for index in draws.candidates(area, 1, false):
			var at := index * RECORD_SIZE
			var rectangle := Rect2i(draw_records[at], draw_records[at + 1], draw_records[at + 2], draw_records[at + 3])
			var texture := draw_images[draw_records[at + 4]]
			var source := Rect2i(Vector2i.ZERO, rectangle.size)
			var target_size := rectangle.size * factor

			if factor != 1:
				texture = texture.duplicate()
				texture.resize(target_size.x, target_size.y, Image.INTERPOLATE_NEAREST)
				source = Rect2i(Vector2i.ZERO, target_size)

			image.blend_rect(texture, source, (rectangle.position - area.position) * factor)

	image.convert(Image.FORMAT_LA8)

	return image


static func failed(message: String) -> CityGpuRegionResult:
	var result := CityGpuRegionResult.new()
	result.error = message

	return result
