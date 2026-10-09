extends SceneTree

const DocumentState = preload("res://tests/support/document_state.gd")
const DIRECTIONS := [Vector2i(0, -1), Vector2i(1, -1), Vector2i(1, 0), Vector2i(1, 1),
	Vector2i(0, 1), Vector2i(-1, 1), Vector2i(-1, 0), Vector2i(-1, -1)]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_check_motion()
	_check_trains()
	_check_train_pixels()
	_check_aircraft_pixels()
	_check_subpixels()
	_check_lifecycle()
	_check_shadow()
	_check_pixel_parity()
	_check_artwork_cache()
	await _check_application()
	print("PASS: traffic interpolation, directions, tile crossings, shadows, ship reflections, toggles and unchanged city/RNG")
	quit()


func _check_motion() -> void:
	var options := VisualEnhancementOptions.normalize({})
	for type in [1, 2, 3, 9]:
		for direction in 8:
			var city := fixture(type)
			var motion := CityTrafficMotion.new()
			motion.observe(city, options)
			var old := motion.tracks[1].current
			var step: Vector2i = DIRECTIONS[direction] * 4
			write_thing(city, 1, {"px": 8 + step.x, "py": 8 + step.y})
			var before := DocumentState.capture(city.document)
			motion.observe(city, options)
			assert(motion.tracks[1].current == old, "A published tick must not jump the display")
			var source := command()
			for divisor in [1, 2, 4]:
				var at_start := motion.draw_command(source, divisor, 128)
				assert(at_start.position != source.position)
			assert(motion.advance(0.1))
			assert(motion.tracks[1].current.is_equal_approx(old.lerp(motion.tracks[1].target, 0.5)))
			assert(motion.advance(0.1))
			assert(motion.draw_command(source, 1, 128) == source)
			assert(not motion.advance(0.1), "Stopped objects must not redraw forever")
			assert(DocumentState.capture(city.document) == before)
	# Crossing a tile boundary keeps continuous sub-tile geometry and draw depth.
	var city := fixture(1)
	write_thing(city, 1, {"px": 14})
	var motion := CityTrafficMotion.new()
	motion.observe(city, options)
	var old := motion.tracks[1].current
	city.set_text_overlay_id(64, 64, 0)
	write_thing(city, 1, {"x": 65, "px": 2})
	motion.observe(city, options)
	var source := command()
	source.depth_order = (65 + 64) * 128 + 64
	assert(motion.draw_command(source, 1, 128).depth_order == (64 + 64) * 128 + 64)
	motion.advance(0.1)
	assert(motion.tracks[1].current.is_equal_approx(old.lerp(motion.tracks[1].target, 0.5)))
	assert(source.position == Vector2i(100, 200), "Cached source commands must stay immutable")
	# A climb moves the aircraft, while its shadow stays on the ground.
	city = fixture(2)
	motion = CityTrafficMotion.new()
	motion.observe(city, options)
	write_thing(city, 1, {"z": 5})
	motion.observe(city, options)
	assert(motion.draw_command(source, 1, 128).position.y == 208)
	source.shadow = true
	assert(motion.draw_command(source, 1, 128).position == source.position)
	motion.advance(0.1)
	source.shadow = false
	assert(motion.draw_command(source, 1, 128).position.y == 204)
	# An early next snapshot continues at the displayed point, with no jump.
	old = motion.tracks[1].current
	write_thing(city, 1, {"px": 12})
	motion.observe(city, options)
	assert(motion.tracks[1].current == old)


