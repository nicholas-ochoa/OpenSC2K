extends "res://tests/support/scene_test_case.gd"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var pack := FixtureGraphics.pack()
	var app := CityApplication.new()
	app.asset_state.palette = pack.palette
	app.asset_state.palette_index_encoding = Sc2Palette.index_encoding()
	for id: int in CityShipArtwork.SOURCES:
		var archive := pack.large_sprites if id >= 1000 else pack.small_medium_sprites
		var entry := archive.find_sprite(id)
		var original := entry.create_image(app.asset_state.palette_index_encoding).image
		var before := original.get_data()
		archive.water_reflections = false
		var classic := app.moving_sprites.dynamic_sprite_resource(archive, id, false, 1)
		assert(classic.image == original, "Classic water artwork changed")
		archive.water_reflections = true
		var resource := app.moving_sprites.dynamic_sprite_resource(archive, id, false, 1)
		var columns := WaterReflectionSprite.hull_columns(original, pack.palette)
		var removed := 0
		var blue_details := 0
		for y in entry.height:
			for x in entry.width:
				var old := original.get_pixel(x, y)
				var clean := resource.image.get_pixel(x, y)
				if y >= columns[x].x and y < columns[x].y:
					assert(clean == old, "Hull, mast or deck detail changed")
					var color := pack.palette.color(roundi(old.r * 255.0))
					blue_details += int(old.a > 0.0 and color.b > color.r * 1.2)
				elif old.a > 0.0:
					assert(clean.a < 0.41, "Opaque baked water or exterior marker remains")
					if clean.a > 0.0:
						assert(roundi(clean.r * 255.0) == 154, "Wake must use neutral foam")
					removed += int(clean.a == 0.0)
		assert(removed > 0, "No exterior water removed for %d" % id)
		if id in [1369, 1370, 1371, 1372, 1373]:
			assert(blue_details > 0, "Blue cargo details were excluded from hull")
		assert(resource.native_size == original.get_size())
		assert(app.moving_sprites.dynamic_sprite_resource(archive, id, false, 1) == resource)
		assert(original.get_data() == before, "Imported/shared artwork was modified")
		# Transform/reflection rules are independent of heading; sample all art sizes
		# and both vessel types instead of repeating the expensive hull scan 34 times.
		if id in [369, 872, 1371, 1380]:
			for flip: bool in [false, true]:
				var transformed := original.duplicate()
				var display := resource.image.duplicate()
				if flip:
					transformed.flip_x()
					display.flip_x()
				transformed.resize(entry.width * 2, entry.height * 2, Image.INTERPOLATE_NEAREST)
				display.resize(entry.width * 2, entry.height * 2, Image.INTERPOLATE_NEAREST)
				var scaled := app.moving_sprites.dynamic_sprite_resource(archive, id, flip, 2)
				assert(scaled.image.get_data() == display.get_data(), "Mirroring/scaling shifted the cleaned hull")
				assert(scaled.waterline() == IsometricFloatingOcclusion.waterline(transformed), "Floating occlusion anchor changed")
				var expected := WaterReflectionSprite.create(transformed, null, Vector2i.ZERO, 0, pack.palette)
				assert(scaled.reflection(Vector2i.ZERO, 0, pack.palette).image.get_data() == expected.image.get_data(), "Foam changed the hull reflection")
		archive.water_reflections = false
		assert(app.moving_sprites.dynamic_sprite_resource(archive, id, false, 1) == classic, "Water option reused an incompatible display cache")
		var indices := entry.decode_indices().pixels
		indices[0] = 163
		var custom := Sc2SpriteArchive.entry_from_indices(id, entry.width, entry.height, indices)
		var custom_image := custom.create_image(app.asset_state.palette_index_encoding).image
		assert(CityShipArtwork.clean(custom, custom_image, pack.palette, true) == custom_image, "Custom ship artwork changed")
	pack.large_sprites.water_reflections = true
	var viewport := SubViewport.new()
	viewport.size = Vector2i(896, 256)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var canvas := CityDynamicSpriteCanvas.new()
	canvas.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var material := ShaderMaterial.new()
	material.shader = preload("res://src/view/map/palette_cycle.gdshader")
	var palette := Image.create_from_data(256, 1, false, Image.FORMAT_RGBA8, pack.palette.to_rgba_bytes())
	material.set_shader_parameter("animated_palette", ImageTexture.create_from_image(palette))
	material.set_shader_parameter("palette_cycle_enabled", true)
	material.set_shader_parameter("palette_lookup_all", true)
	canvas.material = material
	viewport.add_child(canvas)
	for flip: bool in [false, true]:
		for phase: float in [0.0, 0.5]:
			var visuals: Array[CityDynamicVisual] = []
			for index in 7:
				var id := 1369 + index if index < 5 else 1380 + index - 5
				var image := pack.large_sprites.find_sprite(id).create_image(app.asset_state.palette_index_encoding).image.duplicate()
				if flip:
					image.flip_x()
				var original := CityDynamicVisual.new(ImageTexture.create_from_image(image), Vector2(index * 64, 0) + Vector2.ONE * phase, image.get_size())
				visuals.append(original)
				var resource := app.moving_sprites.dynamic_sprite_resource(pack.large_sprites, id, flip, 1)
				visuals.append(CityDynamicVisual.new(resource.texture, original.position + Vector2(0, 64), resource.native_size))
			for zoom: float in [0.25, 0.5, 1.0, 2.0]:
				canvas.set_visuals(visuals, zoom, Vector2.ZERO)
				await process_frame
				await RenderingServer.frame_post_draw
				var pixels := viewport.get_texture().get_image()
				var changed := 0
				var foam := 0
				var size := Vector2i(int(448 * zoom), int(64 * zoom))
				var old_pixels := pixels.get_region(Rect2i(Vector2i.ZERO, size)).get_data().to_int32_array()
				var clean_pixels := pixels.get_region(Rect2i(Vector2i(0, size.y), size)).get_data().to_int32_array()
				for at in old_pixels.size():
					if old_pixels[at] != clean_pixels[at]:
						var old_alpha := (old_pixels[at] >> 24) & 255
						var clean_alpha := (clean_pixels[at] >> 24) & 255
						assert(old_alpha == 255 and clean_alpha <= 104, "GPU ship gained pixels or changed opaque hull colors")
						changed += 1
						foam += int(clean_alpha > 2)
				assert(changed > 0, "GPU ship still carries opaque baked water")
				if zoom >= 1.0:
					assert(foam > 0, "GPU wake foam disappeared")
	viewport.queue_free()
	app.free()
	await process_frame
	print("PASS: 17 ship frames, original/custom art, blue cargo, cache/options, mirrored motion at 25-200%, neutral foam and unchanged floating/reflection anchors")
	quit()
