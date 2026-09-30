class_name IsometricStaticOcclusion
extends IsometricConstants
## Foreground silhouettes of the static city in painter order. The native painter
## selects the sprites and the train crossing masks.

@warning_ignore_start("integer_division")


# every foreground command of the city. whole-city lists leave the region order unset
static func static_occlusion_commands(
	city: CityState, sprites: Sc2SpriteArchive, view_size := VIEW_LARGE
) -> Array[CityStaticCommand]:
	var context := _context(city, sprites, view_size)

	if context == null:
		return []

	var records := context.draw_records(Rect2i(Vector2i.ZERO, IsometricGeometry.output_size_for_view(view_size, city.map_size)))

	return [] if records.has("error") else CityGpuBuildContext.foreground_commands(records.records)


# `base_commands` with the commands of each dirty tile painted again
static func patch_static_occlusion_commands(
	base_commands: Array[CityStaticCommand],
	city: CityState,
	sprites: Sc2SpriteArchive,
	dirty_indices: PackedInt32Array,
	view_size := VIEW_LARGE
) -> Array[CityStaticCommand]:
	var map_edge: int = city.map_size if city != null else 128

	if base_commands.is_empty():
		return static_occlusion_commands(city, sprites, view_size)

	var context := _context(city, sprites, view_size)

	if context == null:
		return []

	var replacements: Dictionary[int, Array] = {}

	for value in dirty_indices:
		var index := int(value)

		if index < 0 or index >= (map_edge * map_edge):
			continue

		var x := int(index / map_edge)
		var y := index % map_edge
		var drawn := context.tile_draws([Vector2i(x, y)])
		replacements[(x + y) * map_edge + y] = ([] if drawn.has("error")
			else CityGpuBuildContext.foreground_commands(drawn.records))

	if replacements.is_empty():
		return base_commands.duplicate()

	var commands: Array[CityStaticCommand] = []
	var inserted: Dictionary[int, bool] = {}

	for command in base_commands:
		var order := int(command.depth_order)

		if not replacements.has(order):
			commands.append(command)
			continue

		if not inserted.has(order):
			commands.append_array(replacements[order])
			inserted[order] = true

	if inserted.size() != replacements.size():
		# every valid surface tile has an occluder. rebuild if the supplied base
		# list is incomplete instead of risking a bad command order
		return static_occlusion_commands(city, sprites, view_size)

	return commands


# the foreground commands of one tile
static func tile_occlusion_commands(
	city: CityState, sprites: Sc2SpriteArchive, view_size: int, x: int, y: int
) -> Array[CityStaticCommand]:
	var context := _context(city, sprites, view_size)

	if context == null:
		return []

	var drawn := context.tile_draws([Vector2i(x, y)])

	return [] if drawn.has("error") else CityGpuBuildContext.foreground_commands(drawn.records)


static func _context(city: CityState, sprites: Sc2SpriteArchive, view_size: int) -> CityGpuBuildContext:
	if city == null or not city.is_valid() or sprites == null or not sprites.is_valid():
		return null

	var context := CityGpuBuildContext.new()
	var failure := context.prepare(city, Sc2Palette.index_encoding(), sprites, view_size, CityViewMode.Mode.CITY, true, true, true, 0,
		false)

	return context if failure.is_empty() else null
