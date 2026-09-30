extends SceneTree


@warning_ignore_start("integer_division")

const Tiles = preload("res://src/tools/shared/building_tile_ids.gd")

var failures := 0
var checks := 0
var empty_payloads := {}


func _init() -> void:
	for edge in [128, 256, 384, 512, 640, 1024, 2048]:
		check_growth_dispatch(edge)
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
		var payloads := {}

		for chunk in EmptyCityTemplate.create(edge).chunks:
			payloads[chunk.chunk_id] = chunk.decoded_payload

		empty_payloads[edge] = payloads

	var result := {}

	for chunk_id: String in empty_payloads[edge]:
		result[chunk_id] = empty_payloads[edge][chunk_id].duplicate()

	return result


# the native weather, growth, and special-zone rules have their own edge tests
func check_random_sites(edge: int) -> void:
	var city := CityState.from_document(EmptyCityTemplate.create(edge))
	var proposal := MilitaryProposalPhase.resolve(city, true, SequenceGameLcg.new([edge - 10]))
	check(proposal.ok and city.zone_id(edge - 10, edge - 10) == 7, "Military base can select far map")
	city = CityState.from_document(EmptyCityTemplate.create(edge))
	city.buildings.fill(Tiles.SMALL_PARK)
	var choices: Array[int] = []
	choices.resize(48)
	choices.fill(10)

	for site in 6:
		var origin := Vector2i(edge - 30 + (site / 3) * 5, edge - 30 + (site % 3) * 5)
		choices.append_array([origin.x, origin.y])

		for dx in 3:
			for dy in 3:
				city.buildings[(origin.x + dx) * edge + origin.y + dy] = Tiles.EMPTY

	city.document.find_chunk("XBLD").set_decoded_payload(city.buildings)
	var silos := MilitaryProposalPhase.resolve(city, true, SequenceGameLcg.new(choices))
	check(silos.ok and silos.base_type == MilitaryProposalPhase.BASE_MISSILE_SILOS
		and silos.sites.size() == 6, "Military fallback selects six far silo plots")


func check_tools(edge: int) -> void:
	# the native tool tests cover reinforced sections and edge sections at each map width
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
	check(planned.confirmation_required and planned.finish == start + Vector2i(2, 0), "Far tunnel search")
	var applied := TunnelCommand.apply(city, 6, 2, start, 1)
	check(applied.ok, "Far tunnel placement")

	if applied.ok:
		check(TunnelCommand.undo(city, applied).ok and doc.serialize().data == before, "Far tunnel exact undo")


func check_growth_dispatch(edge: int) -> void:
	var doc := EmptyCityTemplate.create(edge)
	var city := CityState.from_document(doc)
	doc.set_misc_i32(Sc2MiscLayout.DEMAND, 2000)
	doc.find_chunk("XVAL").decoded_payload.fill(255)

	for sx in 4:
		for sy in 4:
			var origin := Vector2i(edge - 100 + sx * 24 + sx, edge - 100 + sy * 24 + sy)

			for dx in 2:
				for dy in 2:
					city.set_zone_id(origin.x + dx, origin.y - dy, 2)

				city.set_building_id(origin.x + dx, origin.y, Tiles.LOWER_CLASS_HOMES_1X1_1)
				city.set_tile_flag(origin.x + dx, origin.y, 0x40, true)
				city.zones[(origin.x + dx) * edge + origin.y] |= 0xf0

			for dy in range(1, 5):
				city.set_building_id(origin.x, origin.y + dy, Tiles.ROAD_STRAIGHT_1)

			city.set_zone_id(origin.x, origin.y + 5, 3)

	doc.find_chunk("XZON").set_decoded_payload(city.zones)
	var scanned := 0
	var advanced := 0

	for step in 4:
		for substep in 4:
			var result := GrowthScan.run(city, SequenceRandom.new(), step, substep,
				SequenceLfsr.new([1]), SequenceGameLcg.new())
			check(result.ok, "Full growth dispatch")
			scanned += result.scanned_tiles
			advanced += result.advanced_construction

	check(scanned == edge * edge, "Growth partitions cover each map tile once")
	check(advanced >= 16, "%d growth dispatch advances far developed sites: %d" % [edge, advanced])


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
