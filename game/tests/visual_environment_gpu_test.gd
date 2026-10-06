extends "res://tests/support/scene_test_case.gd"

func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await _check_dispatch_lights()
	var viewport := SubViewport.new()
	viewport.size = Vector2i(16, 16)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var pixels := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	pixels.fill(Color(0.55, 0.6, 0.45))
	var sprite := Sprite2D.new()
	sprite.centered = false
	sprite.texture = ImageTexture.create_from_image(pixels)
	var material := ShaderMaterial.new()
	material.shader = preload("res://src/view/map/palette_cycle.gdshader")
	sprite.material = material
	viewport.add_child(sprite)
	await process_frame
	await RenderingServer.frame_post_draw
	var original := viewport.get_texture().get_image().get_pixel(4, 4)
	material.set_shader_parameter("environment_enabled", true)
	material.set_shader_parameter("environment_tint", Vector3(0.86, 0.93, 1.04))
	await RenderingServer.frame_post_draw
	var morning := viewport.get_texture().get_image()
	assert(morning.get_pixel(4, 4).r < original.r)
	assert(morning.get_pixel(4, 4).b >= original.b)
	assert(morning.get_pixel(4, 4).is_equal_approx(morning.get_pixel(12, 12)), "Lighting introduced a spatial gradient")
	material.set_shader_parameter("environment_tint", Vector3(1.06, 0.83, 0.57))
	await RenderingServer.frame_post_draw
	var evening := viewport.get_texture().get_image().get_pixel(4, 4)
	assert(evening.r >= original.r and evening.b < original.b)
	var emission := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	emission.fill(Color(0.9, 0.15, 0.05, 0.5))
	material.set_shader_parameter("environment_emission", ImageTexture.create_from_image(emission))
	material.set_shader_parameter("environment_has_emission", true)
	material.set_shader_parameter("environment_night", 1.0)
	material.set_shader_parameter("environment_tint", Vector3(0.28, 0.34, 0.52))
	await RenderingServer.frame_post_draw
	var lit := viewport.get_texture().get_image().get_pixel(4, 4)
	assert(lit.r > lit.b and lit.r > original.r * 0.28, "Colored, partial-strength emission was lost")
	material.set_shader_parameter("environment_enabled", false)
	await RenderingServer.frame_post_draw
	assert(viewport.get_texture().get_image().get_pixel(4, 4).is_equal_approx(original))
	material.set_shader_parameter("environment_enabled", true)
	material.set_shader_parameter("environment_tint", Vector3.ONE)
	material.set_shader_parameter("environment_has_emission", false)
	var natural_mask := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	natural_mask.fill_rect(Rect2i(0, 0, 8, 16), Color(1, 0, 0, 1))
	material.set_shader_parameter("environment_season_mask", ImageTexture.create_from_image(natural_mask))
	material.set_shader_parameter("environment_has_seasons", true)
	material.set_shader_parameter("environment_seasons", Vector4(0, 0, 0, 1))
	await RenderingServer.frame_post_draw
	var winter := viewport.get_texture().get_image()
	assert(winter.get_pixel(4, 4).r > original.r and winter.get_pixel(4, 4).b > original.b)
	assert(winter.get_pixel(12, 4).is_equal_approx(original), "Season colors reached unmasked artwork")
	material.set_shader_parameter("environment_seasons", Vector4(0, 1, 0, 0))
	await RenderingServer.frame_post_draw
	assert(viewport.get_texture().get_image().get_pixel(4, 4).is_equal_approx(original))
	material.set_shader_parameter("environment_has_seasons", false)
	material.set_shader_parameter("environment_tint", Vector3(0.28, 0.34, 0.52))
	await RenderingServer.frame_post_draw
	var dark := viewport.get_texture().get_image().get_pixel(4, 4)
	material.set_shader_parameter("environment_ambient_lift", 0.5)
	await RenderingServer.frame_post_draw
	var filled := viewport.get_texture().get_image().get_pixel(4, 4)
	assert(filled.r > dark.r and filled.b > dark.b, "Night fill failed to recover surface detail")
	pixels.fill(Color.BLACK)
	sprite.texture = ImageTexture.create_from_image(pixels)
	await RenderingServer.frame_post_draw
	assert(viewport.get_texture().get_image().get_pixel(4, 4).r == 0.0, "Night fill lifted black to grey")
	viewport.queue_free()
	await process_frame
	await _check_weather_layer()
	await _check_night_glow(false)
	await _check_night_glow(true)
	await _check_street_fixtures(false)
	await _check_street_fixtures(true)
	print("PASS: GPU uniform morning/evening tint, colored graded brightmaps and original pixels when disabled")
	quit()


