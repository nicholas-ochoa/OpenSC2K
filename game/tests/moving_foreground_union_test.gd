extends SceneTree

const Tiles = preload("res://src/tools/shared/building_tile_ids.gd")


func _initialize() -> void:
	_check_train_support()
	_check_shadow_receivers()
	_check_packed_masks()
	_check_neighbor_masks()
	var host := CityApplication.new()
	host.moving_sprites = TestSprites.new(host)

	# The first foreground sprite overlaps only transparent pixels. Later
	# highway and building silhouettes still cover parts of the train.
	for id in 4:
		var image := Image.create(8, 4, false, Image.FORMAT_RGBA8)
		image.fill(Color.TRANSPARENT)

		if id > 0:
			image.set_pixel(id, 1, Color.WHITE)

		host.moving_sprites.images[id] = image
		var command := CityStaticCommand.new()
		command.sprite_id = id
		command.position = Vector2i.ZERO
		command.size = Vector2i(8, 4)
		command.flip = false
		command.depth_order = 11 + id
		host.render_caches.static_occlusion_commands.append(command)

	# A background sprite leaves the moving object visible.
	host.render_caches.static_occlusion_commands[3].depth_order = 9

	for train in [true, false]:
		var mask := host.moving_sprites._dynamic_occluder_image(null, 1, Vector2i.ZERO, Vector2i(8, 4), 10, train)
		assert(mask != null)
		assert(mask.get_pixel(1, 1).a > 0.0, "Later highway silhouette hides the moving sprite")
		assert(mask.get_pixel(2, 1).a > 0.0, "Later building silhouette also hides the moving sprite")
		assert(mask.get_pixel(3, 1).a == 0.0, "Earlier sprite cannot hide the moving sprite")
		var moving := Image.create(8, 4, false, Image.FORMAT_RGBA8)
		moving.fill(Color.WHITE)
		var clipped := CityIsometricRenderer.occlude_dynamic_with_mask(moving, mask, Vector2i.ZERO, null)
		assert(clipped.occluded_pixels == 2)
		assert(clipped.image.get_pixel(4, 1).a > 0.0, "Uncovered train pixels remain visible")

	var crossing := Image.create(8, 4, false, Image.FORMAT_RGBA8)
	crossing.fill(Color.TRANSPARENT)
	crossing.set_pixel(4, 1, Color.WHITE)
	crossing.set_pixel(5, 1, Color.WHITE)
	var track := crossing.duplicate()
	track.set_pixel(4, 1, Color.TRANSPARENT)
	host.moving_sprites.images[4] = crossing
	host.moving_sprites.images[5] = track
	var crossing_command := CityStaticCommand.new()
	crossing_command.sprite_id = 4
	crossing_command.position = Vector2i.ZERO
	crossing_command.size = Vector2i(8, 4)
	crossing_command.flip = false
	crossing_command.depth_order = 10
	crossing_command.train_foreground_reference_sprite_id = 5
	crossing_command.train_foreground_requires_depth = true
	host.render_caches.static_occlusion_commands.append(crossing_command)
	host.render_caches.static_occlusion_grid = null
	host.render_caches.dynamic_occluder_cache.clear()
	var crossing_mask := host.moving_sprites._dynamic_occluder_image(null, 1, Vector2i.ZERO, Vector2i(8, 4), 10, true)
	assert(crossing_mask.get_pixel(4, 1).a > 0.0, "Same-tile raised deck hides train")
	assert(crossing_mask.get_pixel(5, 1).a == 0.0, "Ground-level rails cannot hide train")
	host.render_caches.static_occlusion_commands[-1].depth_order = 9
	host.render_caches.dynamic_occluder_cache.clear()
	var behind_mask := host.moving_sprites._dynamic_occluder_image(null, 1, Vector2i.ZERO, Vector2i(8, 4), 10, true)
	assert(behind_mask.get_pixel(4, 1).a == 0.0, "Crossing behind train cannot hide it")
	# A later power line leaves the train pixels visible.
	host.render_caches.static_occlusion_commands[1].train_ignore = true
	host.render_caches.dynamic_occluder_cache.clear()
	var wire_mask := host.moving_sprites._dynamic_occluder_image(null, 1, Vector2i.ZERO, Vector2i(8, 4), 10, true)
	assert(wire_mask.get_pixel(1, 1).a == 0.0, "Power line cannot cover train")
	var road := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	road.fill(Color.TRANSPARENT)
	road.set_pixel(3, 1, Color(161.0 / 255.0, 0, 0, 1))

	for y in range(2, 8):
		road.set_pixel(3, y, Color.WHITE)

	var only_deck := CityIsometricRenderer.highway_train_deck_mask(road, 2)
	assert(only_deck.get_pixel(3, 1).a > 0.0 and only_deck.get_pixel(3, 3).a > 0.0)
	assert(only_deck.get_pixel(3, 4).a == 0.0 and only_deck.get_pixel(3, 7).a == 0.0, "Pillar below deck cannot cover train")
	var two_decks := Image.create(1, 16, false, Image.FORMAT_RGBA8)
	two_decks.fill(Color.WHITE)
	two_decks.set_pixel(0, 1, Color(161.0 / 255.0, 0, 0, 1))
	two_decks.set_pixel(0, 12, Color(161.0 / 255.0, 0, 0, 1))
	var bands := CityIsometricRenderer.highway_train_deck_mask(two_decks, 2)
	assert(bands.get_pixel(0, 6).a == 0.0, "Pillars between composite highway decks cannot cover train")
	assert(bands.get_pixel(0, 12).a > 0.0, "Second highway deck remains in foreground")

	# Verify that real crossing artwork emits the same-tile mask at each native view.
	var city := CityState.from_document(EmptyCityTemplate.create(128))
	var small := FixtureGraphics.pack().small_medium_sprites
	var large := FixtureGraphics.pack().large_sprites

	for tile in [Tiles.POWER_LINE_STRAIGHT_1, Tiles.POWER_LINE_CROSSROADS, Tiles.ROAD_POWER_CROSSING_1, Tiles.ROAD_POWER_CROSSING_2,
		Tiles.RAIL_POWER_CROSSING_1, Tiles.RAIL_POWER_CROSSING_2, Tiles.HIGHWAY_POWER_CROSSING_1, Tiles.HIGHWAY_POWER_CROSSING_2]:
		assert(city.set_building_id(64, 64, tile))
		var tile_commands := CityIsometricRenderer.tile_occlusion_commands(city, large, CityIsometricRenderer.VIEW_LARGE, 64, 64)
		var command: CityStaticCommand = tile_commands.filter(func(value: CityStaticCommand) -> bool:
			return value.sprite_id == 1000 + tile)[0]

		if tile in [0x4f, 0x50]:
			assert(command.train_deck_reference_sprite_id == 1000 + (0x49 if tile == 0x4f else 0x4a))
		else:
			assert(command.train_ignore, "Power-line artwork is excluded from train masks")

	for view in [CityIsometricRenderer.VIEW_SMALL, CityIsometricRenderer.VIEW_MEDIUM, CityIsometricRenderer.VIEW_LARGE]:
		var config := CityIsometricRenderer.view_configuration(view)
		var archive := large if view == CityIsometricRenderer.VIEW_LARGE else small

		for tile in [Tiles.HIGHWAY_RAIL_CROSSING_1, Tiles.HIGHWAY_RAIL_CROSSING_2]:
			assert(city.set_building_id(64, 64, tile))
			var commands := CityIsometricRenderer.tile_occlusion_commands(city, archive, view, 64, 64)
			var found := false

			for command in commands:
				if int(command.sprite_id) != config.sprite_base + tile:
					continue

				found = true
				assert(command.train_foreground_requires_depth)
				# the raised deck covers a train on the crossing tile too
				assert(command.train_foreground_reference_sprite_id == config.sprite_base + (0x2d if tile == 0x4d else 0x2c))
				var surface: Image = archive.find_sprite(command.sprite_id).create_image(Sc2Palette.index_encoding()).image
				var deck := CityIsometricRenderer.highway_train_deck_mask(surface, int(command.train_deck_thickness))
				assert(not deck.is_invisible(), "Crossing retains raised foreground artwork")

				if view == CityIsometricRenderer.VIEW_LARGE and tile == 0x4d:
					assert(surface.get_pixel(21, 19).a > 0.0 and deck.get_pixel(21, 19).a == 0.0, "Original crossing pillar is omitted")

			assert(found, "Each native view includes crossing foreground")
			var anchor := Vector2i(config.side_margin + city.map_size * config.half_width,
				config.top_margin + 128 * config.half_height)
			var area := Rect2i(anchor - Vector2i(4 * config.half_width, 16 * config.half_height),
				Vector2i(10 * config.half_width, 20 * config.half_height))
			var gpu := CityGpuRegionRenderer.render(city, Sc2Palette.index_encoding(), archive, area, view,
				CityViewMode.Mode.CITY, true, true, CityGpuBuildContext.new(), 1, -1)
			var gpu_found := false

			for command in gpu.foreground_commands():
				if int(command.sprite_id) == config.sprite_base + tile:
					gpu_found = true
					assert(command.train_foreground_requires_depth and command.train_deck_thickness == view + 1)

			assert(gpu_found, "GPU path includes the same deck-only train mask")

	host.free()
	print("PASS: all overlapping foreground silhouettes hide trains and other moving sprites")
	quit()


