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
	var deltas := [{1: 1, 14: -1}, {0: 1, 12: -1, 15: -1, 18: -1}, {13: -1, 19: 1}]
	var flag_cases: Array[int] = [0, 0xfffff, 0x80000000, 0x854003]

	for bit in 20:
		flag_cases.append(1 << bit)

	for category in 3:
		for rate: int in [0, 7, 20]:
			for flags in flag_cases:
				var expected := rate

				for bit: int in deltas[category]:
					if flags & (1 << bit):
						expected += int(deltas[category][bit])

				assert(RciDemandPhase._ordinance_adjusted_tax_rate(category, rate, flags) == maxi(expected, 0))

	print("PASS: ordinance flags, unknown bits and demand effects")
	quit()
