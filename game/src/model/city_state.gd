class_name CityState
extends RefCounted

const MAP_SIZE := 128
const TILE_COUNT := MAP_SIZE * MAP_SIZE
const COARSE_MAP_SIZE := 64
const LABEL_COUNT := 256
const LABEL_RECORD_SIZE := 25
const MICROSIM_COUNT := 150
const MICROSIM_RECORD_SIZE := 8
const THING_COUNT := 40
const THING_RECORD_SIZE := 12
const GRAPH_COUNT := 16
const GRAPH_VALUE_COUNT := 52
const MISC_AUTO_BUDGET_OPTION := 0x0ff0
const MISC_AUTO_GOTO_OPTION := 0x0ff4
const MISC_SOUND_OPTION := 0x0ff8
const MISC_MUSIC_OPTION := 0x0ffc
const MISC_NO_DISASTERS_OPTION := 0x1000

# scurk artwork outside xbld is kept only for this workspace session
var scurk_artwork_stamps: Array[Dictionary] = []
var map_size := 128
var simulation_slice: SimulationSliceBudget
var document: Sc2File
var load_error := ""

var altitude_words := PackedInt32Array()
var terrain := PackedByteArray()
var buildings := PackedByteArray()
var zones := PackedByteArray()
var underground := PackedByteArray()
var text_overlays := PackedByteArray()
var tile_flags := PackedByteArray()
# display-only copies can keep objects at the former water surface while they
# draw the terrain as dry land. this array is never written to an sc2 chunk
var visible_altitude_levels := 32 # display only; never serialized
var object_altitude_overrides := PackedInt32Array()
var _masked_tile_flag_signatures: Dictionary = {}


static func from_document(source: Sc2File) -> CityState:
	var city := CityState.new()

	if source != null and source.is_valid():
		source.upgrade_large_limits()

	city.document = source
	city.map_size = source.map_size if source != null else 128

	if source == null or not source.is_valid():
		city.load_error = "The source document is not valid"

		return city

	var required_chunks := ["ALTM", "XTER", "XBLD", "XZON", "XUND", "XTXT", "XBIT"]

	for chunk_id in required_chunks:
		if source.find_chunk(chunk_id) == null:
			city.load_error = "Required chunk %s is missing" % chunk_id

			return city

	city.altitude_words.resize((city.map_size * city.map_size))
	var altitude_data := source.find_chunk("ALTM").decoded_payload
	var overlay_data := source.find_chunk("XTXT").decoded_payload

	for index in (city.map_size * city.map_size):
		if city.map_size > 128 and not OverlayData.valid_id(OverlayData.read(overlay_data, index), city.map_size):
			city.load_error = "Extended tile link exceeds the city record capacity"

			return city

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
	if x < 0 or x >= map_size or y < 0 or y >= map_size:
		return -1

	return x * map_size + y


func land_altitude(x: int, y: int) -> int:
	var index := index_of(x, y)

	return 0 if index < 0 else altitude_words[index] & 0x1f


func water_altitude(x: int, y: int) -> int:
	var index := index_of(x, y)

	return 0 if index < 0 else (altitude_words[index] >> 5) & 0x1f


func object_altitude(x: int, y: int) -> int:
	var index := index_of(x, y)

	if index < 0:
		return 0

	if (
		object_altitude_overrides.size() == (map_size * map_size)
		and object_altitude_overrides[index] >= 0
	):
		return object_altitude_overrides[index]

	return water_altitude(x, y) if is_water(x, y) else land_altitude(x, y)


func tunnel_levels(x: int, y: int) -> int:
	var index := index_of(x, y)

	return 0 if index < 0 else (altitude_words[index] >> 10) & 0x3f


func terrain_id(x: int, y: int) -> int:
	return _byte_at(terrain, x, y)


func set_terrain_id(x: int, y: int, value: int) -> bool:
	if value < 0 or value > 0xff:
		return false

	var changed := terrain.duplicate()

	if not _set_byte_at(changed, x, y, value):
		return false

	if not document.find_chunk("XTER").set_decoded_payload(changed):
		return false

	terrain = changed

	return true


