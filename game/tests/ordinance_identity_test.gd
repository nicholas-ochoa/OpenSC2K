extends SceneTree


func _initialize() -> void:
	var city := CityState.from_document(EmptyCityTemplate.create(16))
	assert(city.document.set_misc_u32(0x0fa0, 0x80000000))
	var before := city.document.find_chunk("MISC").decoded_payload.duplicate()

	for ordinance: int in OrdinanceIds.Id.values():
		var result := OrdinanceCommand.set_enabled(city, ordinance, true)
		assert(result.ok and result.changed)
		assert(city.document.misc_u32(0x0fa0) == 0x80000000 | (1 << ordinance))
		var after := city.document.find_chunk("MISC").decoded_payload

		for offset in 4800:
			if offset not in range(0x0fa0, 0x0fa4) and offset not in range(0x08c0, 0x08c4):
				assert(after[offset] == before[offset], "Ordinance changes preserve unrelated MISC bytes")

		result = OrdinanceCommand.set_enabled(city, ordinance, false)
		assert(result.ok and result.changed)
		assert(city.document.misc_u32(0x0fa0) == 0x80000000)

	before = city.document.find_chunk("MISC").decoded_payload.duplicate()
	assert(not OrdinanceCommand.set_enabled(city, -1, true).ok)
	assert(not OrdinanceCommand.set_enabled(city, 20, true).ok)
	assert(city.document.find_chunk("MISC").decoded_payload == before)
	# the native demand rule has its own tax-rate unit test
	print("PASS: ordinance flags and unknown bits")
	quit()
