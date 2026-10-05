# gdstyle:ignore-file=quality/max-public-methods
class_name Sc2File
extends RefCounted

enum TilePlane {
	ALTITUDE,
	TERRAIN,
	BUILDINGS,
	ZONES,
	UNDERGROUND,
	TEXT,
	FLAGS,
}


@warning_ignore_start("integer_division")

const ChunkType = preload("res://src/formats/sc2_chunk.gd")
const DECODED_SIZES: Dictionary[String, int] = {
	"CNAM": 32,
	"MISC": Sc2MiscLayout.SIZE,
	"ALTM": 32768,
	"XTER": 16384,
	"XBLD": 16384,
	"XZON": 16384,
	"XUND": 16384,
	"XTXT": 16384,
	"XLAB": Sc2LabelLayout.ORIGINAL_SIZE,
	"XMIC": Sc2MicrosimLayout.ORIGINAL_SIZE,
	"XTHG": Sc2ThingLayout.ORIGINAL_SIZE,
	"XBIT": 16384,
	"XTRF": 4096,
	"XPLT": 4096,
	"XVAL": 4096,
	"XCRM": 4096,
	"XPLC": 1024,
	"XFIR": 1024,
	"XPOP": 1024,
	"XROG": 1024,
	"XGRP": Sc2GraphLayout.SIZE,
}
const RAW_CHUNKS: Dictionary[String, bool] = {
	"CNAM": true,
	"ALTM": true,
	"TEXT": true,
	"SCEN": true,
	"PICT": true,
	"TMPL": true,
}
const MAP_SIZES := [16, 32, 64, 128, 256, 384, 512, 640, 1024, 2048, 4096]
# SCLG files end at 1024 tiles. Larger maps use SC2X version 4 only
const SCLG_MAX_EDGE := 1024
# legacy record tables of larger in-memory maps keep the 1024-tile capacities
const LEGACY_MAX_FACTOR := 64
const FULL_MAP_CHUNKS := ["ALTM", "XTER", "XBLD", "XZON", "XUND", "XTXT", "XBIT"]
# these maps aren't all the same size; traffic uses half, services use a quarter
const HALF_MAP_CHUNKS := ["XTRF", "XPLT", "XVAL", "XCRM"]
const QUARTER_MAP_CHUNKS := ["XPLC", "XFIR", "XPOP", "XROG"]

var map_size := 128
# 1 through 3 are SCLG versions. 4 marks an SC2X version 4 working document
var large_version := 2
var chunks: Array[Sc2Chunk] = []
var source_bytes := PackedByteArray()
var source_path := ""
var parse_error := ""
# The FORM length was zero, so the reader used the file size, as sc2kfix does
var repaired_form_length := false
# "sc2kfix" for an original city from an sc2kfix SC2X archive (Sc2kfixArchive)
var source_format := ""
# Cache the first occurrence of each chunk ID. Worker lookups only read
# the cache; rebuild it when the chunk list changes. A size mismatch
# falls back to a scan. Store positions so the cache cannot keep chunks alive.
var _chunk_cache: Dictionary[String, int] = {}
var _chunk_cache_size := -1
# typed tile-plane slots follow full_map_chunks and share its invalidation rule
var _tile_chunks: Array[Sc2Chunk] = []
# SC2X version 4 state outside the working chunks. See Sc2xDocument.
var sc2x_metadata: Sc2xMetadata
# the XLAB.bin compatibility table. Names never come from it
var sc2x_compat_labels := PackedByteArray()
# persistent identity, name, and object type of each XTHG slot
var sc2x_object_ids := PackedInt64Array()
var sc2x_object_kinds := PackedByteArray()
var sc2x_object_names := PackedStringArray()
# encoded XMIC and XTHG extension blocks that this version does not own, kept
# for the next save
var sc2x_extensions: Dictionary[String, PackedByteArray] = {}
# source order of each TEXT occurrence
var sc2x_text_orders := PackedInt64Array()
# preserved chunks: {chunk_id, occurrence, source_order, flags, payload, entry}
var sc2x_preserved: Array[Dictionary] = []
# archive entries that are not structures, kept for the next save
var sc2x_extra_entries: Dictionary[String, PackedByteArray] = {}
# required features that this version does not support; the city is read-only
var sc2x_unsupported_features := PackedStringArray()
# the legacy file that a conversion read. a save never replaces it
var sc2x_converted_from := ""