func _check_dispatch_lights() -> void:
	var pack := GraphicsPack.load_root("res://../ext/graphics")
	assert(pack.error.is_empty(), pack.error)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(32, 80)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var sprite := Sprite2D.new()
	sprite.centered = false
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	viewport.add_child(sprite)
	var material := ShaderMaterial.new()
	material.shader = preload("res://src/view/map/palette_cycle.gdshader")
	sprite.material = material
	for archive: Sc2SpriteArchive in [pack.large_sprites, pack.small_medium_sprites]:
		CityDispatchLights.prepare(archive, pack.palette)
		for id: int in CityDispatchLights.HEADS:
			var entry := archive.find_sprite(id)
			if entry == null:
				continue
			var original: Image = entry.create_image(pack.palette).image
			var mask: Image = archive.visual_emission[id]
			var head_height: int = CityDispatchLights.HEADS[id][2]
			sprite.texture = ImageTexture.create_from_image(original)
			material.set_shader_parameter("environment_emission", ImageTexture.create_from_image(mask))
			material.set_shader_parameter("environment_has_emission", true)
			material.set_shader_parameter("environment_enabled", false)
			await process_frame
			await RenderingServer.frame_post_draw
			var day := viewport.get_texture().get_image()
			material.set_shader_parameter("environment_enabled", true)
			material.set_shader_parameter("environment_tint", Vector3(0.28, 0.34, 0.52))
			material.set_shader_parameter("environment_night", 1.0)
			await RenderingServer.frame_post_draw
			var night := viewport.get_texture().get_image()
			for y in entry.height:
				for x in entry.width:
					var a := day.get_pixel(x, y)
					var b := night.get_pixel(x, y)
					assert(a.a8 == b.a8, "Marker lighting changed its silhouette")
					if a.a == 0.0:
						continue
					if y < head_height:
						assert(abs(a.r8 - b.r8) <= 1 and abs(a.g8 - b.g8) <= 1 and abs(a.b8 - b.b8) <= 1,
							"Dispatch symbol lost original shading or brightness at night")
					else:
						assert(mask.get_pixel(x, y).a == 0.0, "Dispatch post was included in the light mask")
						assert(b.r <= a.r * 0.28 + 0.01 and b.g <= a.g * 0.34 + 0.01 and b.b <= a.b * 0.52 + 0.01)
	# Do not apply standard coordinates to changed SCURK artwork; authored masks win.
	var changed := Sc2SpriteArchive.new()
	var entry := pack.large_sprites.find_sprite(1382)
	var pixels: PackedInt32Array = entry.decode_indices().pixels.duplicate()
	pixels[0] = 5
	changed.entries_by_id[1382] = Sc2SpriteArchive.entry_from_indices(1382, entry.width, entry.height, pixels)
	CityDispatchLights.prepare(changed, pack.palette)
	assert(changed.visual_emission.is_empty())
	changed.visual_emission[1382] = Image.create(32, 70, false, Image.FORMAT_RGBA8)
	var custom: Image = changed.visual_emission[1382]
	CityDispatchLights.prepare(changed, pack.palette)
	assert(changed.visual_emission[1382] == custom)
	viewport.queue_free()
	await process_frame
	print("PASS: nine dispatch heads preserve daytime colors at night; posts stay dark and custom artwork is respected")


