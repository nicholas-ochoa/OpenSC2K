extends SceneTree

func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var lake_maps := 0
	var dry_bank_maps := 0
	for seed in range(1, 13):
		var doc := _generate(128, seed)
		var components := _water_components(CityState.from_document(doc))
		assert(not components.is_empty())
		if components.size() > 1:
			lake_maps += 1
		else:
			dry_bank_maps += 1
		print("Meander seed ", seed, ": ", components.size(), " water bodies")
	assert(lake_maps > 0 and dry_bank_maps > 0, "Expected seeds both with and without oxbow lakes")
	for edge in [128, 256, 384, 512]:
		var doc := _generate(edge, 1)
		var city := CityState.from_document(doc)
		var bodies := _water_components(city)
		var largest: Array = []
		for body in bodies:
			if body.size() > largest.size():
				largest = body
		var border_tiles := 0
		for point: Vector2i in largest:
			if point.x == 0 or point.y == 0 or point.x == edge - 1 or point.y == edge - 1:
				border_tiles += 1
		assert(border_tiles > 1, "Main channel does not cross the map")
		var again := _generate(edge, 1)
		assert(doc.serialize().data == again.serialize().data)
		for features in [["meander", "delta", "peninsula", "bay"], ["meander", "bay"], ["meander", "branch", "rejoin", "crossing"]]:
			var combined := EmptyCityTemplate.create(edge)
			assert(NewCityTerrain.generate(combined, true, true, 12, 5, 0,
				SimRandom.new(1), GameLcgRandom.new(1), "classic", features, true).ok)
			var reloaded := Sc2File.new()
			assert(reloaded.parse(combined.serialize().data))
			assert(reloaded.serialize().data == combined.serialize().data)
		print("Meandering River checks: ", edge)
	# The shared bend displacement is applied to every branch endpoint.
	var paths: Array[PackedVector2Array] = [PackedVector2Array([Vector2(0, -0.9), Vector2.ZERO]),
		PackedVector2Array([Vector2.ZERO, Vector2(0, 0.9)])]
	TerrainFeatures._meander_channels(paths, 0.03, 0, 1.0, GameLcgRandom.new(3))
	assert(paths[0][-1] == paths[1][0])
	# A straight reach gets a few broad bends, not high-frequency zigzags.
	var reach := PackedVector2Array()
	for index in 257:
		reach.append(Vector2(0, -0.5 + float(index) / 256.0))
	var smooth_paths: Array[PackedVector2Array] = [reach]
	TerrainFeatures._meander_channels(smooth_paths, 0.03, 0, 1.0, GameLcgRandom.new(3))
	var turns := 0
	for index in range(1, 256):
		var before := smooth_paths[0][index] - smooth_paths[0][index - 1]
		var after := smooth_paths[0][index + 1] - smooth_paths[0][index]
		assert(absf(before.angle_to(after)) < 0.1, "Sharp bend in the channel")
		if before.x * after.x < 0:
			turns += 1
	assert(turns >= 2 and turns <= 3, "Keep bends broad")
	print("Meandering River and oxbow checks passed")
	quit()


func _generate(edge: int, seed: int) -> Sc2File:
	var doc := EmptyCityTemplate.create(edge)
	assert(NewCityTerrain.generate(doc, false, true, 12, 5, 0,
		SimRandom.new(seed), GameLcgRandom.new(seed), "classic", ["meander"], true).ok)
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
