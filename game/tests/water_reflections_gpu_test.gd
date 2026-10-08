extends "res://tests/support/scene_test_case.gd"

const SHADER := preload("res://src/view/water/water_surface.gdshader")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_check_moving_texture_reuse()
	await _check_unlit_ship_regions()
	await _check_resident_water_uploads()
	var viewport := SubViewport.new()
	viewport.size = Vector2i(32, 32)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var background := ColorRect.new()
	background.size = Vector2(32, 32)
	background.color = Color(0.08, 0.16, 0.65)
	viewport.add_child(background)
	var palette := Image.create(256, 1, false, Image.FORMAT_RGBA8)
	palette.fill(Color(0.08, 0.16, 0.65))
	palette.set_pixel(40, 0, Color(0.7, 0.2, 0.1))
	var surface := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	surface.fill(Color(6.0 / 255.0, 96.0 / 255.0, 0, 1))
	surface.fill_rect(Rect2i(16, 0, 16, 32), Color.TRANSPARENT)
	var mirror := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	mirror.fill(Color(40.0 / 255.0, 0, 0, 1))
	var sprite := Sprite2D.new()
	sprite.centered = false
	sprite.texture = ImageTexture.create_from_image(mirror)
	var material := ShaderMaterial.new()
	material.shader = SHADER
	material.set_shader_parameter("animated_palette", ImageTexture.create_from_image(palette))
	material.set_shader_parameter("water_surface", ImageTexture.create_from_image(surface))
	material.set_shader_parameter("water_enabled", false)
	material.set_shader_parameter("water_geometry_preview", true)
	sprite.material = material
	viewport.add_child(sprite)
	await process_frame
	await RenderingServer.frame_post_draw
	var original := viewport.get_texture().get_image()
	material.set_shader_parameter("water_enabled", true)
	await RenderingServer.frame_post_draw
	var reflected := viewport.get_texture().get_image()
	assert(reflected.get_pixel(8, 8).r > 0.6, "Geometric reflection lost its source color")
	assert(reflected.get_pixel(24, 8).is_equal_approx(original.get_pixel(24, 8)), "Water shader changed land")
	assert(reflected.get_pixel(1, 8).is_equal_approx(original.get_pixel(1, 8)), "Padded region edge was drawn twice")
	material.set_shader_parameter("water_geometry_preview", false)
	material.set_shader_parameter("water_clock", 0.0)
	await RenderingServer.frame_post_draw
	var subtle := viewport.get_texture().get_image()
	assert(subtle.get_pixel(8, 8).r < reflected.get_pixel(8, 8).r)
	material.set_shader_parameter("water_reflections_enabled", false)
	await RenderingServer.frame_post_draw
	assert(viewport.get_texture().get_image().get_pixel(8, 8).r < subtle.get_pixel(8, 8).r,
		"Reflection Off ignored the independent mirror switch")
	material.set_shader_parameter("water_reflections_enabled", true)
	var emission := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	emission.fill(Color(0.9, 0.2, 0.05, 0.75))
	material.set_shader_parameter("environment_enabled", true)
	material.set_shader_parameter("environment_tint", Vector3(0.28, 0.34, 0.52))
	material.set_shader_parameter("environment_night", 1.0)
	material.set_shader_parameter("environment_emission", ImageTexture.create_from_image(emission))
	material.set_shader_parameter("environment_has_emission", true)
	await RenderingServer.frame_post_draw
	var night := viewport.get_texture().get_image()
	assert(night.get_pixel(8, 8).r > original.get_pixel(8, 8).r * 0.28, "Colored reflected brightmaps disappeared")
	material.set_shader_parameter("environment_enabled", false)
	mirror.fill(Color(0, 0, 0, 0))
	(sprite.texture as ImageTexture).update(mirror)
	var bottom := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	bottom.fill(Color(5.0 / 31.0, 0.8, 0, 1))
	material.set_shader_parameter("water_seabed", ImageTexture.create_from_image(bottom))
	material.set_shader_parameter("water_has_seabed", true)
	material.set_shader_parameter("water_topography", true)
	await RenderingServer.frame_post_draw
	var shallow := viewport.get_texture().get_image().get_pixel(8, 8)
	bottom.fill(Color(0, 0.8, 0, 1))
	(material.get_shader_parameter("water_seabed") as ImageTexture).update(bottom)
	await RenderingServer.frame_post_draw
	var deep := viewport.get_texture().get_image().get_pixel(8, 8)
	assert(shallow.r > deep.r, "Shallow water did not reveal more real seabed than deep water")
	material.set_shader_parameter("water_topography", false)
	await RenderingServer.frame_post_draw
	var unshadowed := viewport.get_texture().get_image().get_pixel(8, 8)
	var cloud_field := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	cloud_field.fill(Color.WHITE)
	material.set_shader_parameter("cloud_field", ImageTexture.create_from_image(cloud_field))
	material.set_shader_parameter("cloud_enabled", true)
	material.set_shader_parameter("cloud_density", 1.0)
	material.set_shader_parameter("cloud_shadow_strength", 0.3)
	await RenderingServer.frame_post_draw
	var shadowed := viewport.get_texture().get_image().get_pixel(8, 8)
	assert(shadowed.b < unshadowed.b, "Water pass erased cloud shadows")
	mirror.fill(Color(40.0 / 255.0, 0, 0, 1))
	(sprite.texture as ImageTexture).update(mirror)
	material.set_shader_parameter("water_geometry_preview", true)
	await RenderingServer.frame_post_draw
	var shaded_mirror := viewport.get_texture().get_image().get_pixel(8, 8)
	material.set_shader_parameter("cloud_enabled", false)
	await RenderingServer.frame_post_draw
	var clear_mirror := viewport.get_texture().get_image().get_pixel(8, 8)
	assert(absf(shaded_mirror.r / clear_mirror.r - shadowed.b / unshadowed.b) < 0.02,
		"Water and reflected artwork must receive the same cloud shadow")
	material.set_shader_parameter("water_geometry_preview", false)
	material.set_shader_parameter("water_enabled", false)
	await RenderingServer.frame_post_draw
	assert(viewport.get_texture().get_image().get_data() == original.get_data(), "Off did not restore exact original pixels")
	material.set_shader_parameter("cloud_enabled", false)
	await _check_surface_details(viewport, sprite, material, mirror, bottom)
	await _check_waves(viewport, sprite, material, mirror, bottom)
	await _check_seasonal_water(viewport, material)
	viewport.queue_free()
	await process_frame
	var fixture: Dictionary = load("res://tests/water_reflections_test.gd").fixture()
	var context := CityGpuBuildContext.new()
	context.builder = fixture.builder
	var archive := Sc2SpriteArchive.new()
	archive.water_reflections = true
	archive.water_indices = fixture.indices
	var source := CityMapSource.new(Vector2i(1024, 1024))
	var layer := CityWaterLayer.new()
	root.add_child(layer)
	layer.configure_whole(context, archive, 1, source.get_instance_id())
	layer.set_environment({"water_enabled": true, "water_frozen": true})
	layer.sync(source, 1.0, Vector2.ZERO, ImageTexture.create_from_image(palette), Rect2(fixture.bounds))
	assert(layer.visible and not layer.nodes.is_empty(), "Whole-image CPU path omitted the water pass")
	var retained := layer.whole_regions.duplicate()
	layer.sync(source, 1.0, Vector2.ZERO, ImageTexture.create_from_image(palette), Rect2(fixture.bounds))
	assert(layer.whole_regions == retained, "Unchanged camera rebuilt water geometry")
	var target: Sprite2D = layer.nodes.values()[0]
	var region: WaterReflectionRegion = target.get_meta("region")
	var receiver := Vector2i(-1, -1)
	for y in region.surface.get_height():
		for x in region.surface.get_width():
			if region.surface.get_pixel(x, y).a > 0:
				receiver = Vector2i(x, y)
				break
		if receiver.x >= 0:
			break
	assert(receiver.x >= 0)
	var floating := WaterReflectionSprite.new()
	floating.position = region.bounds.position + receiver
	floating.level = roundi(region.surface.get_pixelv(receiver).r * 255.0) - 1
	floating.image = Image.create(1, 1, false, Image.FORMAT_RGBA8)
	floating.image.fill(Color(0.8, 0, 0, 1))
	floating.emission = Image.create(1, 1, false, Image.FORMAT_RGBA8)
	var visual := CityDynamicVisual.new()
	visual.water_reflection = floating
	layer.set_moving([visual])
	assert(target.texture.get_image().get_pixelv(receiver).r > 0.79, "Moving boat reflection was omitted")
	layer.set_moving([])
	assert(target.texture == region.textures.reflected, "Departed boat left a stale reflection")
	layer.set_environment({"water_enabled": false})
	assert(not layer.visible)
	layer.queue_free()
	await process_frame
	print("PASS: GPU reflection source colors, static occlusion, region clipping, subtle attenuation, brightmaps, depth-dependent transmission and exact Off output")
	quit()


