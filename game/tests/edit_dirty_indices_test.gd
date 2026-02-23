extends SceneTree
const Main = preload("res://src/main.gd")


func _initialize() -> void:
	for edge in [128, 256, 384, 512]:
		var old := {}
		var changed := {}
		var expected := {}

		for id in ["ALTM", "XBLD", "XTER", "XZON", "XBIT", "XTXT"]:
			var stride := 2 if id == "ALTM" or (id == "XTXT" and edge > 128) else 1
			var bytes := PackedByteArray()
			bytes.resize(edge * edge * stride)
			old[id] = bytes
			bytes = bytes.duplicate()

			for index in [0, 255, 256, 257, edge * edge - 1]:
				if id == "XTXT":
					OverlayData.write(bytes, index, 4097 if edge > 128 else 42)
				else:
					bytes[index * stride + stride - 1] = 42

				expected[index] = true

			changed[id] = bytes

		var command := {"old_payloads": old, "new_payloads": changed}
		var began := Time.get_ticks_usec()
		var oracle := {}

		for id in old:
			var a: PackedByteArray = old[id]
			var b: PackedByteArray = changed[id]

			for index in edge * edge:
				if id == "XTXT":
					if OverlayData.read(a, index) != OverlayData.read(b, index):
						oracle[index] = true
				elif id == "ALTM":
					if a[index * 2] != b[index * 2] or a[index * 2 + 1] != b[index * 2 + 1]:
						oracle[index] = true
				elif a[index] != b[index]:
					oracle[index] = true

		print("REFERENCE edge=%d usec=%d" % [edge, Time.get_ticks_usec() - began])
		assert(oracle == expected)
		began = Time.get_ticks_usec()
		var result := Main._edit_dirty_indices(command, edge)
		print("DIRTY edge=%d usec=%d" % [edge, Time.get_ticks_usec() - began])
		assert(result.size() == expected.size())

		for index in result:
			assert(expected.has(index))

		assert(Main._edit_dirty_indices({"old_payloads": old, "new_payloads": old}, edge).is_empty())
		command = {"old_text": old.XTXT, "new_text": changed.XTXT}
		var text_result := Main._edit_dirty_indices(command, edge)
		assert(text_result.size() == expected.size())

		for index in text_result:
			assert(expected.has(index))

		if edge > 128:
			var high_only: PackedByteArray = old.XTXT.duplicate()
			high_only[edge * edge + 257] = 16
			assert(Main._edit_dirty_indices({"old_text": old.XTXT, "new_text": high_only}, edge) == PackedInt32Array([257]))

	print("PASS: dirty tile comparison at all map sizes and byte/block boundaries")
	quit()
