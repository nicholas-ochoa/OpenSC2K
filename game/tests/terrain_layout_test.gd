extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_check_peninsula_headland()
	var names := {}
	var random := RandomNumberGenerator.new()
	random.seed = 123
	for layout in NewCityTerrain.LAYOUTS:
		for attempt in 10:
			var value := CityNameGenerator.generate(layout, random)
			assert(not value.is_empty() and value.length() <= 30)
			names[value] = true
	# Compare water coverage at both ends of the new-layout Water setting.
	for layout in ["branch", "islands", "bay", "lakes"]:
		var previous_water := -1
		for water in [0, 47]:
			var source := EmptyCityTemplate.create()
			var result := NewCityTerrain.generate(source, false, false, 12, water, 0, SimRandom.new(7), GameLcgRandom.new(9), layout)
			assert(result.ok and result.water_tiles > previous_water)
			previous_water = result.water_tiles
	for edge in [128]:
		for layout in ["island", "islands", "crossing", "branch", "rejoin", "bay", "peninsula", "plateau", "delta", "lake", "lakes"]:
			var doc := EmptyCityTemplate.create()
			assert(doc.resize_empty_map(edge))
			var result := NewCityTerrain.generate(doc, false, layout == "classic", 12, 5, 0, SimRandom.new(1), GameLcgRandom.new(1), layout)
			assert(result.ok)
			var city := CityState.from_document(doc)
			# Exhaustive surface joins live in terrain_surface_continuity_test.
			for x in edge:
				for y in edge:
					if x + 1 < edge:
						assert(absi(city.land_altitude(x, y) - city.land_altitude(x + 1, y)) <= 1)
					if x + 1 < edge and y + 1 < edge and layout != "classic":
						assert(absi(city.land_altitude(x, y) - city.land_altitude(x + 1, y + 1)) <= 1)
					if y + 1 < edge:
						assert(absi(city.land_altitude(x, y) - city.land_altitude(x, y + 1)) <= 1)
			if layout in ["island", "islands"]:
				for coordinate in edge:
					assert(city.is_water(0, coordinate) and city.is_water(edge - 1, coordinate))
					assert(city.is_water(coordinate, 0) and city.is_water(coordinate, edge - 1))
				var land_masses := _components(city, false)
				assert(land_masses == (1 if layout == "island" else 2), "%s %s: %s land masses" % [edge, layout, land_masses])
			if layout in ["crossing", "branch", "rejoin"]:
				assert(_components(city, true) == 1)
				var dry_regions := _components(city, false)
				assert(dry_regions == {"crossing": 3, "branch": 3, "rejoin": 3}[layout], "%s %s: %s regions" % [edge, layout, dry_regions])
			if layout in ["bay", "peninsula"]:
				assert(_components(city, true) == 1 and _components(city, false) == 1)
			if layout == "plateau":
				var edge_high := 0
				for coordinate in edge:
					for point in [Vector2i(coordinate, 0), Vector2i(coordinate, edge - 1), Vector2i(0, coordinate), Vector2i(edge - 1, coordinate)]:
						edge_high = maxi(edge_high, city.land_altitude(point.x, point.y))
				assert(edge_high >= 9, "Plateau stops before the map edge")
			if layout in ["lake", "lakes"]:
				assert(_components(city, true) == (2 if layout == "lakes" else 1))
			if layout == "delta":
				assert(_components(city, true) == 1, "Delta channel is disconnected from the ocean")
			print("Terrain ", edge, " ", layout, ": water=", result.water_tiles)
	for seed in [29]:
		# Representative interactions: shared delta outlet/headland, island inlet,
		# and converging river branches. Single-feature topology is checked above.
		for features in [["delta", "peninsula", "bay"], ["bay", "islands"], ["bay", "branch"], ["branch", "crossing", "rejoin"]]:
			# Isolate outlet interactions from unrelated hill interpolation/retile work.
			var city := _feature_city(features, true, seed)
			assert(_components(city, true) == 1, "Disconnected water: %s seed %d" % [features, seed])
			if "island" in features or "islands" in features:
				assert(_components(city, false) == (2 if "islands" in features else 1))
			var inland := _feature_city(features, false, seed)
			for index in inland.tile_flags.size():
				if inland.tile_flags[index] & 4:
					assert(city.tile_flags[index] & 4, "Feature outlet is disconnected from the ocean")
	var estuary := EmptyCityTemplate.create()
	assert(NewCityTerrain.generate(estuary, true, true, 30, 10, 0,
		SimRandom.new(719), GameLcgRandom.new(719), "classic", [], true).ok)
	assert(_components(CityState.from_document(estuary), true) == 1)
	print("Terrain layout and name checks passed: ", names.size(), " distinct names")
	quit()


static func _components(city: CityState, water: bool) -> int:
	# Connectivity needs only water flags. Avoid repeated model lookups per neighbor.
	var edge := city.map_size
	var flags := city.tile_flags
	var seen := PackedByteArray()
	seen.resize(flags.size())
	var count := 0
	for index in flags.size():
		if seen[index] or ((flags[index] & 4) != 0) != water:
			continue
		count += 1
		var queue: Array[int] = [index]
		seen[index] = 1
		var cursor := 0
		while cursor < queue.size():
			var current := queue[cursor]
			cursor += 1
			var y := current % edge
			for next in [current - edge, current + edge,
				current - 1 if y > 0 else -1, current + 1 if y + 1 < edge else -1]:
				if next >= 0 and next < flags.size() and not seen[next] and ((flags[next] & 4) != 0) == water:
					seen[next] = 1
					queue.append(next)
	return count


func _check_peninsula_headland() -> void:
	for seed in [1, 29, 719, 5000]:
		for features in [["peninsula"], ["peninsula", "bay"]]:
			var heights := PackedInt32Array()
			heights.resize(128 * 128)
			heights.fill(6)
			var flags := PackedByteArray()
			flags.resize(128 * 128)
			var random := GameLcgRandom.new(seed)
			var angle := float(GameLcgRandom.new(seed).next_mod(6283)) / 1000.0
			TerrainFeatures.carve(heights, flags, 5, features, true, false, random, 5)
			# The neck and tip stay on-map, with ocean on both sides and beyond the tip.
			for point in [Vector2(0.08, -0.18), Vector2(0.08, 0.0), Vector2(0.08, 0.25)]:
				assert(_peninsula_height(heights, point, angle) >= 5)
			for point in [Vector2(-0.20, 0.15), Vector2(0.35, 0.15), Vector2(0.08, 0.46)]:
				assert(_peninsula_height(heights, point, angle) < 5, "Headland is missing ocean on one of three sides")


func _peninsula_height(heights: PackedInt32Array, point: Vector2, angle: float) -> int:
	var tile := Vector2i(((point.rotated(angle) + Vector2(0.5, 0.5)) * 127.0).round())
	return heights[tile.x * 128 + tile.y]


func _feature_city(features: Array, ocean: bool, seed: int) -> CityState:
	var heights := PackedInt32Array()
	heights.resize(128 * 128)
	heights.fill(6)
	var flags := PackedByteArray()
	flags.resize(heights.size())
	TerrainFeatures.carve(heights, flags, 4, features, ocean, "delta" in features,
		GameLcgRandom.new(seed), 10, 30)
	for index in heights.size():
		if heights[index] <= 4:
			flags[index] |= 4
	var city := CityState.from_document(EmptyCityTemplate.create())
	assert(city.replace_tile_flags(flags))
	return city
