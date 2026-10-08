extends "res://tests/support/scene_test_case.gd"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(256, 256)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var pixels := Image.create(256, 256, false, Image.FORMAT_RGBA8)
	pixels.fill(Color(0.55, 0.65, 0.45))
	pixels.fill_rect(Rect2i(0, 0, 256, 8), Color.TRANSPARENT)
	var sprite := Sprite2D.new()
	sprite.centered = false
	sprite.texture = ImageTexture.create_from_image(pixels)
	var material := ShaderMaterial.new()
	material.shader = preload("res://src/view/map/palette_cycle.gdshader")
	sprite.material = material
	viewport.add_child(sprite)
	var marker := ColorRect.new()
	marker.position = Vector2(100, 100)
	marker.size = Vector2(12, 12)
	marker.color = Color(1, 0, 0)
	marker.z_index = 2
	viewport.add_child(marker)
	await process_frame
	await RenderingServer.frame_post_draw
	var original := viewport.get_texture().get_image()
	var field := CityVisualClouds.make_field()
	var canvas_to_grid := CityVisualClouds.shader_basis(Transform2D(Vector2(0.5, 0), Vector2(0, 0.5), Vector2.ZERO))
	for pair in [["cloud_field", field], ["cloud_canvas_to_grid", canvas_to_grid], ["cloud_enabled", true]]:
		material.set_shader_parameter(pair[0], pair[1])
	await RenderingServer.frame_post_draw
	var shaded := viewport.get_texture().get_image()
	var changed := 0
	var sunny := 0
	for y in range(12, 256, 4):
		for x in range(0, 256, 4):
			var a := original.get_pixel(x, y)
			var b := shaded.get_pixel(x, y)
			if a.r > b.r + 0.01:
				changed += 1
			else:
				sunny += 1
			assert(b.r <= a.r + 0.01 and b.r >= a.r * 0.6 - 0.01, "Shadows changed hue or exceeded strength")
			assert(is_equal_approx(a.a, b.a), "Shadows changed the city silhouette")
	assert(changed > 30 and sunny > 30, "The field must have both cloud shadows and sunny gaps")
	assert(shaded.get_pixel(0, 0).a == 0.0)
	assert(shaded.get_pixel(105, 105).is_equal_approx(original.get_pixel(105, 105)), "Clouds reached a foreground marker")
	await RenderingServer.frame_post_draw
	assert(viewport.get_texture().get_image().get_data() == shaded.get_data(), "Shader time advanced a frozen cloud field")
	material.set_shader_parameter("cloud_drift", Vector2(CityVisualClouds.FIELD_SPAN, CityVisualClouds.FIELD_SPAN))
	await RenderingServer.frame_post_draw
	assert(viewport.get_texture().get_image().get_data() == shaded.get_data(), "Cloud drift wrap introduced a visible seam")
	material.set_shader_parameter("cloud_density", 0.0)
	await RenderingServer.frame_post_draw
	assert(viewport.get_texture().get_image().get_data() == original.get_data(), "Zero density left shadows behind")
	material.set_shader_parameter("cloud_fog_density", 0.24)
	await RenderingServer.frame_post_draw
	var foggy := viewport.get_texture().get_image()
	assert(foggy.get_pixel(48, 48).r > original.get_pixel(48, 48).r, "Fog did not soften the landscape")
	assert(foggy.get_pixel(0, 0).a == 0.0, "Fog escaped the map silhouette")
	assert(foggy.get_pixel(105, 105).is_equal_approx(original.get_pixel(105, 105)), "Fog reached the foreground UI")
	material.set_shader_parameter("cloud_enabled", false)
	await RenderingServer.frame_post_draw
	assert(viewport.get_texture().get_image().get_data() == foggy.get_data(), "Disabling clouds also disabled fog")
	material.set_shader_parameter("cloud_enabled", true)
	material.set_shader_parameter("cloud_fog_drift", Vector2.ONE * CityVisualClouds.FIELD_SPAN)
	await RenderingServer.frame_post_draw
	assert(viewport.get_texture().get_image().get_data() == foggy.get_data(), "Fog jumped at the clock wrap")
	material.set_shader_parameter("cloud_fog_density", 0.0)
	material.set_shader_parameter("cloud_density", 0.4)
	material.set_shader_parameter("cloud_drift", Vector2(13, 8))
	await RenderingServer.frame_post_draw
	assert(viewport.get_texture().get_image().get_data() != shaded.get_data(), "Cloud shadows did not move")
	material.set_shader_parameter("cloud_drift", Vector2.ZERO)
	# Two neighboring source textures must publish the same field at their seam.
	sprite.texture = ImageTexture.create_from_image(pixels.get_region(Rect2i(0, 0, 128, 256)))
	var right := Sprite2D.new()
	right.centered = false
	right.position = Vector2(128, 0)
	right.texture = ImageTexture.create_from_image(pixels.get_region(Rect2i(128, 0, 128, 256)))
	right.material = material
	viewport.add_child(right)
	await RenderingServer.frame_post_draw
	assert(viewport.get_texture().get_image().get_data() == shaded.get_data(), "Cloud field restarted at a source region boundary")
	var pan := Vector2(17, 11)
	sprite.position += pan
	right.position += pan
	marker.position += pan
	viewport.canvas_transform = Transform2D(0.0, -pan)
	material.set_shader_parameter("cloud_canvas_to_grid", CityVisualClouds.shader_basis(
		Transform2D(Vector2(0.5, 0), Vector2(0, 0.5), -pan * 0.5)))
	await RenderingServer.frame_post_draw
	assert(viewport.get_texture().get_image().get_data() == shaded.get_data(), "The GPU lost the camera translation column")
	sprite.position -= pan
	right.position -= pan
	marker.position -= pan
	viewport.canvas_transform = Transform2D.IDENTITY
	material.set_shader_parameter("cloud_canvas_to_grid", canvas_to_grid)
	var body := ColorRect.new()
	body.size = Vector2(256, 256)
	body.z_index = 1
	var body_material := ShaderMaterial.new()
	body_material.shader = preload("res://src/view/clouds/cloud_bodies.gdshader")
	for pair in [["cloud_enabled", true], ["cloud_field", field], ["cloud_canvas_to_body_grid", canvas_to_grid]]:
		body_material.set_shader_parameter(pair[0], pair[1])
	body.material = body_material
	viewport.add_child(body)
	await RenderingServer.frame_post_draw
	var cloudy := viewport.get_texture().get_image()
	var tops := 0
	for y in range(12, 256, 4):
		for x in range(0, 256, 4):
			if cloudy.get_pixel(x, y).r > shaded.get_pixel(x, y).r + 0.08:
				tops += 1
	assert(tops > 30, "The overview cloud tops are missing")
	assert(cloudy.get_pixel(105, 105).is_equal_approx(original.get_pixel(105, 105)))
	body_material.set_shader_parameter("cloud_opacity", 0.0)
	await RenderingServer.frame_post_draw
	assert(viewport.get_texture().get_image().get_data() == shaded.get_data(), "Cloud bodies remain in the near view")
	material.set_shader_parameter("cloud_enabled", false)
	await RenderingServer.frame_post_draw
	assert(viewport.get_texture().get_image().get_data() == original.get_data(), "Disable did not restore the original pixels")
	viewport.queue_free()
	await process_frame
	await _check_overview_stability()
	await _check_type_fronts()
	print("PASS: GPU cloud tops/shadows, sunny gaps, movement, frozen clock, region seams, transparency, foreground and exact disable")
	quit()


