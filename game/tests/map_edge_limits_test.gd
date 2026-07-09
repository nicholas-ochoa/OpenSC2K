extends SceneTree

class SequenceRandom extends SimRandom:
	var values: Array[int]
	var position := 0


	func _init(sequence: Array[int] = [0]) -> void:
		values = sequence


	func next_u15() -> int:
		var value := values[position % values.size()]
		position += 1

		return value


class SequenceLfsr extends SimLfsrRandom:
	var values: Array[int]
	var position := 0


	func _init(sequence: Array[int] = [0]) -> void:
		values = sequence


	func next_mod(limit: int) -> int:
		return _next() % limit


	func next_mask(mask: int) -> int:
		return _next() & mask


	func _next() -> int:
		var value := values[position % values.size()]
		position += 1

		return value


class SequenceGameLcg extends GameLcgRandom:
	var values: Array[int]
	var position := 0


	func _init(sequence: Array[int] = [0]) -> void:
		values = sequence


	func next_mod(limit: int) -> int:
		var value := values[position % values.size()]
		position += 1

		return value % limit

var failures := 0
var checks := 0
var empty_payloads := {}


func _init() -> void:
	for edge in [128, 256, 384, 512]:
		check_growth(edge)
		check_growth_dispatch(edge)
		check_special(edge)
		check_transport(edge)
		check_random_sites(edge)
		check_tools(edge)
		print("PASS: map edge limits at %d" % edge)

	print("Map edge limits: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func check(condition: bool, message: String) -> void:
	checks += 1

	if not condition:
		failures += 1
		push_error(message)


func payloads(edge: int) -> Dictionary:
	if not empty_payloads.has(edge):
		empty_payloads[edge] = GrowthPhase._payloads(CityState.from_document(EmptyCityTemplate.create(edge)))

	return GrowthPhase._duplicate_payloads(empty_payloads[edge])


func check_growth(edge: int) -> void:
	for density in range(2, 5):
		for rotation in 4:
			var radius := IntegerMath.div_trunc(density, 2)

			for anchor in [Vector2i(20, 20), Vector2i(edge - 2 - radius, edge - 2 - radius)]:
				var p := payloads(edge)
				check(GrowthPhase._place_zone(p.XBLD, p.XZON, p.XBIT, p.MISC, p.XVAL,
					anchor, density, GrowthPhase.CLASS_CONSTRUCTION, SequenceRandom.new(), rotation, edge),
					"%d density %d rotation %d at %s" % [edge, density, rotation, anchor])
				var count: int = p.XBLD.size() - p.XBLD.count(0)

				check(count == (radius + 1) * (radius + 1), "Growth footprint size")

			for anchor in [Vector2i(edge - 1 - radius, 20), Vector2i(20, edge - 1 - radius), Vector2i(1, 20)]:
				var p := payloads(edge)
				var before: PackedByteArray = p.XBLD.duplicate()
				check(not GrowthPhase._place_zone(p.XBLD, p.XZON, p.XBIT, p.MISC, p.XVAL,
					anchor, density, GrowthPhase.CLASS_CONSTRUCTION, SequenceRandom.new(), rotation, edge),
					"Growth retains true edge margin")
				check(p.XBLD == before, "Rejected growth does not write buildings")


func check_special(edge: int) -> void:
	var wide := payloads(edge)
	SpecialZoneGrowth._write_u32(wide.MISC, SpecialZoneGrowth.MISC_SUBWAY_COUNT, 65535)
	SpecialZoneGrowth._replace_underground(wide.XUND, wide.XZON, wide.MISC, edge * edge - 1, 1)
	check(SpecialZoneGrowth._read_u32(wide.MISC, SpecialZoneGrowth.MISC_SUBWAY_COUNT)
		== (0 if edge == 128 else 65536), "Special growth preserves wide subway count")
	SpecialZoneGrowth._replace_underground(wide.XUND, wide.XZON, wide.MISC, edge * edge - 1, 0)
	check(SpecialZoneGrowth._read_u32(wide.MISC, SpecialZoneGrowth.MISC_SUBWAY_COUNT) == 65535,
		"Special growth subway decrement")

	for area in [2, 3]:
		for rotation in 4:
			var p := payloads(edge)
			var anchor := Vector2i(edge - 3, edge - 3)
			check(SpecialZoneGrowth._place_special_item(p.XBLD, p.XZON, p.XBIT, p.XTER,
				p.MISC, anchor, 0xdc, area, 8, rotation, edge), "Far special-zone footprint")
			p = payloads(edge)
			check(not SpecialZoneGrowth._place_special_item(p.XBLD, p.XZON, p.XBIT, p.XTER,
				p.MISC, Vector2i(edge - 2, edge - 2), 0xdc, area, 8, rotation, edge), "Special-zone edge margin")

	for origin in [Vector2i(edge - 3, edge - 3), Vector2i(edge - 2, edge - 2)]:
		var p := payloads(edge)
		var result := SpecialZoneGrowth._place_missile_silo(p.XBLD, p.XZON, p.XUND,
			p.MISC, origin, 7, 0, edge)
		check(result.ok == (origin.x == edge - 3), "Silo fits exactly at map edge")
		check(result.changed_tiles == (9 if result.ok else 0), "Silo footprint count")


func check_transport(edge: int) -> void:
	for start in [Vector2i(edge - 4, edge - 4), Vector2i(edge - 3, edge - 3)]:
		var p := payloads(edge)

		for delta in [Vector2i.ZERO, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var point: Vector2i = start + delta
			p.XBLD[point.x * edge + point.y] = 0x2c

		var spawned := MovingThingSpawner._spawn_train_record(p.XBLD, p.XTHG, p.XTXT,
			start, SequenceGameLcg.new(), SequenceLfsr.new(), edge)
		check(spawned == (start.x == edge - 4), "Train uses actual edge margin")

		if spawned:
			check(ThingData.read(p.XTHG, CityState.THING_RECORD_SIZE + 3) == start.x,
				"Train keeps wide coordinates")

	for active in [4, 5, IntegerMath.div_trunc(4 * edge * edge, 16384) + 1]:
		var p := payloads(edge)
		p.XBIT.fill(4)
		var offset := CityState.THING_RECORD_SIZE
		ThingData.write(p.XTHG, offset, MovingThingSpawner.TYPE_SAILBOAT)
		ThingData.write(p.XTHG, offset + 1, 1)
		ThingData.write(p.XTHG, offset + 3, edge - 3)
		ThingData.write(p.XTHG, offset + 4, edge - 3)
		ThingData.write(p.XTHG, offset + 6, 8)
		var counters := {"active_sailboats": active, "removed_sailboats": 0, "malformed_records": 0,
			"distressed_sailboats": 0, "turned_sailboats": 0, "moved_sailboats": 0}
		SailboatThingTick.update(p.XBLD, p.XBIT, p.XTXT, p.XTHG, 1,
			SequenceRandom.new(), SequenceLfsr.new([1]), counters, edge)
		var survives: bool = active <= IntegerMath.div_trunc(4 * edge * edge, 16384)
		check((ThingData.read(p.XTHG, offset) != 0) == survives, "Sailboat population cap matches spawner")

		if survives:
			check(ThingData.read(p.XTHG, offset + 3) == edge - 2, "Sailboat reaches far interior")
			SailboatThingTick._move(p.XTXT, p.XTHG, 1, 1, counters, edge)
			check(ThingData.read(p.XTHG, offset) == 0, "Sailboat retains last-edge removal")


func check_random_sites(edge: int) -> void:
	var random := SequenceRandom.new([0, edge - 3])
	check(WeatherDisasterPhase._random_map_point(random, edge) == Vector2i(edge - 2, 1),
		"Random disaster spans full interior and keeps y-first order")
	check(random.position == 2, "Disaster point uses two random calls")
	var doc := EmptyCityTemplate.create(edge)
	doc.set_misc_u32(WeatherDisasterPhase.MISC_DIFFICULTY, 1)
	doc.set_misc_u32(WeatherDisasterPhase.MISC_CITY_DAYS, 100000)
	doc.set_misc_u32(WeatherDisasterPhase.MISC_NO_DISASTERS, 0)
	doc.set_misc_u32(WeatherDisasterPhase.MISC_WEATHER_TREND, 11)
	var result := WeatherDisasterPhase._select_disaster(doc.find_chunk("MISC").decoded_payload,
		doc.find_chunk("XPLT").decoded_payload, SequenceRandom.new([0, edge - 3, edge - 3]),
		SequenceLfsr.new(), Vector2i.ZERO, edge)
	check(result.disaster_type == WeatherDisasterPhase.DISASTER_TORNADO
		and result.disaster_point == Vector2i(edge - 2, edge - 2), "Weather dispatch passes map edge")
	doc.set_misc_u32(WeatherDisasterPhase.MISC_WEATHER_TREND, 9)
	doc.set_misc_u32(WeatherDisasterPhase.MISC_WEATHER_HEAT, 255)
	doc.set_misc_u32(0x0e48, 1)
	doc.set_misc_u32(0x01f0 + WeatherDisasterPhase.TILE_RUNWAY * 4, 1)

	for candidate in [WeatherDisasterPhase.DISASTER_FIRE, WeatherDisasterPhase.DISASTER_EARTHQUAKE,
		WeatherDisasterPhase.DISASTER_TORNADO, WeatherDisasterPhase.DISASTER_FLOOD,
		WeatherDisasterPhase.DISASTER_MASS_FLOODS, WeatherDisasterPhase.DISASTER_PLANE_CRASH]:
		var sequence: Array[int] = [0, candidate]

		if candidate == WeatherDisasterPhase.DISASTER_FIRE:
			sequence.append(0)

		sequence.append_array([edge - 3, edge - 3])
		result = WeatherDisasterPhase._select_disaster(doc.find_chunk("MISC").decoded_payload,
			doc.find_chunk("XPLT").decoded_payload, SequenceRandom.new(sequence),
			SequenceLfsr.new(), Vector2i.ZERO, edge)
		check(result.disaster_type == candidate and result.disaster_point == Vector2i(edge - 2, edge - 2),
			"Disaster %d passes map edge" % candidate)

	var city := CityState.from_document(EmptyCityTemplate.create(edge))
	result = MilitaryProposalPhase.resolve(city, true, SequenceGameLcg.new([edge - 10]))
	check(result.ok and city.zone_id(edge - 10, edge - 10) == 7, "Military base can select far map")
	city = CityState.from_document(EmptyCityTemplate.create(edge))
	city.buildings.fill(0x0d)
	var choices: Array[int] = []
	choices.resize(48)
	choices.fill(10)

	for site in 6:
		var origin := Vector2i(edge - 30 + (IntegerMath.div_trunc(site, 3)) * 5, edge - 30 + (site % 3) * 5)
		choices.append_array([origin.x, origin.y])

		for dx in 3:
			for dy in 3:
				city.buildings[(origin.x + dx) * edge + origin.y + dy] = 0

	city.document.find_chunk("XBLD").set_decoded_payload(city.buildings)
	result = MilitaryProposalPhase.resolve(city, true, SequenceGameLcg.new(choices))
	check(result.ok and result.get("base_type") == MilitaryProposalPhase.BASE_MISSILE_SILOS
		and result.get("sites", []).size() == 6, "Military fallback selects six far silo plots")


func check_tools(edge: int) -> void:
	var p := payloads(edge)
	var corner := Vector2i(edge - 2, edge - 2)

	for dx in 2:
		for dy in 2:
			p.XBLD[(corner.x + dx) * edge + corner.y + dy] = 0x6a

	check(DemolishCommand._reinforced_section_is_valid(p.XBLD, corner, edge), "Far reinforced bridge section")
	check(not DemolishCommand._reinforced_section_is_valid(p.XBLD, corner + Vector2i.ONE, edge), "Bridge bounds reject overflow")

	for anchor in [Vector2i(20, 20), Vector2i(edge - 10, edge - 10), Vector2i(edge - 2, 20), Vector2i(20, edge - 2)]:
		p = payloads(edge)
		OverlayData.write(p.XTXT, anchor.x * edge + anchor.y, HighwayCommand.CONNECTION_LABEL)

		for direction in 2:
			var kind := HighwayCommand._select_section_kind(p.XBLD, p.XTER, p.XZON, p.XBIT,
				p.ALTM, p.XTXT, anchor, direction, edge)
			var expected: int = direction + 2
			check(kind == expected, "Highway edge connection at %s: %d expected %d" % [anchor, kind, expected])

	var doc := EmptyCityTemplate.create(edge)
	doc.set_misc_i32(0x14, 1000)
	var city := CityState.from_document(doc)
	var start := Vector2i(edge - 8, edge - 8)
	city.set_terrain_id(start.x, start.y, 3)
	city.set_land_altitude(start.x, start.y, 5)
	city.set_land_altitude(start.x + 1, start.y, 6)
	city.set_terrain_id(start.x + 2, start.y, 1)
	city.set_land_altitude(start.x + 2, start.y, 5)
	var before: PackedByteArray = doc.serialize().data
	var planned := TunnelCommand.apply(city, 6, 2, start)
	check(planned.get("confirmation_required", false) and planned.get("finish") == start + Vector2i(2, 0), "Far tunnel search")
	var applied := TunnelCommand.apply(city, 6, 2, start, 1)
	check(applied.ok, "Far tunnel placement")

	if applied.ok:
		check(TunnelCommand.undo(city, applied).ok and doc.serialize().data == before, "Far tunnel exact undo")


func check_growth_dispatch(edge: int) -> void:
	var doc := EmptyCityTemplate.create(edge)
	var city := CityState.from_document(doc)
	doc.set_misc_i32(GrowthPhase.MISC_DEMAND, 2000)
	doc.find_chunk("XVAL").decoded_payload.fill(255)

	for sx in 4:
		for sy in 4:
			var origin := Vector2i(edge - 100 + sx * 24 + sx, edge - 100 + sy * 24 + sy)

			for dx in 2:
				for dy in 2:
					city.set_zone_id(origin.x + dx, origin.y - dy, 2)

				city.set_building_id(origin.x + dx, origin.y, 0x70)
				city.set_tile_flag(origin.x + dx, origin.y, 0x40, true)
				city.zones[(origin.x + dx) * edge + origin.y] |= 0xf0

			for dy in range(1, 5):
				city.set_building_id(origin.x, origin.y + dy, 0x1d)

			city.set_zone_id(origin.x, origin.y + 5, 3)

	doc.find_chunk("XZON").set_decoded_payload(city.zones)
	var scanned := 0
	var advanced := 0

	for step in 4:
		for substep in 4:
			var result := GrowthPhase.run(city, SequenceRandom.new(), step, substep,
				SequenceLfsr.new([1]), SequenceGameLcg.new())
			check(result.ok, "Full growth dispatch")
			scanned += int(result.get("scanned_tiles", 0))
			advanced += int(result.get("advanced_construction", 0))

	check(scanned == edge * edge, "Growth partitions cover each map tile once")
	check(advanced >= 16, "%d growth dispatch advances far developed sites: %d" % [edge, advanced])
