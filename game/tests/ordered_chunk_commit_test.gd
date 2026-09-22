extends SceneTree

const Commit = preload("res://src/model/city/ordered_chunk_commit.gd")
const IDS: PackedStringArray = ["XBLD", "ALTM", "XUND", "XTXT", "XBIT", "MISC"]


class ObservedChunk extends Sc2Chunk:
	var writes: Array[String] = []

	func set_decoded_payload(value: PackedByteArray, transfer_ownership := false) -> bool:
		writes.append(chunk_id)
		return super.set_decoded_payload(value, transfer_ownership)


func _initialize() -> void:
	for operation in [BuildingState._apply_payloads, LandscapeCommand._apply_payloads, Commit.apply]:
		_test_success(operation, 16)
		for failure in ["invalid_size", "missing_payload", "missing_chunk"]:
			_test_failure(operation, failure)
	_test_success(Commit.apply, 256)
	_test_commands()
	print("PASS: ordered chunk writes, rollback metadata, mirrors, cache invalidation, copy ownership and command undo/RNG")
	quit()


func _fixture(edge: int) -> CityState:
	var saved := EmptyCityTemplate.create(edge).serialize(true)
	assert(saved.ok)
	var document := Sc2File.new()
	assert(document.parse(saved.data))
	var city := CityState.from_document(document)
	assert(city.is_valid())
	return city


func _payloads(city: CityState) -> Dictionary[String, PackedByteArray]:
	var result: Dictionary[String, PackedByteArray] = {}
	for id in IDS:
		result[id] = city.document.find_chunk(id).decoded_payload.duplicate()
	return result


func _changes(city: CityState) -> Dictionary[String, PackedByteArray]:
	var result := _payloads(city)
	result.XBLD[1] = BuildingTileIds.TREES_2
	BinaryData.write_u16_be(result.ALTM, 2, 0x0123)
	result.XUND[1] = UndergroundTileIds.SUBWAY_LR
	OverlayData.write(result.XTXT, 1, 0x0101 if city.map_size > 128 else 1)
	result.XBIT[1] = Sc2TileFlags.WATER
	BinaryData.write_u32_be(result.MISC, Sc2MiscLayout.FUNDS, 1000)
	return result


func _observe(city: CityState, writes: Array[String]) -> void:
	for index in city.document.chunks.size():
		var original := city.document.chunks[index]
		if original.chunk_id not in IDS:
			continue
		var observed := ObservedChunk.new()
		observed.chunk_id = original.chunk_id
		observed.source_offset = original.source_offset
		observed.stored_payload = original.stored_payload.duplicate()
		observed.decoded_payload = original.decoded_payload.duplicate()
		observed.expected_decoded_size = original.expected_decoded_size
		observed.is_compressed = original.is_compressed
		observed.is_dirty = original.is_dirty
		observed.mutation_revision = original.mutation_revision
		observed.writes = writes
		city.document.chunks[index] = observed
	city.document.rebuild_chunk_cache()


func _bytes(city: CityState) -> PackedByteArray:
	var result := city.document.serialize(true)
	assert(result.ok)
	return result.data


func _check_mirrors(city: CityState) -> void:
	for pair in [["XBLD", city.buildings], ["XTER", city.terrain], ["XZON", city.zones],
		["XUND", city.underground], ["XTXT", city.text_overlays], ["XBIT", city.tile_flags]]:
		assert(pair[1] == city.document.find_chunk(pair[0]).decoded_payload)
	var altitude := city.document.find_chunk("ALTM").decoded_payload
	for index in city.altitude_words.size():
		assert(city.altitude_words[index] == BinaryData.read_u16_be(altitude, index * 2))
	for index in Sc2File.FULL_MAP_CHUNKS.size():
		assert(city.document.tile_chunk(index) == city.document.find_chunk(Sc2File.FULL_MAP_CHUNKS[index]))


