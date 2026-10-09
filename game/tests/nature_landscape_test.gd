extends SceneTree

const DocumentState = preload("res://tests/support/document_state.gd")

@warning_ignore_start("integer_division")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var pack := FixtureGraphics.pack()
	var indexed := Sc2Palette.index_encoding()
	var city := CityState.from_document(EmptyCityTemplate.create(128))
	for x in range(20, 26):
		for y in range(20, 26):
			city.set_building_id(x, y, 12)
	city.set_building_id(23, 23, 0)
	city.set_building_id(23, 24, 6)
	var before := DocumentState.capture(city.document)
	for view in 3:
		var archive := pack.large_sprites if view == 2 else pack.small_medium_sprites
		var originals := archive.entries_by_id.size()
		CitySeasonColors.prepare(archive, pack.palette)
		CityNatureArtwork.prepare(archive, pack.palette)
		archive.visual_seasons.merge(archive.visual_nature_masks)
		assert(archive.entries_by_id.size() == originals, "Generated art replaced imported artwork")
		for density in range(1, 8):
			var original := archive.entries_by_id[view * 500 + 5 + density]
			assert(archive.find_sprite(original.sprite_id) == original, "Imported original tree was replaced")
			var silhouettes := {}
			for variant in CityNatureArtwork.VARIANTS:
				var entry := archive.find_sprite(CityNatureArtwork.sprite_id(view, density, 0, variant))
				silhouettes[entry.decode_indices().pixels] = true
			assert(silhouettes.size() > 1, "Tree variants have identical silhouettes")
		var ground_id := CityNatureArtwork.FIRST + CityNatureArtwork.GROUND_VARIANT * CityNatureArtwork.SPAN + view * 500 + 256
		for offset in 13:
			var ground: PackedInt32Array = archive.find_sprite(ground_id + offset).decode_indices().pixels
			var old_ground: PackedInt32Array = archive.find_sprite(view * 500 + 256 + offset).decode_indices().pixels
			assert(ground == old_ground, "Original field boundaries, slope shading or terrain silhouette were lost")
		var id := CityNatureArtwork.sprite_id(view, 7, 15, 0)
		var entry := archive.find_sprite(id)
		assert(entry != null)
		CityNatureArtwork.prepare(archive, pack.palette)
		assert(archive.find_sprite(id) == entry, "Unchanged artwork was rebuilt")
		var pixels := entry.decode_indices().pixels
		var mask: Image = archive.visual_nature_masks[id]
		for at in pixels.size():
			if pixels[at] < 0:
				assert(mask.get_pixel(at % entry.width, at / entry.width).a == 0.0)
		var context := CityGpuBuildContext.new()
		archive.visual_nature_enabled = false
		archive.visual_revision += 1
		assert(context.prepare(city, indexed, archive, view).is_empty())
		var classic := context.tile_draws([Vector2i(22, 22)])
		archive.visual_nature_enabled = true
		archive.visual_revision += 1
		assert(context.prepare(city, indexed, archive, view).is_empty())
		var selected := context.tile_draws([Vector2i(22, 22)])
		var tree: int = selected.records[CityGpuBuildContext.RECORD_SIZE + 5]
		assert(tree >= CityNatureArtwork.FIRST and tree % 1500 == view * 500 + 12)
		assert(selected.records.size() == classic.records.size(), "Forests added draw calls")
		var clearing := context.tile_draws([Vector2i(23, 23)])
		assert(clearing.records.size() == CityGpuBuildContext.RECORD_SIZE, "Clearing acquired trees")
		var single := context.tile_draws([Vector2i(23, 24)])
		assert(single.records[CityGpuBuildContext.RECORD_SIZE + 5] % 500 == 6)
		var bounds := Rect2i(Vector2i(selected.records[0], selected.records[1]) - Vector2i(32, 48), Vector2i(192, 128))
		var rendered := context.render(city, indexed, archive, bounds, view, CityViewMode.Mode.CITY,
			true, true, 0, -1, true, true)
		assert(rendered.ok, rendered.error)
		var build_count := context.tile_builds
		var atlas_revision := context.atlas_revision
		var warm := context.render(city, indexed, archive, bounds, view, CityViewMode.Mode.CITY,
			true, true, 0, atlas_revision, true, true)
		assert(warm.ok and context.tile_builds == build_count)
		assert(warm.atlas_image == null and warm.gpu_arrays == rendered.gpu_arrays)
		archive.visual_nature_enabled = false
		archive.visual_revision += 1
		assert(context.prepare(city, indexed, archive, view).is_empty())
		assert(context.tile_draws([Vector2i(22, 22)]).records == classic.records)
		archive.visual_terrain_enabled = true
		archive.visual_revision += 1
		assert(context.prepare(city, indexed, archive, view).is_empty())
		var softened := context.tile_draws([Vector2i(23, 23)])
		assert(softened.records.size() == CityGpuBuildContext.RECORD_SIZE and softened.records[5] == ground_id)
		archive.visual_terrain_enabled = false
		archive.visual_revision += 1
	assert(DocumentState.capture(city.document) == before, "Nature rendering changed city data or RNG")
	print("PASS: bounded forest artwork, density, clearings, masks, cache reuse, classic restoration and unchanged city")
	quit()