func _check_surface_details(viewport: SubViewport, sprite: Sprite2D, material: ShaderMaterial, mirror: Image, bottom: Image) -> void:
	material.set_shader_parameter("water_enabled", true)
	material.set_shader_parameter("water_reflections_enabled", false)
	material.set_shader_parameter("water_topography", true)
	bottom.fill(Color(5.0 / 31.0, 0.8, 0, 1))
	var seabed := material.get_shader_parameter("water_seabed") as ImageTexture
	seabed.update(bottom)
	await RenderingServer.frame_post_draw
	var light_face := viewport.get_texture().get_image().get_pixel(8, 8)
	bottom.fill(Color(5.0 / 31.0, 0.2, 0, 1))
	seabed.update(bottom)
	await RenderingServer.frame_post_draw
	assert(viewport.get_texture().get_image().get_pixel(8, 8).r < light_face.r,
		"Underwater slope faces lost their geometry shading")
	var tones := {}
	for origin in [0.0, 96.0, 192.0, 288.0, 384.0]:
		material.set_shader_parameter("water_origin", Vector2(origin, 0))
		await RenderingServer.frame_post_draw
		tones[viewport.get_texture().get_image().get_pixel(8, 8).to_rgba32()] = true
	assert(tones.size() > 1, "Water body has no map-anchored variation")
	material.set_shader_parameter("water_origin", Vector2(4, 0))
	await RenderingServer.frame_post_draw
	var shifted := viewport.get_texture().get_image().get_pixel(8, 8)
	material.set_shader_parameter("water_origin", Vector2.ZERO)
	await RenderingServer.frame_post_draw
	assert(shifted == viewport.get_texture().get_image().get_pixel(12, 8),
		"Water pattern moves with region boundaries instead of map coordinates")
	# Opaque contact columns must stay attached even at maximum rain.
	# Alpha attenuation permits ripples farther away from those contacts.
	for x in 32:
		mirror.fill_rect(Rect2i(x, 0, 1, 32), Color((40.0 if x % 2 == 0 else 96.0) / 255.0, 0, 0, 1))
	(sprite.texture as ImageTexture).update(mirror)
	material.set_shader_parameter("water_reflections_enabled", true)
	material.set_shader_parameter("water_rain", 1.0)
	material.set_shader_parameter("water_waves_enabled", true)
	for time in [0.0, 2.0, 7.0]:
		material.set_shader_parameter("water_clock", time)
		await RenderingServer.frame_post_draw
		var result := viewport.get_texture().get_image()
		assert(result.get_pixel(8, 8).r > result.get_pixel(9, 8).r,
			"Ripple displaced a reflection's water contact")