static func load_path(path: String) -> Sc2File:
	var city := Sc2File.new()
	city.source_path = path

	if not FileAccess.file_exists(path):
		city.parse_error = "File does not exist: %s" % path

		return city

	var bytes := FileAccess.get_file_as_bytes(path)

	if FileAccess.get_open_error() != OK:
		city.parse_error = "Cannot read file: %s" % path

		return city

	city.parse(bytes)

	return city


func parse(bytes: PackedByteArray) -> bool:
	chunks.clear()
	invalidate_chunk_cache()
	source_bytes = PackedByteArray()
	parse_error = ""
	repaired_form_length = false
	source_format = ""
	map_size = 128
	large_version = 2
	_clear_sc2x_state()

	# the signature selects the reader, not the file extension
	var parsed: Dictionary = NativeCityDocument.parse(bytes)

	if not parsed.ok:
		return _fail(parsed.error)

	apply_native(parsed.document)

	return true


# The document in the form of the native library. See
# native/simulation/src/bridge/document.rs.
func to_native() -> Dictionary:
	var native_chunks := []

	for chunk in chunks:
		native_chunks.append({
			"chunk_id": chunk.chunk_id, "source_offset": chunk.source_offset, "stored": chunk.stored_payload,
			"decoded": chunk.decoded_payload, "expected_size": chunk.expected_decoded_size,
			"compressed": chunk.is_compressed, "dirty": chunk.is_dirty,
		})

	return {
		"map_size": map_size, "large_version": large_version, "source_format": source_format,
		"repaired_form_length": repaired_form_length, "source_bytes": source_bytes,
		"chunks": native_chunks, "sc2x": _sc2x_native(),
	}


# Takes the fields and chunks of a native document. Chunk objects stay when the
# chunk list keeps its IDs, so that holders of a chunk see the new payload.
func apply_native(native: Dictionary) -> void:
	map_size = native.map_size
	large_version = native.large_version
	source_format = native.source_format
	repaired_form_length = native.repaired_form_length
	source_bytes = native.source_bytes
	var native_chunks: Array = native.chunks
	var same := native_chunks.size() == chunks.size()

	for index in native_chunks.size():
		if same and chunks[index].chunk_id != native_chunks[index].chunk_id:
			same = false

	if not same:
		chunks.clear()

	for index in native_chunks.size():
		var fields: Dictionary = native_chunks[index]
		var chunk := chunks[index] if same else ChunkType.new()
		chunk.chunk_id = fields.chunk_id
		chunk.source_offset = fields.source_offset
		chunk.stored_payload = fields.stored
		chunk.decoded_payload = fields.decoded
		chunk.expected_decoded_size = fields.expected_size
		chunk.is_compressed = fields.compressed

		chunk.is_dirty = fields.dirty
		chunk.mutation_revision = NativeSimulation.next_revision()

		if not same:
			chunks.append(chunk)

	apply_native_sc2x(native.sc2x)
	rebuild_chunk_cache()


func _sc2x_native() -> Dictionary:
	if sc2x_metadata == null:
		return {}

	var extra_names := PackedStringArray()
	var extra_payloads := []
	# the native library reads untyped arrays
	var preserved := []
	preserved.assign(sc2x_preserved)

	for name in sc2x_extra_entries:
		extra_names.append(name)
		extra_payloads.append(sc2x_extra_entries[name])

	return {
		"metadata": sc2x_metadata.to_fields(), "compat_labels": sc2x_compat_labels,
		"object_ids": sc2x_object_ids, "object_kinds": sc2x_object_kinds, "object_names": sc2x_object_names,
		"xmic_extension": sc2x_extensions.get("XMIC", PackedByteArray()),
		"xthg_extension": sc2x_extensions.get("XTHG", PackedByteArray()),
		"text_orders": sc2x_text_orders, "preserved": preserved,
		"extra_names": extra_names, "extra_payloads": extra_payloads,
		"unsupported_features": sc2x_unsupported_features, "converted_from": sc2x_converted_from,
	}


# Takes the SC2X state of a native document. An empty state is an original city.
func apply_native_sc2x(state: Dictionary) -> void:
	if state.is_empty():
		_clear_sc2x_state()

		return

	sc2x_metadata = Sc2xMetadata.from_fields(state.metadata)
	sc2x_compat_labels = state.compat_labels
	sc2x_object_ids = state.object_ids
	sc2x_object_kinds = state.object_kinds
	sc2x_object_names = state.object_names
	sc2x_extensions = {"XMIC": state.xmic_extension, "XTHG": state.xthg_extension}
	sc2x_text_orders = state.text_orders
	sc2x_preserved.assign(state.preserved)
	sc2x_extra_entries = {}

	for index in state.extra_names.size():
		sc2x_extra_entries[state.extra_names[index]] = state.extra_payloads[index]

	sc2x_unsupported_features = state.unsupported_features
	sc2x_converted_from = state.converted_from