func _check_night_glow(hdr: bool) -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(128, 96)
	viewport.transparent_bg = true
	viewport.use_hdr_2d = hdr
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var app := CityApplication.new()
	var map := CityMapControl.new()
	map.size = Vector2(viewport.size)
	app.map_view = map
	viewport.add_child(map)
	var pixels := Image.create(128, 96, false, Image.FORMAT_RGBA8)
	pixels.fill(Color(0.2, 0.3, 0.4))
	var light := Image.create(128, 96, false, Image.FORMAT_RGBA8)
	light.fill_rect(Rect2i(60, 44, 8, 8), Color(1.0, 0.35, 0.1, 0.5))
	map.city_source = CityMapSource.whole(ImageTexture.create_from_image(pixels))
	map.city_source.emission = ImageTexture.create_from_image(light)
	map.source_center = Vector2(64, 48)
	map.layers._sync_base_layer()
	var options := VisualEnhancementOptions.normalize({"night_ground": 0.0, "night_glow": 100.0})
	var lighting := app.visual_environment.night_lighting
	lighting.process(true, 1.0, options)
	for i in 4:
		await RenderingServer.frame_post_draw
	var on := viewport.get_texture().get_image()
	lighting.process(true, 0.0, options)
	await RenderingServer.frame_post_draw
	var off := viewport.get_texture().get_image()
	var delta := on.get_pixel(58, 48) - off.get_pixel(58, 48)
	assert(delta.r > 0.01 and delta.r > delta.g * 1.5, "Graded, colored emission produced no local glow outside its sharp core")
	assert(on.get_pixel(10, 10).is_equal_approx(off.get_pixel(10, 10)), "Glow added a full-screen veil: hdr=%s on=%s off=%s" % [hdr, on.get_pixel(10, 10), off.get_pixel(10, 10)])
	# Repeated updates must keep both weather and tool markers above the glow.
	var marker := ColorRect.new()
	marker.color = Color.GREEN
	marker.position = Vector2(56, 40)
	marker.size = Vector2(16, 16)
	for target in [map.layers.overlay_layer, app.visual_environment.weather]:
		if target is CityVisualWeather:
			target.rain = 0.5
			target._sync_layer(true)
			target.layer.show()
			target.layer.add_child(marker)
		else:
			target.add_child(marker)
		await RenderingServer.frame_post_draw
		var marker_pixel := viewport.get_texture().get_image().get_pixel(58, 48)
		for frame in 4:
			lighting.process(true, 1.0, options)
			await RenderingServer.frame_post_draw
			assert(viewport.get_texture().get_image().get_pixel(58, 48).is_equal_approx(marker_pixel), "Night glow covered weather or tool overlays")
		marker.get_parent().remove_child(marker)
	marker.free()
	app.visual_environment.weather.layer.hide()
	lighting.process(true, 1.0, options)
	var cover := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	cover.fill(Color.WHITE)
	lighting._add_texture(ImageTexture.create_from_image(cover), null, Vector2(56, 40), Vector2(16, 16))
	for i in 4:
		await RenderingServer.frame_post_draw
	assert(viewport.get_texture().get_image().get_data() == off.get_data(), "Hidden windows leaked through foreground geometry")
	assert(lighting.ground.visible == false)
	lighting.process(false, 1.0, options)
	assert(not lighting.output.visible)
	for buffer in lighting.buffers:
		assert(buffer.render_target_update_mode == SubViewport.UPDATE_DISABLED)
	viewport.queue_free()
	app.free()
	await process_frame


