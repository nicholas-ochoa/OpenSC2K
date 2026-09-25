extends SceneTree

class TestVisual extends CityDynamicVisual:
	var sprite_id: int
	var mode: int

## Draw the CPU-composed moving sprites through the native palette shader.
## Compare their pixels with independent foreground, crossing, and shadow rules.

@warning_ignore_start("integer_division")

enum Mode { SPRITE, TRAIN, SHADOW }

const VIEW := 2
const EDGE := 256
const CROSSINGS := [0x4f, 0x50, 0x4d, 0x4e, 0x47, 0x48]

var _app: CityApplication
var _palette: Sc2Palette
var _sprites: Sc2SpriteArchive
var _images := {}
var _commands: Array[CityStaticCommand] = []
var _index_regions: Array[Dictionary] = []
var _checked_pixels := 0
var _hidden_pixels := 0
var _shadow_pixels := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		print("SKIP: moving occlusion pixels need a native GPU window")
		quit()

		return

	_palette = Sc2Palette.index_encoding()
	_sprites = FixtureGraphics.pack().large_sprites
	var city := CityState.from_document(Sc2File.load_path("res://tests/fixtures/cities/generated-128.SC2"))
	var configuration := CityIsometricRenderer.view_configuration(VIEW)
	var focus := _crossing_point(city, configuration)
	var center_key := Vector2i(focus / EDGE)
	var keys: Array[Vector2i] = []

	for y in range(-1, 2):
		for x in range(-1, 2):
			keys.append(center_key + Vector2i(x, y))

	var request := CityGpuRegionBatch.Request.new()
	request.city = city
	request.prepared = true
	request.visibility = {}
	request.palette = _palette
	request.sprites = _sprites
	request.keys = keys
	request.edge = EDGE
	request.view = VIEW
	request.mode = CityViewMode.Mode.CITY
	request.pipes = true
	request.subways = true
	request.generation = 1
	request.signs = [] as Array[CitySignRequest]
	var batch := CityGpuRegionBatch.build(request, CityGpuBuildContext.new(), -1)
	assert(batch.ok, "GPU region build failed")
	var atlas := ImageTexture.create_from_image(batch.atlas_image)
	var source := CityMapSource.new(CityIsometricRenderer.output_size_for_view(VIEW, city.map_size))
	_app = CityApplication.new()
	_app.asset_state.palette_index_encoding = _palette
	var cache := CityRegionCache.new()
	cache.region_edge = EDGE
	cache.native_size = source.size
	cache.visible.assign(keys)
	_app.render_caches.region_cache = cache
	var found := {}

	for region: CityGpuRegionResult in batch.regions:
		var mesh := ArrayMesh.new()

		if not region.gpu_arrays[Mesh.ARRAY_VERTEX].is_empty():
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, region.gpu_arrays, [], {}, Mesh.ARRAY_FLAG_USE_2D_VERTICES)

		source.meshes.append(CityMapSource.MeshEntry.new(Vector2(region.bounds.position), mesh, atlas, 1))
		cache.entries[region.key] = region
		_index_regions.append({"bounds": region.bounds,
			"image": CityGpuDrawList.paint(region.gpu_draws, region.bounds, region.background, region.gpu_draw_grid)})

		# The union of region commands, as CityRegionCache.occlusion_candidates returns it.
		for command: CityStaticCommand in region.occlusion_commands:
			found[int(command.region_order)] = command

	var orders := found.keys()
	orders.sort()

	for order in orders:
		_commands.append(found[order])

	var viewport := SubViewport.new()
	viewport.size = Vector2i(640, 640)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var map := CityMapControl.new()
	map.size = Vector2(viewport.size)
	viewport.add_child(map)
	await process_frame
	map.set_signs_visible(false)
	map.animated_palette_texture = _identity_palette()
	map.set_city_view(city, source, null, true)
	map.zoom_factor = 1.0
	var center_region := Rect2i(center_key * EDGE, Vector2i.ONE * EDGE)
	map.source_center = Vector2(center_region.get_center())
	map.layers._sync_base_layer()
	map._base_layer.hide()

	var grid: Array[Vector2i] = []

	for y in 3:
		for x in 3:
			grid.append(center_region.position + Vector2i(12 + x * 84, 12 + y * 84))

	var airplane := 1359 + 2
	var train := 1374 + 1

	# Space grid sprites apart so later sprites cannot cover earlier ones.
	for sprite_id in [airplane, train]:
		assert(_sprite_image(sprite_id, false).get_width() < 84 and _sprite_image(sprite_id, false).get_height() < 84)

	for choice in ["median", "first", "last"]:
		await _check_pass(map, viewport, _grid_visuals(grid, airplane, Mode.SPRITE, choice))

	await _check_pass(map, viewport, _grid_visuals(grid, train, Mode.TRAIN, "median"))
	await _check_pass(map, viewport, _grid_visuals(grid, airplane, Mode.SHADOW, "median"))

	# Trains over the crossing, at the orders around the crossing tile.
	var focus_order := _order_at(city, focus)

	for delta in [-1, 0, 1, 40]:
		for offset in [Vector2i(-20, -30), Vector2i(-4, -14), Vector2i(8, -24)]:
			var visual := _visual(train, focus + offset, Mode.TRAIN, focus_order + delta)
			await _check_pass(map, viewport, [visual])

	assert(_hidden_pixels > 0 and _checked_pixels > _hidden_pixels, "Fixture lacks hidden or visible pixels")
	assert(_shadow_pixels > 0, "Fixture has no shadow pixels")
	print("PASS: native moving sprites match foreground, crossing and shadow rules (%d pixels, %d hidden, %d shadow)" % [_checked_pixels, _hidden_pixels, _shadow_pixels])
	_app.render_caches.region_cache.close()
	_app.free()
	viewport.queue_free()
	await process_frame
	quit()