func _check_overview_stability() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(256, 256)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var body := ColorRect.new()
	body.size = Vector2(256, 256)
	var material := ShaderMaterial.new()
	material.shader = preload("res://src/view/clouds/cloud_bodies.gdshader")
	body.material = material
	viewport.add_child(body)
	# Small solid cores isolate each cluster from its neighbors. Density must
	# select or omit the core, preserving only the artwork's edge transparency.
	var pixels := Image.create(256, 256, false, Image.FORMAT_RGBA8)
	pixels.fill(Color.TRANSPARENT)
	for y in 2:
		for x in 2:
			pixels.fill_rect(Rect2i(x * 128 + 48, y * 128 + 48, 32, 32), Color.WHITE)
	var core_texture := ImageTexture.create_from_image(pixels)
	for pair in [["cloud_enabled", true], ["cloud_field", core_texture], ["cloud_map_edge", 512.0],
		["cloud_projection", Vector4(1, 0, 0, 1)], ["cloud_canvas_to_body_grid", CityVisualClouds.shader_basis(
			Transform2D(Vector2(0.75, 0), Vector2(0, 0.75), Vector2.ZERO))]]:
		material.set_shader_parameter(pair[0], pair[1])
	await process_frame
	for density in [0.4, 0.43, 0.5, 1.0]:
		material.set_shader_parameter("cloud_density", density)
		await RenderingServer.frame_post_draw
		var image := viewport.get_texture().get_image()
		for y in 4:
			for x in 4:
				var site := Vector2(x, y)
				var jitter := Vector2(_cloud_hash(site + Vector2(5, 9)), _cloud_hash(site + Vector2(23, 3))) - Vector2(0.5, 0.5)
				var center := (site + Vector2(0.5, 0.5) + jitter * 0.24) * 48.0
				var pixel := Vector2i(center / 0.75)
				var alpha := image.get_pixelv(pixel).a
				var selected: bool = _cloud_hash(site + Vector2(17, 31)) < density * 1.55
				assert(alpha > 0.98 if selected else alpha < 0.01, "Density left a translucent cloud core")
	material.set_shader_parameter("cloud_field", CityVisualClouds.make_field())
	material.set_shader_parameter("cloud_density", 0.4)
	material.set_shader_parameter("cloud_projection", Vector4(1, 0.5, -1, 0.5))
	for zoom in [0.1, 0.25]:
		var transform := Transform2D(Vector2(1.0 / 32, -1.0 / 32) / zoom,
			Vector2(1.0 / 16, 1.0 / 16) / zoom, Vector2(48, 48))
		material.set_shader_parameter("cloud_canvas_to_body_grid", CityVisualClouds.shader_basis(transform))
		material.set_shader_parameter("cloud_drift", Vector2.ZERO)
		await RenderingServer.frame_post_draw
		var previous := viewport.get_texture().get_image()
		var largest_change := 0.0
		for frame in range(1, 9):
			material.set_shader_parameter("cloud_drift", Vector2(0.01, 0.006) * frame)
			await RenderingServer.frame_post_draw
			var current := viewport.get_texture().get_image()
			for y in range(0, 256, 2):
				for x in range(0, 256, 2):
					var a := previous.get_pixel(x, y)
					var b := current.get_pixel(x, y)
					largest_change = maxf(largest_change, absf(a.a - b.a))
					largest_change = maxf(largest_change, absf(a.r * a.a - b.r * b.a))
			previous = current
		assert(largest_change < 0.16, "Slow overview drift changed cloud opacity abruptly: %s at zoom %s" % [largest_change, zoom])
		print("PASS: solid overview cores and stable moving atlas at zoom %s (maximum pixel change %s)" % [zoom, largest_change])
		material.set_shader_parameter("cloud_formation", 0.18)
		var site := Vector2(1, 1)
		var jitter := Vector2(_cloud_hash(site + Vector2(5, 9)), _cloud_hash(site + Vector2(23, 3))) - Vector2(0.5, 0.5)
		var center := (site + Vector2(0.5, 0.5) + jitter * 0.24) * 48.0
		transform.origin = center - transform.basis_xform(Vector2(128, 128))
		material.set_shader_parameter("cloud_canvas_to_body_grid", CityVisualClouds.shader_basis(transform))
		material.set_shader_parameter("cloud_drift", Vector2.ZERO)
		var threshold := _cloud_hash(Vector2(1, 1) + Vector2(17, 31)) / 1.55
		material.set_shader_parameter("cloud_density", threshold - 0.0008)
		await RenderingServer.frame_post_draw
		previous = viewport.get_texture().get_image()
		var largest_front := 0.0
		for frame in range(1, 33):
			material.set_shader_parameter("cloud_density", threshold - 0.0008 + frame * 0.0001)
			await RenderingServer.frame_post_draw
			var current := viewport.get_texture().get_image()
			for y in range(0, 256, 2):
				for x in range(0, 256, 2):
					largest_front = maxf(largest_front, absf(previous.get_pixel(x, y).a - current.get_pixel(x, y).a))
			previous = current
		assert(largest_front < 0.16, "A weather front popped a whole cloud into view: %s" % largest_front)
		assert(largest_front > 0.0, "The weather-front fixture did not show a forming cloud")
		print("PASS: gradual weather front at zoom %s (maximum alpha change %s)" % [zoom, largest_front])
		material.set_shader_parameter("cloud_formation", 0.0)
		material.set_shader_parameter("cloud_density", 0.4)
	viewport.queue_free()
	await process_frame


