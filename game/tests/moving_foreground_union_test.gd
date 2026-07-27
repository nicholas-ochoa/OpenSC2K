extends SceneTree

class TestSprites extends ApplicationMovingSprites:
	var images: Dictionary = {}


	func _dynamic_sprite_resource(_archive: Sc2SpriteArchive, sprite_id: int, _flip: bool, _divisor: int, _factor := 1) -> Dictionary:
		return {"image": images[sprite_id]}


func _initialize() -> void:
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
		var command := {"sprite_id": id, "position": Vector2i.ZERO,
			"size": Vector2i(8, 4), "flip": false, "depth_order": 11 + id}
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

	# The raised deck covers a train on the crossing tile too.
	for base in [0, 500, 1000]:
		assert(IsometricStaticOcclusion.train_power_foreground_reference_sprite_id(0x4d, base) == base + 0x2d)
		assert(IsometricStaticOcclusion.train_power_foreground_reference_sprite_id(0x4e, base) == base + 0x2c)

	var crossing := Image.create(8, 4, false, Image.FORMAT_RGBA8)
	crossing.fill(Color.TRANSPARENT)
	crossing.set_pixel(4, 1, Color.WHITE)
	crossing.set_pixel(5, 1, Color.WHITE)
	var track := crossing.duplicate()
	track.set_pixel(4, 1, Color.TRANSPARENT)
	host.moving_sprites.images[4] = crossing
	host.moving_sprites.images[5] = track
	host.render_caches.static_occlusion_commands.append({"sprite_id": 4, "position": Vector2i.ZERO,
		"size": Vector2i(8, 4), "flip": false, "depth_order": 10,
		"train_foreground_reference_sprite_id": 5, "train_foreground_requires_depth": true})
	host.render_caches.static_occlusion_grid.clear()
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

	for tile in [0x0e, 0x1c, 0x43, 0x44, 0x47, 0x48, 0x4f, 0x50]:
		var command := {}
		CityIsometricRenderer.configure_train_foreground(command, tile, CityIsometricRenderer.view_configuration(CityIsometricRenderer.VIEW_LARGE))

		if tile in [0x4f, 0x50]:
			assert(command.train_deck_reference_sprite_id == 1000 + (0x49 if tile == 0x4f else 0x4a))
		else:
			assert(command.train_ignore, "Power-line artwork is excluded from train masks")

	# Verify that real crossing artwork emits the same-tile mask at each native view.
	var city := CityState.from_document(EmptyCityTemplate.create(128))
	var small := Sc2SpriteArchive.combine([
		Sc2SpriteArchive.load_path("res://../references/SIMCITY2000/DATA/SMALLMED.DAT"),
		Sc2SpriteArchive.load_path("res://../references/SIMCITY2000/DATA/SPECIAL.DAT")])
	var large := Sc2SpriteArchive.load_path("res://../references/SIMCITY2000/DATA/LARGE.DAT")

	for view in [CityIsometricRenderer.VIEW_SMALL, CityIsometricRenderer.VIEW_MEDIUM, CityIsometricRenderer.VIEW_LARGE]:
		var config := CityIsometricRenderer.view_configuration(view)
		var archive := large if view == CityIsometricRenderer.VIEW_LARGE else small

		for tile in [0x4d, 0x4e]:
			assert(city.set_building_id(64, 64, tile))
			var commands := CityIsometricRenderer.tile_occlusion_commands(city, archive, config, 0, 64, 64, 10)
			var found := false

			for command in commands:
				if int(command.sprite_id) != int(config.sprite_base) + tile:
					continue

				found = true
				assert(command.train_foreground_requires_depth)
				var surface: Image = archive.find_sprite(command.sprite_id).create_image(Sc2Palette.index_encoding()).image
				var deck := CityIsometricRenderer.highway_train_deck_mask(surface, int(command.train_deck_thickness))
				assert(not deck.is_invisible(), "Crossing retains raised foreground artwork")

				if view == CityIsometricRenderer.VIEW_LARGE and tile == 0x4d:
					assert(surface.get_pixel(21, 19).a > 0.0 and deck.get_pixel(21, 19).a == 0.0, "Original crossing pillar is omitted")

			assert(found, "Each native view includes crossing foreground")
			var context := CityGpuBuildContext.new()
			var gpu := context.tile(city, Sc2Palette.index_encoding(), archive, config, 64, 64, "city", true, true)
			var gpu_found := false

			for command in gpu.foreground:
				if int(command.sprite_id) == int(config.sprite_base) + tile:
					gpu_found = true
					assert(command.train_foreground_requires_depth and command.train_deck_thickness == view + 1)

			assert(gpu_found, "GPU path includes the same deck-only train mask")

	host.free()
	print("PASS: all overlapping foreground silhouettes hide trains and other moving sprites")
	quit()