func _check_lifecycle() -> void:
	var legacy := {"traffic_planes_enabled": false, "traffic_helicopters_enabled": false,
		"traffic_ships_enabled": false, "traffic_trains_enabled": false}
	assert(not VisualEnhancementOptions.normalize(legacy).traffic_vehicles_enabled)
	legacy.traffic_ships_enabled = true
	assert(VisualEnhancementOptions.normalize(legacy).traffic_vehicles_enabled)
	legacy.traffic_vehicles_enabled = false
	assert(not VisualEnhancementOptions.normalize(legacy).traffic_vehicles_enabled,
		"The combined setting must take priority over older separate settings")
	var city := fixture(1)
	var motion := CityTrafficMotion.new()
	var options := VisualEnhancementOptions.normalize({})
	motion.observe(city, options)
	write_thing(city, 1, {"px": 12})
	motion.observe(city, options)
	options.traffic_vehicles_enabled = false
	motion.observe(city, options)
	assert(motion.tracks.is_empty())
	options.traffic_vehicles_enabled = true
	motion.observe(city, options)
	assert(motion.tracks[1].current == motion.tracks[1].target)
	write_thing(city, 1, {"x": 100})
	motion.observe(city, options)
	assert(motion.tracks[1].current == motion.tracks[1].target, "Teleports must not fly across the map")
	write_thing(city, 1, {"type": 6})
	motion.observe(city, options)
	assert(motion.tracks.is_empty(), "Crashes must remove the old interpolated vehicle immediately")
	city = fixture(9)
	write_thing(city, 1, {"state": 1})
	motion.observe(city, options)
	assert(motion.tracks.is_empty(), "Nessie is not a ship enhancement")
	city = fixture(3)
	motion.observe(city, options)
	write_thing(city, 1, {"px": 12})
	motion.observe(city, options)
	motion.observe(fixture(3), options)
	assert(motion.tracks[1].current == motion.tracks[1].target, "A new city cannot inherit another city's motion")


func _check_application() -> void:
	var graphics := OS.get_environment("OPENSC2K_GRAPHICS_PACK")
	OS.set_environment("OPENSC2K_GRAPHICS_PACK", ProjectSettings.globalize_path("res://../ext/graphics"))
	var app := (load("res://main.tscn") as PackedScene).instantiate() as CityApplication
	root.add_child(app)
	await process_frame
	OS.set_environment("OPENSC2K_GRAPHICS_PACK", graphics)
	app.set_process(false)
	app.main_menu.city_background.set_process(false)
	assert(app.city_session.activate_document(fixture(3).document))
	app.map_view.zoom_factor = 2.0
	app.map_view.center_on_tile(Vector2i(64, 64))
	var deadline := Time.get_ticks_msec() + 10000
	while app.map_view.city_source == null and Time.get_ticks_msec() < deadline:
		app.static_render.poll_static_render()
		app.static_render.start_pending_static_render()
		await process_frame
	assert(app.map_view.city_source != null)
	var city := app.document_state.city
	app.moving_sprites.refresh_moving_things()
	write_thing(city, 1, {"px": 12})
	app.moving_sprites.refresh_moving_things()
	var before := DocumentState.capture(city.document)
	var engine := app.simulation_state.simulation_engine
	var random_before := [engine.random.state, engine.lfsr_random.state, engine.game_random.state]
	var motion := app.moving_sprites.traffic_motion
	var old := motion.tracks[1].current
	app.simulation_state.speed_controller.speed = GameSpeedController.Speed.PAUSED
	app.moving_sprites.process(0.1)
	assert(motion.tracks[1].current == old, "Pause must freeze real vehicle interpolation")
	app.simulation_state.speed_controller.speed = GameSpeedController.Speed.TURTLE
	app.moving_sprites.process(0.1)
	assert(motion.tracks[1].current != old)
	var ships := app.map_view.dynamic_sprites.filter(func(v: CityDynamicVisual) -> bool: return v.water_reflection != null)
	assert(not ships.is_empty())
	assert(Vector2(ships[0].water_reflection.position).distance_to(ships[0].position) <= 0.71,
		"Raster reflections must stay within half a native pixel of the displayed ship")
	app.view_state.show_vehicles = false
	app.moving_sprites.refresh_moving_things()
	assert(motion.tracks.is_empty() and app.map_view.dynamic_sprites.is_empty())
	app.view_state.show_vehicles = true
	app.moving_sprites.refresh_moving_things()
	assert(motion.tracks[1].current == motion.tracks[1].target)
	assert(DocumentState.capture(city.document) == before)
	write_thing(city, 1, {"type": 2, "z": 4})
	before = DocumentState.capture(city.document)
	app.moving_sprites.refresh_moving_things()
	var shadows := app.map_view.dynamic_sprites.filter(func(v: CityDynamicVisual) -> bool: return v.transparent_shadow)
	assert(not shadows.is_empty(), "Aircraft shadows must use alpha silhouettes")
	assert(not shadows[0].samples_static and shadows[0].shadow)
	app.preferences.visual_enhancements.traffic_shadows_enabled = false
	app.moving_sprites.refresh_moving_things()
	assert(app.map_view.dynamic_sprites.all(func(v: CityDynamicVisual) -> bool: return not v.transparent_shadow))
	app.moving_sprites.process(0.1)
	assert(DocumentState.capture(city.document) == before)
	assert([engine.random.state, engine.lfsr_random.state, engine.game_random.state] == random_before)
	# Exercise the actual train draw pipeline, retaining native crossing masks.
	for x in range(64, 67):
		city.set_building_id(x, 64, BuildingTileIds.RAIL_STRAIGHT_2)
	write_thing(city, 1, {"type": 10, "x": 64, "y": 64})
	app.moving_sprites.refresh_moving_things()
	var train_position := app.map_view.dynamic_sprites[0].position
	city.set_text_overlay_id(64, 64, 0)
	write_thing(city, 1, {"x": 65})
	app.moving_sprites.refresh_moving_things()
	assert(app.map_view.dynamic_sprites[0].position == train_position)
	before = DocumentState.capture(city.document)
	app.moving_sprites.process(0.0125)
	assert(app.map_view.dynamic_sprites[0].position.is_equal_approx(train_position + Vector2(1, 0.5)))
	app.preferences.visual_enhancements.traffic_vehicles_enabled = false
	app.moving_sprites.refresh_moving_things()
	assert(motion.tracks.is_empty() and app.map_view.dynamic_sprites[0].position == train_position + Vector2(16, 8))
	assert(DocumentState.capture(city.document) == before)
	var tab := app.main_overlays.settings_dialog.visual_tab
	var selected := tab.selected_values()
	assert(selected.traffic_vehicles_enabled)
	selected.traffic_vehicles_enabled = false
	tab.show_values(selected)
	assert(not tab.selected_values().traffic_vehicles_enabled and tab.selected_values().traffic_shadows_enabled)
	var save := AppSettingsStore.SaveOptions.new()
	save.visual_enhancements = tab.selected_values()
	var path := "user://traffic-motion-settings.cfg"
	assert(AppSettingsStore.save_values(0.5, 0.5, false, path, save) == OK)
	assert(AppSettingsStore.load_values(path).visual_enhancements == save.visual_enhancements)
	DirAccess.remove_absolute(path)
	app.queue_free()
	await process_frame


