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
			BinaryData.write_u32_be(p.payloads.MISC, 0x01f0 + 0xdd * 4, 1)
			var runway := SpecialZoneSelection.grow_special_zone(p.payloads.XBLD, p.payloads.XZON, p.payloads.XUND, p.payloads.XBIT, p.payloads.XTER,
				p.altitudes, p.payloads.MISC, point, 0xdd, 7, rotation, edge)
			check(runway.ok and runway.changed_tiles == 5, "Military runway grows")
			check(p.payloads.XBLD[point.x * edge + point.y + 4] == 0xdd, "Military parity ignores civilian runway count")
	_test_two_by_two_rules()
	_test_simple_utility_flags()
	print("Military growth regression: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func fixture(edge: int) -> Fixture:
	var doc := EmptyCityTemplate.create(edge)
	var city := CityState.from_document(doc)
	var p := Fixture.new()
	p.payloads = GrowthState.duplicate_payloads(GrowthState.payloads(city))
	p.altitudes = city.altitude_words.duplicate()
	p.payloads.XZON.fill(7)
	BinaryData.write_u32_be(p.payloads.MISC, 0x01f0, 0)
	BinaryData.write_u32_be(p.payloads.MISC, 0x0fa8, edge * edge)
	return p


func grow(p: Fixture, point: Vector2i, tile: int) -> SpecialZonePlacement.Result:
	return SpecialZoneSelection.grow_special_zone(p.payloads.XBLD, p.payloads.XZON, p.payloads.XUND, p.payloads.XBIT, p.payloads.XTER,
		p.altitudes, p.payloads.MISC, point, tile, 7, 0, 128)


func _test_two_by_two_rules() -> void:
	var base := fixture(128)
	var point := Vector2i(2, 2)
	var anchor := 2 * 128 + 2
	var other := 3 * 128 + 2
	var aircraft := 3 * 128 + 3
	# Each original footprint restriction must reject before clearing anything.
	for tile in [Tiles.RUNWAY, Tiles.RUNWAY_CROSSING, Tiles.CRANE]:
		for offset in [0, 1, 128, 129]:
			var p := base.copy()
			p.payloads.XBLD[anchor + offset] = tile
			var before := p.copy()
			check(not grow(p, point, Tiles.PARKING_LOT_2).ok, "Runway or crane blocks the whole footprint")
			check(p.payloads == before.payloads, "Original obstruction prevents all writes")
	for offset in [0, 1, 128, 129]:
		var p := base.copy()
		p.payloads.XZON[anchor + offset] = 8
		var before := p.copy()
		check(not grow(p, point, Tiles.PARKING_LOT_2).ok, "Every footprint cell must have the same zone")
		check(p.payloads == before.payloads, "Zone mismatch prevents all writes")
	var blocked := base.copy()
	blocked.payloads.XBLD[anchor] = Tiles.MISSILE_SILO
	check(not grow(blocked, point, Tiles.PARKING_LOT_2).ok, "High building ID blocks the anchor")

	# Extra military guards must not suppress clearing or change the fallback.
	# The common writer still permits ordinary military buildings.
	for obstruction in [Tiles.FIRST_ROAD, Tiles.RADIOACTIVE_WASTE, Tiles.SMALL_PARK, Tiles.MISSILE_SILO, -1, -2, -3]:
		var p := base.copy()
		SpecialZoneState.replace_building(p.payloads.XBLD, p.payloads.XZON, p.payloads.MISC, aircraft, Tiles.FIGHTER_JET)
		p.payloads.XBIT[aircraft] = 0xf3
		p.payloads.XZON[aircraft] = 0xf7
		if obstruction >= 0:
			SpecialZoneState.replace_building(p.payloads.XBLD, p.payloads.XZON, p.payloads.MISC, other, obstruction)
		elif obstruction == -1:
			p.payloads.XUND[other] = UndergroundTileIds.PIPE_LR
		elif obstruction == -2:
			p.payloads.XTER[other] = 1
		else:
			p.payloads.XBIT[other] = Sc2TileFlags.WATER
		var underground := p.payloads.XUND.duplicate()
		var terrain := p.payloads.XTER.duplicate()
		BinaryData.write_u32_be(p.payloads.MISC, Sc2MiscLayout.MILITARY_BASE_TYPE, 2)
		SpecialZoneGrowth.process(p.payloads.XBLD, p.payloads.XZON, p.payloads.XUND, p.payloads.XBIT, p.payloads.XTER,
			p.altitudes, p.payloads.XTXT, p.payloads.XTHG, p.payloads.MISC, point, SimRandom.new(3), 0, GrowthMaintenanceResult.new())
		var placed: bool = obstruction == -1 or obstruction == Tiles.MISSILE_SILO
		check(p.payloads.XBLD[anchor] == (Tiles.PARKING_LOT_2 if placed else Tiles.EMPTY), "Army growth keeps placement outcome without a hangar fallback")
		check(p.payloads.XBLD[aircraft] == (Tiles.PARKING_LOT_2 if placed else Tiles.EMPTY), "Footprint clearing removes the existing aircraft")
		check(SpecialZoneState.tile_count(p.payloads.MISC, Tiles.FIGHTER_JET, true) == 0, "Clearing updates the military aircraft count")
		check(SpecialZoneState.tile_count(p.payloads.MISC, Tiles.PARKING_LOT_2, true) == (4 if placed else 0), "Military parking count follows actual placement")
		check(p.payloads.XBIT[aircraft] == 3, "Footprint processing clears utility flags and preserves low flags")
		check((p.payloads.XZON[aircraft] & 15) == 7, "Clearing preserves the military zone")
		check(p.payloads.XUND == underground and p.payloads.XTER == terrain, "Growth preserves underground infrastructure and terrain")
		if obstruction in [Tiles.FIRST_ROAD, Tiles.RADIOACTIVE_WASTE, Tiles.SMALL_PARK]:
			check(p.payloads.XBLD[other] == obstruction, "Common placement still rejects road, radiation, or park")


func _test_simple_utility_flags() -> void:
	var base := fixture(128)
	var point := Vector2i(2, 2)
	var index := 2 * 128 + 2
	for tile in [Tiles.SMALL_PARK, Tiles.FIRST_ROAD, Tiles.RUNWAY, Tiles.CONTROL_TOWER_2, Tiles.MISSILE_SILO]:
		var p := base.copy()
		p.payloads.XBLD[index] = tile
		p.payloads.XBIT[index] = 0xf3
		p.payloads.XZON[index] = 0xf7
		var before := p.copy()
		var result := grow(p, point, Tiles.CONTROL_TOWER_2)
		check(result.ok and result.changed_tiles == 0, "Blocked one-cell attempt reports success without placement")
		check(p.payloads == before.payloads, "Blocked one-cell attempt preserves all saved state")
	for tile in [Tiles.EMPTY, Tiles.RADIOACTIVE_WASTE, Tiles.TREE_LAST]:
		var p := base.copy()
		p.payloads.XBLD[index] = tile
		p.payloads.XBIT[index] = 0xf3
		var result := grow(p, point, Tiles.CONTROL_TOWER_2)
		var placed: bool = tile != Tiles.RADIOACTIVE_WASTE
		check(result.ok and result.changed_tiles == int(placed), "Eligible one-cell attempt keeps the common placement result")
		check(p.payloads.XBLD[index] == (Tiles.CONTROL_TOWER_2 if placed else tile), "Eligible one-cell attempt preserves military placement support")
		check(p.payloads.XBIT[index] == 3, "Eligible one-cell attempt still clears utility flags")
