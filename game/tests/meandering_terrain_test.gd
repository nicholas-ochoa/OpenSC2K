extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var lake_maps := 0
	var dry_bank_maps := 0
	var first_document: Sc2File
	var first_components: Array
	for random_seed in [1, 5, 7]:
		var doc := _generate(128, random_seed)
		var components := _water_components(CityState.from_document(doc))
		assert(not components.is_empty())
		if random_seed == 1:
			first_document = doc
			first_components = components
		if components.size() > 1:
			lake_maps += 1
		else:
			dry_bank_maps += 1
		print("Meander seed ", random_seed, ": ", components.size(), " water bodies")
	assert(lake_maps > 0 and dry_bank_maps > 0, "Expected seeds both with and without oxbow lakes")
	for edge in [128]:
		var doc := first_document
		var bodies := first_components
		var largest: Array = []
		for body in bodies:
			if body.size() > largest.size():
				largest = body
		var border_tiles := 0
		for point: Vector2i in largest:
			if point.x == 0 or point.y == 0 or point.x == edge - 1 or point.y == edge - 1:
				border_tiles += 1
		assert(border_tiles > 1, "Main channel does not cross the map")
		if edge == 128:
			var again := _generate(edge, 1)
			assert(doc.serialize().data == again.serialize().data)
		for features in [["meander", "delta", "peninsula", "bay", "ridge", "valley", "cliffs", "lakes"],
			["meander", "delta", "peninsula", "bay"], ["meander", "bay"], ["meander", "branch", "rejoin", "crossing"]]:
			var combined := EmptyCityTemplate.create(edge)
			assert(NewCityTerrain.generate(combined, true, true, 12, 5, 0,
				SimRandom.new(1), GameLcgRandom.new(1), "classic", features, true).ok)
			var reloaded := Sc2File.new()
			assert(reloaded.parse(combined.serialize().data))
			assert(reloaded.serialize().data == combined.serialize().data)
		print("Meandering River checks: ", edge)
	print("Meandering River and oxbow checks passed")
	quit()


func _generate(edge: int, random_seed: int) -> Sc2File:
	var doc := EmptyCityTemplate.create(edge)
	assert(NewCityTerrain.generate(doc, false, true, 12, 5, 0,
		SimRandom.new(random_seed), GameLcgRandom.new(random_seed), "classic", ["meander"], true).ok)
	return doc


func _water_components(city: CityState) -> Array:
	var seen := PackedByteArray()
	seen.resize(city.map_size * city.map_size)
	var result: Array = []
	for x in city.map_size:
		for y in city.map_size:
			var index := city.index_of(x, y)
			if seen[index] or not city.is_water(x, y):
				continue
			var queue: Array[Vector2i] = [Vector2i(x, y)]
			seen[index] = 1
			var cursor := 0
			while cursor < queue.size():
				var point := queue[cursor]
				cursor += 1
				for delta in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
					var near: Vector2i = point + delta
					var next := city.index_of(near.x, near.y)
					if next >= 0 and not seen[next] and city.is_water(near.x, near.y):
						seen[next] = 1
						queue.append(near)
			result.append(queue)
	return result
