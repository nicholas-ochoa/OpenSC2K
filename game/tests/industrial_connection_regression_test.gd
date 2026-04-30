extends SceneTree

var checks := 0
var failures := 0


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)


func _initialize() -> void:
	# SC2, coarse SC2X, and full-resolution SC2X each retain all tile IDs.
	for edge in [128, 256, 512]:
		for native in [edge == 512]:
			var doc := EmptyCityTemplate.create(edge)
			if native:
				doc.enable_full_resolution_maps()
			var buildings := doc.find_chunk("XBLD").decoded_payload.duplicate()
			var overlays := doc.find_chunk("XTXT").decoded_payload.duplicate()
			# All tile IDs at the far edge: validate exact source ranges and exclusions.
			for tile in 256:
				var index: int = edge * edge - 1 - tile
				buildings[index] = tile
				OverlayData.write(overlays, index, 250)
			# A rail without a connection marker is not a neighbor connection.
			buildings[0] = 0x2c
			if edge > 128:
				buildings[1] = 0x61
				OverlayData.write(overlays, 1, 506)
			doc.find_chunk("XBLD").set_decoded_payload(buildings)
			doc.find_chunk("XTXT").set_decoded_payload(overlays)
			doc.set_misc_u32(0x05f0 + 1 * 4, 100000)
			doc.set_misc_u32(0x05f0 + 3 * 4, 50000)
			doc.set_misc_u32(0x05f0 + 5 * 4, 50000)
			doc.set_misc_u32(0x1030, 10000)
			doc.set_misc_u32(0x0074, 100000)
			var before: PackedByteArray = doc.serialize().data
			var city := CityState.from_document(doc)
			var engine := SimulationEngine.new(city, 1, 1, 1)
			check(engine.industry_connections == 40, "Engine reload counts all 40 rail/highway variants")
			check(engine.commerce_connections == 25, "Engine retains separate commerce connections")
			check(doc.serialize().data == before, "Connection reconstruction leaves saved bytes unchanged")
			var reloaded := Sc2File.new()
			check(reloaded.parse(before), "Reload generated city bytes")
			var reload_city := CityState.from_document(reloaded)
			var reload_engine := SimulationEngine.new(reload_city, 1, 1, 1)
			check(reload_engine.industry_connections == engine.industry_connections, "Connections survive save and reload")
			var first := RciDemandPhase.run(city)
			var second := RciDemandPhase.run(reload_city)
			check(first.ok and second.ok and first.targets == second.targets and first.demands == second.demands,
				"Industrial target and demand do not drop after load")
			check(first.targets[2] == 61500, "Industrial cap includes every reconstructed connection")
			overlays.fill(0)
			reloaded.find_chunk("XTXT").set_decoded_payload(overlays)
			reload_city = CityState.from_document(reloaded)
			var disconnected := RciDemandPhase.run(reload_city)
			check(disconnected.ok and disconnected.targets[2] == 1500, "Negative control detects the missing-connection cap")
	print("Industrial connection regression: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