func is_valid() -> bool:
	return parse_error.is_empty()


# An SC2X version 4 working document
func is_sc2x() -> bool:
	return large_version == 4


# Empty when the city can be edited and simulated. A version 4 file that
# requires unknown features can only be inspected.
func compatibility_error() -> String:
	if sc2x_unsupported_features.is_empty():
		return ""

	return "This city needs features that this version of OpenSC2K does not have: %s. It can be inspected but not played." % (
		", ".join(sc2x_unsupported_features))


# A working document gives a new identity to a moving-object slot whose object
# was freed or changed type. The next save assigns the new object ID. Call this
# after each change of XTHG.
func reconcile_object_identities() -> void:
	var chunk := find_chunk("XTHG") if is_sc2x() else null

	if chunk == null:
		return

	var things := chunk.decoded_payload
	var count := ThingData.count(things)
	sc2x_object_ids.resize(count)
	sc2x_object_names.resize(count)
	var previous := sc2x_object_kinds.size()
	sc2x_object_kinds.resize(count)

	for record in count:
		var kind := things[record * Sc2ThingLayout.RECORD_SIZE]

		if record >= previous or Sc2ThingLayout.identity_kind(sc2x_object_kinds[record]) != Sc2ThingLayout.identity_kind(kind):
			sc2x_object_ids[record] = 0
			sc2x_object_names[record] = ""
			sc2x_object_kinds[record] = kind


func _clear_sc2x_state() -> void:
	sc2x_metadata = null
	sc2x_compat_labels = PackedByteArray()
	sc2x_object_ids = PackedInt64Array()
	sc2x_object_kinds = PackedByteArray()
	sc2x_object_names = PackedStringArray()
	sc2x_extensions = {}
	sc2x_text_orders = PackedInt64Array()
	sc2x_preserved = []
	sc2x_extra_entries = {}
	sc2x_unsupported_features = PackedStringArray()
	sc2x_converted_from = ""


# simulation may share immutable file bytes; decoded payloads always remain private
func duplicate_document(share_source_bytes := false) -> Sc2File:
	var result := Sc2File.new()
	result.map_size = map_size
	result.large_version = large_version
	result.source_bytes = source_bytes if share_source_bytes else source_bytes.duplicate()
	result.source_path = source_path
	result.parse_error = parse_error
	result.repaired_form_length = repaired_form_length
	result.source_format = source_format
	result.sc2x_metadata = sc2x_metadata.copy() if sc2x_metadata != null else null
	result.sc2x_compat_labels = sc2x_compat_labels.duplicate()
	result.sc2x_object_ids = sc2x_object_ids.duplicate()
	result.sc2x_object_kinds = sc2x_object_kinds.duplicate()
	result.sc2x_object_names = sc2x_object_names.duplicate()
	result.sc2x_extensions = sc2x_extensions.duplicate(true)
	result.sc2x_text_orders = sc2x_text_orders.duplicate()
	result.sc2x_preserved = sc2x_preserved.duplicate(true)
	result.sc2x_extra_entries = sc2x_extra_entries.duplicate(true)
	result.sc2x_unsupported_features = sc2x_unsupported_features.duplicate()
	result.sc2x_converted_from = sc2x_converted_from

	for chunk in chunks:
		var copied := Sc2Chunk.new()
		copied.chunk_id = chunk.chunk_id
		copied.source_offset = chunk.source_offset
		copied.stored_payload = chunk.stored_payload if share_source_bytes else chunk.stored_payload.duplicate()
		copied.decoded_payload = chunk.decoded_payload.duplicate()
		copied.expected_decoded_size = chunk.expected_decoded_size
		copied.is_compressed = chunk.is_compressed
		copied.is_dirty = chunk.is_dirty
		copied.mutation_revision = chunk.mutation_revision
		result.chunks.append(copied)

	result.rebuild_chunk_cache()

	return result


