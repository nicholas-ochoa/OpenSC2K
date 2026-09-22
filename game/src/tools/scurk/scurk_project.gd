class_name ScurkProject
extends RefCounted

const Mif = preload("res://src/assets/scurk_mif.gd")
const MAGIC := "SCURK-PROJECT\n"
const VERSION := 1
const EXTENSION := "scurk"
const MAX_FILE_BYTES := 128 * 1024 * 1024
const MAX_DATA_BYTES := 64 * 1024 * 1024
const MAX_MIF_BYTES := 16 * 1024 * 1024
const MAX_DOCUMENTS := 1500
const MAX_LAYERS := 32
const MAX_STAMPS := 256
const MAX_CHECKPOINTS := 24
const MAX_WIDTH := 128
const MAX_HEIGHT := 256
static var _base64_pattern := RegEx.create_from_string("^[A-Za-z0-9+/]*={0,2}$")

class Result extends RefCounted:
	var ok := false
	var error := ""
	var bytes := PackedByteArray()
	var project: ScurkProject

	static func failure(message: String) -> Result:
		var result := Result.new()
		result.error = message
		return result


var original_mif := PackedByteArray()
var current_mif := PackedByteArray()
var metadata: Dictionary = {}
var resources: Dictionary = {}
var documents: Dictionary = {}
var stamps: Array[Dictionary] = []
var checkpoints: Array[Dictionary] = []
var extra_fields: Dictionary = {}
var revision := 0
var parse_error := ""
var _decoded_bytes := 0


func initialize(mif_bytes: PackedByteArray) -> Result:
	if not _valid_mif(mif_bytes):
		return Result.failure("The project tile set is invalid.")

	original_mif = mif_bytes.duplicate()
	current_mif = mif_bytes.duplicate()
	metadata.clear()
	resources.clear()
	documents.clear()
	stamps.clear()
	checkpoints.clear()
	extra_fields.clear()
	revision = 0
	return _success()


func set_current_mif(mif_bytes: PackedByteArray) -> bool:
	if mif_bytes == current_mif:
		return true
	if not _valid_mif(mif_bytes):
		return false

	current_mif = mif_bytes.duplicate()
	revision += 1
	return true


func ensure_document(key: String, pixels: PackedInt32Array, width := 128, height := 256) -> bool:
	if documents.has(key):
		return int(documents[key].width) == width and int(documents[key].height) == height
	if key.is_empty() or key.length() > 128 or documents.size() >= MAX_DOCUMENTS:
		return false
	if not _valid_pixels(pixels, width, height):
		return false

	documents[key] = {
		"width": width, "height": height, "active": 0,
		"original_pixels": pixels.duplicate(),
		"layers": [_new_layer("Root", pixels)],
	}
	return true


func active_pixels(key: String) -> PackedInt32Array:
	var layer := _active_layer(key)
	return layer.pixels.duplicate() if not layer.is_empty() else PackedInt32Array()


func active_layer_locked(key: String) -> bool:
	var layer := _active_layer(key)
	return layer.is_empty() or bool(layer.locked)


func set_active_pixels(key: String, pixels: PackedInt32Array) -> bool:
	var layer := _active_layer(key)
	if layer.is_empty() or bool(layer.locked):
		return false

	var document: Dictionary = documents[key]
	if not _valid_pixels(pixels, int(document.width), int(document.height)):
		return false
	if layer.pixels != pixels:
		layer.pixels = pixels.duplicate()
		revision += 1
	return true


func flatten(key: String) -> PackedInt32Array:
	if not documents.has(key):
		return PackedInt32Array()

	var document: Dictionary = documents[key]
	var pixels := PackedInt32Array()
	pixels.resize(int(document.width) * int(document.height))
	pixels.fill(-1)
	for layer: Dictionary in document.layers:
		if not bool(layer.visible):
			continue
		var source: PackedInt32Array = layer.pixels
		for index in pixels.size():
			if source[index] >= 0:
				pixels[index] = source[index]
	return pixels


