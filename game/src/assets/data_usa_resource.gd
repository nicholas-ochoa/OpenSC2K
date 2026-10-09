class_name DataUsaResource
extends RefCounted
## The newspaper grammar of DATA_USA.DAT and its index. The native simulation
## library reads it; see native/core/assets/src/data_usa.rs.

const TABLE_ENTRY_COUNT := 250
const PHRASE_COUNT := 2500

var bases := PackedInt32Array()
var counts := PackedInt32Array()
var offsets := PackedInt32Array()
var grammar := PackedByteArray()
var is_johab := false
var load_error := ""


static func load_path(data_path: String, index_path: String) -> DataUsaResource:
	var result := DataUsaResource.new()
	result._load(data_path, index_path)

	return result


func is_valid() -> bool:
	return load_error.is_empty()


func _load(data_path: String, index_path: String) -> void:
	var data := FileAccess.get_file_as_bytes(data_path)

	if data.is_empty():
		load_error = "cannot read DATA_USA data file: %s" % data_path

		return

	var index := FileAccess.get_file_as_bytes(index_path)

	if index.is_empty():
		load_error = "cannot read DATA_USA index file: %s" % index_path

		return

	var parsed := NativeNewspaper.parse_data_usa(data, index)

	if not parsed.ok:
		load_error = parsed.error

		return

	bases = parsed.bases
	counts = parsed.counts
	offsets = parsed.offsets
	grammar = parsed.grammar
	is_johab = parsed.is_johab