func _check_waves(viewport: SubViewport, sprite: Sprite2D, material: ShaderMaterial, mirror: Image, bottom: Image) -> void:
	mirror.fill(Color.TRANSPARENT)
	(sprite.texture as ImageTexture).update(mirror)
	bottom.fill(Color(0, 0.8, 1, 1))
	(material.get_shader_parameter("water_seabed") as ImageTexture).update(bottom)
	for pair in [["water_waves_enabled", true], ["water_reflections_enabled", false],
		["water_topography", false], ["water_enabled", true], ["water_clock", 0.0],
		["water_rain", 0.0], ["environment_enabled", false], ["cloud_enabled", false]]:
		material.set_shader_parameter(pair[0], pair[1])
	await RenderingServer.frame_post_draw
	var first := viewport.get_texture().get_image()
	material.set_shader_parameter("water_clock", 2.0)
	await RenderingServer.frame_post_draw
	var next := viewport.get_texture().get_image()
	assert(first.get_data() != next.get_data(), "Open water waves are not animated")
	assert(first.get_pixel(24, 8) == next.get_pixel(24, 8), "Waves reached dry land")
	material.set_shader_parameter("water_waves_enabled", false)
	await RenderingServer.frame_post_draw
	var still := viewport.get_texture().get_image()
	material.set_shader_parameter("water_clock", 8.0)
	await RenderingServer.frame_post_draw
	assert(still.get_data() == viewport.get_texture().get_image().get_data(), "Disabled waves still animate")
	# A cached coastal contour adds moving foam without changing the terrain.
	material.set_shader_parameter("water_waves_enabled", true)
	bottom.fill(Color(0, 0.8, 6.0 * 8.0 / 255.0, 1))
	(material.get_shader_parameter("water_seabed") as ImageTexture).update(bottom)
	await RenderingServer.frame_post_draw
	var shore := viewport.get_texture().get_image()
	material.set_shader_parameter("water_clock", 9.2)
	await RenderingServer.frame_post_draw
	assert(shore.get_data() != viewport.get_texture().get_image().get_data(), "Coastal surf is static")
	material.set_shader_parameter("water_origin", Vector2(4, 0))
	await RenderingServer.frame_post_draw
	var shifted := viewport.get_texture().get_image().get_pixel(8, 8)
	material.set_shader_parameter("water_origin", Vector2.ZERO)
	await RenderingServer.frame_post_draw
	assert(shifted == viewport.get_texture().get_image().get_pixel(12, 8), "Wave phase changes at region boundaries")
	material.set_shader_parameter("water_waves_enabled", false)