func add_layer(key: String, name := "Layer") -> int:
	if not documents.has(key):
		return -1

	var document: Dictionary = documents[key]
	var layers: Array = document.layers
	if layers.size() >= MAX_LAYERS or not _valid_name(name):
		return -1

	var pixels := PackedInt32Array()
	pixels.resize(int(document.width) * int(document.height))
	pixels.fill(-1)
	var index := int(document.active) + 1
	layers.insert(index, _new_layer(name, pixels))
	document.active = index
	revision += 1
	return index


func delete_layer(key: String, index: int) -> bool:
	if not _has_layer(key, index):
		return false
	var document: Dictionary = documents[key]
	var layers: Array = document.layers
	if layers.size() == 1 or bool(layers[index].locked):
		return false

	layers.remove_at(index)
	var active := int(document.active)
	document.active = maxi(0, active - 1) if active >= index else active
	revision += 1
	return true


func rename_layer(key: String, index: int, name: String) -> bool:
	if not _has_layer(key, index) or not _valid_name(name):
		return false
	if documents[key].layers[index].name != name:
		documents[key].layers[index].name = name
		revision += 1
	return true


func select_layer(key: String, index: int) -> bool:
	if not _has_layer(key, index):
		return false
	documents[key].active = index
	return true


func set_layer_visible(key: String, index: int, visible: bool) -> bool:
	return _set_layer_flag(key, index, "visible", visible)


func set_layer_locked(key: String, index: int, locked: bool) -> bool:
	return _set_layer_flag(key, index, "locked", locked)


func move_layer(key: String, index: int, destination: int) -> bool:
	if not _has_layer(key, index) or not _has_layer(key, destination):
		return false
	if index == destination:
		return true

	var document: Dictionary = documents[key]
	var layers: Array = document.layers
	var active := int(document.active)
	var layer: Dictionary = layers[index]
	layers.remove_at(index)
	layers.insert(destination, layer)
	if active == index:
		document.active = destination
	elif index < active and active <= destination:
		document.active = active - 1
	elif destination <= active and active < index:
		document.active = active + 1
	revision += 1
	return true


func add_stamp(name: String, width: int, height: int, pixels: PackedInt32Array, spacing := 1) -> int:
	if stamps.size() >= MAX_STAMPS or not _valid_name(name) or spacing < 1 or spacing > 256:
		return -1
	if not _valid_pixels(pixels, width, height):
		return -1

	stamps.append({"name": name, "width": width, "height": height,
		"pixels": pixels.duplicate(), "spacing": spacing})
	revision += 1
	return stamps.size() - 1


func remove_stamp(index: int) -> bool:
	if index < 0 or index >= stamps.size():
		return false
	stamps.remove_at(index)
	revision += 1
	return true


func add_checkpoint(name: String) -> int:
	if not _valid_name(name):
		return -1
	if checkpoints.size() >= MAX_CHECKPOINTS:
		checkpoints.pop_front()
	checkpoints.append({"name": name, "created": Time.get_datetime_string_from_system(true),
		"revision": revision, "snapshot": snapshot()})
	revision += 1
	return checkpoints.size() - 1


func snapshot() -> Dictionary:
	return {"current_mif": current_mif.duplicate(), "documents": documents.duplicate(true),
		"metadata": metadata.duplicate(true), "resources": resources.duplicate(true),
		"stamps": stamps.duplicate(true)}


func restore_checkpoint(index: int) -> bool:
	if index < 0 or index >= checkpoints.size():
		return false
	return restore_snapshot(checkpoints[index].snapshot)


func restore_snapshot(state: Dictionary) -> bool:
	if not _valid_state(state):
		return false
	var validator := ScurkProject.new()
	var encoded := _encode_snapshot(state)
	if not validator._decode_snapshot(encoded):
		return false
	current_mif = validator.current_mif
	documents = validator.documents
	metadata = validator.metadata
	resources = validator.resources
	stamps = validator.stamps
	revision += 1
	return true