func _test_success(operation: Callable, edge: int) -> void:
	var city := _fixture(edge)
	var writes: Array[String] = []
	_observe(city, writes)
	var original := _payloads(city)
	var changed := _changes(city)
	var before := _bytes(city)
	var signature := CityIsometricRenderer.static_visual_signature(city)
	var flags := city.masked_tile_flag_signature(Sc2TileFlags.WATER)
	assert(operation.call(city, IDS, changed, original))
	assert(PackedStringArray(writes) == IDS)
	for id in IDS:
		assert(city.document.find_chunk(id).decoded_payload == changed[id])
	_check_mirrors(city)
	assert(city.altitude_words[1] == 0x0123)
	assert(OverlayData.read(city.text_overlays, 1) == (0x0101 if edge > 128 else 1))
	assert(CityIsometricRenderer.static_visual_signature(city) != signature)
	assert(city.masked_tile_flag_signature(Sc2TileFlags.WATER) != flags)

	# Payloads and mirror arrays remain private after the commit.
	changed.XBLD[1] = BuildingTileIds.EMPTY
	assert(city.buildings[1] == BuildingTileIds.TREES_2)
	city.buildings[1] = BuildingTileIds.EMPTY
	assert(city.document.find_chunk("XBLD").decoded_payload[1] == BuildingTileIds.TREES_2)
	city.resync_mirrors(PackedStringArray(["XBLD"]))
	assert(operation.call(city, IDS, original, _payloads(city)))
	assert(_bytes(city) == before)
	_check_mirrors(city)
	assert(city.masked_tile_flag_signature(Sc2TileFlags.WATER) == flags)


func _test_failure(operation: Callable, failure: String) -> void:
	var city := _fixture(16)
	var writes: Array[String] = []
	_observe(city, writes)
	var original := _payloads(city)
	var changed := _changes(city)
	var before := _bytes(city)
	var signature := CityIsometricRenderer.static_visual_signature(city)
	var flags := city.masked_tile_flag_signature(Sc2TileFlags.WATER)
	var revisions := {}
	for id in IDS:
		var chunk := city.document.find_chunk(id)
		revisions[id] = chunk.mutation_revision
		assert(not chunk.is_dirty)
	var ordered := IDS.duplicate()
	match failure:
		"invalid_size":
			changed.MISC = PackedByteArray()
		"missing_payload":
			changed.erase("MISC")
		"missing_chunk":
			ordered[ordered.size() - 1] = "MISS"
	assert(not operation.call(city, ordered, changed, original))
	var expected := IDS.slice(0, IDS.size() - 1)
	if failure == "invalid_size":
		expected.append("MISC")
	expected.append_array(IDS.slice(0, IDS.size() - 1))
	assert(PackedStringArray(writes) == expected, "Rollback keeps the original forward order")
	for id in IDS:
		var chunk := city.document.find_chunk(id)
		assert(chunk.decoded_payload == original[id])
		assert(chunk.mutation_revision - int(revisions[id]) == (0 if id == "MISC" else 2))
		assert(chunk.is_dirty == (id != "MISC"))
	_check_mirrors(city)
	assert(_bytes(city) == before)
	assert(CityIsometricRenderer.static_visual_signature(city) != signature, "Rollback retains revision invalidation")
	assert(city.masked_tile_flag_signature(Sc2TileFlags.WATER) == flags, "Rollback restores cached flag content")


func _test_commands() -> void:
	var city := _fixture(128)
	var before := _bytes(city)
	var lfsr := SimLfsrRandom.new(123)
	var random := SimRandom.new(456)
	var building := BuildingCommand.apply(city, 13, 0, Vector2i(20, 20), lfsr, random)
	assert(building.ok)
	_check_mirrors(city)
	assert(BuildingCommand.undo(city, building, lfsr, random).ok)
	assert(_bytes(city) == before and lfsr.state == 123 and random.state == 456)
	_check_mirrors(city)
	var forest := LandscapeCommand.apply_path(city, 1, 3, [Vector2i(20, 20)], random)
	assert(forest.ok)
	_check_mirrors(city)
	assert(LandscapeCommand.undo(city, forest, random).ok)
	assert(_bytes(city) == before and random.state == 456)
	_check_mirrors(city)

	# A final MISC rejection exercises command-level RNG restoration.
	var misc := city.document.find_chunk("MISC")
	misc.expected_decoded_size += 1
	assert(not BuildingCommand.apply(city, 13, 0, Vector2i(20, 20), lfsr, random).ok)
	assert(lfsr.state == 123 and random.state == 456)
	_check_mirrors(city)
	assert(not LandscapeCommand.apply_path(city, 1, 3, [Vector2i(20, 20)], random).ok)
	assert(random.state == 456)
	_check_mirrors(city)
	misc.expected_decoded_size -= 1
	assert(_bytes(city) == before)
