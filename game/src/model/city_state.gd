class_name CityState
extends RefCounted

@warning_ignore_start("integer_division")

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
# chunks with a citystate mirror array. see resync_mirrors
const MIRRORED_CHUNKS: PackedStringArray = ["ALTM", "XTER", "XBLD", "XZON", "XUND", "XTXT", "XBIT"]

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
# Only the main thread fills these lazy caches. Workers also read CityState,
# so filling them from workers would race on the dictionaries.
# CityTileEdits, CityRecords, and IsometricStaticVisuals check this in debug builds.
# Masked XBIT signatures use revisions, with a content check as fallback.
var _masked_tile_flag_signatures: Dictionary[int, Dictionary] = {}
# runtime-only sign pages and static overlay content, keyed by xtxt/xthg revisions
var _static_text_overlay_cache: Dictionary = {}
# runtime-only microsim footprints, rebuilt when xtxt or xthg changes
var _microsim_sites: Dictionary[int, CityRecords.Site] = {}
var _microsim_sites_key := []


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


# refresh the mirrors of the named chunks from the document. a commit passes
# the ids it actually wrote, so a tick that only moved things does not copy
# six map arrays and decode two bytes per tile for nothing. ids without a
# mirror are ignored, so a caller can pass its whole chunk list
func resync_mirrors(chunk_ids: PackedStringArray) -> void:
	for chunk_id in chunk_ids:
		var chunk := document.find_chunk(chunk_id) if document != null else null

		if chunk == null:
			continue

		match chunk_id:
			"ALTM":
				_resync_altitude_words(chunk.decoded_payload)
			"XTER":
				terrain = chunk.decoded_payload.duplicate()
			"XBLD":
				buildings = chunk.decoded_payload.duplicate()
			"XZON":
				zones = chunk.decoded_payload.duplicate()
			"XUND":
				underground = chunk.decoded_payload.duplicate()
			"XTXT":
				text_overlays = chunk.decoded_payload.duplicate()
			"XBIT":
				tile_flags = chunk.decoded_payload.duplicate()


# altm is the one mirror that is decoded rather than copied: each tile is a
# big-endian word of land, water, and tunnel fields
func _resync_altitude_words(altitude: PackedByteArray) -> void:
	for index in (map_size * map_size):
		if simulation_slice != null and (index & 127) == 0:
			simulation_slice.checkpoint()

		altitude_words[index] = (altitude[index * 2] << 8) | altitude[index * 2 + 1]


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
	return CityTileEdits.set_terrain_id(self, x, y, value)


func building_id(x: int, y: int) -> int:
	return _byte_at(buildings, x, y)


func set_building_id(x: int, y: int, value: int) -> bool:
	return CityTileEdits.set_building_id(self, x, y, value)


func replace_buildings(value: PackedByteArray) -> bool:
	return CityTileEdits.replace_buildings(self, value)


func zone_id(x: int, y: int) -> int:
	return _byte_at(zones, x, y) & 0x0f


func set_zone_id(x: int, y: int, value: int) -> bool:
	return CityTileEdits.set_zone_id(self, x, y, value)


func set_building_corners(x: int, y: int, value: int) -> bool:
	return CityTileEdits.set_building_corners(self, x, y, value)


func replace_zones(value: PackedByteArray) -> bool:
	return CityTileEdits.replace_zones(self, value)


func building_corners(x: int, y: int) -> int:
	return _byte_at(zones, x, y) & 0xf0


func underground_id(x: int, y: int) -> int:
	return _byte_at(underground, x, y)


func set_underground_id(x: int, y: int, value: int) -> bool:
	return CityTileEdits.set_underground_id(self, x, y, value)


func text_overlay_id(x: int, y: int) -> int:
	var index := index_of(x, y)

	return 0 if index < 0 else OverlayData.read(text_overlays, index)


func set_text_overlay_id(x: int, y: int, value: int) -> bool:
	return CityTileEdits.set_text_overlay_id(self, x, y, value)


func replace_text_overlays(value: PackedByteArray) -> bool:
	return CityTileEdits.replace_text_overlays(self, value)


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
	return CityTileEdits.set_tile_flag(self, x, y, mask, enabled)


func replace_tile_flags(value: PackedByteArray) -> bool:
	return CityTileEdits.replace_tile_flags(self, value)


func masked_tile_flag_signature(mask: int) -> int:
	return CityTileEdits.masked_tile_flag_signature(self, mask)


# revision of a stored chunk. every committed write bumps it, so a display
# cache can ask "did this map change?" without hashing the whole payload
# returns -1 when the document does not carry the chunk
func chunk_revision(chunk_id: String) -> int:
	var chunk := document.find_chunk(chunk_id) if document != null else null

	return chunk.mutation_revision if chunk != null else -1


func set_land_altitude(x: int, y: int, value: int) -> bool:
	return CityTileEdits.set_land_altitude(self, x, y, value)


func set_water_altitude(x: int, y: int, value: int) -> bool:
	return CityTileEdits.set_water_altitude(self, x, y, value)


func set_tunnel_levels(x: int, y: int, value: int) -> bool:
	return CityTileEdits.set_tunnel_levels(self, x, y, value)


func city_name() -> String:
	return CityRecords.city_name(self)


func display_name() -> String:
	return CityRecords.display_name(self)


func mayor_name() -> String:
	return CityRecords.mayor_name(self)


func label(label_id: int) -> String:
	return CityRecords.label(self, label_id)


func set_label(label_id: int, value: String) -> bool:
	return CityRecords.set_label(self, label_id, value)


func microsim(microsim_id: int) -> CityRecords.Microsim:
	return CityRecords.microsim(self, microsim_id)


func thing(thing_id: int) -> ThingRecord:
	return CityRecords.thing(self, thing_id)


func graph_series(graph_id: int) -> CityRecords.GraphSeries:
	return CityRecords.graph_series(self, graph_id)


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
	return founding_year() + int(age_in_days() / 300)


func current_month() -> int:
	return int((age_in_days() % 300) / 25) + 1


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


func _set_altitude_word(x: int, y: int, value: int) -> bool:
	return CityTileEdits._set_altitude_word(self, x, y, value)


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
	return CityRecords.thing_count(self)


func microsim_count() -> int:
	return CityRecords.microsim_count(self)


func microsim_site(microsim_id: int) -> CityRecords.Site:
	return CityRecords.microsim_site(self, microsim_id)


func microsim_sites() -> Dictionary[int, CityRecords.Site]:
	return CityRecords.microsim_sites(self)


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
