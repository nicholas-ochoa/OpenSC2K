class_name PeIconCursorResource
extends RefCounted
# indexed windows icon/cursor dibs. keep and and xor data separate. the native
# formats library reads and composes them


static func load_image(path: String, resource_id: int, cursor := false) -> DecodedImage:
	var resource := load_resource(path, 1 if cursor else 3, resource_id)

	return decode_image(resource.bytes, cursor) if resource.ok else DecodedImage.failure(resource.error)


static func load_group(path: String, resource_id: int, cursor := false) -> GroupResult:
	var resource := load_resource(path, 12 if cursor else 14, resource_id)

	return decode_group(resource.bytes, cursor) if resource.ok else GroupResult.failure(resource.error)


static func load_resource(path: String, type_id: int, resource_id: int) -> AssetBytesResult:
	if resource_id < 0 or resource_id > 65535 or type_id not in [1, 3, 12, 14]:
		return AssetBytesResult.failure("Invalid icon/cursor resource ID or type")

	var directory := PeBitmapResource._load_resource_directory(path)

	if not directory.ok:
		return AssetBytesResult.failure(directory.error)

	return resource_from_directory(directory, type_id, resource_id)


static func resource_from_directory(directory: PeDirectoryResult, type_id: int, resource_id: int) -> AssetBytesResult:
	var loaded := NativePeResources.icon_resource(directory.bytes, type_id, resource_id)

	if not loaded.ok:
		return AssetBytesResult.failure(loaded.error)

	var result := AssetBytesResult.new()
	result.ok = true
	result.bytes = loaded.bytes
	result.error = ""

	return result


static func decode_group(bytes: PackedByteArray, cursor := false) -> GroupResult:
	var decoded := NativePeResources.decode_icon_group(bytes, cursor)

	if not decoded.ok:
		return GroupResult.failure(decoded.error)

	var entries: Array[GroupEntry] = []

	for values: PackedInt64Array in decoded.entries:
		var entry := GroupEntry.new()
		entry.id = values[0]
		entry.width = values[1]
		entry.height = values[2]
		entry.planes = values[3]
		entry.bits = values[4]
		entry.length = values[5]
		entries.append(entry)

	var result := GroupResult.new()
	result.ok = true
	result.entries = entries
	result.error = ""

	return result


static func decode_image(bytes: PackedByteArray, cursor := false) -> DecodedImage:
	var decoded := NativePeResources.decode_icon(bytes, cursor)

	if not decoded.ok:
		return DecodedImage.failure(decoded.error)

	var result := DecodedImage.new()
	result.ok = true
	result.width = decoded.width
	result.height = decoded.height
	result.bits = decoded.bits
	result.hotspot = decoded.hotspot
	var rgb: PackedByteArray = decoded.palette

	for at in range(0, rgb.size(), 3):
		result.palette.append(Color8(rgb[at], rgb[at + 1], rgb[at + 2]))

	result.pixels = decoded.pixels
	result.and_mask = decoded.and_mask
	result.inverting_pixels = decoded.inverting_pixels
	result.trailing_bytes = decoded.trailing_bytes
	result.error = ""

	return result


static func composite(decoded: DecodedImage, background: Image) -> Image:
	assert(decoded.ok and background.get_size() == Vector2i(decoded.width, decoded.height))

	return NativePeResources.icon_composite(decoded.width, decoded.height, decoded.pixels, decoded.and_mask,
		_rgb(decoded.palette), background)


static func transparent_image(decoded: DecodedImage) -> AssetImageResult:
	if not decoded.ok:
		return AssetImageResult.failure(decoded.error)

	if decoded.inverting_pixels > 0:
		return AssetImageResult.failure("This cursor requires background XOR compositing")

	var image := NativePeResources.icon_transparent(decoded.width, decoded.height, decoded.pixels, decoded.and_mask,
		_rgb(decoded.palette))

	if image == null:
		return AssetImageResult.failure("Icon/cursor pixels do not match the image")

	var result := AssetImageResult.new()
	result.ok = true
	result.image = image
	result.error = ""

	return result


static func _rgb(colors: PackedColorArray) -> PackedByteArray:
	var bytes := PackedByteArray()

	for color in colors:
		bytes.append_array(PackedByteArray([color.r8, color.g8, color.b8]))

	return bytes


class GroupEntry extends RefCounted:
	var id := 0
	var width := 0
	var height := 0
	var planes := 0
	var bits := 0
	var length := 0


class GroupResult extends RefCounted:
	var ok := false
	var error := ""
	var entries: Array[GroupEntry] = []

	static func failure(message: String) -> GroupResult:
		var result := GroupResult.new()
		result.error = message

		return result


class DecodedImage extends RefCounted:
	var ok := false
	var error := ""
	var width := 0
	var height := 0
	var bits := 0
	var hotspot := Vector2i.ZERO
	var palette := PackedColorArray()
	var pixels := PackedInt32Array()
	var and_mask := PackedByteArray()
	var inverting_pixels := 0
	var trailing_bytes := 0

	static func failure(message: String) -> DecodedImage:
		var result := DecodedImage.new()
		result.error = message

		return result
