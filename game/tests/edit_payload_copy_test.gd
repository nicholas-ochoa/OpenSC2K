extends SceneTree
## Published snapshots survive later city edits and independent command copies.

func _initialize() -> void:
	for edge in [128, 256]:
		var city := CityState.from_document(EmptyCityTemplate.create(edge))
		var lfsr := SimLfsrRandom.new(456)
		var random := SimRandom.new(123)
		var before := city.document.serialize().data
		var command := BuildingCommand.apply(city, 14, 0, Vector2i(20, 20), lfsr, random)
		assert(command.ok)
		assert(command.old_payloads.size() == command.changed_ids.size())
		assert(command.new_payloads.size() == command.changed_ids.size())
		var copied := command.copy() as BuildingEditResult
		var saved := command.new_payloads.XBLD.duplicate()
		copied.new_payloads.XBLD = PackedByteArray([99])
		copied.tile_indices.append(7)
		assert(command.new_payloads.XBLD == saved, "Copy replaces its own snapshot entries")
		assert(copied.tile_indices.size() == command.tile_indices.size() + 1)
		assert(BuildingCommand.undo(city, command, lfsr, random).ok)
		assert(city.document.serialize().data == before, "Undo did not restore the saved bytes")
		command = BuildingCommand.apply(city, 14, 0, Vector2i(20, 20), lfsr, random)
		assert(command.ok)
		saved = command.new_payloads.XBLD.duplicate()
		city.set_building_id(25, 25, BuildingTileIds.RUBBLE_1)
		assert(command.new_payloads.XBLD == saved, "Later in-place writes cannot change history")
		assert(not BuildingCommand.undo(city, command, lfsr, random).ok,
			"Undo still rejects changes elsewhere in a recorded chunk")
	print("PASS: edit copy containers, retained snapshots, exact undo and conflict detection")
	quit()