static func _check_shadow() -> void:
	var source := Image.create(4, 1, false, Image.FORMAT_RGBA8)
	source.fill(Color.WHITE)
	source.set_pixel(3, 0, Color.TRANSPARENT)
	var occluder := Image.create(4, 1, false, Image.FORMAT_RGBA8)
	occluder.set_pixel(1, 0, Color.WHITE)
	var shadow := CityAircraftShadow.create(source, occluder, Vector2i.ZERO, Vector2i(3, 1))
	assert(shadow.get_pixel(0, 0).r == 0 and is_equal_approx(shadow.get_pixel(0, 0).a, 89.0 / 255.0))
	assert(shadow.get_pixel(1, 0).a == 0, "Buildings must hide shadow pixels")
	assert(shadow.get_pixel(2, 0).a > 0 and shadow.get_pixel(3, 0).a == 0)
	assert(CityAircraftShadow.create(source, null, Vector2i(4, 0), Vector2i(3, 1)) == null)
	assert(source.get_pixel(0, 0) == Color.WHITE, "Shadow generation cannot edit the source artwork")


static func _check_pixel_parity() -> void:
	var shape := Image.create(256, 256, false, Image.FORMAT_RGBA8)
	for y in 256:
		for x in 256:
			shape.set_pixel(x, y, Color8(71, 109, 203, y))
	for format in [Image.FORMAT_RGBA8, Image.FORMAT_LA8]:
		var mask := Image.create(256, 256, false, format)
		for y in 256:
			for x in 256:
				mask.set_pixel(x, y, Color8(x, x, x, x))
		var expected: Image = mask.duplicate()
		for y in 256:
			for x in 256:
				var color := expected.get_pixel(x, y)
				color.a *= shape.get_pixel(x, y).a
				expected.set_pixel(x, y, color)
		assert(CityBrightmaps.transform_mask(mask, shape, false).get_data() == expected.get_data(),
			"All 65536 light/silhouette alpha pairs must retain the original pixels")
	var foreground := Image.create(256, 256, false, Image.FORMAT_RGBA8)
	foreground.fill_rect(Rect2i(20, 30, 70, 80), Color.WHITE)
	for origin in [Vector2i.ZERO, Vector2i(-13, -17), Vector2i(231, 237), Vector2i(500, 500)]:
		var expected := Image.create(256, 256, false, Image.FORMAT_RGBA8)
		var any_visible := false
		for y in 256:
			for x in 256:
				var point: Vector2i = origin + Vector2i(x, y)
				var alpha := int(round(y * CityAircraftShadow.OPACITY))
				if not Rect2i(0, 0, 256, 256).has_point(point) or foreground.get_pixel(x, y).a > 0:
					alpha = 0
				expected.set_pixel(x, y, Color8(0, 0, 0, alpha))
				any_visible = any_visible or alpha > 0
		var actual := CityAircraftShadow.create(shape, foreground, origin, Vector2i(256, 256))
		assert(actual != null if any_visible else actual == null)
		if actual != null:
			assert(actual.get_data() == expected.get_data(), "Native shadows must retain every alpha and clipping edge")


