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

const METADATA_ENTRY := "metadata.json"
const SCHEMA_ENTRY := "metadata.schema.json"
const ENTRY_SUFFIX := ".bin"
const MAX_ARCHIVE_BYTES := 512 * 1024 * 1024
const MAX_DATA_BYTES := 768 * 1024 * 1024
const ZIP_SIGNATURE := 0x04034b50
const EMPTY_ZIP_SIGNATURE := 0x06054b50
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
const SCENARIO_ENTRIES: PackedStringArray = ["SCEN", "TEXT", "PICT", "TMPL"]
# legacy containers and headers that metadata and ZIP replace
const PROHIBITED_ENTRIES: PackedStringArray = ["FORM", "SCDH", "SCLG", "SIZE", "CNAM"]
# bytes per tile of each dense plane. The working tile index has two bytes per tile
const DENSE_ENTRIES: Dictionary[String, int] = {
	"ALTM": 2, "XTER": 1, "XBLD": 1, "XZON": 1, "XUND": 1, "XTXT": 1, "XBIT": 1,
	"XTRF": 1, "XPLT": 1, "XVAL": 1, "XCRM": 1, "XPLC": 1, "XFIR": 1, "XPOP": 1, "XROG": 1,
}
const DATA_MAPS: PackedStringArray = ["XTRF", "XPLT", "XVAL", "XCRM", "XPLC", "XFIR", "XPOP", "XROG"]
# known structures that a working document keeps as one chunk. Repeated TEXT
# chunks are the one exception
const SINGLETONS: PackedStringArray = [
	"CNAM", "MISC", "ALTM", "XTER", "XBLD", "XZON", "XUND", "XTXT", "XLAB", "XMIC", "XTHG", "XBIT",
	"XTRF", "XPLT", "XVAL", "XCRM", "XPLC", "XFIR", "XPOP", "XROG", "XGRP", "SCEN", "PICT", "TMPL",
]
const FRESH_LABEL_TABLE_SIZE := Sc2LabelLayout.ORIGINAL_SIZE
const CHUNK_STORED := 1
const CHUNK_SUPERSEDED := 2
const TEXT_ID := "TEXT"


