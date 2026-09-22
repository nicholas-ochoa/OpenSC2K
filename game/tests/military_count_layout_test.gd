extends SceneTree


func _initialize() -> void:
	var counted_tiles := [0xdd, 0xde, 0xef, 0xf2, 0xea, 0xe3, 0xe4, 0xe5, 0xf1, 0xe0, 0xe2, 0xe7, 0xe8, 0xf6, 0xf9]
	var base := PackedByteArray()
	base.resize(4800)
	base.fill(90)

	for offset in range(0xfa8, 0xfe8):
		base[offset] = 0

	base[0xfab] = 10

	for tile in 256:
		var slot := counted_tiles.find(tile) + 1
		assert(SpecialZoneState._special_count_offset(tile, true) == 0xfa8 + slot * 4)
		assert(SpecialZoneState._special_count_offset(tile, false) == 0x1f0 + tile * 4)
		var expected := base.duplicate()

		if slot != 0:
			expected[0xfab] = 9
			expected[0xfab + slot * 4] = 1

		for edge: int in [128, 16]:
			for replace in [NetworkState.replace_building, SpecialZoneState.replace_building]:
				var buildings := PackedByteArray()
				buildings.resize(edge * edge)
				var zones := buildings.duplicate()
				zones[0] = 0xf7
				var misc := base.duplicate()
				replace.call(buildings, zones, misc, 0, tile)
				assert(buildings[0] == tile)
				assert(misc == expected, "Only the original military count slots change")

	print("PASS: all military tile slots, absent IDs and both replacement paths")
	quit()
