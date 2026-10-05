class_name Sc2DataConvert
extends RefCounted
## Convert DOS and Macintosh text and newspaper records to the Windows data files.

# the newspaper record IDs: phrase table bases and counts, phrase offsets, and grammar
const BASES_ID := 1000
const COUNTS_ID := 1001
const OFFSETS_ID := 1002
const GRAMMAR_ID := 1003


class Records extends RefCounted:
	var text: Dictionary[int, PackedByteArray] = {}
	var newspaper: Dictionary[int, PackedByteArray] = {}


# DOS keeps TXT and PPDT records in SC2000.DAT. Windows demos keep .DAT and .IDX pairs.
# A Macintosh application keeps TEXT and DATA resources. The native formats
# library holds the rules; see native/core/assets/src/import/newspaper.rs
static func find_records(source: Sc2ImportSource) -> Records:
	var names := PackedStringArray()
	var kinds := PackedStringArray()
	var ids := PackedInt64Array()
	var sources := PackedStringArray()
	var payloads := []

	for resource in source.resources:
		names.append(resource.name)
		kinds.append(resource.type)
		ids.append(resource.id)
		sources.append(resource.source)
		payloads.append(resource.bytes)

	var found := NativeDataImport.find_records(names, kinds, ids, sources, payloads)
	var records := Records.new()
	records.text = _records(found.text_ids, found.text_payloads)
	records.newspaper = _records(found.newspaper_ids, found.newspaper_payloads)

	return records


# a Windows .IDX file holds a little-endian ID and data offset for each record, in data order
static func indexed_records(data: PackedByteArray, index: PackedByteArray) -> Dictionary[int, PackedByteArray]:
	var found := NativeDataImport.indexed_records(data, index)

	return _records(found.ids, found.payloads)


# DOS, Macintosh, and the Windows 3.x demo use tokens 0x80 to 0x9d often
static func uses_shifted_tokens(records: Dictionary[int, PackedByteArray]) -> bool:
	return NativeDataImport.uses_shifted_tokens(PackedInt64Array(records.keys()), records.values())


# Keep the record layout and phrase offsets. Change only the shifted token bytes, the
# Macintosh quotes, and the base of each empty table
static func windows_newspaper(records: Dictionary[int, PackedByteArray]) -> Dictionary[int, PackedByteArray]:
	var converted := NativeDataImport.windows_newspaper(PackedInt64Array(records.keys()), records.values())

	return _records(converted.ids, converted.payloads)


# The Windows .DAT file holds the records in ID order. Each .IDX record holds a
# little-endian ID and data offset.
static func resource_files(records: Dictionary[int, PackedByteArray]) -> Array[PackedByteArray]:
	var files: Array[PackedByteArray] = []
	files.assign(NativeDataImport.resource_files(PackedInt64Array(records.keys()), records.values()))

	return files


# The 1993 Macintosh demo grammar has no headline ends, so the game cannot use it
static func has_headline_ends(records: Dictionary[int, PackedByteArray]) -> bool:
	return NativeDataImport.has_headline_ends(PackedInt64Array(records.keys()), records.values())


static func _records(ids: PackedInt64Array, payloads: Array) -> Dictionary[int, PackedByteArray]:
	var records: Dictionary[int, PackedByteArray] = {}

	for index in ids.size():
		records[ids[index]] = payloads[index]

	return records
