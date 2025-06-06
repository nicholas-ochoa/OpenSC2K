class_name CityState
extends RefCounted

const MAP_SIZE := 128
const TILE_COUNT := MAP_SIZE * MAP_SIZE

var document: Sc2File
var load_error := ""

var altitude_words := PackedInt32Array()
var terrain := PackedByteArray()
var buildings := PackedByteArray()
var zones := PackedByteArray()
var underground := PackedByteArray()
var text_overlays := PackedByteArray()
var tile_flags := PackedByteArray()


static func from_document(source: Sc2File) -> CityState:
	var city := CityState.new()
	city.document = source
	if source == null or not source.is_valid():
		city.load_error = "The source document is not valid"
		return city

	var required_chunks := ["ALTM", "XTER", "XBLD", "XZON", "XUND", "XTXT", "XBIT"]
	for chunk_id in required_chunks:
		if source.find_chunk(chunk_id) == null:
			city.load_error = "Required chunk %s is missing" % chunk_id
			return city

	city.altitude_words.resize(TILE_COUNT)
	var altitude_data := source.find_chunk("ALTM").decoded_payload
	for index in TILE_COUNT:
		var byte_offset := index * 2
		city.altitude_words[index] = (
			(altitude_data[byte_offset] << 8) | altitude_data[byte_offset + 1]
		)

	city.terrain = source.find_chunk("XTER").decoded_payload.duplicate()
	city.buildings = source.find_chunk("XBLD").decoded_payload.duplicate()
	city.zones = source.find_chunk("XZON").decoded_payload.duplicate()
	city.underground = source.find_chunk("XUND").decoded_payload.duplicate()
	city.text_overlays = source.find_chunk("XTXT").decoded_payload.duplicate()
	city.tile_flags = source.find_chunk("XBIT").decoded_payload.duplicate()
	return city


func is_valid() -> bool:
	return load_error.is_empty()


func index_of(x: int, y: int) -> int:
	if x < 0 or x >= MAP_SIZE or y < 0 or y >= MAP_SIZE:
		return -1
	return x * MAP_SIZE + y


func land_altitude(x: int, y: int) -> int:
	var index := index_of(x, y)
	return 0 if index < 0 else altitude_words[index] & 0x1f


func water_altitude(x: int, y: int) -> int:
	var index := index_of(x, y)
	return 0 if index < 0 else (altitude_words[index] >> 5) & 0x1f


func tunnel_levels(x: int, y: int) -> int:
	var index := index_of(x, y)
	return 0 if index < 0 else (altitude_words[index] >> 10) & 0x3f


func terrain_id(x: int, y: int) -> int:
	return _byte_at(terrain, x, y)


func building_id(x: int, y: int) -> int:
	return _byte_at(buildings, x, y)


func zone_id(x: int, y: int) -> int:
	return _byte_at(zones, x, y) & 0x0f


func building_corners(x: int, y: int) -> int:
	return _byte_at(zones, x, y) & 0xf0


func underground_id(x: int, y: int) -> int:
	return _byte_at(underground, x, y)


func text_overlay_id(x: int, y: int) -> int:
	return _byte_at(text_overlays, x, y)


func is_salt_water(x: int, y: int) -> bool:
	return (_byte_at(tile_flags, x, y) & 0x01) != 0


func is_flipped(x: int, y: int) -> bool:
	return (_byte_at(tile_flags, x, y) & 0x02) != 0


func is_water(x: int, y: int) -> bool:
	return (_byte_at(tile_flags, x, y) & 0x04) != 0


func is_watered(x: int, y: int) -> bool:
	return (_byte_at(tile_flags, x, y) & 0x10) != 0


func is_piped(x: int, y: int) -> bool:
	return (_byte_at(tile_flags, x, y) & 0x20) != 0


func is_powered(x: int, y: int) -> bool:
	return (_byte_at(tile_flags, x, y) & 0x40) != 0


func is_powerable(x: int, y: int) -> bool:
	return (_byte_at(tile_flags, x, y) & 0x80) != 0


func city_name() -> String:
	return document.city_name()


func mayor_name() -> String:
	var labels := document.find_chunk("XLAB")
	if labels == null or labels.decoded_payload.size() < 25:
		return ""
	var declared_length: int = mini(labels.decoded_payload[0], 23)
	var end := 1
	while end < 1 + declared_length and labels.decoded_payload[end] != 0:
		end += 1
	return labels.decoded_payload.slice(1, end).get_string_from_ascii()


func funds() -> int:
	return document.misc_i32(0x14)


func set_funds(value: int) -> bool:
	return document.set_misc_i32(0x14, value)


func founding_year() -> int:
	return document.misc_u32(0x0c)


func age_in_days() -> int:
	return document.misc_u32(0x10)


func set_age_in_days(value: int) -> bool:
	if value < 0:
		return false
	return document.set_misc_u32(0x10, value)


func current_year() -> int:
	return founding_year() + int(age_in_days() / 300)


func current_month() -> int:
	return int(age_in_days() % 300 / 25) + 1


func current_day() -> int:
	return age_in_days() % 25 + 1


func population() -> int:
	return document.misc_u32(0x1020) + document.misc_u32(0x102c)


func rci_demand() -> Vector3i:
	return Vector3i(
		document.misc_i32(0x0718),
		document.misc_i32(0x071c),
		document.misc_i32(0x0720)
	)


func _byte_at(data: PackedByteArray, x: int, y: int) -> int:
	var index := index_of(x, y)
	return 0 if index < 0 else data[index]