func _check_neighbor_masks() -> void:
	var host := CityApplication.new()
	host.moving_sprites = TestSprites.new(host)
	var size := Vector2i(13, 9)
	var world := Rect2i(-64, -64, 160, 160)
	var reference := Image.create(world.size.x, world.size.y, false, Image.FORMAT_RGBA8)
	reference.fill(Color.TRANSPARENT)
	for i in 3:
		var pixels := Image.create(40, 60, false, Image.FORMAT_RGBA8)
		for y in 60:
			for x in 40:
				pixels.set_pixel(x, y, Color8(x * 5, y * 4, i * 70, [0, 80, 255][(x + y) % 3]))
		var command := CityStaticCommand.new()
		command.position = Vector2i(i * 23 - 45, i * 19 - 39)
		command.size = pixels.get_size()
		command.depth_order = 12
		command.sprite_id = i
		host.render_caches.static_occlusion_commands.append(command)
		host.moving_sprites.images[i] = pixels
		reference.blend_rect(pixels, Rect2i(Vector2i.ZERO, pixels.get_size()), Vector2i(command.position) - world.position)
	for y in [-33, -32, -1, 0, 31, 32]:
		for x in range(-33, 34):
			var position := Vector2i(x, y)
			var actual := host.moving_sprites._dynamic_occluder_image(null, 1, position, size, 10)
			var expected := reference.get_region(Rect2i(position - world.position, size))
			if actual == null:
				assert(expected.is_invisible())
			else:
				# Invisible RGB is irrelevant; masks consume alpha only.
				for py in size.y:
					for px in size.x:
						assert(actual.get_pixel(px, py).a == expected.get_pixel(px, py).a,
							"Neighbor mask changed alpha at a negative coordinate or cache boundary")
	assert(host.render_caches.dynamic_occluder_cache.size() == 16, "Neighboring positions rebuilt individual masks")
	var changed: Array[Rect2i] = [Rect2i(-4, -4, 8, 8)]
	host.map_render._invalidate_region_foregrounds(changed, changed)
	for entry: RenderCaches.OccluderMask in host.render_caches.dynamic_occluder_cache.values():
		assert(not entry.bounds.intersects(changed[0]), "A changed silhouette retained a shared neighbor mask")
	host.free()