static func _check_artwork_cache() -> void:
	var resource := CitySpriteResource.new()
	resource.image = Image.create(8, 8, false, Image.FORMAT_RGBA8)
	resource.image.fill_rect(Rect2i(1, 1, 6, 5), Color.WHITE)
	var lights := resource.image.duplicate()
	var mask := resource.light_mask(lights, true)
	var texture := resource.light_texture()
	var first := resource.reflection(Vector2i(10, 20), 3, null)
	var next := resource.reflection(Vector2i(11, 22), 4, null)
	var fresh := WaterReflectionSprite.create(resource.image, mask, next.position, next.level)
	assert(first.position == Vector2i(10, 20) and first.level == 3)
	assert(first.image == next.image and first.emission == next.emission, "Motion must share immutable reflected artwork")
	assert(next.image.get_data() == fresh.image.get_data() and next.emission.get_data() == fresh.emission.get_data())
	assert(resource.light_mask(lights, true) == mask and resource.light_texture() == texture)
	var replacement := lights.duplicate()
	replacement.fill(Color.TRANSPARENT)
	assert(resource.light_mask(replacement, true) != mask)
	assert(resource.reflection(Vector2i.ZERO, 0, null).emission.is_invisible(), "Changed authored lights must invalidate reflection pixels")
	resource.light_mask(null, true)
	assert(resource.light_texture() == null)


static func _check_subpixels() -> void:
	for divisor in [1, 2, 4]:
		var city := fixture(3)
		var motion := CityTrafficMotion.new()
		var options := VisualEnhancementOptions.normalize({})
		motion.observe(city, options)
		var source := command()
		source.position = Vector2i(0, int(8.0 / divisor))
		var initial := Vector2(source.position * divisor) + motion.display_offset(source, divisor)
		write_thing(city, 1, {"px": 9})
		motion.observe(city, options)
		source.position = Vector2i(int(1.0 / divisor), int(8.5 / divisor))
		assert((Vector2(source.position * divisor) + motion.display_offset(source, divisor)).is_equal_approx(initial))
		motion.advance(0.1)
		var middle := Vector2(source.position * divisor) + motion.display_offset(source, divisor)
		assert(middle.is_equal_approx(initial + Vector2(0.5, 0.25)),
			"Even one-pixel ship steps must move through fractional display positions at every artwork size")


static func _check_trains() -> void:
	var options := VisualEnhancementOptions.normalize({})
	for type in [10, 11]:
		for direction in 4:
			var city := fixture(type)
			city.set_building_id(64, 64, BuildingTileIds.RAIL_STRAIGHT_1 if direction % 2 == 0 else BuildingTileIds.RAIL_STRAIGHT_2)
			var motion := CityTrafficMotion.new()
			motion.observe(city, options)
			var old := motion.tracks[1].current
			var tile: Vector2i = Vector2i(64, 64) + CityLifePaths.DIRECTIONS[direction]
			city.set_building_id(tile.x, tile.y, city.building_id(64, 64))
			city.set_text_overlay_id(64, 64, 0)
			write_thing(city, 1, {"x": tile.x, "y": tile.y, "px": 255, "py": 255, "z": 255})
			motion.observe(city, options)
			assert(motion.tracks[1].current == old, "Both engine and car must retain their displayed position on publication")
			var before := DocumentState.capture(city.document)
			motion.advance(0.0125)
			var moved := motion.tracks[1].current - old
			assert(is_equal_approx(absf(moved.x), 1.0) and is_equal_approx(absf(moved.y), 0.5), "Trains must advance through individual source pixels")
			motion.advance(0.1875)
			assert(motion.tracks[1].current == motion.tracks[1].target)
			assert(DocumentState.capture(city.document) == before)
			options.traffic_vehicles_enabled = false
			motion.observe(city, options)
			assert(motion.tracks.is_empty())
			options.traffic_vehicles_enabled = true
	# Rail artwork offsets and elevated bridge decks belong to the displayed anchor.
	var city := fixture(10)
	city.set_building_id(64, 64, BuildingTileIds.RAIL_BRIDGE)
	city.set_water_altitude(64, 64, 4)
	var motion := CityTrafficMotion.new()
	motion.observe(city, options)
	assert(motion.tracks[1].target.y == 128 * 8 - 5 * 12)
	city.set_building_id(64, 64, BuildingTileIds.RAIL_CURVE_1)
	motion.observe(city, options)
	var train := IsometricMovingVisuals.train_sprite(city, 64, 64, city.thing(1))
	assert(motion.tracks[1].target.x == train.screen_x and motion.tracks[1].target.y == 128 * 8 + train.screen_y - train.elevation)
	write_thing(city, 1, {"type": 12})
	motion.observe(city, options)
	assert(motion.tracks.is_empty(), "Entering the subway must remove the surface train immediately")


