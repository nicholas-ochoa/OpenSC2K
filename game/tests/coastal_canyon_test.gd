extends SceneTree

func _initialize() -> void:
	for edge in [128, 256, 384, 512]:
		for feature in ["cliffs", "canyon", "valley"]:
			var doc := EmptyCityTemplate.create(edge)
			var generated := NewCityTerrain.generate(doc, false, feature == "canyon", 12, 5, 0,
				SimRandom.new(29), GameLcgRandom.new(29), feature, [], true)
			assert(generated.ok)
			var city := CityState.from_document(doc)
			var sea := doc.misc_u32(0x0e40)
			var heights := PackedInt32Array()
			heights.resize(edge * edge)
			for x in edge:
				for y in edge:
					heights[x * edge + y] = city.land_altitude(x, y)
			if feature == "canyon":
				assert(generated.water_tiles == 0, "Canyon must remain dry even when River was requested")
				assert(doc.misc_u32(0x0e48) == 0)
				assert(Array(heights).min() > sea)
				assert(Array(heights).max() - Array(heights).min() >= 6)
				var floor_level: int = Array(heights).min()
				assert(_largest_flat_square(city, floor_level) >= 12 * IntegerMath.div_trunc(edge, 128),
					"The canyon floor must fit a city neighborhood")
			elif feature == "valley":
				assert(generated.water_tiles > 0)
				assert(_largest_flat_square(city, sea + 1) >= 6 * IntegerMath.div_trunc(edge, 128),
					"River banks must fit a flat buildable neighborhood")
				assert(Array(heights).max() >= sea + 6, "Retain raised valley sides")
			else:
				var distances := TerrainElevation._water_distances(heights, sea, edge)
				var inland_min := 31
				var inland_max := 0
				var inland_count := 0
				var coastal_count := 0
				for index in heights.size():
					if distances[index] >= 20 * IntegerMath.div_trunc(edge, 128):
						inland_min = mini(inland_min, heights[index])
						inland_max = maxi(inland_max, heights[index])
						inland_count += 1
					elif heights[index] > sea and heights[index] < sea + 6:
						coastal_count += 1
				assert(inland_count > 0 and coastal_count > 0)
				assert(inland_min >= sea + 8, "Keep the whole inland plateau high")
				assert(inland_max == inland_min, "Keep inland elevation consistent")
			var data: PackedByteArray = doc.serialize().data
			var loaded := Sc2File.new()
			assert(loaded.parse(data) and loaded.serialize().data == data)
			print(feature, " terrain checks: ", edge)
	print("Coastal plateau, dry canyon, and river floodplain checks passed")
	quit()


func _largest_flat_square(city: CityState, level: int) -> int:
	var edge := city.map_size
	var widths := PackedInt32Array()
	widths.resize(edge + 1)
	var largest := 0
	for x in edge:
		var diagonal := 0
		for y in edge:
			var above := widths[y + 1]
			if city.land_altitude(x, y) == level and city.terrain_id(x, y) == 0 and not city.is_water(x, y):
				widths[y + 1] = 1 + mini(mini(widths[y], above), diagonal)
				largest = maxi(largest, widths[y + 1])
			else:
				widths[y + 1] = 0
			diagonal = above
	return largest