func _check_packed_masks() -> void:
	for format in [Image.FORMAT_RGBA8, Image.FORMAT_RGBAF]:
		var sprite := Image.create(13, 7, false, format)
		var mask := Image.create(13, 7, false, Image.FORMAT_RGBA8)
		for y in 7:
			for x in 13:
				sprite.set_pixel(x, y, Color8(x * 19, y * 31, (x + y) * 11, [0, 1, 127, 255][(x + y) % 4]))
				mask.set_pixel(x, y, Color8(41, 91, 113, [0, 1, 255][(x * 2 + y) % 3]))
		var original := sprite.get_data()
		var expected := sprite.duplicate()
		var hidden := 0
		for y in 7:
			for x in 13:
				var color := sprite.get_pixel(x, y)
				if color.a > 0.0 and mask.get_pixel(x, y).a > 0.0:
					color.a = 0.0
					expected.set_pixel(x, y, color)
					hidden += 1
		var result := IsometricPixelOperations.occlude_dynamic_with_mask(sprite, mask, Vector2i.ZERO)
		assert(result.occluded_pixels == hidden and result.image.get_data() == expected.get_data())
		assert(sprite.get_data() == original, "Occlusion must not change the shared source image")
		assert(IsometricPixelOperations.occlude_dynamic_with_mask(sprite, null, Vector2i.ZERO).image == sprite)
		mask.fill(Color.TRANSPARENT)
		assert(IsometricPixelOperations.occlude_dynamic_with_mask(sprite, mask, Vector2i.ZERO).image == sprite)