static func is_archive(bytes: PackedByteArray) -> bool:
	return bytes.size() >= 4 and (bytes.decode_u32(0) == ZIP_SIGNATURE or bytes.decode_u32(0) == EMPTY_ZIP_SIGNATURE)


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
	var archive := ZipArchive.decode(bytes, MAX_ARCHIVE_BYTES, MAX_DATA_BYTES)

	if not archive.ok:
		return _fail(document, "SC2X archive: " + archive.error)

	var members := archive.members

	for name in archive.order:
		if name.contains("/") or name.contains("\\"):
			return _fail(document, "SC2X entry %s is in a folder; every entry must be at the archive root" % name)

	if not members.has(METADATA_ENTRY):
		return _fail(document, "SC2X archive has no metadata.json")

	# the application rules decide validity; an included schema changes nothing
	var parsed := Sc2xMetadata.parse_bytes(members[METADATA_ENTRY])

	if not parsed.ok:
		return _fail(document, parsed.error)

	var metadata := parsed.metadata
	var edge := metadata.map_size
	document.map_size = edge
	document.large_version = 4
	document.sc2x_metadata = metadata
	document.sc2x_unsupported_features = metadata.unsupported_features()

	var phase_error := Sc2xMetadata.phase_state_error(metadata.phase_state)

	if not phase_error.is_empty():
		return _fail(document, phase_error)

	if edge not in Sc2File.MAP_SIZES:
		return _fail(document, "This version cannot open a %d by %d city. SC2X files can describe it, but the game supports %s." % [
			edge, edge, ", ".join(Sc2File.MAP_SIZES.map(func(size: int) -> String: return str(size)))])

	var entries: Dictionary[String, PackedByteArray] = {}
	var preserved: Array[Dictionary] = []
	var extras: Dictionary[String, PackedByteArray] = {}

	for name in archive.order:
		if name == METADATA_ENTRY or name == SCHEMA_ENTRY:
			continue

		var id := name.trim_suffix(ENTRY_SUFFIX)

		if not name.ends_with(ENTRY_SUFFIX) or id.length() != 4 or not Sc2File._is_chunk_id(id):
			extras[name] = members[name]
			continue

		if id in PROHIBITED_ENTRIES:
			return _fail(document, "SC2X version 4 files must not contain %s" % name)

		if id in ENTRY_ORDER:
			entries[id] = members[name]
		else:
			preserved.append({
				"chunk_id": id, "occurrence": 0, "source_order": preserved.size(), "flags": CHUNK_STORED,
				"payload": members[name], "entry": name,
			})

	for id in REQUIRED_ENTRIES:
		if not entries.has(id):
			return _fail(document, "SC2X archive has no %s" % entry_name(id))

	var size_error := _check_sizes(entries, edge)

	if not size_error.is_empty():
		return _fail(document, size_error)

	if entries.has("CUNK"):
		var decoded: Dictionary = NativeSc2x.decode_chunks(entries.CUNK)

		if not decoded.ok:
			return _fail(document, "CUNK.bin: " + str(decoded.error))

		for chunk: Dictionary in decoded.chunks:
			chunk["entry"] = ""
			preserved.append(chunk)

	var joined: Dictionary = NativeSc2x.join({
		"edge": edge, "XTXT": entries.XTXT, "XMIC": entries.XMIC, "XTHG": entries.XTHG,
		"mayor_name": metadata.mayor_name, "team_names": metadata.stadium_teams,
	})

	if not joined.ok:
		return _fail(document, str(joined.error))

	var working: Dictionary[String, PackedByteArray] = {}

	for id in REQUIRED_ENTRIES:
		working[id] = entries[id]

	working.XTXT = joined.xtxt
	working.XMIC = joined.xmic
	working.XTHG = joined.xthg
	working.XLAB = joined.labels
	document.chunks.clear()

	for id in REQUIRED_ENTRIES:
		document.chunks.append(_chunk(id, working[id], _fixed_size(id, edge, working[id])))

	if entries.has("SCEN"):
		document.chunks.append(_chunk("SCEN", entries.SCEN, -1))

	var text_orders := PackedInt64Array()

	if entries.has(TEXT_ID):
		var text: Dictionary = NativeSc2x.decode_text(entries.TEXT)

		for occurrence: Dictionary in text.occurrences:
			document.chunks.append(_chunk(TEXT_ID, occurrence.payload, -1))
			text_orders.append(int(occurrence.source_order))

	for id in ["PICT", "TMPL"]:
		if entries.has(id):
			document.chunks.append(_chunk(id, entries[id], -1))

	document.sc2x_compat_labels = entries.XLAB
	document.sc2x_extensions = {"XMIC": joined.xmic_extension, "XTHG": joined.xthg_extension}
	document.sc2x_object_ids = joined.object_ids
	document.sc2x_object_names = joined.object_names
	document.sc2x_object_kinds = _kinds(joined.xthg)
	document.sc2x_text_orders = text_orders
	document.sc2x_preserved = preserved
	document.sc2x_extra_entries = extras
	document.rebuild_chunk_cache()

	return true