func building_id(x: int, y: int) -> int:
	return _byte_at(buildings, x, y)


func set_building_id(x: int, y: int, value: int) -> bool:
	if value < 0 or value > 0xff:
		return false

	var changed := buildings.duplicate()

	if not _set_byte_at(changed, x, y, value):
		return false

	if not document.find_chunk("XBLD").set_decoded_payload(changed):
		return false

	buildings = changed

	return true


func replace_buildings(value: PackedByteArray) -> bool:
	if value.size() != (map_size * map_size):
		return false

	var chunk := document.find_chunk("XBLD")

	if chunk == null or not chunk.set_decoded_payload(value):
		return false

	buildings = value.duplicate()

	return true


func zone_id(x: int, y: int) -> int:
	return _byte_at(zones, x, y) & 0x0f


func set_zone_id(x: int, y: int, value: int) -> bool:
	if value < 0 or value > 0x0f:
		return false

	var index := index_of(x, y)

	if index < 0:
		return false

	var changed := zones.duplicate()
	changed[index] = (changed[index] & 0xf0) | value

	if not document.find_chunk("XZON").set_decoded_payload(changed):
		return false

	zones = changed

	return true


func set_building_corners(x: int, y: int, value: int) -> bool:
	if value < 0 or value > 0xf0 or value & 0x0f:
		return false

	var index := index_of(x, y)

	if index < 0:
		return false

	var changed := zones.duplicate()
	changed[index] = value | (changed[index] & 0x0f)

	if not document.find_chunk("XZON").set_decoded_payload(changed):
		return false

	zones = changed

	return true


func replace_zones(value: PackedByteArray) -> bool:
	if value.size() != (map_size * map_size):
		return false

	var chunk := document.find_chunk("XZON")

	if chunk == null or not chunk.set_decoded_payload(value):
		return false

	zones = value.duplicate()

	return true


func building_corners(x: int, y: int) -> int:
	return _byte_at(zones, x, y) & 0xf0


func underground_id(x: int, y: int) -> int:
	return _byte_at(underground, x, y)


func set_underground_id(x: int, y: int, value: int) -> bool:
	if value < 0 or value > 0xff:
		return false

	var changed := underground.duplicate()

	if not _set_byte_at(changed, x, y, value):
		return false

	if not document.find_chunk("XUND").set_decoded_payload(changed):
		return false

	underground = changed

	return true


func text_overlay_id(x: int, y: int) -> int:
	var index := index_of(x, y)

	return 0 if index < 0 else OverlayData.read(text_overlays, index)


func set_text_overlay_id(x: int, y: int, value: int) -> bool:
	if value < 0 or value > (0xff if map_size == 128 else 0xffff):
		return false

	var changed := text_overlays.duplicate()
	var index := index_of(x, y)

	if index < 0:
		return false

	OverlayData.write(changed, index, value)

	if not document.find_chunk("XTXT").set_decoded_payload(changed):
		return false

	text_overlays = changed

	return true


func replace_text_overlays(value: PackedByteArray) -> bool:
	if value.size() != document.decoded_size("XTXT"):
		return false

	var chunk := document.find_chunk("XTXT")

	if chunk == null or not chunk.set_decoded_payload(value):
		return false

	text_overlays = value.duplicate()

	return true


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


func traffic_density(x: int, y: int) -> int:
	var index := index_of(x, y)

	if index < 0:
		return 0

	var chunk := document.find_chunk("XTRF")

	if chunk == null or chunk.decoded_payload.size() != document.decoded_size("XTRF"):
		return 0

	return chunk.decoded_payload[CityDataGrid.index(chunk.decoded_payload, map_size, x, y)]


