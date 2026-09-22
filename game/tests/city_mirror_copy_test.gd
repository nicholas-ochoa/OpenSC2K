extends SceneTree


func _initialize() -> void:
	var city := CityState.from_document(EmptyCityTemplate.create(16))
	assert(city.is_valid())
	city.visible_altitude_levels = 9
	city.object_altitude_overrides = PackedInt32Array([4])
	var target := CityState.new()
	var target_document := EmptyCityTemplate.create(16)
	target.document = target_document
	city.copy_mirrors_to(target)
	assert(target.document == target_document)
	assert(target.visible_altitude_levels == 32 and target.object_altitude_overrides.is_empty())
	for field in ["altitude_words", "terrain", "buildings", "zones", "underground", "text_overlays", "tile_flags"]:
		var copied: Variant = target.get(field)
		var original: Variant = city.get(field)
		assert(copied == original)
		var previous: int = original[0]
		original[0] = previous ^ 1
		assert(copied[0] == previous, "captured mirrors stay private")
		copied[0] = previous ^ 2
		assert(original[0] == (previous ^ 1), "source mirrors stay private")
	var filtered := CityViewFilter.surface_copy(city, {})
	assert(filtered.document == city.document)
	assert(filtered.visible_altitude_levels == 9)
	filtered.object_altitude_overrides[0] = 7
	assert(city.object_altitude_overrides[0] == 4)
	var completed := CityState.new()
	city.copy_mirrors_to(completed)
	completed.copy_mirrors_to(target, true)
	completed.terrain[0] = 55
	assert(target.terrain[0] == 55 and city.terrain[0] != 55, "publication transfers private mirrors")
	print("PASS: mirror copy isolation and display/document ownership")
	quit()
