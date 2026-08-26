extends SceneTree

@warning_ignore_start("integer_division")


func _initialize() -> void:
	for path in ["res://../references/SIMCITY2000/CITIES/SYDNEY.SC2", "res://../local/large-cities/stitched-512.sc2x"]:
		var city := CityState.from_document(Sc2File.load_path(path))
		assert(IsometricStaticVisuals._static_text_overlay_signature(city) == _reference(city))
		var things := city.document.find_chunk("XTHG")

		for record in [1, city.thing_count() - 1]:
			things.write_decoded_byte(record * CityState.THING_RECORD_SIZE, 7)
			city.set_text_overlay_id((100 + record) / city.map_size, (100 + record) % city.map_size, OverlayData.thing_id(record))
			city.set_text_overlay_id((1000 + record) / city.map_size, (1000 + record) % city.map_size, OverlayData.thing_id(record))

		assert(IsometricStaticVisuals._static_text_overlay_signature(city) == _reference(city))
		# Include duplicate IDs and high-plane sign values at unrelated coordinates.
		city.set_text_overlay_id(0, 42, 1)
		city.set_text_overlay_id(0, 43, 1)

		if city.map_size > 128:
			city.set_text_overlay_id(0, 44, OverlayData.EXTRA_SIGN)

		assert(IsometricStaticVisuals._static_text_overlay_signature(city) == _reference(city))

	_check_sign_scan()
	_check_cache_edits()
	print("PASS: sparse static overlay signatures retain scan order and duplicate sign IDs")
	quit()


func _reference(city: CityState) -> int:
	var values := PackedInt32Array()

	for index in OverlayData.count(city.text_overlays):
		var overlay := OverlayData.read(city.text_overlays, index)

		if OverlayData.is_sign(overlay):
			values.append(index)
			values.append(overlay)
		elif OverlayData.is_thing(overlay):
			var thing := city.thing(OverlayData.thing_record(overlay))

			if thing != null and thing.type in CityIsometricRenderer.DISPATCH_SPRITE_OFFSETS:
				values.append(index)

				for key in ["type", "direction", "state", "x", "y", "z", "px", "py"]:
					values.append(int(thing.get(key)))

	return hash(values)


func _check_sign_scan() -> void:
	# Every low/high byte combination, in every word lane. Include sign IDs
	# with low byte zero and facility/thing IDs whose low byte looks like a sign.
	var data := PackedByteArray()
	data.resize(131072)

	for lane in 8:
		var expected := PackedInt32Array()

		for index in 65536:
			var value := (index + lane) & 65535
			OverlayData.write(data, index, value)

			if OverlayData.is_sign(value):
				expected.append(index)

		assert(OverlayData.sign_indices(data) == expected)

	for size in [0, 1, 7, 8, 9, 255, 256, 257]:
		data.resize(size)
		var expected := PackedInt32Array()

		for index in size:
			data[index] = index & 255

			if data[index] >= 1 and data[index] <= 50:
				expected.append(index)

		assert(OverlayData.sign_indices(data) == expected)


func _check_cache_edits() -> void:
	for edge in [128, 256]:
		var city := CityState.from_document(EmptyCityTemplate.create(edge))
		var before := IsometricStaticVisuals.static_visual_signature(city)
		var sign_id := 50 if edge == 128 else OverlayData.EXTRA_SIGN
		# The last cell also checks the last cached page.
		assert(city.set_text_overlay_id(edge - 1, edge - 1, sign_id))
		var signed := IsometricStaticVisuals.static_visual_signature(city)
		assert(signed != before, "Placing a sign invalidates the surface")
		assert(IsometricStaticVisuals._static_text_overlay_signature(city) == _reference(city))
		assert(city.set_text_overlay_id(edge - 1, edge - 1, 0))
		assert(IsometricStaticVisuals.static_visual_signature(city) == before, "Deleting a sign restores the content signature")
		var things := city.document.find_chunk("XTHG")
		var record := 1 if edge == 128 else 40
		var offset := record * CityState.THING_RECORD_SIZE
		assert(things.write_decoded_bytes(offset, PackedByteArray([7, 0, 0, 10, 10, 0, 0, 0])))
		assert(city.set_text_overlay_id(10, 10, OverlayData.thing_id(record)))
		before = IsometricStaticVisuals.static_visual_signature(city)
		assert(things.write_decoded_byte(offset + 3, 11))
		assert(IsometricStaticVisuals.static_visual_signature(city) != before, "XTHG-only dispatch movement invalidates the surface")
		before = IsometricStaticVisuals.static_visual_signature(city)
		assert(city.set_text_overlay_id(10, 10, 0))
		assert(city.set_text_overlay_id(11, 10, OverlayData.thing_id(record)))
		assert(IsometricStaticVisuals.static_visual_signature(city) != before, "Moving the dispatch link invalidates the surface")
		assert(IsometricStaticVisuals._static_text_overlay_signature(city) == _reference(city))
		before = IsometricStaticVisuals.static_visual_signature(city)
		assert(things.write_decoded_byte(offset + 8, 12))
		assert(city.set_text_overlay_id(12, 12, 0xfb))
		assert(things.write_decoded_byte(0, 1))
		assert(IsometricStaticVisuals.static_visual_signature(city) == before, "Unrelated XTXT and XTHG bytes do not repaint")
		assert(city.set_tile_flag(20, 20, 0x40, true))
		assert(IsometricStaticVisuals.static_visual_signature(city) != before, "Power flags invalidate the surface")
		before = IsometricStaticVisuals.static_visual_signature(city)

		for mask in [0x10, 0x20]:
			var underground := CityUndergroundView.visual_signature(city, CityIsometricRenderer.VIEW_LARGE)
			assert(city.set_tile_flag(20, 20, mask, true))
			assert(IsometricStaticVisuals.static_visual_signature(city) == before, "Watered and piped bits do not repaint the surface")
			assert(CityUndergroundView.visual_signature(city, CityIsometricRenderer.VIEW_LARGE) != underground, "Watered and piped bits repaint underground")

		var other := CityState.from_document(EmptyCityTemplate.create(edge))
		assert(IsometricStaticVisuals._static_text_overlay_signature(other) == _reference(other))
		assert(IsometricStaticVisuals._static_text_overlay_signature(city) == _reference(city), "Switching cities cannot reuse another city's cache")
