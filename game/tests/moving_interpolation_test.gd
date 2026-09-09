extends SceneTree
## Display interpolation and depth-mesh rules for smooth moving objects.

@warning_ignore_start("integer_division")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_check_blend_timing()
	_check_blend_limits()
	_check_item_colors()
	_check_settings()
	var sprites := Sc2SpriteArchive.load_path("res://../references/SIMCITY2000/DATA/LARGE.DAT")
	var city := CityState.from_document(Sc2File.load_path("res://../references/SIMCITY2000/CITIES/FLARANGE.SC2"))
	_check_anchors(city, sprites)
	_check_depth_arrays(city, sprites)
	print("PASS: moving-object blend timing, anchors, settings and depth meshes")
	quit()


func _check_blend_timing() -> void:
	var blend := func(elapsed: float, rate: int) -> float:
		return ApplicationMovingSprites.blend_alpha(elapsed, rate)

	for elapsed in [0.0, 30.0, 199.0, 200.0, 500.0]:
		assert(blend.call(elapsed, 5) == 1.0, "5 Hz keeps the original steps")

	assert(blend.call(0.0, 20) == 0.0)
	assert(blend.call(49.0, 20) == 0.0, "20 Hz changes the position every 50 ms")
	assert(blend.call(50.0, 20) == 0.25)
	assert(blend.call(99.0, 10) == 0.0)
	assert(blend.call(100.0, 10) == 0.5)
	assert(is_equal_approx(blend.call(34.0, 30), 1000.0 / 30.0 / 200.0))
	assert(is_equal_approx(blend.call(37.0, 60), 37.0 / 200.0), "60 Hz follows the frame clock")
	assert(blend.call(260.0, 60) == 1.0 and blend.call(-5.0, 20) == 0.0)


func _check_blend_limits() -> void:
	var from := IsometricMovingVisuals.Anchor.new(1, Vector2i(10, 10))
	assert(ApplicationMovingSprites.can_blend(from, IsometricMovingVisuals.Anchor.new(1, Vector2i(11, 9))))
	assert(ApplicationMovingSprites.can_blend(from, IsometricMovingVisuals.Anchor.new(1, Vector2i(12, 12))))
	assert(not ApplicationMovingSprites.can_blend(from, IsometricMovingVisuals.Anchor.new(1, Vector2i(13, 10))), "A long move is a new record")
	assert(not ApplicationMovingSprites.can_blend(from, IsometricMovingVisuals.Anchor.new(6, Vector2i(10, 10))), "A crash becomes an explosion in place")
	assert(ApplicationMovingSprites.can_blend(IsometricMovingVisuals.Anchor.new(10, Vector2i(3, 3)), IsometricMovingVisuals.Anchor.new(11, Vector2i(3, 4))), "Engines and cars share a consist")


func _check_item_colors() -> void:
	assert(CityMapMovingOcclusion.item_color(12345, CityMapMovingOcclusion.MODE_PLAIN) == Color.WHITE)

	for order in [0, 1, 255, 256, 32639, 130815]:
		var color := CityMapMovingOcclusion.item_color(order, CityMapMovingOcclusion.MODE_TRAIN)
		assert(CityGpuOcclusionDepth.decode(color) == order and color.a8 == CityMapMovingOcclusion.MODE_TRAIN)

	var unlimited := CityMapMovingOcclusion.item_color(-1, CityMapMovingOcclusion.MODE_SPRITE)
	assert(CityGpuOcclusionDepth.decode(unlimited) == CityMapMovingOcclusion.NO_OCCLUSION)
	assert(CityGpuOcclusionDepth.decode(CityGpuOcclusionDepth.encode(0x123456)) == 0x123456)


func _check_settings() -> void:
	var path := "user://moving-interpolation-settings.cfg"
	assert(AppSettingsStore.load_values(path).moving_frame_rate == 20, "20 Hz is the default")

	for rate in AppSettingsStore.MOVING_FRAME_RATES:
		assert(AppSettingsStore.save_values(0.5, 0.5, false, path, "", "", null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, rate) == OK)
		assert(AppSettingsStore.load_values(path).moving_frame_rate == rate)

	assert(AppSettingsStore.normalize_moving_frame_rate(25) == 20 and AppSettingsStore.normalize_moving_frame_rate("60") == 20)
	var dialog := preload("res://src/ui/settings/app_settings_dialog.tscn").instantiate() as AppSettingsDialog
	root.add_child(dialog)

	for rate in AppSettingsStore.MOVING_FRAME_RATES:
		dialog.select_moving_frame_rate(rate)
		assert(dialog.selected_values().moving_frame_rate == rate)

	dialog.queue_free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


