extends SceneTree
const Main = preload("res://src/main.gd")


func _initialize() -> void:
	for edge in [128, 256, 384, 512]:
		var old := {}
		var changed := {}
		var expected := {}
		var expected_by_chunk := {}

		for id in ["ALTM", "XBLD", "XTER", "XZON", "XBIT", "XTXT"]:
			var stride := 2 if id == "ALTM" or (id == "XTXT" and edge > 128) else 1
			var bytes := PackedByteArray()
			bytes.resize(edge * edge * stride)
			old[id] = bytes
			bytes = bytes.duplicate()

			var changed_indices := PackedInt32Array([0, 255, 256, 257, 512 + changed.size(), edge * edge - 1])
			expected_by_chunk[id] = changed_indices
			for index in changed_indices:
				if id == "XTXT":
					OverlayData.write(bytes, index, 4097 if edge > 128 else 42)
				else:
					bytes[index * stride + stride - 1] = 42

				expected[index] = true

			changed[id] = bytes

		var command := {"old_payloads": old, "new_payloads": changed}
		var expected_indices := PackedInt32Array(expected.keys())
		expected_indices.sort()
		assert(Main._edit_dirty_indices(command, edge) == expected_indices)
		# Change each chunk alone so another changed chunk cannot hide a missed dirty tile.
		for id in old:
			assert(Main._edit_dirty_indices({"old_payloads": {id: old[id]},
				"new_payloads": {id: changed[id]}}, edge) == expected_by_chunk[id])
		var legacy_text: PackedByteArray = old.XTXT.duplicate()
		OverlayData.write(legacy_text, 777, 202)
		command.old_text = old.XTXT
		command.new_text = legacy_text
		command.tile_indices = PackedInt32Array([42, 255])
		command.points = [Vector2i(3, 4)]
		var combined := expected_indices.duplicate()
		combined.append(777)
		combined.append(42)
		combined.append(3 * edge + 4)
		combined.sort()
		assert(Main._edit_dirty_indices(command, edge) == combined,
			"Payload, legacy text, explicit tiles and points form one sorted union")
		assert(Main._edit_dirty_indices({"old_payloads": old, "new_payloads": old}, edge).is_empty())
		command = {"old_text": old.XTXT, "new_text": changed.XTXT}
		assert(Main._edit_dirty_indices(command, edge) == expected_by_chunk.XTXT)

		if edge > 128:
			var high_only: PackedByteArray = old.XTXT.duplicate()
			high_only[edge * edge + 257] = 16
			assert(Main._edit_dirty_indices({"old_text": old.XTXT, "new_text": high_only}, edge) == PackedInt32Array([257]))

	print("PASS: dirty tile comparison at all map sizes and byte/block boundaries")
	quit()
