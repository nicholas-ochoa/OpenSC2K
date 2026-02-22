extends SceneTree
func _initialize() -> void:
	var doc := Sc2File.load_path(ProjectSettings.globalize_path('res://../references/SIMCITY2000/DEFAULT.SC2'))
	var city := CityState.from_document(doc)
	var index := city.index_of(65, 84)
	city.terrain[index] = 0x41
	for x in range(64,67):
		for y in range(83,86):
			city.altitude_words[city.index_of(x,y)] = 6 | (6 << 5)
	assert(CityIsometricRenderer.surface_terrain_id(city,65,84) == 0x41)
	city.altitude_words[city.index_of(64,84)] = 7 | (7 << 5)
	assert(CityIsometricRenderer.surface_terrain_id(city,65,84) == 0x3e)
	assert(city.terrain[index] == 0x41, 'Rendering must preserve saved terrain')
	for shape in range(0x30,0x46):
		city.terrain[index] = shape
		assert(CityIsometricRenderer.surface_terrain_id(city,65,84) == 0x3e, 'All partial-water shapes must fill a sloped face')
	city.terrain[index] = 0x41
	for base in [0,500,1000]:
		assert(CityIsometricRenderer.terrain_sprite_id(CityIsometricRenderer.surface_terrain_id(city,65,84),true,base) == base+284)
	print('PASS: sloped stream uses waterfall at each native size; flat stream and stored terrain unchanged')
	quit()
