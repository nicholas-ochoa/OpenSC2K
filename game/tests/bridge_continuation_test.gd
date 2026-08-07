extends SceneTree
const DocumentState = preload("res://tests/support/document_state.gd")


func _initialize() -> void:
	var sprites := Sc2SpriteArchive.load_path("res://../references/SIMCITY2000/DATA/LARGE.DAT")
	var palette := Sc2Palette.index_encoding()
	for edge: int in [128, 256, 384, 512]:
		for group in [6, 7, 3]:
			var city := _fixture(edge, false)
			var base := edge - 24
			var before: Array = DocumentState.capture(city.document)
			var preview_city := CityState.copy_for_edit(city)
			var command := NetworkCommand.apply(city, group, 0, Vector2i(base, 20), Vector2i(base + 12, 20), NetworkCommand.BRIDGE_ROAD_CAUSEWAY if group == 6 else -1)
			assert(command.ok and command.bridge_built)
			assert(command.dry_points.size() == 9)

			for x in range(base, base + 13):
				assert(city.building_id(x, 20) != 0, "Network continues across the bridge to the endpoint")

			assert(city.funds() == 20000 - command.cost)
			var artwork := NetworkPlacementPreview.build({"city": preview_city, "group": group, "tool": 0, "start": Vector2i(base, 20), "finish": Vector2i(base + 12, 20), "view": 2, "palette": palette, "sprites": sprites, "underground": false})
			assert(not artwork.draws.is_empty() and preview_city.building_id(base + 12, 20) != 0)
			assert(DocumentState.capture(preview_city.document) == DocumentState.capture(city.document), "Bridge preview matches the complete placed route")
			assert(NetworkCommand.undo(city, command).ok)
			assert(DocumentState.capture(city.document) == before, "One Undo restores both banks and the bridge")

		for bridge in [HighwayCommand.BRIDGE_HIGHWAY, HighwayCommand.BRIDGE_REINFORCED]:
			var city := _fixture(edge, true)
			var base := edge - 24
			var before: Array = DocumentState.capture(city.document)
			var command := HighwayCommand.apply(city, 6, 1, Vector2i(base, 20), Vector2i(base + 14, 20), -1, bridge)
			assert(command.ok and command.bridge_built)

			for x in range(base, base + 16):
				assert(city.building_id(x, 20) != 0, "Highway continues from the far bank")

			assert(city.funds() == 20000 - command.cost)
			assert(HighwayCommand.undo(city, command).ok)
			assert(DocumentState.capture(city.document) == before)
			var proposal := HighwayCommand.apply(city, 6, 1, Vector2i(base, 20), Vector2i(edge - 2, 20), -1, bridge)
			assert(proposal.connection_selection_required)
			assert(DocumentState.capture(city.document) == before, "Connection prompt committed earlier route segments")
			var connected := HighwayCommand.apply(city, 6, 1, Vector2i(base, 20), Vector2i(edge - 2, 20), 1, bridge)
			assert(connected.ok and connected.connection_built)
			assert(HighwayCommand.undo(city, connected).ok)
			assert(DocumentState.capture(city.document) == before)

		var city := _fixture(edge, false)
		var base := edge - 24

		for x in range(base + 12, base + 16):
			assert(city.set_land_altitude(x, 20, 4))
			assert(city.set_tile_flag(x, 20, 4, true))
			assert(city.set_terrain_id(x, 20, 0x21 if x == base + 12 else 0x10))

		var before: Array = DocumentState.capture(city.document)
		var multi := NetworkCommand.apply(city, 6, 0, Vector2i(base, 20), Vector2i(base + 20, 20), NetworkCommand.BRIDGE_ROAD_CAUSEWAY)
		assert(multi.ok and multi.bridge_count == 2 and city.building_id(base + 20, 20) != 0)
		assert(NetworkCommand.undo(city, multi).ok and DocumentState.capture(city.document) == before)
		assert(city.set_funds(140))
		var limited := NetworkCommand.apply(city, 6, 0, Vector2i(base, 20), Vector2i(base + 20, 20), NetworkCommand.BRIDGE_ROAD_CAUSEWAY)
		assert(limited.ok and limited.cost == 140 and city.funds() == 0)
		assert(city.building_id(base + 8, 20) == 0 and not limited.continuation_error.is_empty())
		assert(NetworkCommand.undo(city, limited).ok)
		assert(city.set_funds(0))
		var free_route := NetworkCommand.apply(city, 6, 0, Vector2i(base, 20), Vector2i(base + 20, 20), NetworkCommand.BRIDGE_ROAD_CAUSEWAY, -1, true)
		assert(free_route.ok and free_route.cost == 0 and free_route.bridge_count == 2)
		assert(NetworkCommand.undo(city, free_route).ok)
	print("PASS: bridge continuation, costs, deferred connections and one-step Undo at all map sizes")
	quit()


func _fixture(edge: int, highway: bool) -> CityState:
	var city := CityState.from_document(EmptyCityTemplate.create(edge))
	assert(city.set_funds(20000))
	var base := edge - 24
	var far_bank := base + (10 if highway else 8)

	for x in range(base, edge):
		for y in range(20, 22 if highway else 21):
			var water := x >= base + 4 and x < far_bank
			assert(city.set_land_altitude(x, y, 4 if water else 6))
			assert(city.set_water_altitude(x, y, 5))
			assert(city.set_tile_flag(x, y, 4, water))
			assert(city.set_terrain_id(x, y, (0x10 if highway or x != base + 4 else 0x21) if water else 0))

	return city