func _check_street_fixtures(hdr: bool) -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(96, 80)
	viewport.use_hdr_2d = hdr
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var background := ColorRect.new()
	background.size = Vector2(viewport.size)
	background.color = Color(0.08, 0.09, 0.12)
	viewport.add_child(background)
	await RenderingServer.frame_post_draw
	var before := viewport.get_texture().get_image()
	var app := CityApplication.new()
	app.document_state.city = load("res://tests/city_life_test.gd").fixture()
	var ground := CityNightGround.new()
	viewport.add_child(ground)
	var tile := Vector2i(64, 64)
	for axis in 2:
		ground.masker._occluders[Vector3i(tile.x, tile.y, axis)] = []
	var surface := ground._build(app, tile)
	ground.position = Vector2(16, 8) - Vector2(surface.origin)
	ground.cache[tile] = surface
	ground.visible_tiles = [tile]
	(ground.material as ShaderMaterial).set_shader_parameter("strength", 0.45)
	ground.queue_redraw()
	ground.fixtures.queue_redraw()
	await RenderingServer.frame_post_draw
	var after := viewport.get_texture().get_image()
	var red := 0
	var green := 0
	var warm := 0
	for y in after.get_height():
		for x in after.get_width():
			var pixel := after.get_pixel(x, y)
			red += int(pixel.r > 0.6 and pixel.r > pixel.g * 2.0)
			green += int(pixel.g > 0.6 and pixel.g > pixel.r * 1.5)
			warm += int(pixel.r > before.get_pixel(x, y).r + 0.08 and pixel.r > pixel.b * 1.3)
	assert(red >= 2 and green >= 2, "Junction lamps are missing red or green output on the GPU")
	assert(warm > 50, "Street light pools remain too small or dim to read: hdr=%s warm=%d red=%d green=%d" % [hdr, warm, red, green])
	ground.clock = 6.0
	ground.fixtures.queue_redraw()
	await RenderingServer.frame_post_draw
	assert(viewport.get_texture().get_image().get_data() != after.get_data(), "Cosmetic signal phase failed to change visible lenses")
	ground.hide()
	await RenderingServer.frame_post_draw
	assert(viewport.get_texture().get_image().get_data() == before.get_data(), "Disabled street lighting left fixtures behind")
	viewport.queue_free()
	app.free()
	await process_frame


