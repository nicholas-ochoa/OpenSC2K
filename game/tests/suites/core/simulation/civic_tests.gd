extends "res://tests/support/core_test_suite.gd"

## Simulation: civic checks.

@warning_ignore_start("integer_division")

const Milestones = preload("res://src/simulation/civic/milestone_phase.gd")
const MilitaryProposal = preload("res://src/simulation/civic/military_proposal_phase.gd")
const MayorApproval = preload("res://src/simulation/civic/mayor_approval_phase.gd")
const ToolAvailability = preload("res://src/tools/shared/tool_availability.gd")
const TestRandoms = preload("res://tests/support/test_randoms.gd")
const SequenceRandom = TestRandoms.SequenceRandom
const SequenceGameModuloRandom = TestRandoms.SequenceGameModuloRandom


func test_milestone_phase(reference_root: String) -> void:
	var document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))
	var city := CityModel.from_document(document)
	_check(document.set_misc_u32(0x0020, 0), "Milestone fixture clears progression")
	_check(document.set_misc_u32(0x0078, 0), "Milestone fixture clears reward grants")
	_check(document.set_misc_u32(0x1020, 999999), "Milestone fixture sets arcology population")
	_check(document.set_misc_u32(0x102c, 2000), "Milestone fixture reaches the exact threshold")
	var exact := Milestones.run(city)
	_check(exact.ok and not exact.advanced, "A milestone needs population above its threshold")
	_check(document.misc_u32(0x0020) == 0, "Arcology population does not advance a milestone")

	_check(document.set_misc_u32(0x102c, 2001), "Milestone fixture exceeds the first threshold")
	var first := Milestones.run(city)
	_check(first.ok and first.advanced and first.progression == 1, "Milestone advances one level")
	_check(document.misc_u32(0x0078) == 1, "The first milestone grants the mayor house")
	_check(
		first.news_items.size() == 1
		and first.news_items[0].type == 3
		and first.news_items[0].argument == 0,
		"Milestone emits growth news with the old level",
	)

	_check(document.set_misc_u32(0x102c, 10001), "Milestone fixture exceeds the second threshold")
	var second := Milestones.run(city)
	_check(second.progression == 2, "A later milestone still advances only one level")
	_check(document.misc_u32(0x0078) == 3, "The second milestone preserves and adds reward bits")

	var military_document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))
	var military_city := CityModel.from_document(military_document)
	_check(military_document.set_misc_u32(0x0020, 3), "Military milestone fixture sets progression")
	_check(military_document.set_misc_u32(0x0078, 7), "Military milestone fixture sets prior rewards")
	_check(military_document.set_misc_u32(0x102c, 60001), "Military milestone fixture sets population")
	var military := Milestones.run(military_city)
	_check(
		military.ok
		and military.progression == 4
		and military.military_proposal_pending
		and not military.complete,
		"The fourth milestone keeps the military proposal visible",
	)
	_check(military_document.misc_u32(0x0078) == 7, "The military milestone does not grant a reward")

	_check(military_document.set_misc_u32(0x102c, 90001), "Llama milestone fixture sets population")
	var llama := Milestones.run(military_city)
	_check(llama.ok and llama.progression == 5 and llama.reward_id == 3, "The fifth milestone grants the llama dome")
	_check(military_document.misc_u32(0x0078) == 15, "The llama milestone stores reward bit three")
	_check(
		military_document.set_misc_u32(
			ToolAvailability.MISC_INVENTION_YEARS + 12 * 4,
			0,
		),
		"Arcology milestone fixture releases one arcology",
	)
	_check(military_document.set_misc_u32(0x102c, 120001), "Arcology milestone fixture sets population")
	var arcology := Milestones.run(military_city)
	_check(arcology.ok and arcology.progression == 6, "The sixth milestone advances progression")
	_check(
		military_document.misc_u32(0x0078) == 31,
		"The sixth milestone enables the arcology chooser when one is released",
	)

	var final_document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))
	var final_city := CityModel.from_document(final_document)
	_check(final_document.set_misc_u32(0x0020, 9), "Final milestone fixture sets progression")
	_check(final_document.set_misc_u32(0x102c, 10000001), "Final milestone fixture sets population")
	var final := Milestones.run(final_city)
	_check(final.ok and final.progression == 10, "The last recovered threshold advances progression")
	var exhausted := Milestones.run(final_city)
	_check(exhausted.ok and not exhausted.advanced, "Progression stops after the recovered threshold table")