func to_bytes() -> Result:
	if not _valid_mif(original_mif) or not _valid_mif(current_mif):
		return Result.failure("The project tile set is invalid.")
	if not _valid_state(snapshot()) or checkpoints.size() > MAX_CHECKPOINTS:
		return Result.failure("The project data is invalid.")
	var record := extra_fields.duplicate(true)
	record.merge(_encode_snapshot(snapshot()), true)
	record.version = VERSION
	record.original_mif = Marshalls.raw_to_base64(original_mif)
	record.revision = revision
	var history: Array = []
	for checkpoint in checkpoints:
		if not checkpoint.get("snapshot") is Dictionary or not _valid_state(checkpoint.snapshot):
			return Result.failure("The project checkpoint is invalid.")
		var entry := checkpoint.duplicate(true)
		entry.snapshot = _encode_snapshot(checkpoint.snapshot)
		history.append(entry)
	record.checkpoints = history
	if not _json_safe(record):
		return Result.failure("Project metadata must contain only JSON values.")

	var bytes := MAGIC.to_utf8_buffer()
	bytes.append_array(JSON.stringify(record).to_utf8_buffer())
	if bytes.size() > MAX_FILE_BYTES:
		return Result.failure("The project exceeds the file size limit.")
	var checked := from_bytes(bytes)
	if not checked.ok:
		return checked
	var result := _success()
	result.bytes = bytes
	return result


static func from_bytes(bytes: PackedByteArray) -> Result:
	var header := MAGIC.to_utf8_buffer()
	if bytes.size() > MAX_FILE_BYTES or bytes.size() <= header.size():
		return Result.failure("The project file size is invalid.")
	if bytes.slice(0, header.size()) != header:
		return Result.failure("The file is not a SCURK project.")
	var parser := JSON.new()
	if parser.parse(bytes.slice(header.size()).get_string_from_utf8()) != OK:
		return Result.failure("The project JSON is invalid.")
	if not parser.data is Dictionary:
		return Result.failure("The project record is invalid.")
	var record: Dictionary = parser.data
	if not _json_safe(record):
		return Result.failure("The project record contains invalid JSON values.")
	if not _integer_in(record.get("version"), VERSION, VERSION):
		return Result.failure("The project version is not supported.")
	if not _integer_in(record.get("revision"), 0, 9007199254740991):
		return Result.failure("The project revision is invalid.")

	var project := ScurkProject.new()
	project.original_mif = project._decode_blob(record.get("original_mif"), MAX_MIF_BYTES)
	if not project.parse_error.is_empty() or not _valid_mif(project.original_mif):
		return Result.failure("The original project tile set is invalid.")
	if not project._decode_snapshot(record):
		return Result.failure(project.parse_error)
	var history: Variant = record.get("checkpoints", [])
	if not history is Array or history.size() > MAX_CHECKPOINTS:
		return Result.failure("The project history is invalid.")
	for value: Variant in history:
		if not value is Dictionary or not _valid_name(value.get("name", "")):
			return Result.failure("The project checkpoint is invalid.")
		if not value.get("created", "") is String or not _integer_in(value.get("revision"), 0, 9007199254740991):
			return Result.failure("The project checkpoint metadata is invalid.")
		if not value.get("snapshot") is Dictionary:
			return Result.failure("The project checkpoint data is invalid.")
		var historical := ScurkProject.new()
		historical._decoded_bytes = project._decoded_bytes
		if not historical._decode_snapshot(value.snapshot):
			return Result.failure(historical.parse_error)
		project._decoded_bytes = historical._decoded_bytes
		var entry: Dictionary = value.duplicate(true)
		entry.snapshot = historical.snapshot()
		project.checkpoints.append(entry)
	project.revision = int(record.revision)
	project.extra_fields = record.duplicate(true)
	for key in ["version", "original_mif", "current_mif", "revision", "documents", "metadata", "resources", "stamps", "checkpoints"]:
		project.extra_fields.erase(key)
	var result := project._success()
	result.project = project
	return result


static func load_path(path: String) -> Result:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return Result.failure("Cannot open the SCURK project.")
	if file.get_length() > MAX_FILE_BYTES:
		return Result.failure("The project exceeds the file size limit.")
	return from_bytes(file.get_buffer(file.get_length()))


