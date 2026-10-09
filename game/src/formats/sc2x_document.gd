# gdstyle:ignore-file=quality/max-public-methods
class_name Sc2xDocument
extends RefCounted
## SC2X file version 4: a ZIP archive with flat entries. Each binary structure is
## `<ID>.bin` with its raw bytes; ZIP compresses every entry with DEFLATE level 9.
## `metadata.json` holds the city name, the file version, and the saved state
## that no structure holds. The repository publishes its JSON schema; earlier
## archives also hold a copy as `metadata.schema.json`, which a load ignores.
##
## A loaded file becomes a working document (`Sc2File.large_version` 4). The
## simulation and the tools read its chunks in the extended layout. Its tile
## index, label table, and record tables are runtime state that `join` rebuilds
## from the saved structures and `split` saves again. See docs/sc2x-format.md.
## The native simulation library reads, writes and converts the documents; see
## native/core/sim/src/formats/sc2x/document.rs.

const METADATA_ENTRY := "metadata.json"
const SCHEMA_ENTRY := "metadata.schema.json"
const ENTRY_SUFFIX := ".bin"
const MAX_ARCHIVE_BYTES := 512 * 1024 * 1024
const MAX_DATA_BYTES := 768 * 1024 * 1024
# the entry order after metadata. Missing optional entries are skipped
const ENTRY_ORDER: PackedStringArray = [
	"MISC", "ALTM", "XTER", "XBLD", "XZON", "XUND", "XTXT", "XLAB", "XMIC", "XTHG", "XBIT",
	"XTRF", "XPLT", "XVAL", "XCRM", "XPLC", "XFIR", "XPOP", "XROG", "XGRP", "XSGN",
	"SCEN", "TEXT", "PICT", "TMPL", "CUNK",
]
const REQUIRED_ENTRIES: PackedStringArray = [
	"MISC", "ALTM", "XTER", "XBLD", "XZON", "XUND", "XTXT", "XLAB", "XMIC", "XTHG", "XBIT",
	"XTRF", "XPLT", "XVAL", "XCRM", "XPLC", "XFIR", "XPOP", "XROG", "XGRP", "XSGN",
]
# legacy containers and headers that metadata and ZIP replace
const PROHIBITED_ENTRIES: PackedStringArray = ["FORM", "SCDH", "SCLG", "SIZE", "CNAM"]
# bytes per tile of each dense plane. The working tile index has two bytes per tile
const DENSE_ENTRIES: Dictionary[String, int] = {
	"ALTM": 2, "XTER": 1, "XBLD": 1, "XZON": 1, "XUND": 1, "XTXT": 1, "XBIT": 1,
	"XTRF": 1, "XPLT": 1, "XVAL": 1, "XCRM": 1, "XPLC": 1, "XFIR": 1, "XPOP": 1, "XROG": 1,
}
const FRESH_LABEL_TABLE_SIZE := Sc2LabelLayout.ORIGINAL_SIZE


static func is_archive(bytes: PackedByteArray) -> bool:
	return bytes.size() >= 4 and (bytes.decode_u32(0) == 0x04034b50 or bytes.decode_u32(0) == 0x06054b50)


# the default record capacities and vehicle caps of an edge, or an empty dictionary
static func profile(edge: int) -> Dictionary:
	return NativeSc2x.profile(edge)


static func entry_name(id: String) -> String:
	return id + ENTRY_SUFFIX


# A name that an unknown chunk can use as its own entry
static func is_safe_chunk_id(id: String) -> bool:
	if id.length() != 4 or id in ENTRY_ORDER or id in PROHIBITED_ENTRIES:
		return false

	for character in id:
		if not ((character >= "A" and character <= "Z") or (character >= "0" and character <= "9")):
			return false

	return true


# Read an archive into a working document. A failure leaves `parse_error` set.
static func load_bytes(document: Sc2File, bytes: PackedByteArray) -> bool:
	return document.parse(bytes)


