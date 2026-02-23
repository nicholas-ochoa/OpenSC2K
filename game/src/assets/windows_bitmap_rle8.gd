class_name WindowsBitmapRle8
extends RefCounted
# bi_rle8 decoding to top-down palette indices. no rgb index matching


static func decode(bytes: PackedByteArray, width: int, height: int) -> Dictionary:
	if width <= 0 or height <= 0 or width > 4096 or height > 4096:
		return _failure("RLE8 dimensions must be 1 through 4096")

	var pixels := PackedInt32Array()
	pixels.resize(width * height)
	pixels.fill(0)
	var x := 0
	var y := 0 # row from the bottom of the dib
	var offset := 0

	while offset + 2 <= bytes.size():
		var count := int(bytes[offset])
		var value := int(bytes[offset + 1])
		offset += 2

		if count == 0:
			if value == 1:
				return {"ok": true, "pixels": pixels, "consumed": offset, "error": ""}

			if value == 0:
				x = 0
				y += 1

				if y > height:
					return _failure("RLE8 line escape exceeds the image")

				continue

			if value == 2:
				if offset + 2 > bytes.size():
					return _failure("RLE8 delta is truncated")

				x += int(bytes[offset])
				y += int(bytes[offset + 1])
				offset += 2

				if x > width or y >= height:
					return _failure("RLE8 delta exceeds the image")

				continue

			count = value
			var padded_size := (count + 1) & ~1

			if offset + padded_size > bytes.size():
				return _failure("RLE8 absolute run or padding is truncated")

			if x + count > width or y >= height:
				return _failure("RLE8 absolute run exceeds its row")

			for i in count:
				pixels[(height - 1 - y) * width + x + i] = bytes[offset + i]

			offset += padded_size
		else:
			if x + count > width or y >= height:
				return _failure("RLE8 encoded run exceeds its row")

			for i in count:
				pixels[(height - 1 - y) * width + x + i] = value

		x += count

	return _failure("RLE8 end-of-bitmap escape is missing")


static func _failure(message: String) -> Dictionary:
	return {"ok": false, "error": message}
