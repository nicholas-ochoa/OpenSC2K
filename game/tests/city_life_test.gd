extends SceneTree

const DocumentState = preload("res://tests/support/document_state.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var city := fixture()
	_check_paths(city)
	_check_network_sections()
	_check_density(city)
	_check_occlusion()
	_check_spacing()
	_check_vehicle_mix()
	var before := DocumentState.capture(city.document)
	var app := CityApplication.new()
	var life := app.city_life
	life._viewport = Rect2i(0, 0, 5000, 4000)
	for x in range(58, 71):
		for y in range(58, 71):
			if CityLifePaths.ports(city, Vector2i(x, y)) > 0:
				life.tiles.append(Vector2i(x, y))
	var options := VisualEnhancementOptions.normalize({})
	for step in 30:
		life._spawn(city, options)
		life._advance(city, 0.08)
	assert(not life.figures.is_empty())
	var cars := 0
	var people := 0
	for figure in life.figures:
		if figure.walking:
			people += 1
		else:
			cars += 1
	assert(cars > 0 and people > 0, "Both density-driven figure types must spawn")
	var figure: CityLifeController.Figure = life.figures[0]
	var initial_tile := figure.tile
	var original_variant := figure.variant
	var original_kind := figure.vehicle_kind
	life.figures = [figure]
	figure.wait = 0.0
	for step in 100:
		life._advance(city, 0.08)
	assert(figure.tile != initial_tile, "Figures must cross tile boundaries")
	assert(figure.variant == original_variant, "A figure must keep its appearance")
	assert(figure.vehicle_kind == original_kind, "Vehicles must keep their type across tiles")
	assert(DocumentState.capture(city.document) == before, "City life wrote saved city data")
	# Zero density does not seed decorative traffic. Amount controls remain local.
	life.figures.clear()
	city.document.find_chunk("XTRF").decoded_payload.fill(0)
	city.document.find_chunk("XPOP").decoded_payload.fill(0)
	for step in 10:
		life._spawn(city, options)
	assert(life.figures.is_empty())
	app.free()
	await _check_application()
	print("PASS: city life topology, continuous lanes, local density, shared artwork, occlusion and unchanged city data")
	quit()


func _check_application() -> void:
	var graphics_override := OS.get_environment("OPENSC2K_GRAPHICS_PACK")
	OS.set_environment("OPENSC2K_GRAPHICS_PACK", ProjectSettings.globalize_path("res://../ext/graphics"))
	var app := (load("res://main.tscn") as PackedScene).instantiate() as CityApplication
	root.add_child(app)
	await process_frame
	OS.set_environment("OPENSC2K_GRAPHICS_PACK", graphics_override)
	app.set_process(false)
	app.main_menu.city_background.set_process(false)
	assert(app.city_session.activate_document(fixture().document))
	app.map_view.zoom_factor = 2.0
	app.map_view.center_on_tile(Vector2i(64, 64))
	var deadline := Time.get_ticks_msec() + 10000
	while app.map_view.city_source == null and Time.get_ticks_msec() < deadline:
		app.static_render.poll_static_render()
		app.static_render.start_pending_static_render()
		await process_frame
	assert(app.map_view.city_source != null, "Test city must finish its static render")
	_check_fades(app)
	var city := app.document_state.city
	var before := DocumentState.capture(city.document)
	var engine := app.simulation_state.simulation_engine
	var random_before := [engine.random.state, engine.lfsr_random.state, engine.game_random.state]
	app.preferences.visual_enhancements.pause_freezes = false
	for step in 20:
		app.city_life.process(0.08)
	assert(app.city_life.canvas != null and not app.city_life.figures.is_empty())
	_check_running_cache(app)
	_check_day_emission(app)
	assert(app.asset_state.large_sprites.visual_city_life_traffic)
	app.preferences.visual_enhancements.pause_freezes = true
	app.simulation_state.speed_controller.speed = GameSpeedController.Speed.PAUSED
	var figure: CityLifeController.Figure = app.city_life.figures[0]
	var position := figure.position
	app.city_life.process(1.0)
	assert(figure.position == position, "Pause must freeze figure movement")
	var original_size := app.map_view.size
	app.map_view.size = Vector2(10000, 10000)
	app.city_life.process(0.0)
	assert(not app.asset_state.large_sprites.visual_city_life_traffic and not app.city_life.canvas.visible,
		"A viewport outside the drawing budget must retain classic traffic")
	app.map_view.size = original_size
	app.city_life.process(0.0)
	assert(app.asset_state.large_sprites.visual_city_life_traffic)
	app.preferences.visual_enhancements.life_people_enabled = false
	app.city_life.process(0.0)
	assert(app.city_life.figures.all(func(f: CityLifeController.Figure) -> bool: return not f.walking))
	app.preferences.visual_enhancements.life_cars_enabled = false
	app.city_life.process(0.0)
	assert(not app.asset_state.large_sprites.visual_city_life_traffic and not app.city_life.canvas.visible)
	assert(DocumentState.capture(city.document) == before)
	assert([engine.random.state, engine.lfsr_random.state, engine.game_random.state] == random_before)
	app.queue_free()
	await process_frame


func _check_running_cache(app: CityApplication) -> void:
	if app.render_caches.region_cache == null:
		return
	var canvas := app.city_life.canvas
	var key := Vector3i(-1, -1, 0)
	# Track an existing-cache entry across a traffic-only publication. Geometry
	# invalidation and pixels are exercised by the separate occlusion tests.
	canvas._occluders[key] = []
	app.document_state.city.document.find_chunk("XTRF").mark_mutated()
	app.map_render.refresh_map(false)
	canvas.render(app, app.city_life.figures, app.city_life.sprites)
	assert(canvas._occluders.has(key), "Traffic-density updates discarded unchanged city-life silhouettes")
	app.render_caches.region_cache._layout_generation += 1
	canvas.render(app, app.city_life.figures, app.city_life.sprites)
	assert(not canvas._occluders.has(key), "A replacement region layout must discard old masks")
	app.render_caches.region_cache._layout_generation -= 1


func _check_day_emission(app: CityApplication) -> void:
	var canvas := app.city_life.canvas
	var saved_night := app.visual_environment.night
	app.visual_environment.night = 1.0
	canvas.render(app, app.city_life.figures, app.city_life.sprites)
	assert(canvas.emission != null and canvas._emission_active and canvas.road_layer.visible)
	var texture := canvas.emission_texture
	var pixels := canvas.emission.get_data()
	app.visual_environment.night = 0.0
	canvas.render(app, [], app.city_life.sprites)
	assert(not canvas._emission_active and not canvas.road_layer.visible)
	assert(canvas.emission.get_data() == pixels and canvas.emission_texture == texture,
		"Day rendering must leave the unused emission image and texture alone")
	app.visual_environment.night = 1.0
	canvas.render(app, [], app.city_life.sprites)
	assert(canvas.emission_texture == texture and canvas._emission_active)
	var clear := Image.create(canvas.emission.get_width(), canvas.emission.get_height(), false, Image.FORMAT_RGBA8)
	clear.fill(Color.TRANSPARENT)
	assert(canvas.emission.get_data() == clear.get_data(), "Night reactivation retained stale lamp pixels")
	app.visual_environment.night = saved_night


func _check_fades(app: CityApplication) -> void:
	var city := app.document_state.city
	var life := app.city_life
	var options := app.preferences.visual_enhancements
	options.pause_freezes = false
	options.speed_link = true
	app.simulation_state.speed_controller.speed = GameSpeedController.Speed.AFRICAN_SWALLOW
	life.process(0.0)
	life.figures.clear()
	var tracked: Array[CityLifeController.Figure] = []
	for kind in 4:
		var figure := CityLifeController.Figure.new()
		figure.id = 10000 + kind
		figure.walking = kind == 3
		figure.vehicle_kind = mini(kind, 2)
		figure.tile = Vector2i(64, 61 + kind)
		figure.enter = 0
		figure.exit = 2
		figure.direction = 2
		figure.progress = 0.5
		figure.speed = 0.0
		figure.lifetime = 100.0
		figure.position = CityLifePaths.point(city, figure.tile, 0, 2, 0.5, figure.walking)
		tracked.append(figure)
		life.figures.append(figure)
	for step in 4:
		life.process(0.08)
	for figure in tracked:
		assert(figure.opacity() > 0.3 and figure.opacity() < 0.7,
			"African Swallow must not compress a readable fade-in into one frame")
		assert(is_equal_approx(figure.age, 0.96), "Movement time must retain its selected speed")
	# Frequent density and unrelated building updates must preserve figure identity and opacity.
	var opacity := tracked[0].opacity()
	var traffic := city.document.find_chunk("XTRF")
	var population := city.document.find_chunk("XPOP")
	var traffic_before := traffic.decoded_payload.duplicate()
	var population_before := population.decoded_payload.duplicate()
	for step in 4:
		city.set_building_id(0, 0, 0x74 if step % 2 == 0 else 0)
		traffic.decoded_payload.fill(0 if step % 2 == 0 else 200)
		population.decoded_payload.fill(0 if step % 2 == 0 else 160)
		traffic.mark_mutated()
		population.mark_mutated()
		life.process(0.0)
		for figure in tracked:
			assert(figure in life.figures and not figure.retiring, "A remote update reset valid city-life figures")
			assert(is_equal_approx(figure.opacity(), opacity), "A data refresh restarted a fade")
	traffic.set_decoded_payload(traffic_before)
	population.set_decoded_payload(population_before)
	for step in 5:
		life.process(0.08)
	for figure in tracked:
		assert(figure.opacity() == 1.0)
	# A removed lane fades its occupants only; natural expiry uses the same transition.
	var removed := tracked[0]
	var road_id := city.building_id(removed.tile.x, removed.tile.y)
	city.set_building_id(removed.tile.x, removed.tile.y, 0)
	life.process(0.0)
	assert(removed in life.figures and removed.retiring and removed.opacity() == 1.0)
	assert(not tracked[1].retiring)
	for figure in tracked.slice(1):
		figure.lifetime = figure.age
	life.process(0.08)
	for figure in tracked:
		assert(figure in life.figures and figure.retiring and figure.opacity() > 0.9,
			"Expired cars, trucks, buses and pedestrians must remain visible for their fade-out")
	options.pause_freezes = true
	app.simulation_state.speed_controller.speed = GameSpeedController.Speed.PAUSED
	opacity = removed.opacity()
	life.process(0.5)
	assert(removed.opacity() == opacity, "Pause must freeze the fade when configured")
	app.simulation_state.speed_controller.speed = GameSpeedController.Speed.AFRICAN_SWALLOW
	for step in 5:
		life.process(0.08)
	for figure in tracked:
		assert(figure in life.figures and figure.opacity() > 0.2 and figure.opacity() < 0.6)
	for step in 6:
		life.process(0.08)
	for figure in tracked:
		assert(figure not in life.figures and figure.opacity() == 0.0, "Remove a figure only after its fade ends")
	city.set_building_id(removed.tile.x, removed.tile.y, road_id)
	options.pause_freezes = false
	app.simulation_state.speed_controller.speed = GameSpeedController.Speed.PAUSED
	print("PASS: real-time city-life fades at African Swallow, density/geometry continuity and pause")


static func fixture() -> CityState:
	var city := CityState.from_document(EmptyCityTemplate.create(128))
	for x in range(58, 71):
		for y in range(58, 71):
			var tile := Vector2i(x, y)
			city.set_land_altitude(x, y, 0)
			city.set_terrain_id(x, y, 0)
			if x % 3 == 1 or y % 3 == 1:
				var id := 0x2b if x % 3 == 1 and y % 3 == 1 else (0x1d if x % 3 == 1 else 0x1e)
				city.set_building_id(tile.x, tile.y, id)
	city.document.find_chunk("XTRF").decoded_payload.fill(200)
	city.document.find_chunk("XPOP").decoded_payload.fill(160)
	return city


static func _check_paths(city: CityState) -> void:
	assert(CityLifePaths.ports(city, Vector2i(0, 0)) == 0)
	assert(CityLifePaths.ports(city, Vector2i(-1, 64)) == 0)
	var tile := Vector2i(64, 64)
	for direction in 4:
		assert(CityLifePaths.connected(city, tile, direction))
		var next: Vector2i = tile + CityLifePaths.DIRECTIONS[direction]
		for walking in [true, false]:
			var a := CityLifePaths.point(city, tile, (direction + 2) % 4, direction, 1.0, walking)
			var b := CityLifePaths.point(city, next, (direction + 2) % 4, direction, 0.0, walking)
			assert(a.is_equal_approx(b), "Lane endpoints must join without jumps")
	city.set_building_id(64, 63, 0x1e)
	assert(not CityLifePaths.connected(city, tile, 0), "Adjacent roads must have reciprocal ports")
	city.set_building_id(64, 63, 0x1d)
	city.set_land_altitude(64, 63, 2)
	assert(not CityLifePaths.connected(city, tile, 0), "Figures cannot cross an unconnected height step")
	city.set_land_altitude(64, 63, 0)
	city.set_building_id(64, 64, 0x49)
	assert(not CityLifePaths.walkable(city, tile), "No pedestrians on highways")
	city.set_building_id(64, 64, 0x2b)


static func _check_density(city: CityState) -> void:
	var traffic := city.document.find_chunk("XTRF").decoded_payload
	var population := city.document.find_chunk("XPOP").decoded_payload
	assert(CityDataGrid.edge(traffic, 128) == 64 and CityDataGrid.edge(population, 128) == 32)
	for walking in [false, true]:
		assert(CityLifePaths.target(0, 1.0, walking) == 0.0)
		var previous := 0.0
		for density_value in [1, 16, 64, 128, 192, 255]:
			var target := CityLifePaths.target(density_value, 1.0, walking)
			assert(target > previous)
			assert(CityLifePaths.target(density_value, 2.0, walking) > target)
			previous = target
	assert(CityLifePaths.density(city, Vector2i(64, 64), false) == 200)
	assert(CityLifePaths.density(city, Vector2i(64, 64), true) == 160)
	var expanded := city.document.duplicate_document(true)
	expanded.find_chunk("XTRF").decoded_payload = CityDataGrid.expand(traffic, city.map_size)
	expanded.find_chunk("XPOP").decoded_payload = CityDataGrid.expand(population, city.map_size)
	var full := CityState.from_document(expanded)
	assert(CityLifePaths.density(full, Vector2i(64, 64), false) == 200)
	assert(CityLifePaths.density(full, Vector2i(64, 64), true) == 160)


static func _check_occlusion() -> void:
	var destination := Image.create(3, 1, false, Image.FORMAT_RGBA8)
	var sprite := Image.create(3, 1, false, Image.FORMAT_RGBA8)
	sprite.fill(Color.RED)
	var mask := Image.create(2, 1, false, Image.FORMAT_RGBA8)
	mask.set_pixel(0, 0, Color.WHITE)
	CityLifeCanvas.stamp(destination, Vector2i.ZERO, sprite, Vector2i.ZERO, [{"origin": Vector2i(1, 0), "image": mask}])
	assert(destination.get_pixel(0, 0) == Color.RED)
	assert(destination.get_pixel(1, 0).a == 0.0)
	assert(destination.get_pixel(2, 0) == Color.RED, "Transparent foreground pixels cannot hide a figure")


static func _check_spacing() -> void:
	var life := CityLifeController.new(CityApplication.new())
	var a := CityLifeController.Figure.new()
	var b := CityLifeController.Figure.new()
	a.enter = 2
	a.exit = 0
	b.enter = 0
	b.exit = 2
	b.position = Vector2(0, 4)
	life.figures = [a, b]
	life._rebuild_buckets()
	assert(not life._crowded(a, Vector2.ZERO, false), "Opposite lanes cannot block each other")
	b.enter = 2
	b.exit = 0
	b.position = Vector2(3, -1.5)
	assert(life._crowded(a, Vector2.ZERO, false), "Cars must yield to a car ahead")
	b.position = Vector2(-3, 1.5)
	assert(not life._crowded(a, Vector2.ZERO, false), "A following car cannot block the leader")
	b.vehicle_kind = CityLifeSprites.Vehicle.BUS
	b.position = Vector2(5, -2.5)
	life._rebuild_buckets()
	assert(life._crowded(a, Vector2.ZERO, false), "A longer vehicle needs more following space")
	life.app.free()


static func _check_vehicle_mix() -> void:
	var city := fixture()
	var app := CityApplication.new()
	var life := app.city_life
	var near := Vector2i(64, 64)
	life._refresh_bus_area(city)
	var trucks := 0
	for sample in 2000:
		var kind := life._vehicle_kind(near)
		assert(kind != CityLifeSprites.Vehicle.BUS, "No bus may appear without a nearby station")
		trucks += int(kind == CityLifeSprites.Vehicle.TRUCK)
	assert(trucks > 0 and trucks < 200, "Trucks must remain a small part of traffic")
	city.set_building_id(62, 62, BuildingTileIds.BUS_DEPOT)
	life._refresh_bus_area(city)
	assert(life._bus_tiles.has(near))
	assert(life._bus_tiles.has(Vector2i(62, 70)), "Roads at the station radius boundary are eligible")
	assert(not life._bus_tiles.has(Vector2i(70, 70)), "Distant roads cannot show local buses")
	var buses := 0
	for sample in 2000:
		buses += int(life._vehicle_kind(near) == CityLifeSprites.Vehicle.BUS)
		assert(life._vehicle_kind(Vector2i(70, 70)) != CityLifeSprites.Vehicle.BUS)
	assert(buses > 0 and buses < 120, "Buses must remain rarer than ordinary cars")
	# A local bus must turn or retire before it leaves the station area.
	var bus := CityLifeController.Figure.new()
	bus.vehicle_kind = CityLifeSprites.Vehicle.BUS
	bus.tile = Vector2i(62, 70)
	bus.enter = 0
	assert(life._exit(city, bus) == -1)
	life._viewport = Rect2i(0, 0, 5000, 4000)
	life._collect_tiles(city)
	var before := DocumentState.capture(city.document)
	var options := VisualEnhancementOptions.normalize({})
	var spawned_bus := false
	var spawned_truck := false
	for step in 100:
		life.figures.clear()
		life._spawn(city, options)
		for figure in life.figures:
			if figure.walking:
				assert(figure.vehicle_kind == CityLifeSprites.Vehicle.CAR)
				continue
			if figure.vehicle_kind == CityLifeSprites.Vehicle.BUS:
				spawned_bus = true
				assert(life._bus_tiles.has(figure.tile))
				for tick in 60:
					life._advance(city, 0.08)
					assert(life._bus_tiles.has(figure.tile), "A bus left its station neighborhood")
			spawned_truck = spawned_truck or figure.vehicle_kind == CityLifeSprites.Vehicle.TRUCK
	assert(spawned_bus and spawned_truck, "Density-driven traffic must include both rare vehicle types")
	assert(DocumentState.capture(city.document) == before, "Vehicle diversity cannot alter saved city data")
	city.set_building_id(62, 62, 0)
	life._refresh_bus_area(city)
	assert(life._bus_tiles.is_empty(), "Removing a station must invalidate its display area")
	city.set_building_id(0, 0, BuildingTileIds.BUS_DEPOT)
	life._refresh_bus_area(city)
	assert(life._bus_tiles.is_empty(), "An isolated boundary station does not create traffic on distant roads")
	var sprites := CityLifeSprites.new()
	for direction in 4:
		var car := sprites.sprite(false, 0, direction, 0)
		for kind in [CityLifeSprites.Vehicle.TRUCK, CityLifeSprites.Vehicle.BUS]:
			var image := sprites.sprite(false, 0, direction, 0, kind)
			assert(image.get_width() > car.get_width() and not image.is_invisible())
			assert(image == sprites.sprite(false, 0, direction, 1, kind), "Vehicle artwork must share its cache")
	app.free()


static func _check_network_sections() -> void:
	var city := CityState.from_document(EmptyCityTemplate.create(128))
	var tile := Vector2i(64, 64)
	# Every surface that previously received a car-pattern overlay has a lane.
	for id in range(BuildingTileIds.ROAD_STRAIGHT_1, BuildingTileIds.REINFORCED_HIGHWAY_BRIDGE + 1):
		var variant: int = IsometricConstants.TRAFFIC_TILE_VARIANTS[id - BuildingTileIds.ROAD_STRAIGHT_1]
		if variant == 0:
			continue
		city.set_building_id(64, 64, id)
		if id >= BuildingTileIds.HIGHWAY_CURVE_1 and id <= BuildingTileIds.HIGHWAY_CURVE_4:
			var occupied := 0
			for corner in [0x10, 0x20, 0x40, 0x80]:
				city.set_building_corners(64, 64, corner)
				if CityLifePaths.ports(city, tile) > 0:
					occupied += 1
			assert(occupied == 3, "A composite curve has three occupied footprint cells")
		else:
			assert(CityLifePaths.ports(city, tile) > 0, "Missing individual lanes for tile %02x" % id)
	city.set_building_corners(64, 64, 0)
	for flipped in [false, true]:
		city.set_tile_flag(64, 64, Sc2TileFlags.FLIPPED, flipped)
		for id in range(BuildingTileIds.SUSPENSION_BRIDGE_1, BuildingTileIds.RAISING_BRIDGE_CLOSED + 1):
			city.set_building_id(64, 64, id)
			city.set_tile_flag(64, 64, Sc2TileFlags.WATER, true)
			city.set_water_altitude(64, 64, 3)
			assert(CityLifePaths.ports(city, tile) == (10 if flipped else 5))
			assert(CityLifePaths.edge_height(city, tile, 0) == 4.0)
			assert(CityLifePaths.walkable(city, tile))
		city.set_tile_flag(64, 64, Sc2TileFlags.WATER, false)
		for id in range(BuildingTileIds.HIGHWAY_ONRAMP_1, BuildingTileIds.HIGHWAY_ONRAMP_4 + 1):
			city.set_building_id(64, 64, id)
			var high := CityLifePaths.ramp_highway_direction(city, tile)
			var road := CityLifePaths.ramp_road_direction(city, tile)
			assert(CityLifePaths.edge_height(city, tile, high) == 1.0)
			assert(CityLifePaths.edge_height(city, tile, road) == 0.0)
			assert(not CityLifePaths.walkable(city, tile))
			var highway_tile: Vector2i = tile + CityLifePaths.DIRECTIONS[high]
			var road_tile: Vector2i = tile + CityLifePaths.DIRECTIONS[road]
			city.set_building_id(highway_tile.x, highway_tile.y, 0x49 if high % 2 == 0 else 0x4a)
			city.set_building_id(road_tile.x, road_tile.y, 0x1d if road % 2 == 0 else 0x1e)
			for direction in [high, road]:
				assert(CityLifePaths.connected(city, tile, direction))
				var next: Vector2i = tile + CityLifePaths.DIRECTIONS[direction]
				var endpoint := CityLifePaths.point(city, tile, road if direction == high else high, direction, 1.0, false)
				var startpoint := CityLifePaths.point(city, next, (direction + 2) % 4, direction, 0.0, false)
				assert(endpoint.is_equal_approx(startpoint), "Ramp endpoints must meet both road levels without jumps")
	# Real composite curves have one inside bend and one three-cell outside bend.
	for shape in 4:
		var id := BuildingTileIds.HIGHWAY_CURVE_1 + shape
		for y in 2:
			for x in 2:
				city.set_building_id(64 + x, 64 + y, id)
				city.set_tile_flag(64 + x, 64 + y, Sc2TileFlags.FLIPPED, false)
				city.set_building_corners(64 + x, 64 + y, [[0x10, 0x20], [0x80, 0x40]][y][x])
		for y in 2:
			for x in 2:
				var current := Vector2i(64 + x, 64 + y)
				assert(CityLifePaths.section_origin(city, current) == tile)
				for direction in 4:
					var next: Vector2i = current + CityLifePaths.DIRECTIONS[direction]
					if next.x < 64 or next.x > 65 or next.y < 64 or next.y > 65:
						continue
					if CityLifePaths.ports(city, current) & (1 << direction):
						assert(CityLifePaths.connected(city, current, direction), "Composite bend lanes must be reciprocal")
	city.set_building_id(64, 64, BuildingTileIds.HIGHWAY_ROAD_CROSSING_1)
	assert(CityLifePaths.edge_height(city, tile, 0) == 1.0 and CityLifePaths.edge_height(city, tile, 1) == 0.0)
	assert(not CityLifePaths.can_turn(city, tile, 0, 1), "Crossings must not connect a road directly to its overhead highway")
	var source := Image.create(3, 30, false, Image.FORMAT_RGBA8)
	source.fill(Color.WHITE)
	var deck := CityLifeCanvas.deck_foreground(source, Vector2i.ZERO, Vector2(1, 20), 0.5)
	assert(deck.get_pixel(1, 10).a == 1.0 and deck.get_pixel(1, 20).a == 0.0,
		"Towers must remain foreground while the deck beneath a car is removed")
	assert(source.get_pixel(1, 20) == Color.WHITE)
