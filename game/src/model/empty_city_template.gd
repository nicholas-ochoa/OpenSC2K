class_name EmptyCityTemplate
extends RefCounted



static func create(map_edge: int = 128) -> Sc2File:
	var document := Sc2File.new()

	for id in Sc2File.DECODED_SIZES:
		var chunk := Sc2Chunk.new()
		chunk.chunk_id = id
		chunk.expected_decoded_size = Sc2File.DECODED_SIZES[id]
		chunk.is_compressed = not Sc2File.RAW_CHUNKS.has(id)
		var bytes := PackedByteArray()
		bytes.resize(chunk.expected_decoded_size)
		bytes.fill(0)
		chunk.set_decoded_payload(bytes, true)
		document.chunks.append(chunk)

	document.rebuild_chunk_cache()

	# independent starting policy. newcitysetup supplies difficulty/year values
	var values := {
		0x0000: 0x122, Sc2MiscLayout.CITY_MODE: 1, Sc2MiscLayout.START_YEAR: 1900, Sc2MiscLayout.FUNDS: 20000, Sc2MiscLayout.DIFFICULTY: 1,
		Sc2MiscLayout.NATIONAL_POPULATION: 10000, Sc2MiscLayout.NATIONAL_VALUE: 3000, Sc2MiscLayout.NATIONAL_FEDERAL_RATE: 3,
		Sc2MiscLayout.WEATHER_HEAT: 150, Sc2MiscLayout.WEATHER_WIND: 10, Sc2MiscLayout.WEATHER_RAIN: 15, Sc2MiscLayout.WEATHER_TREND: 4,
		Sc2MiscLayout.TILE_COUNTS: (map_edge * map_edge),
		Sc2MiscLayout.SIMULATION_SPEED: 2, Sc2MiscLayout.AUTO_GOTO: 1, Sc2MiscLayout.SOUND: 1, Sc2MiscLayout.MUSIC: 1,
	}

	for offset in values:
		document.set_misc_u32(offset, values[offset])

	for industry in Sc2IndustryLayout.COUNT:
		document.set_misc_u32(Sc2MiscLayout.INDUSTRIES + industry * Sc2IndustryLayout.RECORD_SIZE + Sc2IndustryLayout.TAX_RATE, 7)

	for budget in Sc2BudgetLayout.COUNT:
		var funding := 7 if budget < 3 else (1 if budget == 3 else (0 if budget == 4 else 100))
		document.set_misc_u32(Sc2MiscLayout.BUDGETS + budget * Sc2BudgetLayout.RECORD_SIZE + Sc2BudgetLayout.FUNDING, funding)

	for neighbor in 4:
		document.set_misc_u32(Sc2MiscLayout.NEIGHBORS + neighbor * 16, neighbor)
		document.set_misc_u32(0x06dc + neighbor * 16, 1000)
		document.set_misc_u32(0x06e0 + neighbor * 16, 1000)

	document.set_city_name("New City")
	document.resize_empty_map(map_edge)

	return document
