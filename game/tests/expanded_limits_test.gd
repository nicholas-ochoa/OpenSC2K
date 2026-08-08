extends SceneTree
var failures := 0


func _init() -> void:
	check_upgrade()

	for edge in [128, 256, 384, 512]:
		var document := EmptyCityTemplate.create(edge)
		var city := CityState.from_document(document)
		var factor: int = edge * edge / 16384
		check(city.microsim_count() == 150 * factor, "facility capacity")
		check(city.thing_count() == 40 * factor, "object capacity")
		var signs := OverlayData.sign_ids(document.decoded_size("XLAB"))
		check(signs.size() == 50 * factor, "sign capacity")

		# Fill the table directly, then allocate real signs at width/capacity boundaries.
		var selected_signs: Array[int] = []
		for index in [0, 49, 50, signs.size() - 1]:
			if index < signs.size() and not selected_signs.has(signs[index]):
				selected_signs.append(signs[index])
		var sign_labels := document.find_chunk("XLAB").decoded_payload.duplicate()
		for id in signs:
			if not selected_signs.has(id):
				BuildingFacilities.write_label(sign_labels, id, "Occupied")
		document.find_chunk("XLAB").set_decoded_payload(sign_labels)
		for index in selected_signs.size():
			var point := Vector2i(0, index)
			check(SignCommand.set_sign(city, point, "Sign %d" % index).ok, "sign placement")
			check(city.text_overlay_id(point.x, point.y) == selected_signs[index], "boundary sign link")
		check(not SignCommand.set_sign(city, Vector2i(1, 0), "Overflow").ok, "full sign table rejects allocation")

		var micro := document.find_chunk("XMIC").decoded_payload.duplicate()
		var labels := document.find_chunk("XLAB").decoded_payload.duplicate()
		var overlays := city.text_overlays.duplicate()
		var rng := SimRandom.new(123)

		var selected_records: Array[int] = []
		for record in [10, 149, 150, city.microsim_count() - 1]:
			if record < city.microsim_count() and not selected_records.has(record):
				selected_records.append(record)
		for record in range(10, city.microsim_count()):
			if not selected_records.has(record):
				micro[record * CityState.MICROSIM_RECORD_SIZE] = 0xd2
		for record in selected_records:
			var id := BuildingFacilities.provision_microsim(micro, labels, overlays, 0xd2, 2050, rng, document.find_chunk("MISC").decoded_payload)
			check(id == OverlayData.facility_id(record), "facility boundary allocation %d" % record)

		check(BuildingFacilities.provision_microsim(micro, labels, overlays, 0xd2, 2050, rng, document.find_chunk("MISC").decoded_payload) == 0, "capacity enforced")
		document.find_chunk("XMIC").set_decoded_payload(micro)
		document.find_chunk("XLAB").set_decoded_payload(labels)
		var things := document.find_chunk("XTHG").decoded_payload.duplicate()

		for record in range(1, city.thing_count()):
			var index: int = edge * edge - record
			ThingData.write(things, record * 12, 7)
			ThingData.write(things, record * 12 + 3, index / edge)
			ThingData.write(things, record * 12 + 4, index % edge)
			OverlayData.write(overlays, index, OverlayData.thing_id(record))

		document.find_chunk("XTHG").set_decoded_payload(things)
		city.replace_text_overlays(overlays)
		var result := MovingThingPhase.run(city, rng, SimLfsrRandom.new(456))
		check(result.get("ok", false), "all object slots tick: " + str(result.get("error", "")))
		check(result.get("scanned_records", 0) == city.thing_count() - 1, "all object slots scanned")
		# Dispatch into an extended slot, then check that undo restores the bytes.
		things = document.find_chunk("XTHG").decoded_payload.duplicate()
		var last := city.thing_count() - 1
		ThingData.write(things, last * 12, 0)
		document.find_chunk("XTHG").set_decoded_payload(things)
		var dispatch_before: PackedByteArray = document.serialize().data
		var dispatch := DispatchCommand.apply(city, 2, 2, Vector2i(edge - 3, 8))
		check(dispatch.ok and dispatch.thing_index == last, "dispatch uses last extended slot")
		check(DispatchCommand.undo(city, dispatch).ok, "extended dispatch undo")
		check(document.serialize().data == dispatch_before, "exact dispatch undo")
		ThingData.write(things, last * 12, 10)
		ThingData.write(things, last * 12 + 2, last - 1)
		ThingData.write(things, last * 12 + 6, edge - 7)
		ThingData.write(things, last * 12 + 7, edge - 8)
		TrainThingTick._copy_record(things, last, last - 1)
		check(ThingData.read(things, (last - 1) * 12 + 6) == edge - 7, "train copy retains wide previous coordinate")
		check(ThingData.read(things, last * 12 + 2) == last - 1, "train record link retains width")

		if edge > 128:
			ThingData.write(things, last * 12, 3)
			ThingData.set_ship_home(things, last, Vector2i(edge - 1, edge - 2))
			ThingData.write(things, last * 12 + 1, 6)
			ThingData.write(things, last * 12 + 2, 2)
			check(ThingData.ship_home(things, last, Vector2i.ZERO) == Vector2i(edge - 1, edge - 2), "ship home survives direction and state changes")
			document.find_chunk("XTHG").set_decoded_payload(things)
			var rotation_before: PackedByteArray = document.serialize().data

			if edge == 512:
				for ccw in [false, true]:
					check(CityRotationCommand.apply(city, ccw).ok, "rotate extended records")
				check(document.serialize().data == rotation_before, "inverse rotations preserve extended records")
			var markers := city.text_overlays.duplicate()
			OverlayData.write(markers, 0, 0x1fb)
			OverlayData.write(markers, 1, 0xfb)
			check(OverlayData.occurrences(markers, 0xfb) == 1, "facility low byte is not counted as fire")
			check(OverlayData.find(markers, 0xfb) == 1, "facility low byte is not drawn as fire")

		var bytes: PackedByteArray = document.serialize().data
		var loaded := Sc2File.new()
		check(loaded.parse(bytes), "reload extended records")
		check(loaded.serialize(true).data == bytes, "exact extended round trip")
		print("Checked record limits at %d" % edge)

	print("Expanded limit checks: %d failures" % failures)
	quit(1 if failures else 0)


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)


func check_upgrade() -> void:
	var document := EmptyCityTemplate.create(512)
	document.large_version = 1

	for id in ["XTXT", "XMIC", "XLAB", "XTHG"]:
		var chunk := document.find_chunk(id)
		chunk.expected_decoded_size = document.decoded_size(id)
		var data := PackedByteArray()
		data.resize(chunk.expected_decoded_size)
		chunk.set_decoded_payload(data)

	var bytes: PackedByteArray = document.serialize().data
	var loaded := Sc2File.new()
	check(loaded.parse(bytes), "version 1 still loads")
	check(loaded.serialize(true).data == bytes, "inactive version 1 stays byte exact")
	var city := CityState.from_document(loaded)
	check(city.is_valid() and loaded.large_version == 2 and city.thing_count() == 640, "active version 1 upgrades capacities")
	var bad := city.text_overlays.duplicate()
	OverlayData.write(bad, 0, 65535)
	loaded.find_chunk("XTXT").set_decoded_payload(bad)
	check(not CityState.from_document(loaded).is_valid(), "invalid extended link blocks gameplay")