func _check_train_support() -> void:
	var host := CityApplication.new()
	host.moving_sprites = TestSprites.new(host)
	var city := CityState.from_document(EmptyCityTemplate.create(128))
	host.document_state.city = city
	city.set_land_altitude(64, 64, 0)
	city.set_land_altitude(65, 64, 0)
	city.set_terrain_id(65, 64, TerrainTileIds.FLAT)
	city.set_land_altitude(64, 65, 2)
	var start := (64 + 64) * 128 + 64
	var end := (65 + 64) * 128 + 64
	var ids := [1256, 1120, 1045, 1077, 1257, 1269]
	for index in ids.size():
		var sprite := Image.create(8, 4, false, Image.FORMAT_RGBA8)
		sprite.set_pixel(index, 1, Color.WHITE)
		host.moving_sprites.images[ids[index]] = sprite
		var command := CityStaticCommand.new()
		command.sprite_id = ids[index]
		command.size = sprite.get_size()
		command.depth_order = end + 1 if index == 4 else end
		if index == 3:
			command.train_foreground_reference_sprite_id = -1
			command.train_foreground_requires_depth = true
		host.render_caches.static_occlusion_commands.append(command)
	var original := host.moving_sprites._dynamic_occluder_image(null, 1, Vector2i.ZERO, Vector2i(8, 4), start, true)
	assert(original.get_pixel(0, 1).a > 0.0 and original.get_pixel(2, 1).a > 0.0)
	var moving := host.moving_sprites._dynamic_occluder_image(null, 1, Vector2i.ZERO, Vector2i(8, 4), start, true, 1, null, -1, PackedInt32Array([start, end]))
	assert(moving.get_pixel(0, 1).a == 0.0 and moving.get_pixel(2, 1).a == 0.0, "Supporting ground and track must not cover a moving train")
	for index in [1, 3, 4, 5]:
		assert(moving.get_pixel(index, 1).a > 0.0, "Train support rule removed a building, deck, higher terrain or cliff mask")
	host.free()


func _check_shadow_receivers() -> void:
	var host := CityApplication.new()
	host.moving_sprites = TestSprites.new(host)
	var city := CityState.from_document(EmptyCityTemplate.create(128))
	host.document_state.city = city
	for tile in [Vector2i(64, 64), Vector2i(65, 64)]:
		city.set_land_altitude(tile.x, tile.y, 0)
		city.set_terrain_id(tile.x, tile.y, TerrainTileIds.FLAT)
	city.set_land_altitude(64, 65, 2)
	var start := 128 * 128 + 64
	var ids := [1256, 1045, 1291, 1270, 1120, 1077, 1257, 1269, 1006]
	for i in ids.size():
		var pixels := Image.create(12, 4, false, Image.FORMAT_RGBA8)
		pixels.set_pixel(i, 1, Color.WHITE)
		host.moving_sprites.images[ids[i]] = pixels
		var command := CityStaticCommand.new()
		command.sprite_id = ids[i]
		command.size = pixels.get_size()
		command.depth_order = start + 129 if i == 6 else start + 128
		host.render_caches.static_occlusion_commands.append(command)
	var ordinary := host.moving_sprites._dynamic_occluder_image(null, 1, Vector2i.ZERO, Vector2i(12, 4), start)
	var shadow := host.moving_sprites._dynamic_occluder_image(null, 1, Vector2i.ZERO, Vector2i(12, 4), start, false, 1, null, -1, PackedInt32Array(), true)
	for i in ids.size():
		assert(ordinary.get_pixel(i, 1).a > 0.0)
		assert((shadow.get_pixel(i, 1).a > 0.0) == (i >= 4), "Shadow receiver masking lost a surface or foreground structure")
	host.free()


class TestSprites extends ApplicationMovingSprites:
	var images: Dictionary = {}


	func dynamic_sprite_resource(
		_archive: Sc2SpriteArchive,
		sprite_id: int,
		_flip: bool,
		_divisor: int,
		_factor := 1,
	) -> CitySpriteResource:
		var result := CitySpriteResource.new()
		result.image = images[sprite_id]

		return result