static func _check_train_pixels() -> void:
	var graphics := FixtureGraphics.pack()
	var app := CityApplication.new()
	app.asset_state.palette = graphics.palette
	app.asset_state.palette_index_encoding = Sc2Palette.index_encoding()
	app.asset_state.large_sprites = graphics.large_sprites
	for direction in 4:
		var city := fixture(10)
		var step: Vector2i = CityLifePaths.DIRECTIONS[direction]
		for x in range(60, 69):
			for y in range(60, 69):
				city.set_land_altitude(x, y, 0)
				city.set_terrain_id(x, y, TerrainTileIds.FLAT)
		for distance in range(-3, 4):
			var tile := Vector2i(64, 64) + step * distance
			city.set_building_id(tile.x, tile.y, BuildingTileIds.RAIL_STRAIGHT_1 if direction % 2 == 0 else BuildingTileIds.RAIL_STRAIGHT_2)
		app.document_state.city = city
		var context := CityGpuBuildContext.new()
		assert(context.prepare(city, app.asset_state.palette_index_encoding, graphics.large_sprites,
			CityIsometricRenderer.VIEW_LARGE, CityViewMode.Mode.CITY, true, true, true, 0, false).is_empty())
		var drawn := context.draw_records(Rect2i(1980, 1430, 240, 240))
		app.moving_sprites.set_static_occlusion_commands(CityGpuBuildContext.foreground_commands(drawn.records), CityIsometricRenderer.VIEW_LARGE)
		for type in [10, 11]:
			city.set_text_overlay_id(64 + step.x, 64 + step.y, 0)
			write_thing(city, 1, {"type": type, "x": 64, "y": 64})
			var motion := CityTrafficMotion.new()
			motion.observe(city, VisualEnhancementOptions.normalize({}))
			city.set_text_overlay_id(64, 64, 0)
			write_thing(city, 1, {"x": 64 + step.x, "y": 64 + step.y})
			motion.observe(city, VisualEnhancementOptions.normalize({}))
			var source := CityIsometricRenderer.dynamic_draw_commands(city, graphics.large_sprites)[0]
			var original := source.value_signature()
			var resource := app.moving_sprites.dynamic_sprite_resource(graphics.large_sprites, source.sprite_id, source.flip, 1)
			for frame in 17:
				var command := motion.draw_command(source, 1, city.map_size)
				var position := Vector2i((Vector2(source.position) + motion.display_offset(source, 1)).round())
				var mask := app.moving_sprites._dynamic_occluder_image(graphics.large_sprites, 1, position, resource.native_size,
					command.depth_order, true, 1, null, -1, command.train_support_orders)
				var composed := CityIsometricRenderer.occlude_dynamic_with_mask(resource.image, mask, position)
				assert(composed.occluded_pixels == 0, "Ground cut %d pixels from train %d direction %d frame %d" % [composed.occluded_pixels, type, direction, frame])
				assert(source.value_signature() == original, "Train interpolation edited the cached source command")
				motion.advance(0.0125)
	app.free()


