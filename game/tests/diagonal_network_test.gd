extends SceneTree
## Display-only diagonal lanes must follow the diagonal network artwork.
@warning_ignore_start("integer_division")
const State = preload("res://tests/support/document_state.gd")

func _initialize() -> void:
	_check_roads()
	_check_fixture_spacing()
	_check_highways()
	_check_joins_and_grades()
	_check_artwork()
	_check_deck_occlusion()
	print("PASS: diagonal lanes, headings, lamp alignment, receivers, highway separation and rail anchors")
	quit()


func _check_roads() -> void:
	for rotation in 4:
		var city := CityState.from_document(EmptyCityTemplate.create(128))
		var tiles: Array[Vector2i] = []
		for i in 8:
			var offset := Vector2i((i + 1) / 2, i / 2)
			for turn in rotation:
				offset = Vector2i(-offset.y, offset.x)
			var tile := Vector2i(64, 64) + offset
			tiles.append(tile)
			city.set_land_altitude(tile.x, tile.y, 0)
			city.set_terrain_id(tile.x, tile.y, 0)
			city.set_building_id(tile.x, tile.y, BuildingTileIds.ROAD_CURVE_1 + (rotation + (0 if i % 2 == 0 else 2)) % 4)
		var before := State.capture(city.document)
		var lights := CityLifeLights.new()
		lights.sync_geometry(city)
		for reverse in [false, true]:
			for walking in [false, true]:
				var lateral := INF
				var lamp_lateral := INF
				var previous := Vector2.ZERO
				var heading := -1
				for i in tiles.size():
					var tile := tiles[i]
					var enter := ((0 if i % 2 == 0 else 3) + rotation) % 4
					var exit := ((1 if i % 2 == 0 else 2) + rotation) % 4
					if reverse:
						var swap := enter
						enter = exit
						exit = swap
					var segment := CityLifePaths.Segment.new(city, tile, enter, exit, walking)
					for j in 21:
						var point := segment.point(j / 20.0)
						var value := point.x if rotation % 2 == 0 else point.y
						if lateral == INF:
							lateral = value
						assert(absf(value - lateral) < 0.001, "A diagonal lane zigzags between tile edges")
						assert(point == CityLifePaths.point(city, tile, enter, exit, j / 20.0, walking))
						var current_heading := CityLifePaths.heading(enter, exit, j / 20.0, true)
						if heading < 0:
							heading = current_heading
						assert(current_heading == heading and heading >= 4, "Heading changes halfway along a diagonal")
					if i > 0:
						assert(previous.is_equal_approx(segment.point(1.0 if reverse else 0.0)), "Lane jumps at tile boundary")
					previous = segment.point(0.0 if reverse else 1.0)
					for fixture in CityNightFixtures.street_layout(city, tile, 2):
						var foot := CityNightFixtures._foot(city, tile, fixture.offset, fixture.enter)
						var value := float(foot.x if rotation % 2 == 0 else foot.y)
						if lamp_lateral == INF:
							lamp_lateral = value
						assert(value == lamp_lateral, "Lamp feet drift across a straight diagonal")
					_check_patch(city, tile, enter, lights)
		var direction := CityLifePaths.heading(rotation, (rotation + 1) % 4, 0.5, true)
		var surface := lights.surface(city, tiles[0], rotation, direction)
		assert(surface.occlusion_keys.size() == 3, "Diagonal headlights stop at the first alternating curve")
		assert(State.capture(city.document) == before, "Rendering changed the city")
		# The existing train anchors already form one straight diagonal.
		var train_lateral := INF
		var thing := ThingRecord.new()
		thing.type = 10
		for i in tiles.size():
			var tile := tiles[i]
			city.set_building_id(tile.x, tile.y, BuildingTileIds.RAIL_CURVE_1 + (rotation + (0 if i % 2 == 0 else 2)) % 4)
			var train := IsometricMovingVisuals.train_sprite(city, tile.x, tile.y, thing)
			var point := Vector2((tile.x - tile.y) * 16 + train.screen_x, (tile.x + tile.y) * 8 + train.screen_y - train.elevation)
			var value := point.x if rotation % 2 == 0 else point.y
			if train_lateral == INF:
				train_lateral = value
			assert(value == train_lateral, "Rail anchors no longer follow a straight diagonal")
		lights.sync_geometry(city)
		assert(lights.roads.is_empty() and lights.surfaces.is_empty(), "Replaced diagonal roads retain light receivers")