# The raw entries of a working document, in archive order. This also stores
# the new identity counters and object identities in the document.
static func entries(document: Sc2File) -> EntriesResult:
	if document == null or not document.is_sc2x():
		return EntriesResult.failure("The document is not an SC2X version 4 working document")

	var edge := document.map_size

	for id in REQUIRED_ENTRIES:
		if document.find_chunk(id) == null:
			return EntriesResult.failure("City data has no %s" % id)

	var things := document.find_chunk("XTHG").decoded_payload
	var identity := _reconciled_identities(document, things)
	var metadata := document.sc2x_metadata
	var split: Dictionary = NativeSc2x.split({
		"edge": edge,
		"xtxt": document.find_chunk("XTXT").decoded_payload,
		"xmic": document.find_chunk("XMIC").decoded_payload,
		"xthg": things,
		"labels": document.find_chunk("XLAB").decoded_payload,
		"wide_labels": true,
		"signs": document.find_chunk("XSGN").decoded_payload,
		"object_ids": identity.ids,
		"object_names": identity.names,
		"next_sign_id": metadata.next_sign_id,
		"next_object_id": metadata.next_object_id,
		"xmic_extension": document.sc2x_extensions.get("XMIC", PackedByteArray()),
		"xthg_extension": document.sc2x_extensions.get("XTHG", PackedByteArray()),
	})

	if not split.ok:
		return EntriesResult.failure(str(split.error))

	document.sc2x_object_ids = split.object_ids
	document.sc2x_object_names = identity.names
	document.sc2x_object_kinds = _kinds(things)
	metadata.next_sign_id = int(split.next_sign_id)
	metadata.next_object_id = int(split.next_object_id)
	metadata.mayor_name = Sc2xMetadata.limit_name(split.mayor_name)

	for team in Sc2xMetadata.TEAM_COUNT:
		metadata.stadium_teams[team] = Sc2xMetadata.limit_name(split.team_names[team])

	if metadata.city_name.is_empty():
		metadata.city_name = "New City"

	var result := EntriesResult.new()
	result.ok = true
	result.issues = split.issues
	result.add(METADATA_ENTRY, metadata.to_bytes())
	var structures: Dictionary = split.entries

	for id in REQUIRED_ENTRIES:
		match id:
			"XTXT", "XMIC", "XTHG", "XSGN":
				result.add(entry_name(id), structures[id])
			"XLAB":
				result.add(entry_name(id), document.sc2x_compat_labels)
			_:
				result.add(entry_name(id), document.find_chunk(id).decoded_payload)

	var scenario := document.find_chunk("SCEN")

	if scenario != null:
		result.add(entry_name("SCEN"), scenario.decoded_payload)

	var occurrences := []
	var text_index := 0

	for chunk in document.chunks:
		if chunk.chunk_id != TEXT_ID:
			continue

		var order := text_index

		if document.sc2x_text_orders.size() > text_index:
			order = document.sc2x_text_orders[text_index]

		occurrences.append({"source_order": order, "source_occurrence": text_index, "payload": chunk.decoded_payload})
		text_index += 1

	if not occurrences.is_empty():
		result.add(entry_name(TEXT_ID), NativeSc2x.encode_text(occurrences))

	for id in ["PICT", "TMPL"]:
		var chunk := document.find_chunk(id)

		if chunk != null:
			result.add(entry_name(id), chunk.decoded_payload)

	var framed := []

	for record in document.sc2x_preserved:
		if str(record.get("entry", "")).is_empty():
			framed.append(record)

	if not framed.is_empty():
		var encoded: Dictionary = NativeSc2x.encode_chunks(framed)

		if not encoded.ok:
			return EntriesResult.failure("CUNK.bin: " + str(encoded.error))

		result.add(entry_name("CUNK"), encoded.data)

	for record in document.sc2x_preserved:
		if not str(record.get("entry", "")).is_empty():
			result.add(record.entry, record.payload)

	for name in document.sc2x_extra_entries:
		result.add(name, document.sc2x_extra_entries[name])

	for name in result.order:
		var id := name.trim_suffix(ENTRY_SUFFIX)
		var error := str(NativeSc2x.validate_entry(id, result.members[name], edge)) if name.ends_with(ENTRY_SUFFIX) else ""

		if not error.is_empty():
			return EntriesResult.failure("%s: %s" % [name, error])

	return result