func test_military_proposal_phase(reference_root: String) -> void:
	var declined_document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))
	var declined_city := CityModel.from_document(declined_document)
	var declined := MilitaryProposal.resolve(declined_city, false, null)
	_check(declined.ok and not declined.accepted, "The player can decline a military proposal")
	_check(
		declined.base_type == MilitaryProposal.BASE_DECLINED
		and declined_document.misc_u32(MilitaryProposal.MISC_BASE_TYPE) == MilitaryProposal.BASE_DECLINED,
		"A declined proposal stores the original base type",
	)
	_check(declined.changed_indices.is_empty(), "A declined proposal does not change map zones")

	var air_document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))

	for chunk_id in ["XBLD", "XTER", "XZON", "XUND", "XBIT", "XTXT"]:
		_check(
			air_document.find_chunk(chunk_id).set_decoded_payload(_filled_bytes(CityState.TILE_COUNT, 0)),
			"Air Force fixture clears %s" % chunk_id,
		)

	_check(
		air_document.find_chunk("ALTM").set_decoded_payload(_filled_bytes(CityState.TILE_COUNT * 2, 0)),
		"Air Force fixture levels the map",
	)
	_check(
		air_document.set_misc_u32(MilitaryProposal.MISC_TILE_COUNTS, CityState.TILE_COUNT),
		"Air Force fixture counts clear tiles",
	)
	_check(
		air_document.set_misc_u32(MilitaryProposal.MISC_MILITARY_TILE_COUNTS, 0),
		"Air Force fixture clears its military count",
	)
	var air_city := CityModel.from_document(air_document)
	var air_random := SequenceGameModuloRandom.new([10, 20])
	var air := MilitaryProposal.resolve(air_city, true, air_random)
	_check(
		air.ok
		and air.accepted
		and air.base_type == MilitaryProposal.BASE_AIR_FORCE
		and air.notice_id == MilitaryProposal.NOTICE_AIR_FORCE,
		"A level candidate becomes an Air Force base",
	)
	_check(
		air.site == Rect2i(10, 20, 8, 8)
		and air.view_center_requests == [Vector2i(14, 24)]
		and air_random.position == 2,
		"The Air Force search accepts the first suitable eight-by-eight plot",
	)
	_check(air.changed_indices.size() == 64, "The Air Force proposal zones all clear plot tiles")
	_check(
		air_city.zone_id(10, 20) == MilitaryProposal.ZONE_MILITARY
		and air_city.zone_id(17, 27) == MilitaryProposal.ZONE_MILITARY,
		"The Air Force proposal stores military zones at both plot corners",
	)
	_check(
		air_document.misc_u32(MilitaryProposal.MISC_TILE_COUNTS) == CityState.TILE_COUNT - 64
		and air_document.misc_u32(MilitaryProposal.MISC_MILITARY_TILE_COUNTS) == 64,
		"The Air Force proposal moves each zoned tile into the military count",
	)

	var army_document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))

	for chunk_id in ["XBLD", "XTER", "XZON", "XUND", "XBIT"]:
		_check(
			army_document.find_chunk(chunk_id).set_decoded_payload(_filled_bytes(CityState.TILE_COUNT, 0)),
			"Army fixture clears %s" % chunk_id,
		)

	var army_altitude := _filled_bytes(CityState.TILE_COUNT * 2, 0)
	army_altitude[(10 * CityState.MAP_SIZE + 21) * 2 + 1] = 1
	_check(
		army_document.find_chunk("ALTM").set_decoded_payload(army_altitude),
		"Army fixture makes one plot tile uneven",
	)
	var army_city := CityModel.from_document(army_document)
	var army := MilitaryProposal.resolve(army_city, true, SequenceGameModuloRandom.new([10, 20]))
	_check(
		army.ok
		and army.base_type == MilitaryProposal.BASE_ARMY
		and army.notice_id == MilitaryProposal.NOTICE_ARMY,
		"A suitable uneven candidate becomes an Army base",
	)

	var missile_document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))
	var missile_buildings := _filled_bytes(CityState.TILE_COUNT, Tiles.SMALL_PARK)
	var expected_sites: Array[Rect2i] = []

	for origin in [Vector2i(5, 5), Vector2i(15, 15), Vector2i(25, 25), Vector2i(35, 35), Vector2i(45, 45), Vector2i(55, 55)]:
		expected_sites.append(Rect2i(origin, Vector2i(3, 3)))

		for x in range(origin.x, origin.x + 3):
			for y in range(origin.y, origin.y + 3):
				missile_buildings[x * CityState.MAP_SIZE + y] = Tiles.EMPTY

	_check(
		missile_document.find_chunk("XBLD").set_decoded_payload(missile_buildings),
		"Missile fixture installs six clear sites",
	)

	for chunk_id in ["XTER", "XZON", "XUND", "XBIT"]:
		_check(
			missile_document.find_chunk(chunk_id).set_decoded_payload(_filled_bytes(CityState.TILE_COUNT, 0)),
			"Missile fixture clears %s" % chunk_id,
		)

	_check(
		missile_document.find_chunk("ALTM").set_decoded_payload(_filled_bytes(CityState.TILE_COUNT * 2, 0)),
		"Missile fixture levels the map",
	)
	_check(
		missile_document.set_misc_u32(MilitaryProposal.MISC_TILE_COUNTS, 54)
		and missile_document.set_misc_u32(MilitaryProposal.MISC_MILITARY_TILE_COUNTS, 0),
		"Missile fixture initializes tile counts",
	)
	var missile_values: Array[int] = []

	for _attempt in 24:
		missile_values.append_array([100, 100])

	for site in expected_sites:
		missile_values.append_array([site.position.x, site.position.y])

	var missile_random := SequenceGameModuloRandom.new(missile_values)
	var missile_city := CityModel.from_document(missile_document)
	var missile := MilitaryProposal.resolve(missile_city, true, missile_random)
	_check(
		missile.ok
		and missile.accepted
		and missile.base_type == MilitaryProposal.BASE_MISSILE_SILOS
		and missile.notice_id == MilitaryProposal.NOTICE_MISSILE_SILOS,
		"Six small candidates become missile silos when no large plot is suitable",
	)
	_check(
		missile.sites == expected_sites
		and missile.site == expected_sites[-1]
		and missile.view_center_requests == [expected_sites[-1].position]
		and missile_random.position == 60,
		"The missile search preserves the executable attempt order and final view target",
	)
	_check(missile.changed_indices.size() == 54, "The missile proposal zones six three-by-three sites")
	_check(
		missile_document.misc_u32(MilitaryProposal.MISC_TILE_COUNTS) == 0
		and missile_document.misc_u32(MilitaryProposal.MISC_MILITARY_TILE_COUNTS) == 54,
		"The missile proposal moves all site tiles into the military count",
	)


