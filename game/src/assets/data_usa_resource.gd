class_name DataUsaResource
extends RefCounted

const INDEX_RECORD_SIZE := 8
const BASE_RESOURCE_ID := 1000
const COUNT_RESOURCE_ID := 1001
const OFFSET_RESOURCE_ID := 1002
const GRAMMAR_RESOURCE_ID := 1003
const TABLE_ENTRY_COUNT := 250
const PHRASE_COUNT := 2500

var bases := PackedInt32Array()
var counts := PackedInt32Array()
var offsets := PackedInt32Array()
var grammar := PackedByteArray()
var load_error := ""


static func load_path(data_path: String, index_path: String) -> DataUsaResource:
	var result := DataUsaResource.new()
	result._load(data_path, index_path)

	return result


func is_valid() -> bool:
	return load_error.is_empty()


func phrase_bytes(phrase_id: int) -> PackedByteArray:
	if not is_valid() or phrase_id < 0 or phrase_id >= offsets.size():
		return PackedByteArray()

	var start := int(offsets[phrase_id])
	var end := start

	while end < grammar.size() and grammar[end] != 0:
		end += 1

	return grammar.slice(start, end)


func _load(data_path: String, index_path: String) -> void:
	var data := FileAccess.get_file_as_bytes(data_path)

	if data.is_empty():
		load_error = "cannot read DATA_USA data file: %s" % data_path

		return

	var index := FileAccess.get_file_as_bytes(index_path)

	if index.is_empty():
		load_error = "cannot read DATA_USA index file: %s" % index_path

		return

	if index.size() % INDEX_RECORD_SIZE != 0:
		load_error = "DATA_USA index has a partial record"

		return

	var records: Array[Vector2i] = []

	for offset in range(0, index.size(), INDEX_RECORD_SIZE):
		var resource_id := index.decode_u32(offset)
		var data_offset := index.decode_u32(offset + 4)

		if data_offset < 0 or data_offset > data.size():
			load_error = "DATA_USA resource %d has an invalid offset" % resource_id

			return

		if not records.is_empty() and data_offset < records[-1].y:
			load_error = "DATA_USA resource offsets are not ordered"

			return

		records.append(Vector2i(resource_id, data_offset))

	var resources: Dictionary[int, PackedByteArray] = {}

	for record_index in records.size():
		var record := records[record_index]
		var end := records[record_index + 1].y if record_index + 1 < records.size() else data.size()
		resources[record.x] = data.slice(record.y, end)

	for resource_id in [
		BASE_RESOURCE_ID, COUNT_RESOURCE_ID, OFFSET_RESOURCE_ID, GRAMMAR_RESOURCE_ID
	]:
		if not resources.has(resource_id):
			load_error = "DATA_USA resource %d is missing" % resource_id

			return

	var base_bytes: PackedByteArray = resources[BASE_RESOURCE_ID]
	var count_bytes: PackedByteArray = resources[COUNT_RESOURCE_ID]
	var offset_bytes: PackedByteArray = resources[OFFSET_RESOURCE_ID]
	grammar = resources[GRAMMAR_RESOURCE_ID]

	if base_bytes.size() != TABLE_ENTRY_COUNT * 2:
		load_error = "DATA_USA headline-base table has the wrong size"

		return

	if count_bytes.size() != TABLE_ENTRY_COUNT * 2:
		load_error = "DATA_USA headline-count table has the wrong size"

		return

	if offset_bytes.size() != PHRASE_COUNT * 4:
		load_error = "DATA_USA phrase-offset table has the wrong size"

		return

	if grammar.is_empty():
		load_error = "DATA_USA grammar text is empty"

		return

	for offset in range(0, base_bytes.size(), 2):
		bases.append(BinaryData.read_u16_be(base_bytes, offset))
		counts.append(BinaryData.read_u16_be(count_bytes, offset))

	for offset in range(0, offset_bytes.size(), 4):
		offsets.append(BinaryData.read_u32_be(offset_bytes, offset))

	for table_id in TABLE_ENTRY_COUNT:
		if bases[table_id] < 0 or bases[table_id] + counts[table_id] > PHRASE_COUNT:
			load_error = "DATA_USA phrase table %d is outside the offset table" % table_id

			return

	for phrase_id in PHRASE_COUNT:
		var phrase_offset := int(offsets[phrase_id])

		if phrase_offset < 0 or phrase_offset >= grammar.size():
			load_error = "DATA_USA phrase %d has an invalid text offset" % phrase_id

			return

		var terminator := phrase_offset

		while terminator < grammar.size() and grammar[terminator] != 0:
			terminator += 1

		if terminator == grammar.size():
			load_error = "DATA_USA phrase %d is not terminated" % phrase_id

			return