func save_path(path: String) -> Result:
	if path.get_extension().to_lower() != EXTENSION:
		return Result.failure("SCURK projects use the .scurk extension.")
	var encoded := to_bytes()
	if not encoded.ok:
		return encoded
	var absolute := ProjectSettings.globalize_path(path)
	if DirAccess.make_dir_recursive_absolute(absolute.get_base_dir()) != OK:
		return Result.failure("Cannot create the project folder.")
	var temporary := "%s.%d.%d.tmp" % [absolute, OS.get_process_id(), Time.get_ticks_usec()]
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return Result.failure("Cannot write the SCURK project.")
	file.store_buffer(encoded.bytes)
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK or FileAccess.get_file_as_bytes(temporary) != encoded.bytes:
		DirAccess.remove_absolute(temporary)
		return Result.failure("The SCURK project write failed.")
	if DirAccess.rename_absolute(temporary, absolute) != OK:
		DirAccess.remove_absolute(temporary)
		return Result.failure("Cannot replace the SCURK project.")
	return _success()


func autosave_path(path: String) -> Result:
	return save_path(path)


static func recover_path(path: String) -> Result:
	return load_path(path)


func _decode_snapshot(record: Dictionary) -> bool:
	current_mif = _decode_blob(record.get("current_mif"), MAX_MIF_BYTES)
	if not parse_error.is_empty() or not _valid_mif(current_mif):
		return _fail("The current project tile set is invalid.")
	var source_documents: Variant = record.get("documents", {})
	if not source_documents is Dictionary or source_documents.size() > MAX_DOCUMENTS:
		return _fail("The project documents are invalid.")
	for key: Variant in source_documents:
		if not key is String or key.is_empty() or key.length() > 128:
			return _fail("The project document key is invalid.")
		var document := _decode_document(source_documents[key])
		if document.is_empty():
			return false
		documents[key] = document
	var source_metadata: Variant = record.get("metadata", {})
	if not source_metadata is Dictionary or not _json_safe(source_metadata):
		return _fail("The project metadata is invalid.")
	metadata = source_metadata.duplicate(true)
	var source_resources: Variant = record.get("resources", {})
	if not source_resources is Dictionary or source_resources.size() > 1024:
		return _fail("The project resources are invalid.")
	for key: Variant in source_resources:
		if not key is String or key.is_empty() or key.length() > 256:
			return _fail("The project resource name is invalid.")
		resources[key] = _decode_blob(source_resources[key], MAX_MIF_BYTES)
		if not parse_error.is_empty():
			return false
	var source_stamps: Variant = record.get("stamps", [])
	if not source_stamps is Array or source_stamps.size() > MAX_STAMPS:
		return _fail("The project stamps are invalid.")
	for value: Variant in source_stamps:
		if not value is Dictionary or not _valid_name(value.get("name", "")):
			return _fail("The project stamp is invalid.")
		if not _valid_dimensions(value.get("width"), value.get("height")) or not _integer_in(value.get("spacing"), 1, 256):
			return _fail("The project stamp size is invalid.")
		var stamp: Dictionary = value.duplicate(true)
		stamp.pixels = _decode_pixels(value.get("pixels"), int(value.width), int(value.height))
		if not parse_error.is_empty():
			return false
		stamp.width = int(value.width)
		stamp.height = int(value.height)
		stamp.spacing = int(value.spacing)
		stamps.append(stamp)
	return true


func _decode_document(value: Variant) -> Dictionary:
	if not value is Dictionary or not _valid_dimensions(value.get("width"), value.get("height")):
		_fail("The project document size is invalid.")
		return {}
	var source_layers: Variant = value.get("layers")
	if not source_layers is Array or source_layers.is_empty() or source_layers.size() > MAX_LAYERS:
		_fail("The project layers are invalid.")
		return {}
	if not _integer_in(value.get("active"), 0, source_layers.size() - 1):
		_fail("The active project layer is invalid.")
		return {}
	var document: Dictionary = value.duplicate(true)
	document.width = int(value.width)
	document.height = int(value.height)
	document.active = int(value.active)
	document.original_pixels = _decode_pixels(value.get("original_pixels"), document.width, document.height)
	document.layers = []
	for source: Variant in source_layers:
		if not source is Dictionary or not _valid_name(source.get("name", "")):
			_fail("The project layer name is invalid.")
			return {}
		if not source.get("visible") is bool or not source.get("locked") is bool:
			_fail("The project layer state is invalid.")
			return {}
		var layer: Dictionary = source.duplicate(true)
		layer.pixels = _decode_pixels(source.get("pixels"), document.width, document.height)
		document.layers.append(layer)
	if not parse_error.is_empty():
		return {}
	return document