func _check_seasonal_water(viewport: SubViewport, material: ShaderMaterial) -> void:
	for pair in [["water_geometry_preview", true], ["water_reflections_enabled", false], ["water_topography", false],
		["environment_enabled", true], ["environment_has_emission", false], ["environment_tint", Vector3.ONE],
		["environment_saturation", 1.0], ["environment_weather", Vector3.ONE], ["environment_frost", 0.0],
		["environment_day_lut_strength", 0.0], ["environment_weather_lut_strength", 0.0],
		["environment_season_lut_strength", 0.0], ["water_season_strength", 0.0]]:
		material.set_shader_parameter(pair[0], pair[1])
	await RenderingServer.frame_post_draw
	var original := viewport.get_texture().get_image()
	var water := original.get_pixel(8, 8)
	var colors: Array[Color] = []
	material.set_shader_parameter("water_season_strength", 1.0)
	for season in range(4):
		var weights := Vector4.ZERO
		weights[season] = 1.0
		material.set_shader_parameter("environment_seasons", weights)
		await RenderingServer.frame_post_draw
		var result := viewport.get_texture().get_image()
		colors.append(result.get_pixel(8, 8))
		assert(result.get_pixel(24, 8) == original.get_pixel(24, 8), "Seasonal water color reached dry land")
		assert(colors[-1] != water, "Seasonal water color missing: %d" % season)
	assert(colors[0].g > colors[1].g and colors[2].r > colors[0].r and colors[2].b < colors[1].b)
	assert(colors[3].g > colors[1].g and colors[3].b > colors[2].b)
	material.set_shader_parameter("environment_seasons", Vector4(0.5, 0.5, 0, 0))
	await RenderingServer.frame_post_draw
	var blended := viewport.get_texture().get_image().get_pixel(8, 8)
	var expected := colors[0].lerp(colors[1], 0.5)
	assert(maxf(absf(blended.r - expected.r), maxf(absf(blended.g - expected.g), absf(blended.b - expected.b))) < 0.01, "Water season transition is discontinuous")
	material.set_shader_parameter("water_season_strength", 0.0)
	await RenderingServer.frame_post_draw
	assert(viewport.get_texture().get_image().get_pixel(8, 8) == water, "Zero seasonal water strength changed pixels")
	material.set_shader_parameter("water_season_strength", 1.0)
	material.set_shader_parameter("environment_enabled", false)
	await RenderingServer.frame_post_draw
	assert(viewport.get_texture().get_image().get_pixel(8, 8) == water, "Disabled environment still colored the water")
	# A reflected fully emissive object retains its authored light color.
	var reflected := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	reflected.fill(Color(40.0 / 255.0, 0, 0, 1))
	(viewport.get_child(1) as Sprite2D).texture = ImageTexture.create_from_image(reflected)
	var emission := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	emission.fill(Color(0.9, 0.15, 0.05, 1))
	material.set_shader_parameter("environment_emission", ImageTexture.create_from_image(emission))
	material.set_shader_parameter("environment_has_emission", true)
	material.set_shader_parameter("environment_night", 1.0)
	material.set_shader_parameter("environment_enabled", true)
	material.set_shader_parameter("water_reflections_enabled", true)
	await RenderingServer.frame_post_draw
	var light := viewport.get_texture().get_image().get_pixel(8, 8)
	assert(light.r > 0.89 and light.g < 0.16 and light.b < 0.06, "Water tint recolored reflected night lights")
	material.set_shader_parameter("water_season_strength", 0.0)