func find_chunk(chunk_id: String, occurrence: int = 0) -> Sc2Chunk:
	if occurrence != 0 or _chunk_cache_size != chunks.size():
		return _scan_chunk(chunk_id, occurrence)

	var index: int = _chunk_cache.get(chunk_id, -1)

	if index < 0:
		return null

	var chunk := chunks[index]
	# stripped from release builds; the size guard above covers every append,
	# erase, and clear. a same-size replacement needs rebuild_chunk_cache
	assert(chunk.chunk_id == chunk_id, "Stale chunk cache; call rebuild_chunk_cache after editing chunks")

	return chunk


# Call rebuild_chunk_cache after changing chunks directly, before sharing
# the document with workers. The size check cannot catch same-size replacements.
func rebuild_chunk_cache() -> void:
	_chunk_cache.clear()

	for index in chunks.size():
		var id := chunks[index].chunk_id

		if not _chunk_cache.has(id):
			_chunk_cache[id] = index

	_tile_chunks.clear()

	for id in FULL_MAP_CHUNKS:
		var index: int = _chunk_cache.get(id, -1)
		_tile_chunks.append(chunks[index] if index >= 0 else null)

	_chunk_cache_size = chunks.size()


# drop the cached lookups and return find_chunk to a plain scan
func invalidate_chunk_cache() -> void:
	_chunk_cache.clear()
	_tile_chunks.clear()
	_chunk_cache_size = -1


# slot order is full_map_chunks. rebuild after same-size chunk replacements,
# as with find_chunk. uncached or resized lists use the authoritative scan
func tile_chunk(slot: int) -> Sc2Chunk:
	if _chunk_cache_size != chunks.size():
		return _scan_chunk(FULL_MAP_CHUNKS[slot], 0)

	return _tile_chunks[slot]


func _scan_chunk(chunk_id: String, occurrence: int) -> Sc2Chunk:
	for chunk in chunks:
		if chunk.chunk_id != chunk_id:
			continue

		if occurrence == 0:
			return chunk

		occurrence -= 1

	return null


func city_name() -> String:
	if is_sc2x():
		return sc2x_metadata.city_name if sc2x_metadata != null else ""

	var chunk := find_chunk("CNAM")

	if chunk == null or chunk.decoded_payload.size() < 2:
		return ""

	var end := 1

	while end < chunk.decoded_payload.size() and chunk.decoded_payload[end] != 0:
		end += 1

	return chunk.decoded_payload.slice(1, end).get_string_from_ascii()


# SC2 and SCN names hold 30 ASCII bytes. An SC2X name holds 64 characters.
func set_city_name(value: String) -> bool:
	if is_sc2x():
		var name := Sc2xMetadata.limit_name(value)

		if sc2x_metadata == null or name.is_empty():
			return false

		sc2x_metadata.city_name = name

		return true

	var chunk := find_chunk("CNAM")

	if chunk == null or chunk.decoded_payload.size() != DECODED_SIZES.CNAM:
		return false

	var encoded := value.to_ascii_buffer()

	if encoded.size() > 30:
		encoded = encoded.slice(0, 30)

	var changed := chunk.decoded_payload.duplicate()

	for index in encoded.size():
		changed[index + 1] = encoded[index]

	changed[encoded.size() + 1] = 0

	return chunk.set_decoded_payload(changed, true)


# Some supplied cities have no CNAM chunk. The Windows game stores 0x1f in the first byte.
# Other files put CNAM last, so the new chunk goes at the end. Returns the existing chunk if there is one
func add_city_name_chunk() -> Sc2Chunk:
	# an SC2X version 4 city keeps its name in metadata
	if is_sc2x():
		return null

	var existing := find_chunk("CNAM")

	if existing != null:
		return existing

	var chunk := Sc2Chunk.new()
	chunk.chunk_id = "CNAM"
	chunk.expected_decoded_size = DECODED_SIZES.CNAM
	var payload := PackedByteArray()
	payload.resize(DECODED_SIZES.CNAM)
	payload.fill(0)
	payload[0] = 0x1f
	chunk.set_decoded_payload(payload, true)
	chunks.append(chunk)
	rebuild_chunk_cache()

	return chunk


func misc_u32(offset: int) -> int:
	var chunk := find_chunk("MISC")

	if chunk == null or offset < 0 or offset + 4 > chunk.decoded_payload.size():
		return 0

	return BinaryData.read_u32_be(chunk.decoded_payload, offset)


func misc_i32(offset: int) -> int:
	var value := misc_u32(offset)

	if value >= 0x80000000:
		return value - 0x100000000

	return value