func _check_pass(map: CityMapControl, viewport: SubViewport, visuals: Array[CityDynamicVisual]) -> void:
	map.set_dynamic_sprites(visuals)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var actual := viewport.get_texture().get_image()
	actual.convert(Image.FORMAT_RGBA8)
	var offset := Vector2i(map.camera._draw_offset(1.0))
	var differences := 0
	var first_difference := ""

	for visual: TestVisual in visuals:
		var position := Vector2i(visual.position)
		var order := int(visual.depth_order)
		var image: Image = _sprite_image(int(visual.sprite_id), false)
		var expected := _expected(image, position, order, int(visual.mode))

		for y in image.get_height():
			for x in image.get_width():
				var screen := position + Vector2i(x, y) + offset
				var wanted := int(expected[y * image.get_width() + x])
				var pixel := actual.get_pixelv(screen)
				var matches := pixel.a8 == 0 if wanted < 0 else (pixel.a8 == 255 and pixel.r8 == wanted)

				if image.get_pixel(x, y).a > 0.0:
					_checked_pixels += 1

				if not matches:
					differences += 1

					if first_difference.is_empty():
						first_difference = "mode %d at %s: wanted %d, got %s" % [int(visual.mode), screen, wanted, pixel]

	assert(differences == 0, "Native moving pixels differ at %d pixels; first %s" % [differences, first_difference])


func _expected(image: Image, position: Vector2i, order: int, mode: int) -> PackedInt32Array:
	var width := image.get_width()
	var result := PackedInt32Array()
	result.resize(width * image.get_height())
	result.fill(-1)
	var hidden := _occluder(image.get_size(), position, order, mode == Mode.TRAIN)

	for y in image.get_height():
		for x in width:
			var index := y * width + x

			if image.get_pixel(x, y).a <= 0.0:
				continue

			if hidden[index] != 0:
				_hidden_pixels += 1
				continue

			var palette_index := roundi(image.get_pixel(x, y).r * 255.0)

			if mode == Mode.SHADOW:
				var under := _static_index(position + Vector2i(x, y))
				var shadow := CityIsometricRenderer.shadow_palette_index(under)

				if shadow == under:
					continue

				_shadow_pixels += 1
				palette_index = shadow

			result[index] = palette_index

	return result


## The CPU rule of ApplicationMovingSprites._dynamic_occluder_image.
func _occluder(size: Vector2i, position: Vector2i, order: int, is_train: bool) -> PackedByteArray:
	var hidden := PackedByteArray()
	hidden.resize(size.x * size.y)
	var bounds := Rect2i(position, size)

	for command in _commands:
		if is_train and bool(command.train_ignore):
			continue

		var later := int(command.depth_order) > order
		var train_foreground: bool = (
			is_train and (command.train_foreground_reference_sprite_id != 0 or command.train_deck_thickness != 0)
			and (not (bool(command.train_foreground_requires_depth) or command.train_deck_thickness != 0)
				or int(command.depth_order) >= order)
		)

		if not (later and not train_foreground) and not train_foreground:
			continue

		var occluder_position := Vector2i(command.position)
		var overlap := bounds.intersection(Rect2i(occluder_position, Vector2i(command.size)))

		if not overlap.has_area():
			continue

		var mask := _sprite_image(int(command.sprite_id), bool(command.flip))

		if train_foreground:
			mask = _train_mask(command, mask)

		for y in range(overlap.position.y, overlap.end.y):
			for x in range(overlap.position.x, overlap.end.x):
				if mask.get_pixel(x - occluder_position.x, y - occluder_position.y).a > 0.0:
					hidden[(y - position.y) * size.x + x - position.x] = 1

	return hidden


