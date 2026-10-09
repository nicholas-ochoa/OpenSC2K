extends "res://tests/support/scene_test_case.gd"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var pack := FixtureGraphics.pack()
	var pixels := Image.create(512, 192, false, Image.FORMAT_RGBA8)
	var masks := Image.create(512, 192, false, Image.FORMAT_RGBA8)
	var shores: Array[Vector2i] = []
	var water: Array[Vector2i] = []
	# All channel shapes at all original artwork sizes, with a flat ground
	# and open-water control. Horizontal mirroring must preserve the mask too.
	for view in 3:
		var archive := pack.large_sprites if view == 2 else pack.small_medium_sprites
		CitySeasonColors.prepare(archive, pack.palette)
		for column in 8:
			var offset: int = [256, 270, 285, 286, 287, 288, 289, 290][column]
			var id := view * 500 + offset
			var entry := archive.find_sprite(id)
			var art: Image = entry.create_image(pack.palette).image
			var mask: Image = archive.visual_seasons.get(id)
			if offset >= 285:
				assert(mask != null and not mask.is_invisible(), "Channel bank has no season/terrain mask: %d" % id)
			for mirror in 2:
				var image: Image = art.duplicate()
				var natural: Image = mask.duplicate() if mask != null else Image.create(entry.width, entry.height, false, Image.FORMAT_RGBA8)
				if mirror == 1:
					image.flip_x()
					natural.flip_x()
				var origin := Vector2i(column * 64, view * 64 + mirror * 32)
				pixels.blit_rect(image, Rect2i(Vector2i.ZERO, image.get_size()), origin)
				masks.blit_rect(natural, Rect2i(Vector2i.ZERO, natural.get_size()), origin)
				for y in image.get_height():
					for x in image.get_width():
						var color := image.get_pixel(x, y)
						var mark := natural.get_pixel(x, y)
						if color.a == 0.0:
							assert(mark.a == 0.0, "Shore mask escaped the artwork")
						elif color.b > color.r and color.b > color.g:
							assert(mark.a == 0.0, "Water was marked as land")
							water.append(origin + Vector2i(x, y))
						elif offset >= 285 and color.r > color.b + 0.1:
							assert(mark.g == 1.0 and mark.a == 1.0, "A brown bank pixel was omitted")
							shores.append(origin + Vector2i(x, y))
	assert(not shores.is_empty() and not water.is_empty())
	var viewport := SubViewport.new()
	viewport.size = pixels.get_size()
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var sprite := Sprite2D.new()
	sprite.centered = false
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.texture = ImageTexture.create_from_image(pixels)
	var material := ShaderMaterial.new()
	material.shader = preload("res://src/view/map/palette_cycle.gdshader")
	material.set_shader_parameter("environment_has_seasons", true)
	material.set_shader_parameter("environment_season_mask", ImageTexture.create_from_image(masks))
	material.set_shader_parameter("nature_ground", CityNatureArtwork.ground_texture())
	material.set_shader_parameter("nature_canvas_to_grid", Basis(Vector3(0.0625, 0, 0), Vector3(0, 0.0625, 0), Vector3(0, 0, 1)))
	sprite.material = material
	viewport.add_child(sprite)
	await process_frame
	await RenderingServer.frame_post_draw
	var original := viewport.get_texture().get_image()
	var captures: Array[Image] = [original]
	for terrain in [false, true]:
		material.set_shader_parameter("nature_terrain_enabled", terrain)
		material.set_shader_parameter("nature_terrain_strength", 0.5)
		material.set_shader_parameter("environment_enabled", true)
		for season in 4:
			var weights := Vector4.ZERO
			weights[season] = 1.0
			material.set_shader_parameter("environment_seasons", weights)
			await RenderingServer.frame_post_draw
			var rendered := viewport.get_texture().get_image()
			for point in water:
				assert(rendered.get_pixelv(point) == original.get_pixelv(point), "Land grading changed a water pixel")
			for point in shores:
				var before := original.get_pixelv(point)
				var after := rendered.get_pixelv(point)
				if season != 1 or terrain:
					assert(before != after, "Shore did not follow the season or terrain variation")
				else:
					assert(before == after, "Summer without terrain variation changed original artwork")
				if season == 3:
					assert(after.b > after.r and after.b > before.b, "Winter bank retained brown soil")
			captures.append(rendered)
	# Turning both effects off restores the original graphics exactly.
	material.set_shader_parameter("environment_enabled", false)
	material.set_shader_parameter("nature_terrain_enabled", false)
	await RenderingServer.frame_post_draw
	assert(viewport.get_texture().get_image().get_data() == original.get_data())
	var output := OS.get_environment("OPENSC2K_SHORE_CAPTURE")
	if not output.is_empty():
		var sheet := Image.create(512, 192 * captures.size(), false, Image.FORMAT_RGBA8)
		for index in captures.size():
			sheet.blit_rect(captures[index], Rect2i(0, 0, 512, 192), Vector2i(0, 192 * index))
		assert(sheet.save_png(output) == OK)
	viewport.queue_free()
	await process_frame
	print("PASS: all channel banks, three artwork sizes, mirroring, four seasons, terrain variation, original water and disabled restoration")
	quit()