func set_tile_flag(x: int, y: int, mask: int, enabled: bool) -> bool:
	if mask < 0 or mask > 0xff:
		return false

	var index := index_of(x, y)

	if index < 0:
		return false

	var changed := tile_flags.duplicate()

	if enabled:
		changed[index] |= mask
	else:
		changed[index] &= ~mask & 0xff

	if not document.find_chunk("XBIT").set_decoded_payload(changed):
		return false

	tile_flags = changed

	return true


func replace_tile_flags(value: PackedByteArray) -> bool:
	if value.size() != (map_size * map_size):
		return false

	var chunk := document.find_chunk("XBIT")

	if chunk == null or not chunk.set_decoded_payload(value):
		return false

	tile_flags = value.duplicate()

	return true


func masked_tile_flag_signature(mask: int) -> int:
	var byte_mask := mask & 0xff
	var source_signature := hash(tile_flags)
	var cached: Dictionary = _masked_tile_flag_signatures.get(byte_mask, {})

	if (
		cached.get("source") == source_signature
		and cached.get("size") == tile_flags.size()
	):
		return int(cached.get("value", 0))

	var visible_flags := PackedByteArray()
	visible_flags.resize(tile_flags.size())
	var word_mask := 0

	for lane in 8:
		word_mask |= byte_mask << (lane * 8)

	var full_bytes := tile_flags.size() - tile_flags.size() % 8

	for offset in range(0, full_bytes, 8):
		visible_flags.encode_u64(offset, tile_flags.decode_u64(offset) & word_mask)

	for index in range(full_bytes, tile_flags.size()):
		visible_flags[index] = tile_flags[index] & byte_mask

	var value := hash(visible_flags)
	_masked_tile_flag_signatures[byte_mask] = {
		"source": source_signature,
		"size": tile_flags.size(),
		"value": value,
	}

	return value


func set_land_altitude(x: int, y: int, value: int) -> bool:
	if value < 0 or value > 0x1f:
		return false

	var index := index_of(x, y)

	if index < 0:
		return false

	return _set_altitude_word(x, y, (altitude_words[index] & ~0x1f) | value)


func set_water_altitude(x: int, y: int, value: int) -> bool:
	if value < 0 or value > 0x1f:
		return false

	var index := index_of(x, y)

	if index < 0:
		return false

	return _set_altitude_word(x, y, (altitude_words[index] & ~0x3e0) | (value << 5))


func set_tunnel_levels(x: int, y: int, value: int) -> bool:
	if value < 0 or value > 0x3f:
		return false

	var index := index_of(x, y)

	if index < 0:
		return false

	return _set_altitude_word(x, y, (altitude_words[index] & ~0xfc00) | (value << 10))


func city_name() -> String:
	return document.city_name()


func display_name() -> String:
	var name := city_name()

	if name.is_empty():
		name = document.source_path.get_file().get_basename()

	return name if not name.is_empty() else "New City"


func mayor_name() -> String:
	return label(0)


func label(label_id: int) -> String:
	if label_id < 0 or label_id >= IntegerMath.div_trunc(document.decoded_size("XLAB"), LABEL_RECORD_SIZE):
		return ""

	var chunk := document.find_chunk("XLAB")

	if chunk == null:
		return ""

	var offset := label_id * LABEL_RECORD_SIZE
	var declared_length: int = mini(chunk.decoded_payload[offset], 23)
	var start := offset + 1
	var end := start

	while end < start + declared_length and chunk.decoded_payload[end] != 0:
		end += 1

	return chunk.decoded_payload.slice(start, end).get_string_from_ascii()


func set_label(label_id: int, value: String) -> bool:
	if label_id < 0 or label_id >= IntegerMath.div_trunc(document.decoded_size("XLAB"), LABEL_RECORD_SIZE):
		return false

	var chunk := document.find_chunk("XLAB")

	if chunk == null:
		return false

	var encoded := value.to_ascii_buffer()

	if encoded.size() > 23:
		encoded = encoded.slice(0, 23)

	var changed := chunk.decoded_payload.duplicate()
	var offset := label_id * LABEL_RECORD_SIZE
	changed[offset] = encoded.size()

	for index in encoded.size():
		changed[offset + 1 + index] = encoded[index]

	changed[offset + 1 + encoded.size()] = 0

	return chunk.set_decoded_payload(changed)


