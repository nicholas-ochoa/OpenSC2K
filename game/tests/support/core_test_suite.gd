extends RefCounted

## Shared assertions, fixture data, and binary helpers for core suites.

@warning_ignore_start("integer_division")

const UnderTiles = preload("res://src/tools/shared/underground_tile_ids.gd")
const Tiles = preload("res://src/tools/shared/building_tile_ids.gd")
const CityModel = preload("res://src/model/city_state.gd")
const NewsQueue = preload("res://src/simulation/reports/news_queue.gd")
const DisasterMap = preload("res://src/simulation/disasters/map/constants.gd")

const CoreTestContext = preload("res://tests/support/core_test_context.gd")

var context: CoreTestContext


func _init(test_context: CoreTestContext) -> void:
	context = test_context


func _check(condition: bool, message: String) -> void:
	context.check(condition, message)


func _load_fixture(path: String) -> Sc2File:
	return context.load_fixture(path)


func _filled_bytes(size: int, value: int) -> PackedByteArray:
	var result := PackedByteArray()
	result.resize(size)
	result.fill(value)

	return result


func _write_u32_be(data: PackedByteArray, offset: int, value: int) -> void:
	data[offset] = (value >> 24) & 0xff
	data[offset + 1] = (value >> 16) & 0xff
	data[offset + 2] = (value >> 8) & 0xff
	data[offset + 3] = value & 0xff


func _files_with_extension(directory: String, extension: String) -> PackedStringArray:
	var paths := PackedStringArray()

	for filename in DirAccess.get_files_at(directory):
		if filename.get_extension().to_upper() == extension:
			paths.append(directory.path_join(filename))

	paths.sort()

	return paths


func _read_u32_le(data: PackedByteArray, offset: int) -> int:
	return (
		int(data[offset])
		| (int(data[offset + 1]) << 8)
		| (int(data[offset + 2]) << 16)
		| (int(data[offset + 3]) << 24)
	)


func _read_u16_le(data: PackedByteArray, offset: int) -> int:
	return int(data[offset]) | (int(data[offset + 1]) << 8)


func _load_pe_rva_bytes(path: String, rva: int, size: int) -> PackedByteArray:
	var data := FileAccess.get_file_as_bytes(path)

	if data.size() < 0x40 or _read_u16_le(data, 0) != 0x5a4d:
		return PackedByteArray()

	var pe_offset := _read_u32_le(data, 0x3c)

	if pe_offset < 0 or pe_offset > data.size() - 24:
		return PackedByteArray()

	var section_count := _read_u16_le(data, pe_offset + 6)
	var optional_size := _read_u16_le(data, pe_offset + 20)
	var section_offset := pe_offset + 24 + optional_size

	if section_offset < 0 or section_offset > data.size() - section_count * 40:
		return PackedByteArray()

	for section_index in section_count:
		var header := section_offset + section_index * 40
		var virtual_size := _read_u32_le(data, header + 8)
		var virtual_address := _read_u32_le(data, header + 12)
		var raw_size := _read_u32_le(data, header + 16)
		var raw_offset := _read_u32_le(data, header + 20)
		var mapped_size := maxi(virtual_size, raw_size)

		if rva < virtual_address or rva + size > virtual_address + mapped_size:
			continue

		var file_offset := raw_offset + rva - virtual_address

		if file_offset < 0 or file_offset > data.size() - size:
			return PackedByteArray()

		return data.slice(file_offset, file_offset + size)

	return PackedByteArray()


func _clear_news_records(document) -> bool:
	var misc_chunk = document.find_chunk("MISC")

	if misc_chunk == null or misc_chunk.decoded_payload.size() != NewsQueue.MISC_SIZE:
		return false

	var misc: PackedByteArray = misc_chunk.decoded_payload.duplicate()

	for slot in NewsQueue.STORY_RECORD_COUNT:
		var offset := NewsQueue.STORY_OFFSET + slot * NewsQueue.STORY_RECORD_SIZE
		_write_u32_be(misc, offset, 11 + slot)
		_write_u32_be(misc, offset + 4, 0)
		_write_u32_be(misc, offset + 8, 0)

		for field in range(3, NewsQueue.STORY_FIELD_COUNT):
			_write_u32_be(misc, offset + field * 4, 0xff)

	return misc_chunk.set_decoded_payload(misc)