static func encode(document: Sc2File) -> BinaryResult:
	var prepared := entries(document)

	if not prepared.ok:
		return BinaryResult.failure(prepared.error)

	var archive := ZipArchive.encode(prepared.order, prepared.members, MAX_ARCHIVE_BYTES, MAX_DATA_BYTES, true)

	if not archive.ok:
		return BinaryResult.failure(archive.error)

	var result := BinaryResult.new()
	result.ok = true
	result.data = archive.bytes

	return result


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

	if source.is_sc2x():
		return ConversionResult.failure("The source city is already an SC2X version 4 document")

	var edge := source.map_size
	var limits := profile(edge)

	if limits.is_empty():
		return ConversionResult.failure("No SC2X profile exists for a %d tile map" % edge)

	var working := source.duplicate_document()

	if not working.enable_full_resolution_maps():
		return ConversionResult.failure("Cannot expand the data maps: city data is incomplete")

	for id in REQUIRED_ENTRIES:
		if id != "XSGN" and working.find_chunk(id) == null:
			return ConversionResult.failure("City data has no %s" % id)

	var split: Dictionary = NativeSc2x.split({
		"edge": edge,
		"xtxt": working.find_chunk("XTXT").decoded_payload,
		"xmic": working.find_chunk("XMIC").decoded_payload,
		"xthg": working.find_chunk("XTHG").decoded_payload,
		"labels": working.find_chunk("XLAB").decoded_payload,
		"wide_labels": false,
		"next_sign_id": 1,
		"next_object_id": 1,
		"facility_capacity": limits.facilities,
		"thing_capacity": limits.things,
		"sign_capacity": limits.signs,
		"trim_free_tail": fresh,
	})

	if not split.ok:
		return ConversionResult.failure(str(split.error))

	var metadata := Sc2xMetadata.new()
	metadata.map_size = edge
	metadata.city_name = Sc2xMetadata.limit_name(source.city_name().strip_edges())

	if metadata.city_name.is_empty():
		metadata.city_name = Sc2xMetadata.limit_name(fallback_name) if not fallback_name.is_empty() else "New City"

	metadata.mayor_name = Sc2xMetadata.limit_name(split.mayor_name)

	for team in Sc2xMetadata.TEAM_COUNT:
		metadata.stadium_teams[team] = Sc2xMetadata.limit_name(split.team_names[team])

	metadata.next_sign_id = int(split.next_sign_id)
	metadata.next_object_id = int(split.next_object_id)
	metadata.legacy = _legacy_record(source)
	var preserved: Array[Dictionary] = []
	var seen: Dictionary[String, int] = {}
	var text_orders := PackedInt64Array()
	var text_payloads: Array[PackedByteArray] = []
	var scenario := PackedByteArray()
	var template := PackedByteArray()
	var picture := PackedByteArray()
	var result := ConversionResult.new()
	result.issues = split.issues

	for order in source.chunks.size():
		var chunk := source.chunks[order]
		var id := chunk.chunk_id
		var occurrence: int = seen.get(id, 0)
		seen[id] = occurrence + 1

		if id == TEXT_ID:
			text_orders.append(order)
			text_payloads.append(chunk.decoded_payload)
			continue

		if id == "CNAM" and occurrence == 0:
			continue

		if id in SINGLETONS and occurrence == 0:
			match id:
				"SCEN":
					scenario = chunk.decoded_payload
				"TMPL":
					template = chunk.decoded_payload
				"PICT":
					picture = chunk.decoded_payload

			continue

		var known := id in SINGLETONS
		preserved.append({
			"chunk_id": id, "occurrence": occurrence, "source_order": order,
			"flags": 0 if known else CHUNK_STORED,
			"payload": chunk.decoded_payload if known else chunk.stored_payload,
			"entry": "",
		})

	# an unknown chunk with one occurrence and a safe name keeps its own entry
	for record in preserved:
		if int(record.flags) == CHUNK_STORED and int(seen[record.chunk_id]) == 1 and is_safe_chunk_id(record.chunk_id):
			record.entry = entry_name(record.chunk_id)

	if not scenario.is_empty():
		var upgraded: Dictionary = NativeSc2x.upgrade_scenario(scenario)

		if not upgraded.ok:
			return ConversionResult.failure("SCEN: " + str(upgraded.error))

		scenario = upgraded.data

		if not template.is_empty():
			var upgraded_template: PackedByteArray = NativeSc2x.upgrade_template(template)

			if upgraded_template.is_empty():
				preserved.append({
					"chunk_id": "TMPL", "occurrence": 0, "source_order": source.chunks.size(), "flags": CHUNK_SUPERSEDED,
					"payload": template, "entry": "",
				})
				result.issues.append("TMPL has descriptors that SCEN schema 2 does not use; it was kept as superseded data")

			template = upgraded_template
	elif not template.is_empty():
		preserved.append({
			"chunk_id": "TMPL", "occurrence": 0, "source_order": source.chunks.size(), "flags": CHUNK_SUPERSEDED,
			"payload": template, "entry": "",
		})
		template = PackedByteArray()

	preserved.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.source_order) < int(b.source_order))
	var entries_by_id: Dictionary[String, PackedByteArray] = {}

	for id in REQUIRED_ENTRIES:
		if id != "XSGN":
			entries_by_id[id] = working.find_chunk(id).decoded_payload

	entries_by_id.merge(split.entries, true)
	var joined: Dictionary = NativeSc2x.join({
		"edge": edge, "XTXT": entries_by_id.XTXT, "XMIC": entries_by_id.XMIC, "XTHG": entries_by_id.XTHG,
		"mayor_name": metadata.mayor_name, "team_names": metadata.stadium_teams,
	})

	if not joined.ok:
		return ConversionResult.failure(str(joined.error))

	var document := Sc2File.new()
	document.map_size = edge
	document.large_version = 4
	document.source_path = ""
	document.sc2x_metadata = metadata

	for id in REQUIRED_ENTRIES:
		var data: PackedByteArray = entries_by_id[id]

		match id:
			"XTXT":
				data = joined.xtxt
			"XMIC":
				data = joined.xmic
			"XTHG":
				data = joined.xthg
			"XLAB":
				data = joined.labels

		document.chunks.append(_chunk(id, data, _fixed_size(id, edge, data)))

	if not scenario.is_empty():
		document.chunks.append(_chunk("SCEN", scenario, -1))

	for payload in text_payloads:
		document.chunks.append(_chunk(TEXT_ID, payload, -1))

	if not picture.is_empty():
		document.chunks.append(_chunk("PICT", picture, -1))

	if not template.is_empty():
		document.chunks.append(_chunk("TMPL", template, -1))

	document.sc2x_compat_labels = split.residual_labels
	document.sc2x_object_ids = joined.object_ids
	document.sc2x_object_names = joined.object_names
	document.sc2x_object_kinds = _kinds(joined.xthg)
	document.sc2x_text_orders = text_orders
	document.sc2x_preserved = preserved
	document.rebuild_chunk_cache()
	result.ok = true
	result.document = document

	return result


