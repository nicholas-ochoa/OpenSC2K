extends SceneTree
## Check resource metadata and geometric masks.


func _initialize() -> void:
	var bytes := FileAccess.get_file_as_bytes("res://../references/BITMAPS/NEIGHBOR.BMP")
	assert(bytes.decode_u16(0) == 0x4d42 and bytes.decode_u32(14) == 40)
	assert(bytes.decode_s32(18) == 128 and bytes.decode_s32(22) == 448)
	assert(bytes.decode_u16(28) == 8 and bytes.decode_u32(30) == 0)
	var offset := bytes.decode_u32(10)
	var counts := PackedInt32Array()
	for row in 7:
		var count := 0
		for y in 64:
			for x in 128:
				var index := int(bytes[offset + (447 - row * 64 - y) * 128 + x])
				count += int(index != 0)
				var distance := absf(x - 63.5) + 2 * absi(y - 32)
				if row == 0:
					assert((index != 0) == (distance < 63))
				elif row == 6:
					assert(index == (255 if distance > 65 else 0))
		counts.append(count)
	assert(counts == PackedInt32Array([3970, 3960, 3935, 3889, 3777, 3559, 3970]))
	print("PASS: NEIGHBOR.BMP 128×448, six visible rows, diamond ground and expanded seventh-row mask; nonzero counts ", counts)
	quit()