# The raw entries of a working document, in archive order. This also stores
# the new identity counters and object identities in the document.
static func entries(document: Sc2File) -> EntriesResult:
	if document == null or not document.is_sc2x():
		return EntriesResult.failure("The document is not an SC2X version 4 working document")

	var prepared: Dictionary = NativeCityDocument.sc2x_entries(document.to_native())

	if not prepared.ok:
		return EntriesResult.failure(prepared.error)

	document.apply_native_sc2x(prepared.sc2x)
	var result := EntriesResult.new()
	result.ok = true
	result.issues = prepared.issues

	for name: String in prepared.order:
		result.add(name, prepared.members[name])

	return result


static func encode(document: Sc2File) -> BinaryResult:
	if document == null or not document.is_sc2x():
		return BinaryResult.failure("The document is not an SC2X version 4 working document")

	return document.serialize(true)


# A digest of the saved content: the raw entries without ZIP compression.
# Equal digests mean that a save would write the same city.
static func content_digest(document: Sc2File) -> PackedByteArray:
	var prepared := entries(document)

	return digest_entries(prepared) if prepared.ok else PackedByteArray()


static func digest_entries(prepared: EntriesResult) -> PackedByteArray:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)

	for name in prepared.order:
		context.update(name.to_utf8_buffer())
		var size := PackedByteArray()
		size.resize(8)
		size.encode_u64(0, prepared.members[name].size())
		context.update(size)

		# the hashing context rejects an empty update
		if not prepared.members[name].is_empty():
			context.update(prepared.members[name])

	return context.finish()


# A working document from a valid SC2, SCN, or SCLG document. The source stays
# unchanged. `issues` lists links that the new structures cannot hold. An import
# keeps record capacities above its map profile; a `fresh` city uses the profile.
static func from_legacy(source: Sc2File, fallback_name := "", fresh := false) -> ConversionResult:
	if source == null or not source.is_valid():
		return ConversionResult.failure("The source city is not valid")

	return _converted(NativeCityDocument.from_legacy(source.to_native(), fallback_name, fresh))


# A fresh working document of `edge` tiles with the starting values of a new city
static func create_empty(edge: int, city_name := "New City") -> ConversionResult:
	# per-tile data maps first, so that a resize makes empty full-size maps
	var template := EmptyCityTemplate.create(128)
	template.enable_full_resolution_maps()

	if edge != 128 and not template.resize_empty_map(edge):
		return ConversionResult.failure("Unsupported map size %d" % edge)

	EmptyCityTemplate.fill_neutral_growth(template)

	return from_new_city(template, city_name, "")


# A working document from a city that the new-city tools made in the legacy
# layout. A new city has no import data, so it keeps no legacy record and
# starts with an empty compatibility label table.
static func from_new_city(source: Sc2File, city_name: String, mayor_name: String) -> ConversionResult:
	if source == null or not source.is_valid():
		return ConversionResult.failure("The source city is not valid")

	return _converted(NativeCityDocument.from_new_city(source.to_native(), city_name, mayor_name))


static func _converted(native: Dictionary) -> ConversionResult:
	if not native.ok:
		return ConversionResult.failure(native.error)

	var result := ConversionResult.new()
	result.ok = true
	result.issues = native.issues
	result.document = Sc2File.new()
	result.document.apply_native(native.document)

	return result


# the payload size that a chunk keeps for its document; -1 lets it vary
static func _fixed_size(id: String, edge: int, data: PackedByteArray) -> int:
	# the layered tile index
	if id == "XTXT":
		return edge * edge * OverlayData.LAYERED_PLANES

	if DENSE_ENTRIES.has(id):
		return edge * edge * DENSE_ENTRIES[id]

	match id:
		"MISC":
			return Sc2MiscLayout.SIZE
		"XGRP":
			return Sc2GraphLayout.SIZE
		"XMIC", "XTHG", "XLAB":
			return data.size()

	return -1


class EntriesResult extends RefCounted:
	var ok := false
	var error := ""
	var order := PackedStringArray()
	var members: Dictionary[String, PackedByteArray] = {}
	var issues := PackedStringArray()

	func add(name: String, data: PackedByteArray) -> void:
		order.append(name)
		members[name] = data

	static func failure(message: String) -> EntriesResult:
		var result := EntriesResult.new()
		result.error = message

		return result


class ConversionResult extends RefCounted:
	var ok := false
	var error := ""
	var document: Sc2File
	var issues := PackedStringArray()

	static func failure(message: String) -> ConversionResult:
		var result := ConversionResult.new()
		result.error = message

		return result
