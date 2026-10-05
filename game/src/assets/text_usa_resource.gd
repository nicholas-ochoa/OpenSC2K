class_name TextUsaResource
extends RefCounted
## The text resources of TEXT_USA.DAT and its index.


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
		var empty_result := Result.new()
		empty_result.ok = true
		empty_result.strings = result
		empty_result.error = ""

		return empty_result

	var data := FileAccess.get_file_as_bytes(data_path)

	if data.is_empty():
		return _failure("cannot read text data file: %s" % data_path)

	var index := FileAccess.get_file_as_bytes(index_path)

	if index.is_empty():
		return _failure("cannot read text index file: %s" % index_path)

	# the native formats library reads the records; see native/core/assets/src/text_usa.rs
	var loaded := NativeDataImport.text_resources(data, index, PackedInt64Array(Array(resource_ids)))

	if not loaded.ok:
		return _failure(loaded.error)

	var texts: PackedStringArray = loaded.texts
	var loaded_ids: PackedInt64Array = loaded.ids

	for position in loaded_ids.size():
		result[loaded_ids[position]] = texts[position]

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


class Result extends RefCounted:
	var ok := false
	var error := ""
	var strings: Dictionary[int, String] = {}
