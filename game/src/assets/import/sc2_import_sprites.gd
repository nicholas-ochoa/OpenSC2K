class_name Sc2ImportSprites
extends RefCounted
## Decode source sprite sets while retaining valid records from partial sets.

@warning_ignore_start("integer_division")

var archive := Sc2SpriteArchive.new()
var warnings := PackedStringArray()
var error := ""


static func mac_tile_set(data: PackedByteArray) -> Sc2ImportSprites:
	var result := Sc2ImportSprites.new()

	if data.size() < 34 or data.slice(0, 4).get_string_from_ascii() != "MIFF" or Sc2ImportContainer.be32(data, 4) != data.size() - 8 or data.slice(8, 16).get_string_from_ascii() != "SC2KINFO":
		result.error = "Invalid Macintosh tile-set header."
		return result

	if Sc2ImportContainer.be32(data, 16) != 4 or data.slice(20, 28).get_string_from_ascii() != "_MACTILE" or Sc2ImportContainer.be32(data, 28) != 2:
		result.error = "Unsupported Macintosh tile-set directory."
		return result

	# Mac TILE stores a count followed by SHAP chunks; it does not use the Windows MIF layout.
	var count := BinaryData.read_u16_be(data, 32)
	var cursor := 34
	var total_pixels := 0

	for index in count:
		if not Sc2ImportContainer.has_range(data, cursor, 8) or data.slice(cursor, cursor + 4).get_string_from_ascii() != "SHAP":
			result.warnings.append("The Macintosh tile set ends before shape %d. Kept preceding shapes." % index)
			break

		var length := Sc2ImportContainer.be32(data, cursor + 4)
		cursor += 8

		if not Sc2ImportContainer.has_range(data, cursor, length):
			result.warnings.append("Macintosh shape %d extends past the tile set. Kept preceding shapes." % index)
			break

		var start := cursor
		cursor += length

		# Empty SHAP chunks are placeholders with no ID or dimensions.
		if length == 0:
			continue

		if length < 10 or Sc2ImportContainer.be32(data, start + 6) != length - 10:
			result.warnings.append("Macintosh shape %d has an invalid pixel length." % index)
			continue

		var entry := Sc2SpriteArchive.SpriteEntry.new()
		entry.sprite_id = BinaryData.read_u16_be(data, start)
		entry.width = BinaryData.read_u16_be(data, start + 2)
		entry.height = BinaryData.read_u16_be(data, start + 4)

		if entry.width < 1 or entry.height < 1 or entry.width > 4096 or entry.height > 4096 or total_pixels + entry.width * entry.height > 16 * 1024 * 1024:
			result.warnings.append("Macintosh shape %d exceeds the decoded image limits." % entry.sprite_id)
			continue

		total_pixels += entry.width * entry.height
		entry.encoded_pixels = ScurkMif._normalize_pixel_end(data.slice(start + 10, cursor))
		entry.allow_unpadded_odd_runs = true
		var decoded := entry.decode_indices()

		if not decoded.ok:
			result.warnings.append(decoded.error)
			continue

		result.archive.entries.append(entry)
		result.archive.entries_by_id[entry.sprite_id] = entry

	if cursor != data.size():
		result.warnings.append("The Macintosh tile-set size differs from its declared shapes.")

	if result.archive.entries.is_empty():
		result.error = "No readable Macintosh tile-set shapes were found."

	return result


static func tiles_database(data: PackedByteArray) -> Sc2ImportSprites:
	var result := Sc2ImportSprites.new()

	if data.size() < 2:
		result.error = "Truncated tile database."
		return result

	var count := int(data.decode_u16(0))
	var sizes := 2 + count * 10
	var cursor := sizes + count * 4

	if count == 0 or cursor > data.size():
		result.error = "Invalid tile database directory."
		return result

	for index in count:
		var length := int(data.decode_u32(sizes + index * 4))
		var metadata := 2 + index * 10
		var entry := Sc2SpriteArchive.SpriteEntry.new()
		entry.sprite_id = int(data.decode_u16(metadata))
		entry.height = int(data.decode_u16(metadata + 6))
		entry.width = int(data.decode_u16(metadata + 8))

		if not Sc2ImportContainer.has_range(data, cursor, length):
			result.warnings.append("Tile database ends before sprite %d. Kept preceding sprites." % entry.sprite_id)
			break

		var encoded := data.slice(cursor, cursor + length)
		entry.encoded_pixels = ScurkMif._normalize_pixel_end(encoded)
		entry.allow_unpadded_odd_runs = entry.encoded_pixels != encoded
		cursor += length
		var rows := _sprite_rows(entry.encoded_pixels)

		if rows > entry.height and rows <= 4096:
			result.warnings.append("Tile database sprite %d stores %d rows but declares %d. Recovered all rows." % [entry.sprite_id, rows, entry.height])
			entry.height = rows

		if entry.width < 1 or entry.height < 1 or entry.width > 4096 or entry.height > 4096:
			result.warnings.append("Tile database sprite %d has invalid dimensions." % entry.sprite_id)
			continue

		var decoded := entry.decode_indices()

		if not decoded.ok:
			result.warnings.append(decoded.error)
			continue

		result.archive.entries.append(entry)
		result.archive.entries_by_id[entry.sprite_id] = entry

	if result.archive.entries.is_empty():
		result.error = "No readable tile database sprites were found."

	return result


