class_name ScurkProject
extends RefCounted

const Mif = preload("res://src/assets/scurk_mif.gd")
const Archive = preload("res://src/tools/scurk/scurk_project_archive.gd")
const Limits = preload("res://src/tools/scurk/scurk_project_limits.gd")
const VERSION := Archive.VERSION
const EXTENSION := "scurk"
const MAX_FILE_BYTES := Limits.MAX_FILE_BYTES
const MAX_DATA_BYTES := Limits.MAX_DATA_BYTES
const MAX_MIF_BYTES := Limits.MAX_MIF_BYTES
const MAX_DOCUMENTS := Limits.MAX_DOCUMENTS
const MAX_LAYERS := Limits.MAX_LAYERS
const MAX_STAMPS := Limits.MAX_STAMPS
const MAX_CHECKPOINTS := Limits.MAX_CHECKPOINTS
const MAX_WIDTH := Limits.MAX_WIDTH
const MAX_HEIGHT := Limits.MAX_HEIGHT
const MAX_RESOURCES := Limits.MAX_RESOURCES
const STATE_FIELDS := ["current_mif", "documents", "metadata", "resources", "stamps"]
const PROJECT_FIELDS := STATE_FIELDS + ["original_mif", "revision", "checkpoints"]

class Result extends RefCounted:
	var ok := false
	var error := ""
	var bytes := PackedByteArray()
	var project: ScurkProject

	static func failure(message: String) -> Result:
		var result := Result.new()
		result.error = message
		return result


var palette_rgb := PackedByteArray()
var original_mif := PackedByteArray()
var current_mif := PackedByteArray()
var metadata: Dictionary = {}
var resources: Dictionary = {}
var documents: Dictionary = {}
var stamps: Array[Dictionary] = []
var checkpoints: Array[Dictionary] = []
var extra_fields: Dictionary = {}
var revision := 0


func initialize(mif_bytes: PackedByteArray) -> Result:
	if not _valid_mif(mif_bytes):
		return Result.failure("The project tile set is invalid.")

	palette_rgb.clear()
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

	return flatten_range(key, 0, documents[key].layers.size())


# The range includes first and excludes last. Invalid keys or bounds return no pixels.
# A valid empty range returns a transparent buffer with the document dimensions.
func flatten_range(key: String, first: int, last: int) -> PackedInt32Array:
	if not documents.has(key):
		return PackedInt32Array()

	var document: Dictionary = documents[key]
	if first < 0 or last < first or last > document.layers.size():
		return PackedInt32Array()

	var pixels := PackedInt32Array()
	pixels.resize(int(document.width) * int(document.height))
	pixels.fill(-1)
	for layer_index in range(first, last):
		var layer: Dictionary = document.layers[layer_index]
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
	if not _valid_state(state) or _state_data_size(state) > MAX_DATA_BYTES:
		return false
	_replace_state(state)
	revision += 1
	return true


func to_dictionary() -> Dictionary:
	var record := extra_fields.duplicate(true)
	record.merge(snapshot(), true)
	record.original_mif = original_mif.duplicate()
	record.revision = revision
	record.checkpoints = checkpoints.duplicate(true)
	return record


func to_bytes() -> Result:
	var record := to_dictionary()
	var checked := from_dictionary(record, palette_rgb)
	if not checked.ok:
		return checked
	var encoded := Archive.encode(record, palette_rgb)
	if not encoded.ok:
		return Result.failure(encoded.error)
	checked = from_bytes(encoded.bytes)
	if not checked.ok:
		return checked
	var result := _success()
	result.bytes = encoded.bytes
	return result


static func from_dictionary(record: Dictionary, rgb := PackedByteArray()) -> Result:
	if not rgb.is_empty() and rgb.size() != Sc2Palette.RGB_BYTES:
		return Result.failure("The project palette is invalid.")
	if not _integer_in(record.get("revision"), 0, 9007199254740991):
		return Result.failure("The project revision is invalid.")
	if not record.get("original_mif") is PackedByteArray or not _valid_mif(record.original_mif):
		return Result.failure("The original project tile set is invalid.")
	if not _valid_state(record, 0, true):
		return Result.failure("The project data is invalid.")
	var history: Variant = record.get("checkpoints", [])
	if not history is Array or history.size() > MAX_CHECKPOINTS:
		return Result.failure("The project history is invalid.")
	var data_size: int = record.original_mif.size() + _state_data_size(record)
	if data_size > MAX_DATA_BYTES:
		return Result.failure("The project exceeds the resource size limit.")
	for value: Variant in history:
		if not value is Dictionary or not _valid_name(value.get("name", "")) or not _json_fields(value, ["snapshot"], 2):
			return Result.failure("The project checkpoint is invalid.")
		if not value.get("created", "") is String or not _integer_in(value.get("revision"), 0, 9007199254740991):
			return Result.failure("The project checkpoint metadata is invalid.")
		if not value.get("snapshot") is Dictionary or not _valid_state(value.snapshot, 3):
			return Result.failure("The project checkpoint data is invalid.")
		data_size += _state_data_size(value.snapshot)
		if data_size > MAX_DATA_BYTES:
			return Result.failure("The project exceeds the resource size limit.")

	var project := ScurkProject.new()
	project.palette_rgb = rgb.duplicate()
	project.original_mif = record.original_mif.duplicate()
	project._replace_state(record)
	for value: Dictionary in history:
		var entry := value.duplicate(true)
		entry.snapshot = _copy_state(value.snapshot)
		project.checkpoints.append(entry)
	project.revision = int(record.revision)
	project.extra_fields = record.duplicate(true)
	for key: String in PROJECT_FIELDS:
		project.extra_fields.erase(key)
	return project._success()