func _decode_pixels(value: Variant, width: int, height: int) -> PackedInt32Array:
	var bytes := _decode_blob(value, width * height * 2)
	var pixels := PackedInt32Array()
	if not parse_error.is_empty():
		return pixels
	if bytes.size() != width * height * 2:
		_fail("The project pixel count is invalid.")
		return pixels
	pixels.resize(width * height)
	for index in pixels.size():
		var color := bytes.decode_s16(index * 2)
		if color < -1 or color > 255:
			_fail("The project palette index is invalid.")
			return PackedInt32Array()
		pixels[index] = color
	return pixels


func _decode_blob(value: Variant, limit: int) -> PackedByteArray:
	if not value is String or value.length() > limit * 2 + 4:
		_fail("The project resource size is invalid.")
		return PackedByteArray()
	if value.is_empty():
		return PackedByteArray()
	if value.length() % 4 != 0 or _base64_pattern.search(value) == null:
		_fail("The project resource encoding is invalid.")
		return PackedByteArray()
	var bytes := Marshalls.base64_to_raw(value)
	if bytes.is_empty() or bytes.size() > limit or _encode_blob(bytes) != value:
		_fail("The project resource encoding is invalid.")
		return PackedByteArray()
	_decoded_bytes += bytes.size()
	if _decoded_bytes > MAX_DATA_BYTES:
		_fail("The project exceeds the resource size limit.")
		return PackedByteArray()
	return bytes


static func _encode_snapshot(state: Dictionary) -> Dictionary:
	var record := state.duplicate(true)
	record.current_mif = _encode_blob(state.get("current_mif", PackedByteArray()))
	var source_documents: Dictionary = state.get("documents", {})
	var encoded_documents: Dictionary = {}
	for key: String in source_documents:
		var document: Dictionary = source_documents[key].duplicate(true)
		document.original_pixels = _encode_pixels(document.original_pixels)
		var layers: Array = []
		for source: Dictionary in document.layers:
			var layer := source.duplicate(true)
			layer.pixels = _encode_pixels(source.pixels)
			layers.append(layer)
		document.layers = layers
		encoded_documents[key] = document
	record.documents = encoded_documents
	var encoded_resources: Dictionary = {}
	var source_resources: Dictionary = state.get("resources", {})
	for key: String in source_resources:
		encoded_resources[key] = _encode_blob(source_resources[key])
	record.resources = encoded_resources
	var encoded_stamps: Array = []
	for source: Dictionary in state.get("stamps", []):
		var stamp := source.duplicate(true)
		stamp.pixels = _encode_pixels(source.pixels)
		encoded_stamps.append(stamp)
	record.stamps = encoded_stamps
	return record


static func _encode_pixels(pixels: PackedInt32Array) -> String:
	var bytes := PackedByteArray()
	bytes.resize(pixels.size() * 2)
	for index in pixels.size():
		bytes.encode_s16(index * 2, pixels[index])
	return _encode_blob(bytes)


static func _encode_blob(bytes: PackedByteArray) -> String:
	return "" if bytes.is_empty() else Marshalls.raw_to_base64(bytes)