func _train_mask(command: CityStaticCommand, surface: Image) -> Image:
	if command.train_deck_thickness != 0:
		var deck_surface := surface

		if command.train_deck_reference_sprite_id != 0:
			var background := _sprite_image(int(command.train_deck_reference_sprite_id), bool(command.flip))
			deck_surface = Image.create(surface.get_width(), surface.get_height(), false, Image.FORMAT_RGBA8)
			deck_surface.blit_rect(background, Rect2i(Vector2i.ZERO, background.get_size()), Vector2i(0, surface.get_height() - background.get_height()))

		return CityIsometricRenderer.highway_train_deck_mask(deck_surface, int(command.train_deck_thickness))

	var reference := int(command.train_foreground_reference_sprite_id)

	if reference < 0:
		return surface

	return CityIsometricRenderer.foreground_difference_mask(surface, _sprite_image(reference, bool(command.flip)))


func _static_index(point: Vector2i) -> int:
	for region in _index_regions:
		var bounds: Rect2i = region.bounds

		if bounds.has_point(point):
			var pixel: Color = region.image.get_pixelv(point - bounds.position)

			return roundi(pixel.r * 255.0) if pixel.a > 0.0 else 0

	return 0


func _grid_visuals(grid: Array[Vector2i], sprite_id: int, mode: int, choice: String) -> Array[CityDynamicVisual]:
	var visuals: Array[CityDynamicVisual] = []
	var size := _sprite_image(sprite_id, false).get_size()

	for index in grid.size():
		var bounds := Rect2i(grid[index], size)
		var covering: Array[int] = []

		for command in _commands:
			if bounds.intersects(Rect2i(command.position, command.size)):
				covering.append(int(command.depth_order))

		covering.sort()
		var order := 0

		if not covering.is_empty():
			match choice:
				"first":
					order = covering[0] - 1
				"last":
					order = covering.back()
				_:
					order = covering[covering.size() / 2]

		visuals.append(_visual(sprite_id, grid[index], mode, order))

	return visuals


func _visual(sprite_id: int, position: Vector2i, mode: int, order: int) -> TestVisual:
	var image := _sprite_image(sprite_id, false)

	var result := TestVisual.new()
	var mask := _app.moving_sprites._dynamic_occluder_image(_sprites, 1, position, image.get_size(), order, mode == Mode.TRAIN)
	var composed: Image
	if mode == Mode.SHADOW:
		composed = _app.moving_sprites._dynamic_shadow_image(image, position, mask)
	else:
		composed = CityIsometricRenderer.occlude_dynamic_with_mask(image, mask, position, null).image
	if composed == null:
		composed = Image.create(image.get_width(), image.get_height(), false, Image.FORMAT_RGBA8)
	result.texture = ImageTexture.create_from_image(composed)
	result.position = Vector2(position)
	result.size = Vector2(image.get_size())
	result.mode = mode
	result.depth_order = order
	result.sprite_id = sprite_id

	return result


func _sprite_image(sprite_id: int, flip: bool) -> Image:
	return CityIsometricRenderer.sprite_image(_sprites, _palette, _images, sprite_id, flip)


func _crossing_point(city: CityState, configuration: CityViewConfiguration) -> Vector2i:
	for building in CROSSINGS:
		for index in city.buildings.size():
			if int(city.buildings[index]) != building:
				continue

			var x := int(index / city.map_size)
			var y := index % city.map_size
			var origin := configuration.side_margin + city.map_size * configuration.half_width

			return Vector2i(
				origin + (x - y) * configuration.half_width + configuration.half_width,
				configuration.top_margin + (x + y) * configuration.half_height
					- city.land_altitude(x, y) * configuration.altitude_step
			)

	assert(false, "The test city needs a rail crossing")

	return Vector2i.ZERO


func _order_at(city: CityState, point: Vector2i) -> int:
	var tile := CityIsometricRenderer.screen_to_tile(city, Vector2(point) + Vector2(0, 8))

	return (tile.x + tile.y) * city.map_size + tile.y


func _identity_palette() -> ImageTexture:
	var image := Image.create(256, 1, false, Image.FORMAT_RGBA8)

	for index in 256:
		image.set_pixel(index, 0, Color8(index, index, index, 255))

	return ImageTexture.create_from_image(image)
