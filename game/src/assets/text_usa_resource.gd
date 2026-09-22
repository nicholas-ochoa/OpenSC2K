class_name TextUsaResource
extends RefCounted

const INDEX_RECORD_SIZE := 8


class Result extends RefCounted:
	var ok := false
	var error := ""
	var strings: Dictionary[int, String] = {}


static func load_ids(
	data_path: String, index_path: String, resource_ids: PackedInt32Array
) -> Result:
	var wanted: Dictionary[int, bool] = {}
	var result: Dictionary[int, String] = {}

	for resource_id in resource_ids:
		if resource_id < 0:
			return _failure("text resource ID is negative")

		wanted[resource_id] = true

	if wanted.is_empty():
		var outcome := Result.new()
		outcome.ok = true
		outcome.strings = result
		outcome.error = ""

		return outcome

	var data := FileAccess.get_file_as_bytes(data_path)

	if data.is_empty():
		return _failure("cannot read text data file: %s" % data_path)

	var index := FileAccess.get_file_as_bytes(index_path)

	if index.is_empty():
		return _failure("cannot read text index file: %s" % index_path)

	if index.size() % INDEX_RECORD_SIZE != 0:
		return _failure("text index has a partial record")

	var records: Array[Vector2i] = []

	for offset in range(0, index.size(), INDEX_RECORD_SIZE):
		var resource_id := index.decode_u32(offset)
		var data_offset := index.decode_u32(offset + 4)

		if data_offset < 0 or data_offset > data.size():
			return _failure("text resource %d has an invalid offset" % resource_id)

		if not records.is_empty() and data_offset < records[-1].y:
			return _failure("text resource offsets are not ordered")

		records.append(Vector2i(resource_id, data_offset))

	for record_index in records.size():
		var record := records[record_index]

		if not wanted.has(record.x):
			continue

		var end := (
			records[record_index + 1].y
			if record_index + 1 < records.size()
			else data.size()
		)

		if end < record.y or end > data.size():
			return _failure("text resource %d has an invalid length" % record.x)

		result[record.x] = data.slice(record.y, end).get_string_from_ascii()

	if result.size() != wanted.size():
		return _failure("one or more requested text resources are missing")

	var outcome := Result.new()
	outcome.ok = true
	outcome.strings = result
	outcome.error = ""

	return outcome


static func _failure(message: String) -> Result:
	var outcome := Result.new()
	outcome.ok = false
	outcome.error = message

	return outcome