func _cloud_hash(cell: Vector2) -> float:
	var p := Vector2(fposmod(cell.x * 0.1031, 1.0), fposmod(cell.y * 0.0973, 1.0))
	return fposmod(19.19 * (p.x + 0.37) * (p.y + 0.71), 1.0)


func _check_type_fronts() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(256, 256)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var body := ColorRect.new()
	body.size = Vector2(256, 256)
	var material := ShaderMaterial.new()
	material.shader = CityVisualClouds.BODIES
	body.material = material
	viewport.add_child(body)
	for pair in [["cloud_enabled", true], ["cloud_density", 0.7], ["cloud_map_edge", 256.0],
		["cloud_projection", Vector4(1, 0, 0, 1)], ["cloud_canvas_to_body_grid", CityVisualClouds.shader_basis(
			Transform2D(Vector2(0.75, 0), Vector2(0, 0.75), Vector2.ZERO))]]:
		material.set_shader_parameter(pair[0], pair[1])
	await process_frame
	var signatures: Array[int] = []
	for kind in 5:
		material.set_shader_parameter("cloud_field", CityCloudSituations.ATLASES[kind])
		material.set_shader_parameter("cloud_appearance", CityCloudSituations.APPEARANCE[kind])
		material.set_shader_parameter("cloud_drift", Vector2.ZERO)
		await RenderingServer.frame_post_draw
		var pixels := viewport.get_texture().get_image()
		var alpha_sum := 0.0
		for y in range(0, 256, 4):
			for x in range(0, 256, 4):
				alpha_sum += pixels.get_pixel(x, y).a
		assert(alpha_sum > 5.0 and alpha_sum < 3500.0, "A cloud type is missing or hides the entire map")
		signatures.append(hash(pixels.get_data()))
		material.set_shader_parameter("cloud_drift", Vector2.ONE * CityVisualClouds.FIELD_SPAN)
		await RenderingServer.frame_post_draw
		assert(viewport.get_texture().get_image().get_data() == pixels.get_data(), "A cloud type jumps at drift wrap")
	for left in 5:
		for right in range(left + 1, 5):
			assert(signatures[left] != signatures[right], "Cloud situations must look distinct")
	material.set_shader_parameter("cloud_appearance", CityCloudSituations.APPEARANCE[CityCloudSituations.Type.FOG])
	await RenderingServer.frame_post_draw
	assert(viewport.get_texture().get_image().is_invisible(), "Ground fog must not leave an unbounded aerial cloud layer")
	material.set_shader_parameter("cloud_field", CityCloudSituations.ATLASES[0])
	material.set_shader_parameter("cloud_field_next", CityCloudSituations.ATLASES[3])
	material.set_shader_parameter("cloud_appearance", Vector4(0, 1, 1, 1))
	material.set_shader_parameter("cloud_type_blend", 1.0)
	await RenderingServer.frame_post_draw
	var incoming := viewport.get_texture().get_image().get_data()
	material.set_shader_parameter("cloud_field", CityCloudSituations.ATLASES[3])
	material.set_shader_parameter("cloud_type_blend", 0.0)
	await RenderingServer.frame_post_draw
	assert(viewport.get_texture().get_image().get_data() == incoming, "Committing a cloud front changes its pixels")
	viewport.queue_free()
	await process_frame
	print("PASS: five aerial cloud types, ground-only fog, seamless drift and continuous two-atlas front commit")
