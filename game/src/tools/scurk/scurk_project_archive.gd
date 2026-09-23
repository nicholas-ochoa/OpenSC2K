class_name ScurkProjectArchive
extends RefCounted
## Maps project values to JSON, MIF, and PNG members without a scene or project dependency.

const Limits = preload("res://src/tools/scurk/scurk_project_limits.gd")
const Zip = preload("res://src/tools/scurk/scurk_zip.gd")
const Png = preload("res://src/assets/indexed_png.gd")
const Binary = preload("res://src/formats/binary_data.gd")
const FORMAT := "opensc2k-scurk"
const VERSION := 2
const MANIFEST := "project.json"
const PALETTE := "palette.json"
const MASK_CLEAR := 0
const MASK_OPAQUE := 255
const PNG_HEADER_SIZE := 33
const PNG_WIDTH_OFFSET := 16
const PNG_HEIGHT_OFFSET := 20

class Result extends RefCounted:
	var ok := false
	var error := ""
	var bytes := PackedByteArray()
	var record: Dictionary = {}
	var palette_rgb := PackedByteArray()


class Encoder extends RefCounted:
	var members: Dictionary[String, PackedByteArray] = {}
	var palette: Sc2Palette
	var error := ""

	func pixels(value: PackedInt32Array, width: int, height: int, path: String) -> Dictionary:
		var descriptor := {"image": path}
		var used: Dictionary[int, bool] = {}
		for color in value:
			used[color] = true
		var mask_needed := used.has(-1) and used.size() == Sc2Palette.COLOR_COUNT + 1
		var image_pixels := value
		if mask_needed:
			image_pixels = value.duplicate()
			var mask := PackedInt32Array()
			mask.resize(value.size())
			for index in value.size():
				mask[index] = MASK_CLEAR if value[index] == -1 else MASK_OPAQUE
				if value[index] == -1:
					image_pixels[index] = 0
			var encoded_mask := Png.encode(width, height, mask, Sc2Palette.index_encoding())
			if not encoded_mask.ok:
				error = encoded_mask.error
				return {}
			var mask_path := path.get_basename() + ".mask.png"
			members[mask_path] = encoded_mask.bytes
			descriptor.transparency_mask = mask_path
		var encoded := Png.encode(width, height, image_pixels, palette)
		if not encoded.ok:
			error = encoded.error
			return {}
		members[path] = encoded.bytes
		return descriptor

	func snapshot(value: Dictionary, prefix: String) -> Dictionary:
		var record := value.duplicate(true)
		var mif_path := prefix + "/current.mif"
		members[mif_path] = value.current_mif
		record.current_mif = mif_path
		var keys: Array = value.get("documents", {}).keys()
		keys.sort()
		for index in keys.size():
			var key: String = keys[index]
			var document: Dictionary = record.documents[key]
			var directory := "%s/documents/%04d" % [prefix, index]
			document.original_pixels = pixels(document.original_pixels, int(document.width), int(document.height), directory + "/original.png")
			for layer_index in document.layers.size():
				var layer: Dictionary = document.layers[layer_index]
				layer.pixels = pixels(layer.pixels, int(document.width), int(document.height), "%s/layers/%04d.png" % [directory, layer_index])
		keys = value.get("resources", {}).keys()
		keys.sort()
		for index in keys.size():
			var key: String = keys[index]
			var extension := key.get_extension().to_lower()
			if extension.is_empty() or extension.length() > 10 or not extension.is_valid_identifier():
				extension = "bin"
			var path := "%s/resources/%04d.%s" % [prefix, index, extension]
			members[path] = value.resources[key]
			record.resources[key] = path
		var stamps: Array = record.get("stamps", [])
		for index in stamps.size():
			var stamp: Dictionary = stamps[index]
			stamp.pixels = pixels(stamp.pixels, int(stamp.width), int(stamp.height), "%s/stamps/%04d.png" % [prefix, index])
		return record