static func from_bytes(bytes: PackedByteArray) -> Result:
	if bytes.size() > MAX_FILE_BYTES:
		return Result.failure("The project exceeds the file size limit.")
	var decoded := Archive.decode(bytes)
	if not decoded.ok:
		return Result.failure(decoded.error)
	return from_dictionary(decoded.record, decoded.palette_rgb)


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


func _replace_state(state: Dictionary) -> void:
	var copied := _copy_state(state)
	var copied_stamps: Array[Dictionary] = []
	copied_stamps.assign(copied.stamps)
	current_mif = copied.current_mif
	documents = copied.documents
	metadata = copied.metadata
	resources = copied.resources
	stamps = copied_stamps


# Validate first. Copy buffers without serialization and normalize JSON integer fields.
static func _copy_state(state: Dictionary) -> Dictionary:
	var copied := {
		"current_mif": state.current_mif.duplicate(),
		"documents": state.get("documents", {}).duplicate(true),
		"metadata": state.get("metadata", {}).duplicate(true),
		"resources": state.get("resources", {}).duplicate(true),
		"stamps": state.get("stamps", []).duplicate(true),
	}
	for document: Dictionary in copied.documents.values():
		document.width = int(document.width)
		document.height = int(document.height)
		document.active = int(document.active)
	for stamp: Dictionary in copied.stamps:
		stamp.width = int(stamp.width)
		stamp.height = int(stamp.height)
		stamp.spacing = int(stamp.spacing)
	return copied


# Pixels count as signed 16-bit values in the logical budget, independent of PNG size.
static func _state_data_size(state: Dictionary) -> int:
	var size: int = state.current_mif.size()
	for document: Dictionary in state.get("documents", {}).values():
		size += document.original_pixels.size() * 2
		for layer: Dictionary in document.layers:
			size += layer.pixels.size() * 2
	for bytes: PackedByteArray in state.get("resources", {}).values():
		size += bytes.size()
	for stamp: Dictionary in state.get("stamps", []):
		size += stamp.pixels.size() * 2
	return size


static func _valid_state(state: Dictionary, depth := 0, project_record := false) -> bool:
	if not _json_fields(state, PROJECT_FIELDS if project_record else STATE_FIELDS, depth):
		return false
	if not state.get("current_mif") is PackedByteArray or not _valid_mif(state.current_mif):
		return false
	if not state.get("metadata", {}) is Dictionary or not _json_safe(state.get("metadata", {}), depth + 1):
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
		if not _json_fields(document, ["original_pixels", "layers"], depth + 2):
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
			if not _json_fields(layer, ["pixels"], depth + 4):
				return false
			if not layer.get("visible") is bool or not layer.get("locked") is bool:
				return false
			if not layer.get("pixels") is PackedInt32Array or not _valid_pixels(layer.pixels, document.width, document.height):
				return false
	var resource_map: Variant = state.get("resources", {})
	if not resource_map is Dictionary or resource_map.size() > MAX_RESOURCES:
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
		if not _json_fields(stamp, ["pixels"], depth + 2):
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
	return Limits.valid_dimensions(width, height)


static func _integer_in(value: Variant, minimum: int, maximum: int) -> bool:
	return Limits.integer_in(value, minimum, maximum)


static func _valid_name(value: Variant) -> bool:
	return value is String and not value.strip_edges().is_empty() and value.length() <= 256


static func _valid_mif(bytes: PackedByteArray) -> bool:
	return not bytes.is_empty() and bytes.size() <= MAX_MIF_BYTES and Mif.new().parse(bytes)


static func _json_fields(record: Dictionary, handled_fields: Array, depth: int) -> bool:
	if depth > 32:
		return false
	for key: Variant in record:
		if not (key is String or key is StringName):
			return false
		if key not in handled_fields and not _json_safe(record[key], depth + 1):
			return false
	return true


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


func _success() -> Result:
	var result := Result.new()
	result.ok = true
	result.project = self
	return result
