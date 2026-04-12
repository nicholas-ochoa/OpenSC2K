extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var names := {}
	var random := RandomNumberGenerator.new()
	random.seed = 123
	for layout in NewCityTerrain.LAYOUTS:
		for attempt in 300:
			var value := CityNameGenerator.generate(layout, random)
			assert(not value.is_empty() and value.length() <= 30)
			names[value] = true
	assert(names.size() > 1000)
	# Compare water coverage at both ends of the new-layout Water setting.
	for layout in NewCityTerrain.LAYOUTS.slice(1):
		var previous_water := -1
		for water in [0, 47]:
			var source := EmptyCityTemplate.create()
			var result := NewCityTerrain.generate(source, false, false, 12, water, 0, SimRandom.new(7), GameLcgRandom.new(9), layout)
			assert(result.ok and result.water_tiles > previous_water)
			previous_water = result.water_tiles
			var repeat := EmptyCityTemplate.create()
			assert(NewCityTerrain.generate(repeat, false, false, 12, water, 0, SimRandom.new(7), GameLcgRandom.new(9), layout).ok)
			assert(repeat.serialize().data == source.serialize().data)
	for edge in [128, 256, 384, 512]:
		for layout in NewCityTerrain.LAYOUTS:
			var doc := EmptyCityTemplate.create()
			assert(doc.resize_empty_map(edge))
			var result := NewCityTerrain.generate(doc, false, true, 12, 5, 0, SimRandom.new(1), GameLcgRandom.new(1), layout)
			assert(result.ok)
			var city := CityState.from_document(doc)
			for x in edge:
				for y in edge:
					if x + 1 < edge:
						assert(absi(city.land_altitude(x, y) - city.land_altitude(x + 1, y)) <= 1)
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
				assert(dry_regions == {"crossing": 4, "branch": 3, "rejoin": 3}[layout], "%s %s: %s regions" % [edge, layout, dry_regions])
			if layout == "bay":
				assert(_components(city, true) == 1 and _components(city, false) == 1)
			var data: PackedByteArray = doc.serialize().data
			var reloaded := Sc2File.new()
			assert(reloaded.parse(data))
			assert(reloaded.serialize().data == data)
			print("Terrain ", edge, " ", layout, ": water=", result.water_tiles)
	print("Terrain layout and name checks passed: ", names.size(), " distinct names")
	quit()


func _components(city: CityState, water: bool) -> int:
	var seen := PackedByteArray()
	seen.resize(city.map_size * city.map_size)
	var count := 0
	for x in city.map_size:
		for y in city.map_size:
			var index := city.index_of(x, y)
			if seen[index] or city.is_water(x, y) != water:
				continue
			count += 1
			var queue: Array[Vector2i] = [Vector2i(x, y)]
			seen[index] = 1
			var cursor := 0
			while cursor < queue.size():
				var point := queue[cursor]
				cursor += 1
				for offset in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
					var next: Vector2i = point + offset
					var next_index := city.index_of(next.x, next.y)
					if next_index >= 0 and not seen[next_index] and city.is_water(next.x, next.y) == water:
						seen[next_index] = 1
						queue.append(next)
	return count
