extends SceneTree


func _initialize() -> void:
	var names := ["type", "direction", "state", "x", "y", "z", "px", "py", "dx", "dy", "label", "goal"]

	for size: int in [480, 960]:
		for type in 17:
			var wide_fields := [3, 4, 8, 9, 10]

			if type in [10, 11, 12, 13]:
				wide_fields.append_array([2, 6, 7])
			elif type == 16:
				wide_fields.append(11)

			for field in range(1, 12):
				for value: int in [0, 255, 256, 511, 65535]:
					var bytes := PackedByteArray()
					bytes.resize(size)
					bytes.fill(90)
					bytes[24] = type
					var expected := bytes.duplicate()
					expected[24 + field] = value % 256
					var wide: bool = size == 960 and field in wide_fields

					if size == 960 and not (type == 3 and field in [1, 2, 5]):
						expected[480 + 24 + field] = value >> 8 if wide else 0

					ThingData.write(bytes, 24 + field, value)
					assert(bytes == expected, "A field write preserves every unrelated byte")
					assert(ThingData.read(bytes, 24 + field) == (value if wide else value % 256))
					var record := ThingRecord.read(bytes, 24)
					assert(record.get(names[field]) == (value if wide else value % 256))

	var things := PackedByteArray()
	things.resize(960)
	things[24] = 3
	ThingData.set_ship_home(things, 2, Vector2i(255, 511))
	assert(things.slice(504, 510) == PackedByteArray([0, 1, 0, 0, 0, 2]))

	for field in [0, 1, 2, 5]:
		ThingData.write(things, 24 + field, 3 if field == 0 else 7)

	assert(ThingData.ship_home(things, 2, Vector2i(-1, -1)) == Vector2i(255, 511))
	assert(ThingData.count(things) == 40)
	var original := PackedByteArray()
	original.resize(480)
	ThingData.set_ship_home(original, 2, Vector2i(255, 511))
	assert(original.count(0) == 480)
	assert(ThingData.ship_home(original, 2, Vector2i(9, 10)) == Vector2i(9, 10))
	assert(ThingData.count(original) == 40)

	for record in [0, 39, 40, 240, 241, 1000]:
		assert(ThingData.target_record(ThingData.target_id(record)) == record)

	for goal in [0, 240, 8192, 65535]:
		assert(ThingData.is_record_target(goal))

	for goal in [241, 255, 8191]:
		assert(not ThingData.is_record_target(goal))

	print("PASS: original and extended thing fields, ship homes and target boundaries")
	quit()