static func _valid_state(state: Dictionary) -> bool:
	if not state.get("current_mif") is PackedByteArray or not _valid_mif(state.current_mif):
		return false
	if not state.get("metadata", {}) is Dictionary or not _json_safe(state.get("metadata", {})):
		return false
	var document_map: Variant = state.get("documents", {})
	if not document_map is Dictionary or document_map.size() > MAX_DOCUMENTS:
		return false
	for key: Variant in document_map:
		if not key is String or key.is_empty() or key.length() > 128:
			return false
		var document: Variant = document_map[key]
		if not document is Dictionary or not _valid_dimensions(document.get("width"), document.get("height")):
			return false
		if not document.get("original_pixels") is PackedInt32Array or not _valid_pixels(document.original_pixels, document.width, document.height):
			return false
		var layers: Variant = document.get("layers")
		if not layers is Array or layers.is_empty() or layers.size() > MAX_LAYERS:
			return false
		if not _integer_in(document.get("active"), 0, layers.size() - 1):
			return false
		for layer: Variant in layers:
			if not layer is Dictionary or not _valid_name(layer.get("name", "")):
				return false
			if not layer.get("visible") is bool or not layer.get("locked") is bool:
				return false
			if not layer.get("pixels") is PackedInt32Array or not _valid_pixels(layer.pixels, document.width, document.height):
				return false
	var resource_map: Variant = state.get("resources", {})
	if not resource_map is Dictionary or resource_map.size() > 1024:
		return false
	for key: Variant in resource_map:
		if not key is String or key.is_empty() or key.length() > 256:
			return false
		if not resource_map[key] is PackedByteArray or resource_map[key].size() > MAX_MIF_BYTES:
			return false
	var stamp_list: Variant = state.get("stamps", [])
	if not stamp_list is Array or stamp_list.size() > MAX_STAMPS:
		return false
	for stamp: Variant in stamp_list:
		if not stamp is Dictionary or not _valid_name(stamp.get("name", "")):
			return false
		if not _valid_dimensions(stamp.get("width"), stamp.get("height")) or not _integer_in(stamp.get("spacing"), 1, 256):
			return false
		if not stamp.get("pixels") is PackedInt32Array or not _valid_pixels(stamp.pixels, stamp.width, stamp.height):
			return false
	return true


static func _valid_pixels(pixels: PackedInt32Array, width: int, height: int) -> bool:
	if not _valid_dimensions(width, height) or pixels.size() != width * height:
		return false
	for color in pixels:
		if color < -1 or color > 255:
			return false
	return true


static func _valid_dimensions(width: Variant, height: Variant) -> bool:
	return _integer_in(width, 1, MAX_WIDTH) and _integer_in(height, 1, MAX_HEIGHT)


static func _integer_in(value: Variant, minimum: int, maximum: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floor(float(value)) and value >= minimum and value <= maximum


static func _valid_name(value: Variant) -> bool:
	return value is String and not value.strip_edges().is_empty() and value.length() <= 256


static func _valid_mif(bytes: PackedByteArray) -> bool:
	return not bytes.is_empty() and bytes.size() <= MAX_MIF_BYTES and Mif.new().parse(bytes)


static func _json_safe(value: Variant, depth := 0) -> bool:
	if depth > 32:
		return false
	if value == null or value is bool or value is int or value is String or value is StringName:
		return true
	if value is float:
		return is_finite(value)
	if value is Array:
		for item: Variant in value:
			if not _json_safe(item, depth + 1):
				return false
		return true
	if value is Dictionary:
		for key: Variant in value:
			if not (key is String or key is StringName) or not _json_safe(value[key], depth + 1):
				return false
		return true
	return false


static func _new_layer(name: String, pixels: PackedInt32Array) -> Dictionary:
	return {"name": name, "visible": true, "locked": false, "pixels": pixels.duplicate()}


func _active_layer(key: String) -> Dictionary:
	if not documents.has(key):
		return {}
	var document: Dictionary = documents[key]
	return document.layers[int(document.active)]


func _has_layer(key: String, index: int) -> bool:
	return documents.has(key) and index >= 0 and index < documents[key].layers.size()


func _set_layer_flag(key: String, index: int, flag: String, value: bool) -> bool:
	if not _has_layer(key, index):
		return false
	if documents[key].layers[index][flag] != value:
		documents[key].layers[index][flag] = value
		revision += 1
	return true


func _fail(message: String) -> bool:
	parse_error = message
	return false


func _success() -> Result:
	var result := Result.new()
	result.ok = true
	result.project = self
	return result
