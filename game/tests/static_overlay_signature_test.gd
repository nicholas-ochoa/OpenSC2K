extends SceneTree

func _initialize() -> void:
	for path in ["res://../references/CITIES/SYDNEY.SC2", "res://../local/large-cities/stitched-512.sc2x"]:
		var city := CityState.from_document(Sc2File.load_path(path))
		assert(CityIsometricRenderer._static_text_overlay_signature(city) == _reference(city))
		var things := city.document.find_chunk("XTHG")
		for record in [1, city.thing_count() - 1]:
			things.decoded_payload[record * CityState.THING_RECORD_SIZE] = 7
			OverlayData.write(city.text_overlays, 100 + record, OverlayData.thing_id(record))
			OverlayData.write(city.text_overlays, 1000 + record, OverlayData.thing_id(record))
		assert(CityIsometricRenderer._static_text_overlay_signature(city) == _reference(city))
		# Include duplicate IDs and high-plane sign values at unrelated coordinates.
		OverlayData.write(city.text_overlays, 42, 1)
		OverlayData.write(city.text_overlays, 43, 1)
		if city.map_size > 128:
			OverlayData.write(city.text_overlays, 44, OverlayData.EXTRA_SIGN)
		assert(CityIsometricRenderer._static_text_overlay_signature(city) == _reference(city))
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
			if int(thing.get("type", 0)) in CityIsometricRenderer.DISPATCH_SPRITE_OFFSETS:
				values.append(index)
				for key in ["type", "direction", "state", "x", "y", "z", "px", "py"]:
					values.append(int(thing.get(key, 0)))
	return hash(values)