func _check_moving_texture_reuse() -> void:
	var region := WaterReflectionRegion.new()
	region.bounds = Rect2i(0, 0, 8, 8)
	for key in ["surface", "reflected", "emission", "seasons"]:
		region.set(key, Image.create(8, 8, false, Image.FORMAT_RGBA8))
	region.surface.fill(Color(1.0 / 255.0, 0, 0, 1))
	var ship := WaterReflectionSprite.new()
	ship.image = Image.create(2, 2, false, Image.FORMAT_RGBA8)
	ship.image.fill(Color.RED)
	ship.emission = ship.image.duplicate()
	ship.position = Vector2i(1, 1)
	var first := region.compose_moving([ship]).duplicate()
	assert((first.reflected as ImageTexture).get_image().get_pixel(1, 1) == Color.RED)
	var moved := WaterReflectionSprite.new()
	moved.image = ship.image
	moved.emission = ship.emission
	moved.position = Vector2i(4, 4)
	var second := region.compose_moving([moved])
	for key in ["reflected", "emission", "seasons"]:
		assert(second[key] == first[key], "Moving water reflections reallocated a GPU texture")
	var pixels := (second.reflected as ImageTexture).get_image()
	assert(pixels.get_pixel(1, 1).a == 0.0, "Moving reflection left stale pixels")
	assert(pixels.get_pixel(4, 4) == Color.RED)
	assert(region.compose_moving([]).is_empty(), "Removing the last ship retained its reflection")
	assert(not region.compose_moving([ship]).is_empty(), "A returning ship lost its reflection")


func _check_unlit_ship_regions() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(64, 32)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var palette := Image.create(256, 1, false, Image.FORMAT_RGBA8)
	palette.fill(Color(0.05, 0.2, 0.7))
	palette.set_pixel(40, 0, Color(0.8, 0.3, 0.1))
	var palette_texture := ImageTexture.create_from_image(palette)
	var source := CityMapSource.new(Vector2i(64, 32))
	for x in [0, 32]:
		var region := WaterReflectionRegion.new()
		region.bounds = Rect2i(x, 0, 32, 32).grow(WaterReflectionRegion.PADDING)
		for key in ["surface", "reflected", "emission", "seasons"]:
			region.set(key, Image.create(38, 38, false, Image.FORMAT_RGBA8))
		region.surface.fill(Color(1.0 / 255.0, 96.0 / 255.0, 0, 1))
		var entry := CityMapSource.TileEntry.new(Vector2(x, 0), Vector2(32, 32), null)
		entry.water = region
		source.tiles.append(entry)
	var resource := CitySpriteResource.new()
	resource.image = Image.create(4, 4, false, Image.FORMAT_RGBA8)
	resource.image.fill(Color(40.0 / 255.0, 0, 0, 1))
	var light := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	light.fill(Color(1.0, 0.2, 0.1))
	resource.light_mask(light, false)
	var original := resource.reflection(Vector2i(8, 8), 0, null)
	var original_emission := original.emission.get_data()
	var unlit := resource.reflection(Vector2i(8, 8), 0, null, false)
	assert(unlit.emission != null and unlit.emission.is_invisible())
	assert(unlit.emission == resource.reflection(Vector2i(20, 8), 0, null, false).emission,
		"Ship motion must reuse the transparent emission mask")
	assert(original.emission.get_data() == original_emission and not original.emission.is_invisible(),
		"Hiding lights must not erase their shared source mask")
	var layer := CityWaterLayer.new()
	viewport.add_child(layer)
	layer.set_environment({"water_enabled": true, "water_frozen": true, "water_geometry_preview": true})
	var visual := CityDynamicVisual.new()
	visual.water_reflection = unlit
	# A ship can already overlap a region when its water node is first created.
	layer.set_moving([visual])
	for zoom in [0.25, 0.5, 1.0]:
		layer.sync(source, zoom, Vector2.ZERO, palette_texture)
		for lit in [false, true, false]:
			for x in [8, 30, 40]:
				visual.water_reflection = resource.reflection(Vector2i(x, 8), 0, null, lit)
				layer.set_moving([visual])
				await RenderingServer.frame_post_draw
				var frame := viewport.get_texture().get_image()
				for point in [Vector2(4, 4), Vector2(28, 24), Vector2(36, 4), Vector2(60, 24)]:
					var pixel := frame.get_pixelv(Vector2i(point * zoom))
					assert(pixel.a > 0.98 and pixel.b > 0.6, "An unlit ship removed its water region at zoom %s" % zoom)
				var ship_pixel := frame.get_pixelv(Vector2i(Vector2(x + 2, 13) * zoom))
				assert(ship_pixel.r > 0.7, "Hiding lights must preserve the reflected ship")
				for node: Sprite2D in layer.nodes.values():
					var emission: ImageTexture = node.material.get_shader_parameter("environment_emission")
					assert(lit or emission.get_image().is_invisible(), "Unlit ship still emitted reflected light")
		# Returning to a cached region must keep the same complete surface.
		layer.sync(null, zoom, Vector2.ZERO, palette_texture)
		layer.sync(source, zoom, Vector2.ZERO, palette_texture)
	layer.set_moving([])
	await RenderingServer.frame_post_draw
	assert(viewport.get_texture().get_image().get_pixel(42, 13).b > 0.6)
	viewport.queue_free()
	await process_frame


