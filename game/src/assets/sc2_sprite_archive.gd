class_name Sc2SpriteArchive
extends RefCounted


class SpriteEntry extends RefCounted:
	var sprite_id := 0
	var offset := 0
	var width := 0
	var height := 0
	var duplicate_index := 0
	var encoded_pixels := PackedByteArray()
	var allow_unpadded_odd_runs := false
	var _index_image: Image
	var _index_image_mutex := Mutex.new()


	func decode_indices() -> Dictionary:
		var pixels := PackedInt32Array()
		pixels.resize(width * height)
		# -1 is transparent, zero is a perfectly good pixel
		pixels.fill(-1)

		var position := 0
		var row := 0
		var found_end := false
		while position < encoded_pixels.size():
			if position + 2 > encoded_pixels.size():
				return _failure("truncated block header")
			var block_length := int(encoded_pixels[position])
			# two layers of commands here: outer blocks and then row runs
			var block_mode := int(encoded_pixels[position + 1])
			position += 2

			if block_mode == 2:
				found_end = true
				break
			if position + block_length > encoded_pixels.size():
				return _failure("block extends past sprite data")

			if block_mode == 0:
				position += block_length
				continue
			if block_mode != 1:
				return _failure("unsupported outer block mode %d" % block_mode)
			if row >= height:
				return _failure("sprite has more rows than its header")

			var row_end := position + block_length
			var x := 0
			while position < row_end:
				if position + 2 > row_end:
					return _failure("truncated row command")
				var count := int(encoded_pixels[position])
				var mode := int(encoded_pixels[position + 1])
				position += 2

				match mode:
					0, 2:
						pass
					3:
						x += count
						if x > width:
							return _failure("row skip extends past sprite width")
					4:
						if position + count > row_end:
							return _failure("pixel run extends past row block")
						if x + count > width:
							return _failure("pixel run extends past sprite width")
						for pixel_offset in count:
							pixels[row * width + x] = encoded_pixels[position + pixel_offset]
							x += 1
						position += count
						if count % 2 == 1:
							if position < row_end:
								position += 1
							elif not allow_unpadded_odd_runs:
								return _failure("odd pixel run has no padding byte")
					_:
						return _failure("unsupported row mode %d" % mode)
			row += 1

		if not found_end:
			return _failure("sprite has no end block")
		return {"ok": true, "pixels": pixels, "rows": row, "error": ""}


	func create_image(palette: Sc2Palette) -> Dictionary:
		if not palette.is_valid():
			return _failure("palette is invalid")
		if palette.is_index_encoding:
			return _create_index_image()
		var decoded := decode_indices()
		if not decoded.ok:
			return decoded
		var image := Image.create(width, height, false, Image.FORMAT_RGBA8)
		var pixels: PackedInt32Array = decoded.pixels
		for y in height:
			for x in width:
				var palette_index := pixels[y * width + x]
				if palette_index >= 0:
					image.set_pixel(x, y, palette.color(palette_index))
				else:
					image.set_pixel(x, y, Color.TRANSPARENT)
		return {"ok": true, "image": image, "error": ""}


	func _create_index_image() -> Dictionary:
		_index_image_mutex.lock()
		if _index_image != null:
			var cached := {"ok": true, "image": _index_image, "error": ""}
			_index_image_mutex.unlock()
			return cached
		var decoded := decode_indices()
		if not decoded.ok:
			_index_image_mutex.unlock()
			return decoded
		var image := Image.create(width, height, false, Image.FORMAT_RGBA8)
		var pixels: PackedInt32Array = decoded.pixels
		for y in height:
			for x in width:
				var palette_index := pixels[y * width + x]
				if palette_index >= 0:
					image.set_pixel(
						x, y, Color8(palette_index, palette_index, palette_index, 255)
					)
				else:
					image.set_pixel(x, y, Color.TRANSPARENT)
		_index_image = image
		_index_image_mutex.unlock()
		return {"ok": true, "image": image, "error": ""}


	func _failure(message: String) -> Dictionary:
		return {
			"ok": false,
			"error": "sprite %d at 0x%x: %s" % [sprite_id, offset, message],
		}


var entries: Array[SpriteEntry] = []
var entries_by_id: Dictionary = {}
var parse_error := ""


static func load_path(path: String) -> Sc2SpriteArchive:
	var archive := Sc2SpriteArchive.new()
	if not FileAccess.file_exists(path):
		archive.parse_error = "Sprite archive does not exist: %s" % path
		return archive
	archive.parse(FileAccess.get_file_as_bytes(path))
	return archive


static func combine(archives: Array[Sc2SpriteArchive]) -> Sc2SpriteArchive:
	var result := Sc2SpriteArchive.new()
	for archive in archives:
		if archive == null or not archive.is_valid():
			result.parse_error = "cannot combine an invalid sprite archive"
			result.entries.clear()
			result.entries_by_id.clear()
			return result
		for entry in archive.entries:
			result.entries.append(entry)
			result.entries_by_id[entry.sprite_id] = entry
	return result


func parse(bytes: PackedByteArray) -> bool:
	entries.clear()
	entries_by_id.clear()
	parse_error = ""
	if bytes.size() < 2:
		return _fail("archive is shorter than its count field")

	var count := _read_u16_be(bytes, 0)
	var header_end := 2 + count * 10
	if header_end > bytes.size():
		return _fail("metadata table extends past the file")

	var duplicate_counts: Dictionary = {}
	for index in count:
		var metadata_offset := 2 + index * 10
		var entry := SpriteEntry.new()
		entry.sprite_id = _read_u16_be(bytes, metadata_offset)
		entry.offset = _read_u32_be(bytes, metadata_offset + 2)
		entry.height = _read_u16_be(bytes, metadata_offset + 6)
		entry.width = _read_u16_be(bytes, metadata_offset + 8)
		entry.duplicate_index = int(duplicate_counts.get(entry.sprite_id, 0))
		duplicate_counts[entry.sprite_id] = entry.duplicate_index + 1
		if entry.width <= 0 or entry.height <= 0:
			return _fail("sprite %d has an empty dimension" % entry.sprite_id)
		if entry.offset < header_end or entry.offset > bytes.size():
			return _fail("sprite %d has an invalid data offset" % entry.sprite_id)
		entries.append(entry)

	for index in entries.size():
		var entry := entries[index]
		var end := bytes.size()
		if index + 1 < entries.size():
			end = entries[index + 1].offset
		if end < entry.offset:
			return _fail("sprite offsets are not in ascending order")
		entry.encoded_pixels = bytes.slice(entry.offset, end)
		# Use the last duplicate sprite for lookup. Keep the others for archive round trips.
		entries_by_id[entry.sprite_id] = entry
	return true


func is_valid() -> bool:
	return parse_error.is_empty()


func find_sprite(sprite_id: int) -> SpriteEntry:
	return entries_by_id.get(sprite_id) as SpriteEntry


func _fail(message: String) -> bool:
	parse_error = message
	return false


static func _read_u16_be(bytes: PackedByteArray, offset: int) -> int:
	return (bytes[offset] << 8) | bytes[offset + 1]


static func _read_u32_be(bytes: PackedByteArray, offset: int) -> int:
	return (
		(bytes[offset] << 24)
		| (bytes[offset + 1] << 16)
		| (bytes[offset + 2] << 8)
		| bytes[offset + 3]
	)