static func _check_aircraft_pixels() -> void:
	var graphics := FixtureGraphics.pack()
	var app := CityApplication.new()
	app.asset_state.palette = graphics.palette
	app.asset_state.palette_index_encoding = Sc2Palette.index_encoding()
	app.asset_state.large_sprites = graphics.large_sprites
	var old_clipped := 0
	for direction in 8:
		var city := fixture(10)
		var step: Vector2i = DIRECTIONS[direction]
		for x in range(60, 69):
			for y in range(60, 69):
				city.set_land_altitude(x, y, 0)
				city.set_terrain_id(x, y, TerrainTileIds.FLAT)
		for distance in range(-3, 4):
			var tile := Vector2i(64, 64) + step * distance
			city.set_building_id(tile.x, tile.y, BuildingTileIds.RAIL_STRAIGHT_1 if direction % 2 == 0 else BuildingTileIds.RAIL_STRAIGHT_2)
		app.document_state.city = city
		var context := CityGpuBuildContext.new()
		assert(context.prepare(city, app.asset_state.palette_index_encoding, graphics.large_sprites,
			CityIsometricRenderer.VIEW_LARGE, CityViewMode.Mode.CITY, true, true, true, 0, false).is_empty())
		var drawn := context.draw_records(Rect2i(1980, 1430, 240, 240))
		app.moving_sprites.set_static_occlusion_commands(CityGpuBuildContext.foreground_commands(drawn.records), CityIsometricRenderer.VIEW_LARGE)
		for type in [1, 2]:
			city.set_text_overlay_id(64 + step.x, 64 + step.y, 0)
			write_thing(city, 1, {"type": type, "x": 64, "y": 64})
			var motion := CityTrafficMotion.new()
			motion.observe(city, VisualEnhancementOptions.normalize({}))
			city.set_text_overlay_id(64, 64, 0)
			write_thing(city, 1, {"x": 64 + step.x, "y": 64 + step.y})
			motion.observe(city, VisualEnhancementOptions.normalize({}))
			var source := CityIsometricRenderer.dynamic_draw_commands(city, graphics.large_sprites)[0]
			assert(source.shadow)
			var original := source.value_signature()
			var resource := app.moving_sprites.dynamic_sprite_resource(graphics.large_sprites, source.sprite_id, source.flip, 1)
			for frame in 17:
				var command := motion.draw_command(source, 1, city.map_size)
				var position := Vector2i((Vector2(source.position) + motion.display_offset(source, 1)).round())
				var mask := app.moving_sprites._dynamic_occluder_image(graphics.large_sprites, 1, position, resource.native_size,
					command.depth_order, false, 1, null, -1, PackedInt32Array(), true)
				var old_mask := app.moving_sprites._dynamic_occluder_image(graphics.large_sprites, 1, position, resource.native_size, command.depth_order)
				old_clipped += CityIsometricRenderer.occlude_dynamic_with_mask(resource.image, old_mask, position).occluded_pixels
				var composed := CityIsometricRenderer.occlude_dynamic_with_mask(resource.image, mask, position)
				assert(composed.occluded_pixels == 0, "Ground cut %d pixels from aircraft shadow %d direction %d frame %d" % [composed.occluded_pixels, type, direction, frame])
				assert(source.value_signature() == original, "Aircraft interpolation edited the cached source command")
				motion.advance(0.0125)
	print("Aircraft shadow baseline removed pixels: ", old_clipped)
	assert(old_clipped > 0, "Regression scene must exercise the original aircraft shadow clipping")
	app.free()


static func fixture(type: int) -> CityState:
	var city := CityState.from_document(EmptyCityTemplate.create(128))
	city.set_land_altitude(64, 64, 0)
	city.set_terrain_id(64, 64, 0)
	write_thing(city, 1, {"type": type, "direction": 2, "state": 0, "x": 64, "y": 64, "z": 4, "px": 8, "py": 8})
	return city


static func write_thing(city: CityState, record: int, values: Dictionary) -> void:
	var chunk := city.document.find_chunk("XTHG")
	var data := chunk.decoded_payload.duplicate()
	for field in values:
		ThingData.write(data, record * CityState.THING_RECORD_SIZE + ThingRecord.FIELDS.find(field), values[field])
	assert(chunk.set_decoded_payload(data))
	var thing := city.thing(record)
	city.set_text_overlay_id(thing.x, thing.y, OverlayData.thing_id(record))


static func command() -> CityDynamicCommand:
	var result := CityDynamicCommand.new()
	result.record = 1
	result.position = Vector2i(100, 200)
	result.depth_order = 128 * 128 + 64
	return result