func microsim(microsim_id: int) -> Dictionary:
	if microsim_id < 0 or microsim_id >= IntegerMath.div_trunc(document.decoded_size("XMIC"), MICROSIM_RECORD_SIZE):
		return {}

	var chunk := document.find_chunk("XMIC")

	if chunk == null:
		return {}

	var offset := microsim_id * MICROSIM_RECORD_SIZE

	return {
		"tile_id": int(chunk.decoded_payload[offset]),
		"stat_0": int(chunk.decoded_payload[offset + 1]),
		"stat_1": _read_u16_be(chunk.decoded_payload, offset + 2),
		"stat_2": _read_u16_be(chunk.decoded_payload, offset + 4),
		"stat_3": _read_u16_be(chunk.decoded_payload, offset + 6),
	}


func thing(thing_id: int) -> Dictionary:
	if thing_id < 0 or thing_id >= IntegerMath.div_trunc(document.decoded_size("XTHG"), (24 if map_size > 128 else 12)):
		return {}

	var chunk := document.find_chunk("XTHG")

	if chunk == null:
		return {}

	var offset := thing_id * THING_RECORD_SIZE

	return {
		"type": int(chunk.decoded_payload[offset]),
		"direction": int(chunk.decoded_payload[offset + 1]),
		"state": ThingData.read(chunk.decoded_payload, offset + 2),
		"x": ThingData.read(chunk.decoded_payload, offset + 3),
		"y": ThingData.read(chunk.decoded_payload, offset + 4),
		"z": int(chunk.decoded_payload[offset + 5]),
		"px": ThingData.read(chunk.decoded_payload, offset + 6),
		"py": ThingData.read(chunk.decoded_payload, offset + 7),
		"dx": ThingData.read(chunk.decoded_payload, offset + 8),
		"dy": ThingData.read(chunk.decoded_payload, offset + 9),
		"label": ThingData.read(chunk.decoded_payload, offset + 10),
		"goal": ThingData.read(chunk.decoded_payload, offset + 11),
	}


func graph_series(graph_id: int) -> Dictionary:
	if graph_id < 0 or graph_id >= GRAPH_COUNT:
		return {}

	var chunk := document.find_chunk("XGRP")

	if chunk == null:
		return {}

	var values := PackedInt64Array()
	var offset := graph_id * GRAPH_VALUE_COUNT * 4

	for index in GRAPH_VALUE_COUNT:
		values.append(_read_u32_be(chunk.decoded_payload, offset + index * 4))

	return {
		"year": values.slice(0, 12),
		"decade": values.slice(12, 32),
		"century": values.slice(32, 52),
	}


func city_mode() -> int:
	return document.misc_u32(0x04)


func difficulty() -> int:
	return document.misc_u32(0x1c)


func city_status() -> int:
	return document.misc_u32(0x20)


func weather_type() -> int:
	return document.misc_u32(0x6c)


func disaster_type() -> int:
	return document.misc_u32(0x70)


func funds() -> int:
	return document.misc_i32(0x14)


func set_funds(value: int) -> bool:
	return document.set_misc_i32(0x14, value)


func founding_year() -> int:
	return document.misc_u32(0x0c)


func compass_rotation() -> int:
	return document.misc_u32(0x08) & 0x03


func age_in_days() -> int:
	return document.misc_u32(0x10)


func set_age_in_days(value: int) -> bool:
	if value < 0:
		return false

	return document.set_misc_u32(0x10, value)


func simulation_speed() -> int:
	return document.misc_u32(0x0fec)


func set_simulation_speed(value: int) -> bool:
	if value < 1 or value > 5:
		return false

	return document.set_misc_u32(0x0fec, value)


func auto_budget_enabled() -> bool:
	return document.misc_u32(MISC_AUTO_BUDGET_OPTION) != 0