class Decoder extends RefCounted:
	var used_members: Dictionary[String, bool] = {}
	var members: Dictionary[String, PackedByteArray] = {}
	var palette_rgb := PackedByteArray()
	var error := ""
	var data_bytes := 0

	func member(path: Variant) -> PackedByteArray:
		if not path is String or not members.has(path):
			error = "A project archive member is missing."
			return PackedByteArray()
		used_members[path] = true
		return members[path]

	func json(path: Variant) -> Dictionary:
		var bytes := member(path)
		if not error.is_empty():
			return {}
		var parser := JSON.new()
		if parser.parse(bytes.get_string_from_utf8()) != OK or not parser.data is Dictionary:
			error = "A project JSON member is invalid."
			return {}
		return parser.data

	func charge(size: int) -> bool:
		data_bytes += size
		if data_bytes > Limits.MAX_DATA_BYTES:
			error = "The project exceeds the resource size limit."
		return error.is_empty()

	func blob(path: Variant) -> PackedByteArray:
		var bytes := member(path)
		if bytes.size() > Limits.MAX_MIF_BYTES:
			error = "A project resource exceeds its size limit."
		if not charge(bytes.size()):
			return PackedByteArray()
		return bytes

	func image(path: Variant, width: int, height: int, colors: PackedByteArray) -> PackedInt32Array:
		var bytes := member(path)
		if not error.is_empty():
			return PackedInt32Array()
		# Check dimensions before the PNG decoder can allocate its output image.
		if bytes.size() < PNG_HEADER_SIZE or Binary.read_u32_be(bytes, PNG_WIDTH_OFFSET) != width or Binary.read_u32_be(bytes, PNG_HEIGHT_OFFSET) != height:
			error = "A project PNG has the wrong dimensions."
			return PackedInt32Array()
		var decoded := Png.decode(bytes)
		if not decoded.ok:
			error = decoded.error
			return PackedInt32Array()
		if decoded.palette.to_rgb_bytes() != colors:
			error = "A project PNG has the wrong ordered palette."
			return PackedInt32Array()
		return decoded.pixels

	func pixels(value: Variant, width: int, height: int) -> PackedInt32Array:
		if not value is Dictionary or not charge(width * height * 2):
			error = "The project pixel record is invalid." if error.is_empty() else error
			return PackedInt32Array()
		for key: Variant in value:
			if key not in ["image", "transparency_mask"]:
				error = "The project pixel record has an unsupported field."
				return PackedInt32Array()
		var result := image(value.get("image"), width, height, palette_rgb)
		if not error.is_empty():
			return PackedInt32Array()
		if value.has("transparency_mask"):
			var mask := image(value.transparency_mask, width, height, Sc2Palette.index_encoding().to_rgb_bytes())
			if not error.is_empty():
				return PackedInt32Array()
			for index in result.size():
				if mask[index] not in [MASK_CLEAR, MASK_OPAQUE] or result[index] < 0:
					error = "The project transparency mask is invalid."
					return PackedInt32Array()
				if mask[index] == MASK_CLEAR:
					result[index] = -1
		return result

	func snapshot(value: Dictionary) -> Dictionary:
		var record := value.duplicate(true)
		record.current_mif = blob(value.get("current_mif"))
		var documents: Variant = record.get("documents", {})
		if not documents is Dictionary or documents.size() > Limits.MAX_DOCUMENTS:
			error = "The project documents are invalid."
			return {}
		for key: Variant in documents:
			var document: Variant = documents[key]
			if not document is Dictionary or not Limits.valid_dimensions(document.get("width"), document.get("height")):
				error = "The project document size is invalid."
				return {}
			var layers: Variant = document.get("layers")
			if not layers is Array or layers.is_empty() or layers.size() > Limits.MAX_LAYERS:
				error = "The project layers are invalid."
				return {}
			document.original_pixels = pixels(document.get("original_pixels"), int(document.width), int(document.height))
			for layer: Variant in layers:
				if not layer is Dictionary:
					error = "The project layer is invalid."
					return {}
				layer.pixels = pixels(layer.get("pixels"), int(document.width), int(document.height))
				if not error.is_empty():
					return {}
		var resources: Variant = record.get("resources", {})
		if not resources is Dictionary or resources.size() > Limits.MAX_RESOURCES:
			error = "The project resources are invalid."
			return {}
		for key: Variant in resources:
			resources[key] = blob(resources[key])
		var stamps: Variant = record.get("stamps", [])
		if not stamps is Array or stamps.size() > Limits.MAX_STAMPS:
			error = "The project stamps are invalid."
			return {}
		for stamp: Variant in stamps:
			if not stamp is Dictionary or not Limits.valid_dimensions(stamp.get("width"), stamp.get("height")):
				error = "The project stamp size is invalid."
				return {}
			stamp.pixels = pixels(stamp.get("pixels"), int(stamp.width), int(stamp.height))
			if not error.is_empty():
				return {}
		return record


