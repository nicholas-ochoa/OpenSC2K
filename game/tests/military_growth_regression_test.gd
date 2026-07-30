extends SceneTree

var checks := 0
var failures := 0


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)


func _initialize() -> void:
	for edge in Sc2File.MAP_SIZES:
		var base := fixture(edge)
		for rotation in 4:
			for tile in [0xe2, 0xe3, 0xe8, 0xef, 0xf1, 0xf2]:
				var p := GrowthState.duplicate_payloads(base)
				var point := Vector2i(edge - 12, edge - 12)
				var result := SpecialZoneGrowth._grow_special_zone(p.XBLD, p.XZON, p.XUND, p.XBIT, p.XTER,
					p.altitudes, p.MISC, point, tile, 7, rotation, edge)
				check(result.ok and result.changed_tiles == (4 if tile in [0xef, 0xf1, 0xf2] else 1), "Military building grows at far map")
				check(p.XBLD[point.x * edge + point.y] == tile, "Military building has selected tile")
				check((p.XZON[point.x * edge + point.y] & 15) == 7, "Military zone survives growth")
				check(SpecialZoneGrowth.tile_count(p.MISC, tile, true, edge) == result.changed_tiles, "Military tile counter follows growth")
				check(SpecialZoneGrowth.tile_count(p.MISC, tile, false, edge) == 0, "Civilian count stays separate")
			var p := GrowthState.duplicate_payloads(base)
			var point := Vector2i(edge - 11, edge - 11)
			SpecialZoneGrowth._write_u32(p.MISC, 0x01f0 + 0xdd * 4, 1)
			var runway := SpecialZoneGrowth._grow_special_zone(p.XBLD, p.XZON, p.XUND, p.XBIT, p.XTER,
				p.altitudes, p.MISC, point, 0xdd, 7, rotation, edge)
			check(runway.ok and runway.changed_tiles == 5, "Military runway grows")
			check(p.XBLD[point.x * edge + point.y + 4] == 0xdd, "Military parity ignores civilian runway count")
		for obstruction in [0x1d, 0x1e, 0xdd, 0xde, 0xe0, 0xf9, 0x05, 0x0d, -1, -2, -3]:
			var p := GrowthState.duplicate_payloads(base)
			var point := Vector2i(edge - 12, edge - 12)
			var index: int = (point.x + 1) * edge + point.y + 1
			if obstruction >= 0:
				p.XBLD[index] = obstruction
			elif obstruction == -1:
				p.XUND[index] = 1
			elif obstruction == -2:
				p.XTER[index] = 1
			else:
				p.XBIT[index] = 4
			var before := GrowthState.duplicate_payloads(p)
			var result := SpecialZoneGrowth._grow_special_zone(p.XBLD, p.XZON, p.XUND, p.XBIT, p.XTER,
				p.altitudes, p.MISC, point, 0xef, 7, 0, edge)
			check(not result.ok, "Military growth rejects obstruction anywhere in footprint")
			check(p == before, "Rejected military growth is atomic")
	print("Military growth regression: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func fixture(edge: int) -> Dictionary:
	var doc := EmptyCityTemplate.create(edge)
	var city := CityState.from_document(doc)
	var p := GrowthState.duplicate_payloads(GrowthState.payloads(city))
	p["altitudes"] = city.altitude_words.duplicate()
	p.XZON.fill(7)
	SpecialZoneGrowth._write_u32(p.MISC, 0x01f0, 0)
	SpecialZoneGrowth._write_u32(p.MISC, 0x0fa8, edge * edge)
	return p