## Compare anchors with draw commands so interpolation ends at the drawn position.
func _check_anchors(city: CityState, sprites: Sc2SpriteArchive) -> void:
	var configuration := CityIsometricRenderer.view_configuration(CityIsometricRenderer.VIEW_LARGE)
	var origin_x := configuration.side_margin + city.map_size * configuration.half_width + configuration.half_width
	var base_y := configuration.top_margin + configuration.tile_height
	var checked := 0

	for command in CityIsometricRenderer.dynamic_draw_commands(city, sprites, CityIsometricRenderer.VIEW_LARGE, 0):
		if command.record < 0 or command.shadow:
			continue

		var thing := city.thing(int(command.record))
		var type := int(thing.type)

		if type == 5:
			continue

		var anchor := CityIsometricRenderer.moving_thing_anchor(city, int(command.record), CityIsometricRenderer.VIEW_LARGE)
		var entry := sprites.find_sprite(int(command.sprite_id))
		var position := Vector2i(command.position)
		var expected := Vector2i(
			position.x + int(entry.width / 2) - origin_x,
			position.y + entry.height - base_y
		)

		if type == 15:
			expected.x = position.x + entry.width - origin_x

		assert(Vector2i(anchor.anchor) == expected, "Anchor of type %d must match its draw command" % type)
		assert(int(anchor.order) == int(command.depth_order))
		checked += 1

	assert(checked > 0, "Test city has no drawn moving objects")

	for record in city.thing_count():
		if int(city.thing(record).type) == 0:
			assert(CityIsometricRenderer.moving_thing_anchor(city, record, 2) == null, "An unused record has no anchor")


func _check_depth_arrays(city: CityState, sprites: Sc2SpriteArchive) -> void:
	var palette := Sc2Palette.index_encoding()
	var context := CityGpuBuildContext.new()
	var size := CityIsometricRenderer.output_size_for_view(2, city.map_size)
	var totals := {"normal": 0, "train": 0, "always": 0}

	for center in [size / 2, size / 3]:
		var bounds := Rect2i(center - Vector2i(128, 128), Vector2i(256, 256))
		var result := CityGpuRegionRenderer.render(city, palette, sprites, bounds, 2, CityViewMode.Mode.CITY, true, true, context, 1, -1)
		assert(result.ok)
		var clipped := 0
		var ignored := 0

		for command: CityStaticCommand in result.occlusion_commands:
			if Rect2i(command.position, command.size).intersection(bounds).has_area():
				clipped += 1

				if bool(command.train_ignore):
					ignored += 1

		for field in ["depth_arrays", "train_depth_arrays"]:
			var colors: PackedColorArray = result[field][Mesh.ARRAY_COLOR]
			var vertices: PackedVector2Array = result[field][Mesh.ARRAY_VERTEX]
			assert(colors.size() == vertices.size() and colors.size() % 4 == 0)
			var previous := 0

			for index in range(0, colors.size(), 4):
				var value := CityGpuOcclusionDepth.decode(colors[index])
				assert(value >= previous, "Depth quads draw in ascending value order")
				previous = value

				for corner in 4:
					assert(Rect2(Vector2.ZERO, Vector2(bounds.size)).grow(0.01).has_point(vertices[index + corner]), "Depth quads stay inside their region")

				if field == "train_depth_arrays":
					if value == CityGpuOcclusionDepth.ALWAYS:
						totals.always += 1
				else:
					totals.normal += 1

			if field == "depth_arrays":
				assert(int(colors.size() / 4.0) == clipped, "Every visible silhouette has one depth quad")
			else:
				totals.train += int(colors.size() / 4.0)
				assert(int(colors.size() / 4.0) <= clipped - ignored, "Ignored train crossings draw no train depth")

	assert(totals.normal > 0 and totals.train > 0)
	var underground := CityGpuRegionRenderer.render(city, palette, sprites, Rect2i(size / 2, Vector2i(256, 256)), 2, CityViewMode.Mode.UNDERGROUND, true, true, CityGpuBuildContext.new(), 1, -1)
	assert(underground.depth_arrays.is_empty(), "Underground regions have no moving-object depth")