func _check_patch(city: CityState, tile: Vector2i, enter: int, lights: CityLifeLights) -> void:
	var exit := CityLifePaths.paired_exit(city, tile, enter)
	var a := Vector2(CityLifePaths.DIRECTIONS[enter]) * 0.5
	var b := Vector2(CityLifePaths.DIRECTIONS[exit]) * 0.5
	var count := 0
	for patch: Dictionary in lights._road_patches(city, tile, enter):
		for y in patch.image.get_height():
			for x in patch.image.get_width():
				var pixel: Color = patch.image.get_pixel(x, y)
				if pixel.a == 0:
					continue
				count += 1
				var local := Vector2(pixel.r, pixel.g) - Vector2(tile)
				assert(absf(local.x) <= 0.5001 and absf(local.y) <= 0.5001, "Receiver escaped its tile")
				assert(absf((local - a).cross((b - a).normalized())) <= 0.2501, "Light spills outside the diagonal strip")
	assert(count > 8, "Diagonal receiver is empty")


func _check_highways() -> void:
	var city := CityState.from_document(EmptyCityTemplate.create(128))
	for rotation in 4:
		var lights := CityLifeLights.new()
		for y in 2:
			for x in 2:
				city.set_land_altitude(64 + x, 64 + y, 0)
				city.set_terrain_id(64 + x, 64 + y, 0)
				city.set_building_id(64 + x, 64 + y, BuildingTileIds.HIGHWAY_CURVE_1 + rotation)
				city.set_building_corners(64 + x, 64 + y, [[0x10, 0x20], [0x80, 0x40]][y][x])
		for y in 2:
			for x in 2:
				var tile := Vector2i(64 + x, 64 + y)
				var ports := CityLifePaths.ports(city, tile)
				for enter in 4:
					if ports & (1 << enter):
						_check_patch(city, tile, enter, lights)
				if ports == 15:
					var a: Dictionary = lights._road_patches(city, tile, rotation)[0]
					var b: Dictionary = lights._road_patches(city, tile, (rotation + 2) % 4)[0]
					assert(a.origin != b.origin or a.image.get_data() != b.image.get_data(), "Separate highway carriageways share one receiver")


func _check_artwork() -> void:
	var sprites := CityLifeSprites.new()
	var lights := CityLifeLights.new()
	for direction in range(4, 8):
		assert(CityLifePaths.forward(direction) == -CityLifePaths.forward(CityLifePaths.opposite(direction)))
		for kind in 3:
			for variant in 18:
				var image := sprites.sprite(false, variant, direction, 0, kind)
				assert(not image.is_invisible())
				assert(image == sprites.sprite(false, variant, direction, 1, kind), "Static diagonal artwork is not cached")
				var mask := lights.lamp_mask(image, kind, direction)
				assert(not mask.is_invisible() and mask.get_size() == image.get_size(), "Diagonal lamps lost their artwork alignment")


func _check_deck_occlusion() -> void:
	var pack := GraphicsPack.load_root(ProjectSettings.globalize_path("res://../ext/graphics"))
	assert(pack.error.is_empty())
	var app := CityApplication.new()
	app.map_view = CityMapControl.new()
	app.map_view.zoom_factor = 1.0
	app.asset_state.large_sprites = pack.large_sprites
	app.asset_state.small_medium_sprites = pack.small_medium_sprites
	app.asset_state.palette = pack.palette
	app.asset_state.palette_index_encoding = Sc2Palette.index_encoding()
	var city := CityState.from_document(EmptyCityTemplate.create(128))
	app.document_state.city = city
	var tile := Vector2i(64, 64)
	city.set_land_altitude(64, 64, 0)
	city.set_terrain_id(64, 64, 0)
	city.set_building_id(64, 64, BuildingTileIds.HIGHWAY_CURVE_1)
	var center := CityLifePaths.point(city, tile, 0, 1, 0.5, false)
	var command := CityStaticCommand.new()
	command.sprite_id = 1101
	command.size = Vector2i(pack.large_sprites.find_sprite(1101).width, pack.large_sprites.find_sprite(1101).height)
	command.position = center - Vector2(32, 24)
	command.depth_order = 128 * 128 + 64
	app.render_caches.static_occlusion_commands.assign([command])
	app.render_caches.static_occlusion_grid = CityIsometricRenderer.build_occlusion_grid(app.render_caches.static_occlusion_commands, 1)
	var canvas := CityLifeCanvas.new()
	assert(canvas._candidates(app, tile, 0).is_empty(), "The supporting diagonal deck hides its own cars")
	# An unrelated later structure must retain its foreground silhouette.
	command.depth_order += 129
	canvas._occluders.clear()
	assert(not canvas._candidates(app, tile, 0).is_empty(), "Diagonal cars ignore a foreground structure")
	canvas.free()
	app.map_view.free()
	app.free()



