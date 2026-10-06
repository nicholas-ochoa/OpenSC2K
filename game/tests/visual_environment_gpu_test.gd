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
	viewport.queue_free()
	await process_frame
	await _check_weather_layer()
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