# A fresh working document of `edge` tiles with the starting values of a new city
static func create_empty(edge: int, city_name := "New City") -> ConversionResult:
	# per-tile data maps first, so that a resize makes empty full-size maps
	var template := EmptyCityTemplate.create(128)
	template.enable_full_resolution_maps()

	if edge != 128 and not template.resize_empty_map(edge):
		return ConversionResult.failure("Unsupported map size %d" % edge)

	return from_new_city(template, city_name, "")


# A working document from a city that the new-city tools made in the legacy
# layout. A new city has no import data, so it keeps no legacy record and
# starts with an empty compatibility label table.
static func from_new_city(source: Sc2File, city_name: String, mayor_name: String) -> ConversionResult:
	var converted := from_legacy(source, "", true)

	if not converted.ok:
		return converted

	var document := converted.document
	var metadata := document.sc2x_metadata
	metadata.city_name = Sc2xMetadata.limit_name(city_name.strip_edges()) if not city_name.strip_edges().is_empty() else "New City"

	if not mayor_name.strip_edges().is_empty():
		metadata.mayor_name = Sc2xMetadata.limit_name(mayor_name.strip_edges())
		var labels := document.find_chunk("XLAB").decoded_payload.duplicate()
		Sc2LabelLayout.write(labels, 0, metadata.mayor_name)
		document.find_chunk("XLAB").set_decoded_payload(labels)
		document.find_chunk("XLAB").is_dirty = false

	metadata.legacy = {}
	document.sc2x_compat_labels.resize(FRESH_LABEL_TABLE_SIZE)
	document.sc2x_compat_labels.fill(0)
	document.sc2x_preserved.clear()
	document.sc2x_text_orders.clear()

	return converted


static func _chunk(id: String, data: PackedByteArray, fixed_size: int) -> Sc2Chunk:
	var chunk := Sc2Chunk.new()
	chunk.chunk_id = id
	chunk.decoded_payload = data
	chunk.stored_payload = PackedByteArray()
	chunk.expected_decoded_size = fixed_size
	chunk.is_compressed = false

	return chunk


# the payload size that a chunk keeps for its document; -1 lets it vary
static func _fixed_size(id: String, edge: int, data: PackedByteArray) -> int:
	if id == "XTXT":
		return edge * edge * 2

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