# The caller validates the logical record before encoding it.
static func encode(record: Dictionary, palette_rgb: PackedByteArray) -> Result:
	var encoder := Encoder.new()
	encoder.palette = Sc2Palette.index_encoding() if palette_rgb.is_empty() else Sc2Palette.from_rgb_bytes(palette_rgb)
	if not encoder.palette.is_valid():
		return failure("The project palette is invalid.")
	var project := encoder.snapshot(record, "current")
	encoder.members["original.mif"] = record.original_mif
	project.original_mif = "original.mif"
	var checkpoints: Array = project.get("checkpoints", [])
	for index in checkpoints.size():
		checkpoints[index].snapshot = encoder.snapshot(record.checkpoints[index].snapshot, "checkpoints/%04d" % index)
	if not encoder.error.is_empty():
		return failure(encoder.error)
	var colors: Array = []
	for color: Color in encoder.palette.colors:
		colors.append([color.r8, color.g8, color.b8])
	encoder.members[PALETTE] = JSON.stringify({"kind": "index-encoding" if palette_rgb.is_empty() else "rgb", "colors": colors}, "\t").to_utf8_buffer()
	encoder.members[MANIFEST] = JSON.stringify({"format": FORMAT, "version": VERSION, "palette": PALETTE, "project": project}, "\t").to_utf8_buffer()
	var packed := Zip.encode(encoder.members)
	if not packed.ok:
		return failure(packed.error)
	var result := Result.new()
	result.ok = true
	result.bytes = packed.bytes
	return result


static func decode(bytes: PackedByteArray) -> Result:
	var unpacked := Zip.decode(bytes, Limits.MAX_FILE_BYTES)
	if not unpacked.ok:
		return failure(unpacked.error)
	var decoder := Decoder.new()
	decoder.members = unpacked.members
	var manifest := decoder.json(MANIFEST)
	if not decoder.error.is_empty():
		return failure(decoder.error)
	if manifest.get("format") != FORMAT or not Limits.integer_in(manifest.get("version"), VERSION, VERSION):
		return failure("The project archive format or version is not supported.")
	for key: Variant in manifest:
		if key not in ["format", "version", "palette", "project"]:
			return failure("The project archive manifest has an unsupported field.")
	var palette := decoder.json(manifest.get("palette"))
	for key: Variant in palette:
		if key not in ["kind", "colors"]:
			return failure("The project palette has an unsupported field.")
	var kind: Variant = palette.get("kind")
	var colors: Variant = palette.get("colors")
	if not decoder.error.is_empty() or kind not in ["rgb", "index-encoding"] or not colors is Array or colors.size() != Sc2Palette.COLOR_COUNT:
		return failure("The project palette is invalid.")
	for color: Variant in colors:
		if not color is Array or color.size() != Sc2Palette.RGB_CHANNELS:
			return failure("The project palette color is invalid.")
		for channel: Variant in color:
			if not Limits.integer_in(channel, 0, 255):
				return failure("The project palette color is invalid.")
			decoder.palette_rgb.append(int(channel))
	if kind == "index-encoding" and decoder.palette_rgb != Sc2Palette.index_encoding().to_rgb_bytes():
		return failure("The project index palette is invalid.")
	if not manifest.get("project") is Dictionary:
		return failure("The project record is invalid.")
	var source: Dictionary = manifest.project
	var record := decoder.snapshot(source)
	if not decoder.error.is_empty():
		return failure(decoder.error)
	record.original_mif = decoder.blob(source.get("original_mif"))
	var checkpoints: Variant = record.get("checkpoints", [])
	if not checkpoints is Array or checkpoints.size() > Limits.MAX_CHECKPOINTS:
		return failure("The project history is invalid.")
	for entry: Variant in checkpoints:
		if not entry is Dictionary or not entry.get("snapshot") is Dictionary:
			return failure("The project checkpoint is invalid.")
		entry.snapshot = decoder.snapshot(entry.snapshot)
		if not decoder.error.is_empty():
			return failure(decoder.error)
	if not decoder.error.is_empty():
		return failure(decoder.error)
	for path: String in decoder.members:
		if not decoder.used_members.has(path):
			return failure("The project archive contains an unreferenced member: " + path)
	var result := Result.new()
	result.ok = true
	result.record = record
	result.palette_rgb = decoder.palette_rgb if kind == "rgb" else PackedByteArray()
	return result


static func failure(message: String) -> Result:
	var result := Result.new()
	result.error = message
	return result
