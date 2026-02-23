extends SceneTree


func _initialize() -> void:
	var doc := Sc2File.load_path(ProjectSettings.globalize_path('res://../references/SIMCITY2000/DEFAULT.SC2'))
	assert(NewCityTerrain.generate(doc, false, false, 0, 0, 0, SimRandom.new(1), GameLcgRandom.new(1)).ok)
	doc.set_misc_u32(0x0e40, 0)
	var payloads := {}

	for id in ['ALTM','XBLD','XTER','XZON','XBIT','XTXT','MISC']:
		payloads[id] = doc.find_chunk(id).decoded_payload.duplicate()

	var indices := PackedInt32Array()

	for index in CityState.TILE_COUNT:
		indices.append(index)
		TerrainCommand._set_land_altitude(payloads.ALTM, index, maxi(0, 16 - (index / 128) / 4))

	TerrainCommand._retile_region(payloads.ALTM,payloads.XBLD,payloads.XTER,payloads.XZON,payloads.XBIT,payloads.MISC,indices,0)

	for id in payloads:
		doc.find_chunk(id).set_decoded_payload(payloads[id])

	var city := CityState.from_document(doc)
	var before: PackedByteArray = doc.serialize().data
	var rng := SimRandom.new(22)
	var result := LandscapeEditorCommand.apply(city,1,2,Vector2i(40,64),rng)
	assert(result.ok)
	assert(city.terrain_id(40,64) == 0x3e, 'Stream tool must save a waterfall on the descending slope')

	for index in CityState.TILE_COUNT:
		if not city.tile_flags[index] & 4:
			continue

		var point := Vector2i(index / 128,index % 128)

		if CityIsometricRenderer.surface_terrain_id(city,point.x,point.y) == 0x3e:
			assert(city.terrain[index] == 0x3e, 'Edited slope still needs display repair')

	assert(TerrainCommand.undo(city,result,rng).ok)
	assert(doc.serialize().data == before and rng.state == 22)
	print('PASS: editor stream stores waterfall faces and exact Undo restores terrain and RNG')
	quit()