func set_misc_u32(offset: int, value: int) -> bool:
	var chunk := find_chunk("MISC")

	if chunk == null or offset < 0 or offset + 4 > chunk.decoded_payload.size():
		return false

	return chunk.write_decoded_bytes(offset, _u32_be(value & 0xffffffff))


func set_misc_i32(offset: int, value: int) -> bool:
	return set_misc_u32(offset, value)


func serialize(force_rebuild: bool = false) -> BinaryResult:
	var has_changes := false

	for chunk in chunks:
		if chunk.is_dirty:
			has_changes = true
			break

	# an unchanged original file writes its own bytes without a native call
	if not is_sc2x() and not force_rebuild and not has_changes and not source_bytes.is_empty():
		var unchanged_result := BinaryResult.new()
		unchanged_result.ok = true
		unchanged_result.data = source_bytes.duplicate()
		unchanged_result.error = ""

		return unchanged_result

	var saved: Dictionary = NativeCityDocument.serialize(to_native(), force_rebuild)

	if not saved.ok:
		return BinaryResult.failure(saved.error)

	# a working document stores its new identity counters
	if is_sc2x():
		apply_native_sc2x(saved.sc2x)

	var outcome := BinaryResult.new()
	outcome.ok = true
	outcome.data = saved.bytes
	outcome.error = ""

	return outcome


func _fail(message: String) -> bool:
	parse_error = message
	chunks.clear()
	invalidate_chunk_cache()

	return false


static func _u32_be(value: int) -> PackedByteArray:
	return PackedByteArray(
		[
			(value >> 24) & 0xff,
			(value >> 16) & 0xff,
			(value >> 8) & 0xff,
			value & 0xff,
		]
	)


static func _is_chunk_id(value: String) -> bool:
	if value.length() != 4:
		return false

	var bytes := value.to_ascii_buffer()

	for byte in bytes:
		if byte < 0x20 or byte > 0x7e:
			return false

	return true


func decoded_size(chunk_id: String) -> int:
	# a working document keeps the record capacities of its file
	if is_sc2x():
		match chunk_id:
			"XTXT":
				return map_size * map_size * OverlayData.LAYERED_PLANES
			"XMIC", "XTHG", "XLAB", "XSGN":
				var chunk := find_chunk(chunk_id)

				return chunk.decoded_payload.size() if chunk != null else -1
			"CNAM":
				return -1

	return NativeSc2Form.decoded_size(chunk_id, map_size, large_version)


func resize_empty_map(edge: int) -> bool:
	var resized: Dictionary = NativeCityDocument.resize_empty_map(to_native(), edge)

	if resized.ok:
		apply_native(resized.document)

	return resized.ok


func upgrade_large_limits() -> void:
	apply_native(NativeCityDocument.upgrade_large_limits(to_native()))


func is_extended() -> bool:
	return map_size != 128 or full_resolution_maps()


func full_resolution_maps() -> bool:
	return large_version >= 3


# The most characters in a label, sign, or record name
func name_limit() -> int:
	return Sc2xMetadata.MAX_NAME_CODE_POINTS if is_sc2x() else Sc2LabelLayout.MAX_TEXT_BYTES


# The most characters in the city name
func city_name_limit() -> int:
	return Sc2xMetadata.MAX_NAME_CODE_POINTS if is_sc2x() else 30


# Bytes per record of the runtime label table. A working document uses wide
# UTF-8 records; see Sc2LabelLayout.
func label_record_size() -> int:
	return Sc2LabelLayout.WIDE_RECORD_SIZE if is_sc2x() else Sc2LabelLayout.RECORD_SIZE


# A snapshot of the content that a save writes: the file bytes of an SC2 or
# SCN city, or a digest of the raw entries of an SC2X version 4 city. Equal
# snapshots mean that a save would write the same city.
func content_snapshot() -> PackedByteArray:
	if not is_sc2x():
		var serialized := serialize()

		return serialized.data if serialized.ok else PackedByteArray()

	var result: Dictionary = NativeCityDocument.content_snapshot(to_native())
	apply_native_sc2x(result.sc2x)

	return result.snapshot


func enable_full_resolution_maps() -> bool:
	if full_resolution_maps():
		return true

	var expanded: Dictionary = NativeCityDocument.enable_full_resolution_maps(to_native())

	if expanded.ok:
		apply_native(expanded.document)

	return expanded.ok
