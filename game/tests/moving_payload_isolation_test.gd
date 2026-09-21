extends SceneTree
## Tick preparation stays private until commit, including lazy disaster writes.

func _initialize() -> void:
	for edge in [128, 256]:
		for kind in [9, 6]:
			var city := CityState.from_document(EmptyCityTemplate.create(edge))
			city.set_building_id(10, 10, BuildingTileIds.RUBBLE_1)
			city.set_tile_flag(10, 10, 4, true)
			var things := city.document.find_chunk("XTHG").decoded_payload.duplicate()
			for pair in [[0, kind], [1, 2 if kind == 6 else 0], [3, 10], [4, 10], [6, 8], [7, 8]]:
				ThingData.write(things, 12 + pair[0], pair[1])
			assert(city.document.find_chunk("XTHG").set_decoded_payload(things))
			var original: Dictionary[String, PackedByteArray] = {}
			for chunk in city.document.chunks:
				original[chunk.chunk_id] = chunk.decoded_payload.duplicate()
			var tick := MovingThingPhase.TickContext.new(SimRandom.new(123), SimLfsrRandom.new(456),
				GameLcgRandom.new(789), Vector2i(-1, -1), true, false)
			assert(tick.load_payloads(city))
			tick.update_records(MovingThingResult.new())
			for chunk in city.document.chunks:
				assert(chunk.decoded_payload == original[chunk.chunk_id], "Preparation cannot modify the document")
			if kind == 6:
				assert(tick.buildings[10 * edge + 10] == 0, "Explosion changes its private map")
			assert(tick.commit_payloads().is_empty())
			assert(city.buildings == city.document.find_chunk("XBLD").decoded_payload)
			assert(city.text_overlays == city.document.find_chunk("XTXT").decoded_payload)
		var city := CityState.from_document(EmptyCityTemplate.create(edge))
		var tick := MovingThingPhase.TickContext.new(SimRandom.new(1), SimLfsrRandom.new(2),
			GameLcgRandom.new(3), Vector2i(-1, -1), true, false)
		assert(tick.load_payloads(city))
		var before := city.document.find_chunk("XTHG").decoded_payload.duplicate()
		tick.things[12] = 9
		tick.text[0] = 1
		city.document.find_chunk("XTXT").expected_decoded_size += 1
		assert(tick.commit_payloads() == "XTXT")
		assert(city.document.find_chunk("XTHG").decoded_payload == before, "Failed commit rolls back earlier chunks")
	print("PASS: moving-object preparation isolation, disaster writes, mirrors and rollback")
	quit()