func _check_resident_water_uploads() -> void:
	var cache := CityRegionCache.new()
	cache.resident = true
	cache.region_edge = 32
	var worker := CityRegionCache.RegionWorker.new()
	var snapshots := []
	for x in 12:
		var key := Vector2i(x, 0)
		cache.wanted_keys[key] = true
		var result := CityGpuRegionResult.new()
		result.key = key
		result.bounds = Rect2i(x * 32, 0, 32, 32)
		result.gpu_arrays.resize(Mesh.ARRAY_MAX)
		result.gpu_arrays[Mesh.ARRAY_VERTEX] = PackedVector2Array()
		var region := WaterReflectionRegion.new()
		region.bounds = result.bounds.grow(WaterReflectionRegion.PADDING)
		for name in ["surface", "reflected", "emission", "seasons", "seabed"]:
			region.set(name, Image.create(38, 38, false, Image.FORMAT_RGBA8))
		region.surface.fill(Color(1.0 / 255.0, 96.0 / 255.0, 0, 1))
		result.water = region
		snapshots.append(region.surface.get_data())
		CityRegionScheduling._publish_region(cache, worker, result)
		assert(region.textures.is_empty(), "Offscreen preload must not allocate water GPU textures")
	var viewport := SubViewport.new()
	viewport.size = Vector2i(64, 32)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var palette := Image.create(256, 1, false, Image.FORMAT_RGBA8)
	palette.fill(Color(0.05, 0.2, 0.7))
	var layer := CityWaterLayer.new()
	viewport.add_child(layer)
	layer.set_environment({"water_enabled": true, "water_frozen": true})
	var before: PackedByteArray
	for first in [0, 6, 0]:
		var source := CityMapSource.new(Vector2i(384, 32))
		for x in range(first, first + 2):
			var entry := CityMapSource.TileEntry.new(Vector2(x * 32, 0), Vector2(32, 32), null)
			entry.water = cache.entries[Vector2i(x, 0)].water
			source.tiles.append(entry)
		layer.sync(source, 1.0, Vector2(-first * 32, 0), ImageTexture.create_from_image(palette))
		await RenderingServer.frame_post_draw
		var uploads := 0
		for result: CityGpuRegionResult in cache.entries.values():
			uploads += int(not result.water.textures.is_empty())
			assert(result.water.surface.get_data() == snapshots[result.key.x])
		assert(uploads == 2, "Hidden water uploads accumulated after panning")
		var pixels := viewport.get_texture().get_image()
		assert(pixels.get_pixel(16, 16).a > 0.98 and pixels.get_pixel(48, 16).a > 0.98)
		if first == 0:
			if before.is_empty():
				before = pixels.get_data()
			else:
				assert(before == pixels.get_data(), "Returning water changed despite identical cached geometry")
	viewport.queue_free()
	cache.close()
	await process_frame