func _fire_map_fixture(
	reference_root: String, point: Vector2i, tile: int, water := false
) -> Dictionary:
	var document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))
	var index := point.x * CityState.MAP_SIZE + point.y
	var buildings := _filled_bytes(CityState.TILE_COUNT, Tiles.EMPTY)
	var flags := _filled_bytes(CityState.TILE_COUNT, 0)
	var text := _filled_bytes(CityState.TILE_COUNT, 0)
	buildings[index] = tile
	flags[index] = 0x04 if water else 0
	text[index] = DisasterMap.FIRE_OVERLAY

	for entry in [
		["XBLD", buildings],
		["XZON", _filled_bytes(CityState.TILE_COUNT, 0)],
		["XUND", _filled_bytes(CityState.TILE_COUNT, UnderTiles.EMPTY)],
		["XBIT", flags],
		["XTXT", text],
		["XTER", _filled_bytes(CityState.TILE_COUNT, 0)],
		["XTRF", _filled_bytes(64 * 64, 0)],
		["XFIR", _filled_bytes(32 * 32, 0)],
		["XTHG", _filled_bytes(CityState.THING_COUNT * CityState.THING_RECORD_SIZE, 0)],
	]:
		if not document.find_chunk(entry[0]).set_decoded_payload(entry[1]):
			return {"document": document, "city": null}

	document.set_misc_u32(0x01f0, CityState.TILE_COUNT - int(tile != 0))

	if tile != 0:
		document.set_misc_u32(0x01f0 + tile * 4, 1)

	return {"document": document, "city": CityModel.from_document(document)}


func _special_growth_fixture(reference_root: String) -> Dictionary:
	var document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))

	for entry in [
		["XBLD", _filled_bytes(128 * 128, Tiles.EMPTY)],
		["XZON", _filled_bytes(128 * 128, 0)],
		["XUND", _filled_bytes(128 * 128, UnderTiles.EMPTY)],
		["XTXT", _filled_bytes(128 * 128, 0)],
		["XBIT", _filled_bytes(128 * 128, 0)],
		["XTER", _filled_bytes(128 * 128, 0)],
		["XTRF", _filled_bytes(64 * 64, 0)],
		["XPLT", _filled_bytes(64 * 64, 0)],
		["XVAL", _filled_bytes(64 * 64, 0)],
		["XCRM", _filled_bytes(64 * 64, 0)],
		["XMIC", _filled_bytes(150 * 8, 0)],
		["XTHG", _filled_bytes(40 * 12, 0)],
	]:
		_check(
			document.find_chunk(entry[0]).set_decoded_payload(entry[1]),
			"Special growth fixture sets %s" % entry[0],
		)

	for tile in 256:
		_check(document.set_misc_u32(0x01f0 + tile * 4, 0), "Special growth fixture clears tile count")

	_check(document.set_misc_u32(0x01f0, 16384), "Special growth fixture counts clear tiles")

	for military_index in 16:
		_check(
			document.set_misc_u32(0x0fa8 + military_index * 4, 0),
			"Special growth fixture clears military tile count",
		)

	for budget_index in range(10, 16):
		_check(
			document.set_misc_i32(0x077c + budget_index * 0x6c + 4, 100),
			"Special growth fixture fully funds transport",
		)

	_check(document.set_misc_u32(0x0008, 0), "Special growth fixture sets compass rotation")
	_check(document.set_misc_u32(0x0e4c, 0), "Special growth fixture clears military base type")
	_check(document.set_misc_u32(0x0fe8, 0), "Special growth fixture clears the subway count")

	return {"document": document, "city": CityModel.from_document(document)}


func _set_airplane(
	fixture: Dictionary,
	record: int,
	point: Vector2i,
	target: Vector2i,
	direction: int,
	state: int,
	height: int
) -> void:
	var things: PackedByteArray = fixture.document.find_chunk("XTHG").decoded_payload.duplicate()
	var offset := record * 12
	things[offset] = 1
	things[offset + 1] = direction
	things[offset + 2] = state
	things[offset + 3] = point.x
	things[offset + 4] = point.y
	things[offset + 5] = height
	things[offset + 6] = 8
	things[offset + 7] = 8
	things[offset + 8] = target.x
	things[offset + 9] = target.y
	things[offset + 10] = fixture.city.text_overlay_id(point.x, point.y)
	_check(fixture.document.find_chunk("XTHG").set_decoded_payload(things), "Airplane fixture stores its XTHG record")
	_check(fixture.city.set_text_overlay_id(point.x, point.y, record + 201), "Airplane fixture links its XTXT record")
