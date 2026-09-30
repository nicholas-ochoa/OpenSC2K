class_name PeBitmapResource
extends RefCounted
## Bitmap resources of 32-bit Windows executables. The native formats library
## reads the resource directories and decodes the bitmaps.


static func list_numeric_bitmap_ids(path: String) -> PeBitmapIdsResult:
	var directory := _load_resource_directory(path)

	if not directory.ok:
		return PeBitmapIdsResult.failure(directory.error)

	var listed := NativePeResources.bitmap_ids(directory.bytes)

	if not listed.ok:
		return PeBitmapIdsResult.failure(listed.error)

	var outcome := PeBitmapIdsResult.new()
	outcome.ok = true
	outcome.ids = listed.ids
	outcome.error = ""

	return outcome


static func load_numeric(path: String, resource_id: int) -> AssetImageResult:
	if resource_id < 0 or resource_id > 0xffff:
		return AssetImageResult.failure("bitmap resource ID is outside the valid range")

	return _image(path, resource_id)


static func load_named(path: String, resource_name: String) -> AssetImageResult:
	if resource_name.is_empty():
		return AssetImageResult.failure("bitmap resource name is empty")

	return _image(path, resource_name)


static func _image(path: String, resource_id: Variant) -> AssetImageResult:
	var directory := _load_resource_directory(path)

	if not directory.ok:
		return AssetImageResult.failure(directory.error)

	var loaded := NativePeResources.bitmap_image(directory.bytes, resource_id)

	if not loaded.ok:
		return AssetImageResult.failure(loaded.error)

	var outcome := AssetImageResult.new()
	outcome.ok = true
	outcome.image = loaded.image
	outcome.error = ""

	return outcome


static func load_numeric_dib(path: String, resource_id: int) -> PeDibResult:
	if resource_id < 0 or resource_id > 0xffff:
		return PeDibResult.failure("bitmap resource ID is outside the valid range")

	return _dib(path, resource_id)


static func load_named_dib(path: String, resource_name: String) -> PeDibResult:
	if resource_name.is_empty():
		return PeDibResult.failure("bitmap resource name is empty")

	return _dib(path, resource_name)


static func _dib(path: String, resource_id: Variant) -> PeDibResult:
	var directory := _load_resource_directory(path)

	if not directory.ok:
		return PeDibResult.failure(directory.error)

	var loaded := NativePeResources.bitmap_dib(directory.bytes, resource_id)

	if not loaded.ok:
		return PeDibResult.failure(loaded.error)

	var outcome := PeDibResult.new()
	outcome.ok = true
	outcome.bytes = loaded.bytes
	outcome.width = loaded.width
	outcome.height = loaded.height
	outcome.bits_per_pixel = loaded.bits_per_pixel
	outcome.compression = loaded.compression
	outcome.color_count = loaded.color_count
	outcome.error = ""

	return outcome


static func load_numeric_indexed8(path: String, resource_id: int) -> IndexedImageResult:
	if resource_id < 0 or resource_id > 0xffff:
		return IndexedImageResult.failure("bitmap resource ID is outside the valid range")

	var directory := _load_resource_directory(path)

	if not directory.ok:
		return IndexedImageResult.failure(directory.error)

	return _indexed(NativePeResources.bitmap_indexed8(directory.bytes, resource_id))


static func load_numeric_indexed8_many(
	path: String, resource_ids: Array
) -> PeIndexedBatchResult:
	var directory := _load_resource_directory(path)

	if not directory.ok:
		return PeIndexedBatchResult.failure(directory.error)

	var loaded := NativePeResources.bitmaps_indexed8(directory.bytes, PackedInt32Array(resource_ids))

	if not loaded.ok:
		return PeIndexedBatchResult.failure(loaded.error)

	var entries: Array[IndexedImageResult] = []

	for entry: Dictionary in loaded.entries:
		entries.append(_indexed(entry))

	var outcome := PeIndexedBatchResult.new()
	outcome.ok = true
	outcome.entries = entries
	outcome.error = ""

	return outcome


# an 8-bit uncompressed or RLE8 DIB as top-down palette indices
static func decode_indexed8_dib(dib: PackedByteArray, resource_id: Variant) -> IndexedImageResult:
	return _indexed(NativePeResources.dib_indexed8(dib, resource_id))


# a 4-bit uncompressed DIB as top-down palette indices
static func decode_indexed4_dib(dib: PackedByteArray) -> IndexedImageResult:
	return _indexed(NativePeResources.dib_indexed4(dib))


static func _indexed(decoded: Dictionary) -> IndexedImageResult:
	if not decoded.ok:
		return IndexedImageResult.failure(decoded.error)

	var outcome := IndexedImageResult.new()
	outcome.ok = true
	outcome.width = decoded.width
	outcome.height = decoded.height
	outcome.pixels = decoded.pixels
	outcome.error = ""

	return outcome


# the file offset of a relative virtual address, or -1
static func rva_to_offset(directory: PeDirectoryResult, rva: int) -> int:
	return NativePeResources.rva_offset(directory.bytes, rva)


static func _load_resource_directory(path: String) -> PeDirectoryResult:
	var bytes := FileAccess.get_file_as_bytes(path)

	if bytes.is_empty():
		return PeDirectoryResult.failure("cannot read PE file: %s" % path)

	var error := NativePeResources.directory_error(bytes)

	if not error.is_empty():
		return PeDirectoryResult.failure(error)

	var outcome := PeDirectoryResult.new()
	outcome.ok = true
	outcome.bytes = bytes
	outcome.error = ""

	return outcome