func set_auto_budget_enabled(enabled: bool) -> bool:
	return document.set_misc_u32(MISC_AUTO_BUDGET_OPTION, 1 if enabled else 0)


func auto_goto_enabled() -> bool:
	return document.misc_u32(MISC_AUTO_GOTO_OPTION) != 0


func set_auto_goto_enabled(enabled: bool) -> bool:
	return document.set_misc_u32(MISC_AUTO_GOTO_OPTION, 1 if enabled else 0)


func sound_enabled() -> bool:
	return document.misc_u32(MISC_SOUND_OPTION) != 0


func set_sound_enabled(enabled: bool) -> bool:
	return document.set_misc_u32(MISC_SOUND_OPTION, 1 if enabled else 0)


func music_enabled() -> bool:
	return document.misc_u32(MISC_MUSIC_OPTION) != 0


func set_music_enabled(enabled: bool) -> bool:
	return document.set_misc_u32(MISC_MUSIC_OPTION, 1 if enabled else 0)


func no_disasters_enabled() -> bool:
	return document.misc_u32(MISC_NO_DISASTERS_OPTION) != 0


func set_no_disasters_enabled(enabled: bool) -> bool:
	return document.set_misc_u32(MISC_NO_DISASTERS_OPTION, 1 if enabled else 0)


func current_year() -> int:
	return founding_year() + int(IntegerMath.div_trunc(age_in_days(), 300))


func current_month() -> int:
	return int(IntegerMath.div_trunc(age_in_days() % 300, 25)) + 1


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


func _set_byte_at(data: PackedByteArray, x: int, y: int, value: int) -> bool:
	var index := index_of(x, y)

	if index < 0:
		return false

	data[index] = value

	return true


func _set_altitude_word(x: int, y: int, value: int) -> bool:
	var index := index_of(x, y)

	if index < 0:
		return false

	var chunk := document.find_chunk("ALTM")

	if chunk == null:
		return false

	var changed := chunk.decoded_payload.duplicate()
	changed[index * 2] = (value >> 8) & 0xff
	changed[index * 2 + 1] = value & 0xff

	if not chunk.set_decoded_payload(changed):
		return false

	altitude_words[index] = value

	return true


static func _read_u16_be(data: PackedByteArray, offset: int) -> int:
	return (data[offset] << 8) | data[offset + 1]


static func _read_u32_be(data: PackedByteArray, offset: int) -> int:
	return (
		(data[offset] << 24)
		| (data[offset + 1] << 16)
		| (data[offset + 2] << 8)
		| data[offset + 3]
	)


func tile_is_visible(x: int, y: int) -> bool:
	if index_of(x, y) < 0:
		return false

	if visible_altitude_levels >= 32:
		return true

	var height := water_altitude(x, y) if is_water(x, y) else land_altitude(x, y)

	return height < visible_altitude_levels


func underground_level_is_visible(x: int, y: int, depth: int) -> bool:
	if index_of(x, y) < 0:
		return false

	return visible_altitude_levels >= 32 or land_altitude(x, y) - depth < visible_altitude_levels


func thing_count() -> int:
	return ThingData.count(document.find_chunk("XTHG").decoded_payload)


func microsim_count() -> int:
	return IntegerMath.div_trunc(document.decoded_size("XMIC"), MICROSIM_RECORD_SIZE)


static func copy_for_edit(source: CityState) -> CityState:
	# copy the already decoded buffers. do not repeat full-map validation or
	# altitude decoding for each pointer move
	var snapshot := CityState.new()
	snapshot.document = source.document.duplicate_document()
	snapshot.map_size = source.map_size
	snapshot.load_error = source.load_error
	snapshot.altitude_words = source.altitude_words.duplicate()
	snapshot.buildings = source.buildings.duplicate()
	snapshot.terrain = source.terrain.duplicate()
	snapshot.zones = source.zones.duplicate()
	snapshot.underground = source.underground.duplicate()
	snapshot.text_overlays = source.text_overlays.duplicate()
	snapshot.tile_flags = source.tile_flags.duplicate()

	return snapshot
