extends SceneTree

const Tiles = preload("res://src/tools/shared/building_tile_ids.gd")

class Fixture extends RefCounted:
	var payloads: Dictionary[String, PackedByteArray] = {}
	var altitudes := PackedInt32Array()

	func copy() -> Fixture:
		var result := Fixture.new()
		result.payloads = GrowthState.duplicate_payloads(payloads)
		result.altitudes = altitudes.duplicate()

		return result


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
			for tile in [Tiles.CONTROL_TOWER_2, Tiles.SEAPORT_WAREHOUSE, Tiles.HANGAR_1, Tiles.PARKING_LOT_2, Tiles.TOP_SECRET, Tiles.CARGO_YARD]:
				var p := base.copy()
				var point := Vector2i(edge - 12, edge - 12)
				var result := SpecialZoneSelection.grow_special_zone(p.payloads.XBLD, p.payloads.XZON, p.payloads.XUND, p.payloads.XBIT, p.payloads.XTER,
					p.altitudes, p.payloads.MISC, point, tile, 7, rotation, edge)
				check(result.ok and result.changed_tiles == (4 if tile in [0xef, 0xf1, 0xf2] else 1), "Military building grows at far map")
				check(p.payloads.XBLD[point.x * edge + point.y] == tile, "Military building has selected tile")
				check((p.payloads.XZON[point.x * edge + point.y] & 15) == 7, "Military zone survives growth")
				check(SpecialZoneState.tile_count(p.payloads.MISC, tile, true, edge) == result.changed_tiles, "Military tile counter follows growth")
				check(SpecialZoneState.tile_count(p.payloads.MISC, tile, false, edge) == 0, "Civilian count stays separate")
			var p := base.copy()
			var point := Vector2i(edge - 11, edge - 11)
			SpecialZoneState.write_u32(p.payloads.MISC, 0x01f0 + 0xdd * 4, 1)
			var runway := SpecialZoneSelection.grow_special_zone(p.payloads.XBLD, p.payloads.XZON, p.payloads.XUND, p.payloads.XBIT, p.payloads.XTER,
				p.altitudes, p.payloads.MISC, point, 0xdd, 7, rotation, edge)
			check(runway.ok and runway.changed_tiles == 5, "Military runway grows")
			check(p.payloads.XBLD[point.x * edge + point.y + 4] == 0xdd, "Military parity ignores civilian runway count")
		for obstruction in [0x1d, 0x1e, 0xdd, 0xde, 0xe0, 0xf9, 0x05, 0x0d, -1, -2, -3]:
			var p := base.copy()
			var point := Vector2i(edge - 12, edge - 12)
			var index: int = (point.x + 1) * edge + point.y + 1
			if obstruction >= 0:
				p.payloads.XBLD[index] = obstruction
			elif obstruction == -1:
				p.payloads.XUND[index] = UndergroundTileIds.SUBWAY_LR
			elif obstruction == -2:
				p.payloads.XTER[index] = 1
			else:
				p.payloads.XBIT[index] = 4
			var before := p.copy()
			var result := SpecialZoneSelection.grow_special_zone(p.payloads.XBLD, p.payloads.XZON, p.payloads.XUND, p.payloads.XBIT, p.payloads.XTER,
				p.altitudes, p.payloads.MISC, point, 0xef, 7, 0, edge)
			check(not result.ok, "Military growth rejects obstruction anywhere in footprint")
			check(p.payloads == before.payloads and p.altitudes == before.altitudes, "Rejected military growth is atomic")
	print("Military growth regression: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func fixture(edge: int) -> Fixture:
	var doc := EmptyCityTemplate.create(edge)
	var city := CityState.from_document(doc)
	var p := Fixture.new()
	p.payloads = GrowthState.duplicate_payloads(GrowthState.payloads(city))
	p.altitudes = city.altitude_words.duplicate()
	p.payloads.XZON.fill(7)
	SpecialZoneState.write_u32(p.payloads.MISC, 0x01f0, 0)
	SpecialZoneState.write_u32(p.payloads.MISC, 0x0fa8, edge * edge)
	return p
