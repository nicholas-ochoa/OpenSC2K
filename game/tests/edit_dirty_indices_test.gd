extends SceneTree


func _collect(before: PackedByteArray, after: PackedByteArray, stride: int, cells: int, plane_cells := 0) -> PackedInt32Array:
	var dirty := PackedByteArray()
	dirty.resize(cells)
	var indices := PackedInt32Array()
	ApplicationStaticRender._collect_changed_tiles(before, after, stride, dirty, indices, plane_cells)
	indices.sort()

	return indices


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
		assert(ApplicationStaticRender._edit_dirty_indices(command, edge) == expected_indices)
		# Change each chunk alone so another changed chunk cannot hide a missed dirty tile.
		for id in old:
			assert(ApplicationStaticRender._edit_dirty_indices({"old_payloads": {id: old[id]},
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
		assert(ApplicationStaticRender._edit_dirty_indices(command, edge) == combined,
			"Payload, legacy text, explicit tiles and points form one sorted union")
		assert(ApplicationStaticRender._edit_dirty_indices({"old_payloads": old, "new_payloads": old}, edge).is_empty())
		command = {"old_text": old.XTXT, "new_text": changed.XTXT}
		assert(ApplicationStaticRender._edit_dirty_indices(command, edge) == expected_by_chunk.XTXT)

		var word_edge: PackedByteArray = old.XBLD.duplicate()
		word_edge[7] = 1
		word_edge[8] = 1
		assert(ApplicationStaticRender._edit_dirty_indices({"old_payloads": {"XBLD": old.XBLD},
			"new_payloads": {"XBLD": word_edge}}, edge) == PackedInt32Array([7, 8]),
			"Changes on both sides of an eight-byte comparison group report")
		var low_byte: PackedByteArray = old.ALTM.duplicate()
		low_byte[600 * 2] = 5
		assert(ApplicationStaticRender._edit_dirty_indices({"old_payloads": {"ALTM": old.ALTM},
			"new_payloads": {"ALTM": low_byte}}, edge) == PackedInt32Array([600]),
			"The low byte of a two-byte altitude entry marks its tile")

		if edge > 128:
			var high_only: PackedByteArray = old.XTXT.duplicate()
			high_only[edge * edge + 257] = 16
			assert(ApplicationStaticRender._edit_dirty_indices({"old_text": old.XTXT, "new_text": high_only}, edge) == PackedInt32Array([257]))

	# Payload lengths the map-size guards never produce: not a multiple of the
	# eight-byte comparison group, and not a multiple of 256 tiles.
	var odd := PackedByteArray()
	odd.resize(1023)
	var odd_changed := odd.duplicate()
	odd_changed[7] = 1
	odd_changed[8] = 2
	odd_changed[1018] = 3
	odd_changed[1022] = 4
	assert(_collect(odd, odd_changed, 1, 1023) == PackedInt32Array([7, 8, 1018, 1022]),
		"The trailing bytes past the last whole word still report")
	var even := PackedByteArray()
	even.resize(1022)
	var even_changed := even.duplicate()
	even_changed[1021] = 9
	assert(_collect(even, even_changed, 2, 511) == PackedInt32Array([510]),
		"A stride of two maps a trailing high byte back to its tile")
	var planes := PackedByteArray()
	planes.resize(1000)
	var planes_changed := planes.duplicate()
	planes_changed[3] = 1
	planes_changed[503] = 1
	planes_changed[999] = 1
	assert(_collect(planes, planes_changed, 1, 500, 500) == PackedInt32Array([3, 499]),
		"Wide overlay planes fold the high plane onto the same tile")
	assert(_collect(odd, odd, 1, 1023).is_empty())

	print("PASS: dirty tile comparison at all map sizes and byte/word/block boundaries")
	quit()
