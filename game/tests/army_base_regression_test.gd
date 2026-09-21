extends SceneTree

class PlotRandom extends GameLcgRandom:
	var origin: int
	func _init(value: int) -> void:
		origin = value
	func next_mod(limit: int) -> int:
		return origin % limit

var checks := 0
var failures := 0


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)


func _initialize() -> void:
	for edge in Sc2File.MAP_SIZES:
		for native in ([false, true] if edge == 128 else [false]):
			for rotation in (range(4) if edge == 128 and not native else [0]):
				var doc := EmptyCityTemplate.create(edge)
				if native:
					doc.enable_full_resolution_maps()
				var city := CityState.from_document(doc)
				var origin: int = edge - 10
				var heights := doc.find_chunk("ALTM").decoded_payload.duplicate()
				heights[(origin * edge + origin + 1) * 2 + 1] = 1
				doc.find_chunk("ALTM").set_decoded_payload(heights)
				doc.set_misc_u32(0x0008, rotation)
				city = CityState.from_document(doc)
				var funds := city.funds()
				var proposal := MilitaryProposalPhase.resolve(city, true, PlotRandom.new(origin))
				check(proposal.ok and proposal.base_type == 2, "Uneven far-map plot becomes Army base")
				check(proposal.changed_indices.size() == 64, "Army proposal publishes the complete plot")
				var roads := 0
				var crosses := 0
				for x in range(origin, origin + 8):
					for y in range(origin, origin + 8):
						var tile := city.building_id(x, y)
						roads += int(tile >= 0x1d and tile <= 0x2b)
						crosses += int(tile == 0xde)
						check(city.zone_id(x, y) == 7, "Prepared roads retain military zoning")
				check(roads == 20 and crosses == 8, "Four intersecting Army strips have eight cross endpoints")
				check(doc.misc_u32(0x0fa8) == 56 and doc.misc_u32(0x0fb0) == 8, "Army preparation updates military counters")
				check(doc.misc_u32(0x01f0) == edge * edge - 64, "Army transfers only its plot out of normal counts")
				check(city.funds() == funds, "Army preparation does not charge the player")
				var bytes: PackedByteArray = doc.serialize().data
				var loaded := Sc2File.new()
				check(loaded.parse(bytes) and loaded.serialize().data == bytes, "Prepared Army base round trips exactly")
			# Per-cell underground protection: no partial ownership transfer at obstacles.
			var doc := EmptyCityTemplate.create(edge)
			if native:
				doc.enable_full_resolution_maps()
			var city := CityState.from_document(doc)
			city.set_underground_id(12, 10, UndergroundTileIds.SUBWAY_LR)
			var result := MilitaryProposalPhase.resolve(city, true, PlotRandom.new(10))
			check(result.ok and city.zone_id(12, 10) == 0 and city.underground_id(12, 10) == 1,
				"Proposal excludes each underground obstruction")
	print("Army base regression: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
