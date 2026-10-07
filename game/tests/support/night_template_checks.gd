extends RefCounted
## Equivalent roads reuse templates; local edits and silhouettes stay independent.


static func run(app: CityApplication) -> void:
	var original := app.document_state.city
	var city := CityState.from_document(EmptyCityTemplate.create(128))
	app.document_state.city = city
	var ground := CityNightGround.new()
	var a := Vector2i(30, 30)
	var b := Vector2i(90, 90)
	for tile in [a, b]:
		for x in range(tile.x - 1, tile.x + 2):
			for y in range(tile.y - 1, tile.y + 2):
				city.set_land_altitude(x, y, 0)
				city.set_terrain_id(x, y, 0)
		for axis in 2:
			ground.masker._occluders[Vector3i(tile.x, tile.y, axis)] = []
	for id in [BuildingTileIds.ROAD_STRAIGHT_1, BuildingTileIds.ROAD_STRAIGHT_2,
		BuildingTileIds.ROAD_CURVE_1, BuildingTileIds.ROAD_CROSSROADS,
		BuildingTileIds.HIGHWAY_STRAIGHT_1, BuildingTileIds.HIGHWAY_ROAD_CROSSING_1,
		BuildingTileIds.HIGHWAY_ONRAMP_1, BuildingTileIds.HIGHWAY_ONRAMP_2,
		BuildingTileIds.HIGHWAY_ONRAMP_3, BuildingTileIds.HIGHWAY_ONRAMP_4,
		BuildingTileIds.HIGHWAY_SLOPE_1, BuildingTileIds.HIGHWAY_CURVE_1,
		BuildingTileIds.HIGHWAY_INTERSECTION, BuildingTileIds.HIGHWAY_BRIDGE]:
		for shape in [0, 1, 2, 3, 4]:
			for tile in [a, b]:
				city.set_building_id(tile.x, tile.y, id)
				city.set_terrain_id(tile.x, tile.y, shape)
				ground.roads.roads.clear()
			var first := ground._build(app, a)
			var count := ground.templates.receivers.size()
			var second := ground._build(app, b)
			assert(ground.templates.receivers.size() == count, "Translated road rebuilt its template")
			assert(first.texture == second.texture, "Identical road light did not share its GPU texture")
			assert(first.fixtures.get_image().get_data() == second.fixtures.get_image().get_data(), "Translated lamp geometry changed")
			assert(second.origin - first.origin == Vector2i(0, 960), "Template changed world placement")
	# A neighboring facade changes only the local receiver's light profile.
	for tile in [a, b]:
		city.set_building_id(tile.x, tile.y, BuildingTileIds.ROAD_STRAIGHT_1)
		city.set_terrain_id(tile.x, tile.y, 0)
	ground.roads.roads.clear()
	var plain := ground._build(app, a)
	var entrance_id := int(ground.profiles.entrances.keys()[0])
	city.set_building_id(b.x + 1, b.y, entrance_id)
	var shop := ground._build(app, b)
	assert(shop.texture.get_image().get_data() != plain.texture.get_image().get_data(), "Entrance profile reused plain street lighting")
	city.set_building_id(b.x + 1, b.y, 0)
	# One opaque foreground must not poison a shared template for another tile.
	var cover := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	cover.fill(Color.WHITE)
	for axis in 2:
		ground.masker._occluders[Vector3i(a.x, a.y, axis)] = [{"origin": plain.origin, "image": cover}]
	assert(ground._build(app, a).texture.get_image().is_invisible())
	assert(ground._build(app, b).texture == plain.texture)
	# Lower and upper crossing decks have independent foreground masks.
	city.set_building_id(b.x, b.y, BuildingTileIds.HIGHWAY_ROAD_CROSSING_1)
	ground.roads.roads.clear()
	var crossing := ground._build(app, b)
	ground.masker._occluders[Vector3i(b.x, b.y, 0)] = [{"origin": crossing.origin, "image": cover}]
	var lower: Image = ground._build(app, b).texture.get_image()
	assert(not lower.is_invisible(), "Masking one deck removed both crossing approaches")
	assert(lower.get_data() != crossing.texture.get_image().get_data(), "Crossing deck mask had no effect")
	# Lookup limits must not invalidate texture references retained by visible tiles.
	for index in range(CityNightTemplates.LIMIT + 8):
		ground.profiles.street.intensity = float(index + 1) / 512.0
		ground._build(app, b)
	assert(ground.templates.receivers.size() <= CityNightTemplates.LIMIT)
	assert(ground.templates.textures.size() <= CityNightTemplates.LIMIT)
	assert(not plain.texture.get_image().is_invisible())
	ground.reset()
	assert(ground.templates.receivers.is_empty() and ground.templates.textures.is_empty())
	ground.free()
	app.document_state.city = original
	print("PASS: shared road/highway templates, grades, local entrances, independent crossing masks and bounded lookup caches")
