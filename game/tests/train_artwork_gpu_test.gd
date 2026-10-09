extends "res://tests/support/scene_test_case.gd"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var pack := FixtureGraphics.pack()
	var app := CityApplication.new()
	app.asset_state.palette = pack.palette
	app.asset_state.palette_index_encoding = Sc2Palette.index_encoding()
	var originals: Array[Image] = []
	for id in range(1374, 1379):
		var entry := pack.large_sprites.find_sprite(id)
		var original := entry.create_image(app.asset_state.palette_index_encoding).image
		var before := original.get_data()
		originals.append(original)
		var resource := app.moving_sprites.dynamic_sprite_resource(pack.large_sprites, id, false, 1)
		var removed := 0
		for y in entry.height:
			for x in entry.width:
				var old := original.get_pixel(x, y)
				var new := resource.image.get_pixel(x, y)
				if old != new:
					assert(old.a == 1.0 and new.a == 0.0)
					assert(roundi(old.r * 255) in [124, 127], "Removed a non-marker palette index")
					for neighbor: Vector2i in [Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1), Vector2i(-1, 0),
							Vector2i(1, 0), Vector2i(-1, 1), Vector2i(0, 1), Vector2i(1, 1)]:
						var point := Vector2i(x, y) + neighbor
						if Rect2i(Vector2i.ZERO, original.get_size()).has_point(point):
							assert(original.get_pixelv(point).a == 0.0, "Removed a connected wagon pixel")
					removed += 1
		assert(removed == 3, "Each original train has three detached corner dots")
		assert(resource.native_size == original.get_size())
		assert(app.moving_sprites.dynamic_sprite_resource(pack.large_sprites, id, false, 1) == resource,
			"Train cleanup must reuse the cached resource")
		assert(original.get_data() == before and entry.create_image(app.asset_state.palette_index_encoding).image == original,
			"Cleanup changed the imported artwork or its shared image")
		var alternate := entry.decode_indices().pixels
		alternate[0] = 163
		var custom := Sc2SpriteArchive.entry_from_indices(id, entry.width, entry.height, alternate)
		var custom_image := custom.create_image(app.asset_state.palette_index_encoding).image
		assert(CityTrainArtwork.clean(custom, custom_image) == custom_image, "Custom train artwork must remain intact")
		var unrelated := Sc2SpriteArchive.entry_from_indices(1359, entry.width, entry.height, entry.decode_indices().pixels)
		assert(CityTrainArtwork.clean(unrelated, original) == original, "Cleanup affected another vehicle")
	var viewport := SubViewport.new()
	viewport.size = Vector2i(512, 192)
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
			for index in 5:
				var image := originals[index].duplicate()
				if flip:
					image.flip_x()
				var original := CityDynamicVisual.new(ImageTexture.create_from_image(image), Vector2(index * 48 + 4, 4) + Vector2.ONE * phase, image.get_size())
				visuals.append(original)
				var resource := app.moving_sprites.dynamic_sprite_resource(pack.large_sprites, 1374 + index, flip, 1)
				visuals.append(CityDynamicVisual.new(resource.texture, original.position + Vector2(0, 48), resource.native_size))
			for zoom: float in [0.5, 1.0, 2.0]:
				canvas.set_visuals(visuals, zoom, Vector2.ZERO)
				await process_frame
				await RenderingServer.frame_post_draw
				var pixels := viewport.get_texture().get_image()
				var removed := 0
				for y in int(48 * zoom):
					for x in int(256 * zoom):
						var old := pixels.get_pixel(x, y)
						var new := pixels.get_pixel(x, y + int(48 * zoom))
						if not old.is_equal_approx(new):
							assert(old.a > 0.99 and new.a < 0.01, "GPU train body changed during movement or zoom")
							removed += 1
				if zoom >= 1.0 and is_zero_approx(fposmod(phase * zoom, 1.0)):
					assert(removed == int(15 * zoom * zoom), "GPU train corner dots remain: flip=%s phase=%s zoom=%s removed=%d" % [flip, phase, zoom, removed])
	viewport.queue_free()
	app.free()
	await process_frame
	print("PASS: five train shapes, mirrored fractional motion and zoom remove only detached dots; original/custom art and cache retained")
	quit()