func _check_joins_and_grades() -> void:
	var city := CityState.from_document(EmptyCityTemplate.create(128))
	var tile := Vector2i(64, 64)
	for rotation in 4:
		var enter := rotation
		var exit := (rotation + 1) % 4
		city.set_land_altitude(64, 64, 0)
		city.set_terrain_id(64, 64, 0)
		city.set_building_id(64, 64, BuildingTileIds.ROAD_CURVE_1 + rotation)
		for walking in [false, true]:
			for edge in [enter, exit]:
				var neighbor: Vector2i = tile + CityLifePaths.DIRECTIONS[edge]
				city.set_land_altitude(neighbor.x, neighbor.y, 0)
				city.set_terrain_id(neighbor.x, neighbor.y, 0)
				city.set_building_id(neighbor.x, neighbor.y, BuildingTileIds.ROAD_STRAIGHT_1 + edge % 2)
				assert(CityLifePaths.connected(city, tile, edge))
				var on_curve := CityLifePaths.point(city, tile, enter, exit, 0 if edge == enter else 1, walking)
				var on_straight := CityLifePaths.point(city, neighbor, edge if edge == enter else (edge + 2) % 4,
					(edge + 2) % 4 if edge == enter else edge, 1 if edge == enter else 0, walking)
				assert(on_curve.is_equal_approx(on_straight), "Diagonal/straight road join jumps")
		for shape in [1, 6, 9]:
			city.set_terrain_id(64, 64, shape)
			var a := CityLifePaths.point(city, tile, enter, exit, 0, false)
			var b := CityLifePaths.point(city, tile, enter, exit, 1, false)
			assert(CityLifePaths.point(city, tile, enter, exit, 0.25, false).is_equal_approx(a.lerp(b, 0.25)), "Graded diagonal is not linear")
			_check_patch(city, tile, enter, CityLifeLights.new())


func _check_fixture_spacing() -> void:
	var city := CityState.from_document(EmptyCityTemplate.create(128))
	for highway in [false, true]:
		for rotation in 4:
			for phase in 2:
				for spacing in [1, 2, 3]:
					var count := 0
					var previous := -1
					for i in 48:
						var offset := Vector2i((i + 1) / 2, i / 2)
						for turn in rotation:
							offset = Vector2i(-offset.y, offset.x)
						var tile := Vector2i(64 + phase, 64) + offset
						var first := BuildingTileIds.HIGHWAY_CURVE_1 if highway else BuildingTileIds.ROAD_CURVE_1
						city.set_building_id(tile.x, tile.y, first + (rotation + (0 if i % 2 == 0 else 2)) % 4)
						# The occupied half of a highway curve has one carriageway.
						city.set_building_corners(tile.x, tile.y, [0x10, 0x20, 0x40, 0x80][(rotation + (0 if i % 2 == 0 else 2)) % 4])
						var layout := CityNightFixtures.street_layout(city, tile, spacing)
						if layout.is_empty():
							continue
						if previous >= 0:
							assert(i - previous == spacing * 2, "Diagonal lamp intervals changed along the road")
						previous = i
						count += 1
						assert(layout == CityNightFixtures.street_layout(city, tile, spacing))
					assert(count == 48 / (2 * spacing), "Diagonal lamp grid is too dense or direction-dependent")