static func _check_sizes(entries: Dictionary[String, PackedByteArray], edge: int) -> String:
	for id in DENSE_ENTRIES:
		var expected := edge * edge * DENSE_ENTRIES[id]

		if entries[id].size() != expected:
			return "%s has %d bytes; a %d tile map needs %d" % [entry_name(id), entries[id].size(), edge, expected]

	if entries.MISC.size() != Sc2MiscLayout.SIZE:
		return "MISC.bin has %d bytes; expected %d" % [entries.MISC.size(), Sc2MiscLayout.SIZE]

	if entries.XGRP.size() != Sc2GraphLayout.SIZE:
		return "XGRP.bin has %d bytes; expected %d" % [entries.XGRP.size(), Sc2GraphLayout.SIZE]

	if entries.XLAB.size() < FRESH_LABEL_TABLE_SIZE or entries.XLAB.size() % Sc2LabelLayout.RECORD_SIZE != 0:
		return "XLAB.bin must be a table of 25-byte labels with at least 256 records"

	for id in ["XSGN", "SCEN", "TEXT", "TMPL", "CUNK"]:
		if entries.has(id):
			var error := str(NativeSc2x.validate_entry(id, entries[id], edge))

			if not error.is_empty():
				return "%s: %s" % [entry_name(id), error]

	if entries.has("TMPL") and not entries.has("SCEN"):
		return "TMPL.bin describes SCEN.bin, but the archive has no SCEN.bin"

	if entries.has("PICT"):
		var error := _picture_error(entries.PICT)

		if not error.is_empty():
			return error

	return ""


static func _picture_error(data: PackedByteArray) -> String:
	if data.size() < 8 or BinaryData.read_u32_be(data, 0) != 0x80000000:
		return "PICT.bin header is invalid"

	var width := data.decode_u16(4)
	var height := data.decode_u16(6)
	var pixels := data.size() - 8

	if pixels != width * height and pixels != height * (width + 1):
		return "PICT.bin size does not match its dimensions"

	return ""


static func _kinds(things: PackedByteArray) -> PackedByteArray:
	var count := ThingData.count(things)
	var result := PackedByteArray()
	result.resize(count)

	for record in count:
		result[record] = things[record * Sc2ThingLayout.RECORD_SIZE]

	return result


# A slot keeps its identity and name while it holds the same type of object.
# A freed or reused slot gets a new identity when the city is saved.
static func _reconciled_identities(document: Sc2File, things: PackedByteArray) -> Dictionary:
	var count := ThingData.count(things)
	var ids := PackedInt64Array()
	var names := PackedStringArray()
	ids.resize(count)
	names.resize(count)

	for record in count:
		var kind := int(things[record * Sc2ThingLayout.RECORD_SIZE])
		var same := (
			kind != 0 and record < document.sc2x_object_ids.size() and record < document.sc2x_object_kinds.size()
			and Sc2ThingLayout.identity_kind(document.sc2x_object_kinds[record]) == Sc2ThingLayout.identity_kind(kind)
		)

		if same:
			ids[record] = document.sc2x_object_ids[record]
			names[record] = document.sc2x_object_names[record] if record < document.sc2x_object_names.size() else ""

	return {"ids": ids, "names": names}


# the source container, its chunk order, and CNAM bytes that are not the name
static func _legacy_record(source: Sc2File) -> Dictionary:
	var order := []

	for chunk in source.chunks:
		order.append(chunk.chunk_id)

	var result := {
		"source": {
			"format": "SCLG" if source.is_extended() else "SCDH",
			"version": source.large_version if source.is_extended() else 0,
			"map_size": source.map_size,
			"chunk_order": order,
		},
	}
	var name_chunk := source.find_chunk("CNAM")

	if name_chunk != null:
		var data := name_chunk.decoded_payload
		var end := 1

		while end < data.size() and data[end] != 0:
			end += 1

		result["cnam"] = {"first_byte": int(data[0]) if data.size() > 0 else 0, "trailing_hex": data.slice(mini(end + 1, data.size())).hex_encode()}

	return result


static func _fail(document: Sc2File, message: String) -> bool:
	document.parse_error = message
	document.chunks.clear()
	document.invalidate_chunk_cache()

	return false


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