func test_mayor_approval_phase(reference_root: String) -> void:
	var document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))
	var city := CityModel.from_document(document)
	var microsims := _filled_bytes(CityState.MICROSIM_COUNT * CityState.MICROSIM_RECORD_SIZE, 0)
	microsims[8] = 0xf3
	microsims[9] = 4
	microsims[14] = 0
	microsims[15] = 2
	_check(document.find_chunk("XMIC").set_decoded_payload(microsims), "Mayor approval fixture installs a mayor house")
	var graphs: PackedByteArray = document.find_chunk("XGRP").decoded_payload.duplicate()
	_write_u32_be(graphs, 4 * CityModel.GRAPH_VALUE_COUNT * 4, 10)
	_write_u32_be(graphs, 5 * CityModel.GRAPH_VALUE_COUNT * 4, 20)
	_write_u32_be(graphs, 6 * CityModel.GRAPH_VALUE_COUNT * 4, 30)
	_write_u32_be(graphs, 7 * CityModel.GRAPH_VALUE_COUNT * 4, 40)
	_check(document.find_chunk("XGRP").set_decoded_payload(graphs), "Mayor approval fixture installs graph values")
	_check(document.set_misc_u32(0x0048, 65), "Mayor approval fixture sets life expectancy")
	_check(document.set_misc_u32(0x004c, 90), "Mayor approval fixture sets education")
	_check(document.set_misc_u32(0x0fa4, 5), "Mayor approval fixture sets unemployment")
	_check(document.set_misc_u32(0x077c + 4, 7), "Mayor approval fixture sets residential tax")
	_check(document.set_misc_u32(0x102c, 1000), "Mayor approval fixture sets city population")
	var favorable_values: Array[int] = []

	for _index in 100:
		favorable_values.append(190)

	var favorable_random := SequenceRandom.new(favorable_values)
	var favorable := MayorApproval.run(city, favorable_random, 79)
	_check(favorable.ok, "Mayor approval calculation completes: %s" % favorable.error)
	_check(
		favorable.weights == PackedInt32Array([10, 20, 40, 5, 21, 10, 5]),
		"Mayor approval uses traffic, pollution, crime, unemployment, tax, education, and health",
	)
	_check(favorable.approval == 100, "Mayor approval counts all favorable survey samples")
	_check(favorable_random.position == 100, "Mayor approval consumes 100 process random values")
	_check(
		NewsEvent.same_arrays(favorable.news_items, [NewsEvent.new(0x201, 0)]),
		"Mayor approval reports the upward 80-percent threshold",
	)
	var mayor_house := city.microsim(1)
	_check(
		mayor_house.stat_0 == 5 and mayor_house.stat_2 == 100 and mayor_house.stat_3 == 1,
		"Mayor approval updates all mayor-house annual fields",
	)
	var complaint_values: Array[int] = []

	for _index in 100:
		complaint_values.append(0)

	var complaint_random := SequenceRandom.new(complaint_values)
	var complaints := MayorApproval.run(city, complaint_random, favorable.approval)
	_check(complaints.ok, "Mayor complaint calculation completes: %s" % complaints.error)
	_check(complaints.approval == 0, "Mayor approval excludes complaint survey samples")
	_check(complaints.survey_counts[0] == 100, "Mayor survey counts the first complaint")
	_check(complaints.ranking[0] == 0, "Mayor survey ranks the largest complaint first")
	mayor_house = city.microsim(1)
	_check(
		mayor_house.stat_0 == 6 and mayor_house.stat_2 == 0 and mayor_house.stat_3 == 0,
		"Repeated mayor-house queries advance the saved term fields",
	)
