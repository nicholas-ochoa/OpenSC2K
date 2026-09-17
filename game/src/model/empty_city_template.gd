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
		0x0000: 0x122, 0x0004: 1, 0x000c: 1900, 0x0014: 20000, 0x001c: 1,
		0x0050: 10000, 0x0054: 3000, 0x0058: 3,
		0x0060: 150, 0x0064: 10, 0x0068: 15, 0x006c: 4,
		0x01f0: (map_edge * map_edge),
		0x0fec: 2, 0x0ff4: 1, 0x0ff8: 1, 0x0ffc: 1,
	}

	for offset in values:
		document.set_misc_u32(offset, values[offset])

	for industry in 11:
		document.set_misc_u32(0x0170 + industry * 12, 7)

	for budget in 16:
		var funding := 7 if budget < 3 else (1 if budget == 3 else (0 if budget == 4 else 100))
		document.set_misc_u32(0x077c + budget * 0x6c + 4, funding)

	for neighbor in 4:
		document.set_misc_u32(0x06d8 + neighbor * 16, neighbor)
		document.set_misc_u32(0x06dc + neighbor * 16, 1000)
		document.set_misc_u32(0x06e0 + neighbor * 16, 1000)

	document.set_city_name("New City")
	document.resize_empty_map(map_edge)

	return document