static func _sprite_rows(bytes: PackedByteArray) -> int:
	var cursor := 0
	var rows := 0

	while cursor + 2 <= bytes.size():
		var size := int(bytes[cursor])
		var mode := int(bytes[cursor + 1])
		cursor += 2

		if mode == 2:
			return rows

		if mode not in [0, 1] or not Sc2ImportContainer.has_range(bytes, cursor, size):
			return -1

		if mode == 1:
			rows += 1

		cursor += size

	return -1


static func dos(header: PackedByteArray, data: PackedByteArray) -> Sc2ImportSprites:
	var result := Sc2ImportSprites.new()

	if header.is_empty() or header.size() % 8 != 0 or header.size() / 8 > 65536:
		result.error = "Invalid DOS sprite directory."
		return result

	var offsets: Array[int] = []
	var distinct: Dictionary[int, bool] = {}

	for index in header.size() / 8:
		var offset := int(header.decode_u32(index * 8))

		if offset < data.size() and not distinct.has(offset):
			distinct[offset] = true
			offsets.append(offset)

	offsets.sort()
	var ends: Dictionary[int, int] = {}

	for index in offsets.size():
		ends[offsets[index]] = offsets[index + 1] if index + 1 < offsets.size() else data.size()

	for id in header.size() / 8:
		var offset := int(header.decode_u32(id * 8))

		if offset == 0xffffffff:
			continue

		var height := int(header[id * 8 + 4])
		var width := int(header[id * 8 + 5])

		if not ends.has(offset) or width == 0 or height == 0:
			result.warnings.append("DOS sprite %d has an invalid offset or dimension." % id)
			continue

		var decoded := _dos_pixels(data, offset, ends[offset], width, height)

		if not decoded.ok:
			result.warnings.append("DOS sprite %d: %s" % [id, decoded.error])
			continue

		var entry := Sc2SpriteArchive.entry_from_indices(id, width, height, decoded.pixels)
		result.archive.entries.append(entry)
		result.archive.entries_by_id[id] = entry

	if result.archive.entries.is_empty():
		result.error = "No readable DOS sprites were found."

	return result


static func _dos_pixels(data: PackedByteArray, start: int, end: int, width: int, height: int) -> IndexedImageResult:
	var pixels := PackedInt32Array()
	pixels.resize(width * height)
	pixels.fill(-1)
	var cursor := start
	var row := 0
	var terminated := false

	while cursor < end:
		var marker := int(data[cursor])
		cursor += 1

		if marker == 0:
			terminated = true
			break

		if marker != 0x10 or cursor >= end or row >= height:
			return IndexedImageResult.failure("Invalid row marker or row count.")

		var length := int(data[cursor])
		var row_end := cursor + length
		cursor += 1

		if length == 0 or row_end > end:
			return IndexedImageResult.failure("Row exceeds the sprite data.")

		var column := 0

		while cursor < row_end:
			if row_end - cursor < 2:
				return IndexedImageResult.failure("Truncated row command.")

			var operation := int(data[cursor])
			var count := int(data[cursor + 1])
			cursor += 2

			if column + count > width:
				return IndexedImageResult.failure("Row command exceeds the sprite width.")

			if operation == 0x0c:
				if count > row_end - cursor:
					return IndexedImageResult.failure("Pixel run exceeds the row data.")

				for index in count:
					pixels[row * width + column + index] = int(data[cursor + index])

				cursor += count
			elif operation != 0x04:
				return IndexedImageResult.failure("Unsupported row command 0x%02x." % operation)

			column += count

		row += 1

	if not terminated:
		return IndexedImageResult.failure("Sprite has no end marker.")

	var result := IndexedImageResult.new()
	result.ok = true
	result.width = width
	result.height = height
	result.rows = row
	result.pixels = pixels

	return result