func _check_weather_layer() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(256, 192)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var app := CityApplication.new()
	var map := CityMapControl.new()
	map.size = Vector2(viewport.size)
	app.map_view = map
	viewport.add_child(map)
	var pixels := Image.create(256, 192, false, Image.FORMAT_RGBA8)
	pixels.fill(Color(0.2, 0.3, 0.15))
	map.city_source = CityMapSource.whole(ImageTexture.create_from_image(pixels))
	map.source_center = Vector2(128, 96)
	map.layers._sync_base_layer()
	# The map can also publish direct draw commands before a texture layer
	# exists. This path must not draw over the precipitation child.
	map.layers.base_layer.hide()
	map.layers.base_layer = null
	map.queue_redraw()
	var marker := ColorRect.new()
	marker.color = Color(0.1, 0.9, 0.2)
	marker.size = Vector2(12, 12)
	marker.position = Vector2(100, 80)
	map.layers.overlay_layer.add_child(marker)
	app.preferences.visual_enhancements = VisualEnhancementOptions.normalize({"weather_mode": 2})
	var weather := app.visual_environment.weather
	weather.process(5.0, 0.0, true, 1.0)
	await RenderingServer.frame_post_draw
	var sunny := viewport.get_texture().get_image()
	for kind in [CityVisualWeather.Kind.LIGHT_RAIN, CityVisualWeather.Kind.HEAVY_RAIN, CityVisualWeather.Kind.LIGHT_SNOW, CityVisualWeather.Kind.HEAVY_SNOW]:
		app.preferences.visual_enhancements.weather_fixed = kind
		weather.process(5.0, 0.0, true, 3.0)
		if kind in [CityVisualWeather.Kind.LIGHT_SNOW, CityVisualWeather.Kind.HEAVY_SNOW]:
			assert(weather.snow > 0.0 and weather.rain == 0.0, "Winter snow did not reach the particle shader")
		await RenderingServer.frame_post_draw
		var rendered := viewport.get_texture().get_image()
		assert(rendered.get_pixel(104, 84).is_equal_approx(sunny.get_pixel(104, 84)), "Weather covered a tool overlay")
		var changed := 0
		for y in range(16, 176):
			for x in range(16, 240):
				if not rendered.get_pixel(x, y).is_equal_approx(sunny.get_pixel(x, y)):
					changed += 1
		assert(changed > 100 and changed < 20000, "Weather particles are absent or cover the entire city: %d" % changed)
	# Fixed summer snow reaches the GPU; both precipitation types have smaller
	# screen footprints in the overview and remain visible at every zoom level.
	for kind in [CityVisualWeather.Kind.HEAVY_RAIN, CityVisualWeather.Kind.HEAVY_SNOW]:
		app.preferences.visual_enhancements.weather_fixed = kind
		var footprints: Array[float] = []
		for zoom in CityMapConstants.ZOOM_LEVELS:
			map.zoom_factor = zoom
			weather.process(5.0, 0.0, true, 1.0)
			weather.clock = 9.25
			weather._sync_layer(true)
			await RenderingServer.frame_post_draw
			var rendered := viewport.get_texture().get_image()
			footprints.append(_particle_width(rendered, sunny))
		assert(footprints.back() > footprints.front() + 0.1, "Precipitation did not scale with map zoom")
	map.zoom_factor = 1.0
	weather._sync_layer(true)
	var original_center := map.source_center
	for kind in [CityVisualWeather.Kind.HEAVY_RAIN, CityVisualWeather.Kind.HEAVY_SNOW]:
		app.preferences.visual_enhancements.weather_fixed = kind
		weather.process(5.0, 0.0, true, 1.0)
		await RenderingServer.frame_post_draw
		var stationary := viewport.get_texture().get_image().get_data()
		map.source_center += Vector2(120, 80)
		weather._sync_layer(true)
		await RenderingServer.frame_post_draw
		assert(viewport.get_texture().get_image().get_data() != stationary, "Frozen precipitation did not respond to camera panning")
		map.source_center = original_center
		weather._sync_layer(true)
		await RenderingServer.frame_post_draw
		assert(viewport.get_texture().get_image().get_data() == stationary, "Returning the camera changed the precipitation field")
	var pan_before_zoom := weather.camera_pan
	map.zoom_factor = 2.0
	map.source_center += Vector2(20, 10)
	weather._sync_layer(true)
	assert(weather.camera_pan.is_equal_approx(pan_before_zoom), "Anchored zoom introduced a false parallax pan")
	map.zoom_factor = 1.0
	map.source_center = original_center
	weather.reset()
	weather._sync_layer(true)
	assert(weather.camera_pan == Vector2.ZERO, "New city inherited the previous camera drift")
	weather.flash = 1.0
	weather.rain = 0.0
	weather.snow = 0.0
	weather.lightning.origin = Vector2(0.0, 0.0)
	weather.lightning.spread = 0.5
	weather._sync_layer(true)
	await RenderingServer.frame_post_draw
	var discharge := viewport.get_texture().get_image()
	assert(discharge.get_pixel(30, 30).r > sunny.get_pixel(30, 30).r, "Lightning was hidden behind the city")
	assert(discharge.get_pixel(30, 30).r > discharge.get_pixel(220, 160).r, "Lightning lost its spatial origin")
	assert(discharge.get_pixel(104, 84).is_equal_approx(sunny.get_pixel(104, 84)), "Lightning covered the tool overlay")
	weather.flash = 0.0
	app.preferences.visual_enhancements.weather_fixed = CityVisualWeather.Kind.SUNNY
	weather.process(5.0, 0.0, true, 1.0)
	await RenderingServer.frame_post_draw
	assert(viewport.get_texture().get_image().get_data() == sunny.get_data(), "Sunny changed original city pixels")
	viewport.queue_free()
	app.free()
	await process_frame


func _particle_width(rendered: Image, background: Image) -> float:
	var covered := 0
	var adjacent := 0
	for y in range(16, 176):
		for x in range(16, 239):
			if rendered.get_pixel(x, y).r - background.get_pixel(x, y).r > 0.03:
				covered += 1
				if rendered.get_pixel(x + 1, y).r - background.get_pixel(x + 1, y).r > 0.03:
					adjacent += 1
	assert(covered > 60, "Precipitation disappeared at a map zoom level")
	return float(adjacent) / maxf(covered, 1.0)
