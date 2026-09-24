extends "res://tests/support/core_test_suite.gd"

## Simulation: disaster map checks.

@warning_ignore_start("integer_division")

const Water = preload("res://src/simulation/infrastructure/water_phase.gd")
const Pollution = preload("res://src/simulation/data_maps/pollution_phase.gd")
const DisasterStart = preload("res://src/simulation/disasters/disaster_start_phase.gd")
const Simulation = preload("res://src/simulation/core/simulation_engine.gd")
const Dispatch = preload("res://src/tools/city/dispatch_command.gd")
const TestRandoms = preload("res://tests/support/test_randoms.gd")
const SequenceLfsrRandom = TestRandoms.SequenceLfsrRandom
const SequenceRandom = TestRandoms.SequenceRandom


func test_disaster_map_phase(reference_root: String) -> void:
	var water := _fire_map_fixture(reference_root, Vector2i(20, 20), Tiles.TREES_1, true)
	var water_random := SequenceRandom.new([0])
	var water_lfsr := SequenceLfsrRandom.new([])
	var water_tick := DisasterMapFireFlood.run_fire(water.city, water_random, water_lfsr)
	_check(
		water_tick.ok
		and water_tick.active
		and water_tick.map_changed
		and water_tick.counters.water_extinctions == 1
		and water_tick.counters.remaining_fires == 0
		and SoundEvent.same_arrays(water_tick.sound_events, SoundEvent.from_ids([DisasterMap.SOUND_FIRE])),
		"A selected fire marker on water clears and keeps the disaster active for this scan",
	)
	_check(
		water.city.text_overlay_id(20, 20) == 0
		and water_random.position == 1
		and water_lfsr.position == 0,
		"Water extinction consumes only its process-random update gate",
	)
	var empty_tick := DisasterMapFireFlood.run_fire(
		water.city, SequenceRandom.new([]), SequenceLfsrRandom.new([])
	)
	_check(
		empty_tick.ok and not empty_tick.active and empty_tick.sound_events.is_empty(),
		"A later fire scan ends after no marker remains",
	)

	var spread := _fire_map_fixture(reference_root, Vector2i(20, 20), Tiles.TREES_1)
	_check(spread.city.set_building_id(19, 20, Tiles.TREES_1), "Fire spread fixture adds a west target")
	var spread_random := SequenceRandom.new([0, 0])
	var spread_tick := DisasterMapFireFlood.run_fire(
		spread.city, spread_random, SequenceLfsrRandom.new([])
	)
	_check(
		spread_tick.ok
		and spread_tick.counters.spread_attempts == 1
		and spread_tick.counters.spread_fires == 1
		and spread.city.text_overlay_id(19, 20) == 0xff
		and spread_random.position == 2,
		"Fire choice zero spreads west through the shared damage helper",
	)

	var linked_spread := _fire_map_fixture(reference_root, Vector2i(20, 20), Tiles.TREES_1)
	_check(
		linked_spread.city.set_building_id(19, 20, Tiles.LOWER_CLASS_HOMES_1X1_1)
		and linked_spread.city.set_text_overlay_id(19, 20, 51),
		"Linked fire spread fixture adds a west microsimulation building",
	)
	var linked_spread_random := SequenceRandom.new([0, 0, 2, 1])
	var linked_spread_tick := DisasterMapFireFlood.run_fire(
		linked_spread.city, linked_spread_random, SequenceLfsrRandom.new([])
	)
	_check(
		linked_spread_tick.ok
		and linked_spread_tick.counters.spread_fires == 1
		and linked_spread_tick.effect_events.size() == 1
		and linked_spread_tick.effect_events[0].point == Vector2i(19, 20)
		and linked_spread_tick.effect_events[0].sprite_id == 1394
		and linked_spread_tick.effect_events[0].flip
		and SoundEvent.same_arrays(linked_spread_tick.sound_events, SoundEvent.from_ids([
			DisasterMap.SOUND_EARTHQUAKE, DisasterMap.SOUND_FIRE,
		]))
		and linked_spread_random.position == 4,
		"Shared fire damage emits native dust and consumes its two visual random values",
	)

	var covered := _fire_map_fixture(reference_root, Vector2i(20, 20), Tiles.LOWER_CLASS_HOMES_1X1_1)
	var covered_random := SequenceRandom.new([0, 4, 0, 2])
	var covered_lfsr := SequenceLfsrRandom.new([3])
	var covered_tick := DisasterMapFireFlood.run_fire(covered.city, covered_random, covered_lfsr)
	_check(
		covered_tick.ok
		and covered_tick.counters.coverage_extinctions == 1
		and covered_tick.counters.remaining_fires == 0
		and covered.city.text_overlay_id(20, 20) == 0
		and covered.city.building_id(20, 20) == 4,
		"Fire coverage plus eight extinguishes and replaces a burning structure with LFSR rubble",
	)
	_check(
		covered_random.position == 4 and covered_lfsr.position == 1,
		"Coverage extinction preserves the process and LFSR random order",
	)

	var collapsing := _fire_map_fixture(reference_root, Vector2i(20, 20), Tiles.LOWER_CLASS_HOMES_1X1_1)
	var collapse_random := SequenceRandom.new([0, 5, 1])
	var collapse_lfsr := SequenceLfsrRandom.new([2, 0])
	var collapse_tick := DisasterMapFireFlood.run_fire(
		collapsing.city, collapse_random, collapse_lfsr
	)
	var explosion: ThingRecord = collapsing.city.thing(1)
	_check(
		collapse_tick.ok
		and collapse_tick.counters.structure_collapses == 1
		and collapse_tick.counters.created_explosions == 1
		and explosion.type == 6
		and explosion.x == 20
		and explosion.y == 20
		and explosion.z == 0
		and explosion.state == 0
		and explosion.goal == 1,
		"Fire choice five collapses a building and creates the gated explosion record",
	)
	_check(
		collapsing.city.text_overlay_id(20, 20) == 202
		and collapse_random.position == 3
		and collapse_lfsr.position == 2,
		"Fire collapse links its explosion and preserves the original random order",
	)
	var toxic := _fire_map_fixture(reference_root, Vector2i(20, 20), Tiles.CHEMICAL_STORAGE_1X1)
	var toxic_tick := DisasterMapFireFlood.run_fire(
		toxic.city, SequenceRandom.new([0, 5, 1]), SequenceLfsrRandom.new([2, 1])
	)
	_check(
		toxic_tick.ok
		and toxic_tick.counters.structure_collapses == 1
		and toxic_tick.counters.created_explosions == 0
		and toxic_tick.counters.toxic_markers == 1
		and toxic.city.text_overlay_id(20, 20) == DisasterMap.TOXIC_OVERLAY,
		"A special burning structure can leave the recovered toxic marker",
	)

	var expired_toxic := _fire_map_fixture(reference_root, Vector2i(20, 20), Tiles.TREES_1)
	_check(
		expired_toxic.city.set_text_overlay_id(20, 20, DisasterMap.TOXIC_OVERLAY),
		"Toxic expiry fixture installs its marker",
	)
	var toxic_expiry_random := SequenceRandom.new([0])
	var toxic_expiry_lfsr := SequenceLfsrRandom.new([0])
	var toxic_expiry := DisasterMapMarkers.run_toxic(
		expired_toxic.city, toxic_expiry_random, toxic_expiry_lfsr
	)
	_check(
		toxic_expiry.ok
		and toxic_expiry.active
		and toxic_expiry.counters.lfsr_expirations == 1
		and toxic_expiry.counters.remaining_toxic == 0
		and expired_toxic.city.text_overlay_id(20, 20) == 0,
		"A selected toxic marker expires on the one-in-64 LFSR gate",
	)
	_check(
		toxic_expiry_random.position == 1 and toxic_expiry_lfsr.position == 1,
		"Toxic LFSR expiry consumes no later process-random value",
	)

	var water_toxic := _fire_map_fixture(reference_root, Vector2i(20, 20), Tiles.TREES_1, true)
	_check(
		water_toxic.city.set_text_overlay_id(20, 20, DisasterMap.TOXIC_OVERLAY),
		"Water toxic fixture installs its marker",
	)
	var water_toxic_random := SequenceRandom.new([0, 0])
	var water_toxic_lfsr := SequenceLfsrRandom.new([1])
	var water_toxic_tick := DisasterMapMarkers.run_toxic(
		water_toxic.city, water_toxic_random, water_toxic_lfsr
	)
	_check(
		water_toxic_tick.ok
		and water_toxic_tick.counters.water_expirations == 1
		and water_toxic_tick.counters.remaining_toxic == 0
		and water_toxic_random.position == 2
		and water_toxic_lfsr.position == 1,
		"A selected toxic marker on water has the recovered one-in-16 expiry gate",
	)

	var downhill_toxic := _fire_map_fixture(reference_root, Vector2i(20, 20), Tiles.TREES_1)
	_check(
		downhill_toxic.city.set_text_overlay_id(20, 20, DisasterMap.TOXIC_OVERLAY)
		and downhill_toxic.city.set_land_altitude(20, 20, 5)
		and downhill_toxic.city.set_land_altitude(19, 20, 3)
		and downhill_toxic.city.set_land_altitude(20, 19, 6)
		and downhill_toxic.city.set_land_altitude(21, 20, 6)
		and downhill_toxic.city.set_land_altitude(20, 21, 6),
		"Downhill toxic fixture sets one lower neighbor",
	)
	var downhill_random := SequenceRandom.new([0])
	var downhill_lfsr := SequenceLfsrRandom.new([1])
	var downhill_tick := DisasterMapMarkers.run_toxic(
		downhill_toxic.city, downhill_random, downhill_lfsr
	)
	_check(
		downhill_tick.ok
		and downhill_tick.counters.moved_markers == 1
		and downhill_tick.counters.remaining_toxic == 1
		and downhill_toxic.city.text_overlay_id(20, 20) == 0
		and downhill_toxic.city.text_overlay_id(19, 20) == DisasterMap.TOXIC_OVERLAY,
		"A toxic marker moves to its first strictly lower cardinal neighbor",
	)
	_check(
		downhill_random.position == 1 and downhill_lfsr.position == 1,
		"A downhill toxic move does not consume a fallback direction value",
	)

	var flat_toxic := _fire_map_fixture(reference_root, Vector2i(20, 20), Tiles.TREES_1)
	_check(
		flat_toxic.city.set_text_overlay_id(20, 20, DisasterMap.TOXIC_OVERLAY)
		and flat_toxic.city.set_land_altitude(20, 20, 5)
		and flat_toxic.city.set_land_altitude(19, 20, 5)
		and flat_toxic.city.set_land_altitude(20, 19, 5)
		and flat_toxic.city.set_land_altitude(21, 20, 5)
		and flat_toxic.city.set_land_altitude(20, 21, 5),
		"Flat toxic fixture levels all cardinal neighbors",
	)
	var flat_random := SequenceRandom.new([0, 2, 1])
	var flat_lfsr := SequenceLfsrRandom.new([1])
	var flat_tick := DisasterMapMarkers.run_toxic(flat_toxic.city, flat_random, flat_lfsr)
	_check(
		flat_tick.ok
		and flat_tick.counters.toxic_markers_scanned == 2
		and flat_tick.counters.toxic_updates == 1
		and flat_tick.counters.moved_markers == 1
		and flat_toxic.city.text_overlay_id(21, 20) == DisasterMap.TOXIC_OVERLAY,
		"A flat toxic marker uses the process-random cardinal direction",
	)
	_check(
		flat_random.position == 3 and flat_lfsr.position == 1,
		"A marker that moves later in scan order receives its native second scan gate",
	)

	var abandoned_toxic := _fire_map_fixture(reference_root, Vector2i(20, 20), Tiles.LOWER_CLASS_HOMES_1X1_1)
	_check(
		abandoned_toxic.city.set_zone_id(20, 20, 1)
		and abandoned_toxic.city.set_building_corners(20, 20, 0xf0)
		and abandoned_toxic.city.set_text_overlay_id(20, 20, DisasterMap.TOXIC_OVERLAY)
		and abandoned_toxic.city.set_land_altitude(20, 20, 5)
		and abandoned_toxic.city.set_land_altitude(19, 20, 3)
		and abandoned_toxic.city.set_land_altitude(20, 19, 6)
		and abandoned_toxic.city.set_land_altitude(21, 20, 6)
		and abandoned_toxic.city.set_land_altitude(20, 21, 6),
		"Toxic abandonment fixture installs a normal residential building",
	)
	var abandon_random := SequenceRandom.new([0, 1])
	var abandon_tick := DisasterMapMarkers.run_toxic(
		abandoned_toxic.city, abandon_random, SequenceLfsrRandom.new([1])
	)
	_check(
		abandon_tick.ok
		and abandon_tick.counters.abandoned_structures == 1
		and abandoned_toxic.city.building_id(20, 20) == 0x8b
		and abandoned_toxic.city.zone_id(20, 20) == 1,
		"A toxic cloud changes a normal RCI building to its abandoned class before moving",
	)
	_check(
		abandon_random.position == 2,
		"Toxic abandonment consumes the normal building-selection random value",
	)

	var idle_riot := _fire_map_fixture(reference_root, Vector2i(20, 20), Tiles.TREES_1)
	_check(
		idle_riot.city.set_text_overlay_id(20, 20, DisasterMap.RIOT_OVERLAY_REVERSE),
		"Idle riot fixture installs its reverse marker",
	)
	var idle_riot_random := SequenceRandom.new([0, 1, 4, 0])
	var idle_riot_tick := DisasterMapMarkers.run_riot(
		idle_riot.city, idle_riot_random, SequenceLfsrRandom.new([])
	)
	_check(
		idle_riot_tick.ok
		and idle_riot_tick.active
		and idle_riot_tick.counters.riot_updates == 1
		and idle_riot_tick.counters.remaining_riots == 1
		and SoundEvent.same_arrays(idle_riot_tick.sound_events, SoundEvent.from_ids([DisasterMap.SOUND_RIOT]))
		and idle_riot.city.text_overlay_id(20, 20) == DisasterMap.RIOT_OVERLAY_FORWARD,
		"An unsupported reverse riot changes to the forward phase and can request sound",
	)
	_check(
		idle_riot_random.position == 4,
		"An unsupported riot consumes its two gates, damage choice, and final sound gate",
	)

	var water_riot := _fire_map_fixture(reference_root, Vector2i(20, 20), Tiles.TREES_1, true)
	_check(
		water_riot.city.set_text_overlay_id(20, 20, DisasterMap.RIOT_OVERLAY_FORWARD),
		"Water riot fixture installs its forward marker",
	)
	var water_riot_random := SequenceRandom.new([0, 1, 1])
	var water_riot_tick := DisasterMapMarkers.run_riot(
		water_riot.city, water_riot_random, SequenceLfsrRandom.new([])
	)
	_check(
		water_riot_tick.ok
		and water_riot_tick.counters.expired_riots == 1
		and water_riot_tick.counters.remaining_riots == 0
		and water_riot_random.position == 3,
		"An updating riot expires on water after its second process-random gate",
	)

	var reverse_riot := _fire_map_fixture(reference_root, Vector2i(20, 20), Tiles.TREES_1)
	_check(
		reverse_riot.city.set_text_overlay_id(20, 20, DisasterMap.RIOT_OVERLAY_REVERSE)
		and reverse_riot.city.set_building_id(19, 20, Tiles.ROAD_STRAIGHT_2),
		"Reverse riot fixture adds a supported west road",
	)
	var reverse_riot_random := SequenceRandom.new([0, 1, 4, 1, 1])
	var reverse_riot_tick := DisasterMapMarkers.run_riot(
		reverse_riot.city, reverse_riot_random, SequenceLfsrRandom.new([])
	)
	_check(
		reverse_riot_tick.ok
		and reverse_riot_tick.counters.propagated_riots == 1
		and reverse_riot.city.text_overlay_id(20, 20) == 0
		and reverse_riot.city.text_overlay_id(19, 20) == DisasterMap.RIOT_OVERLAY_REVERSE,
		"A reverse riot propagates west along a supported network tile",
	)
	_check(
		reverse_riot_random.position == 5,
		"A one-connection reverse riot skips the connection-choice random value",
	)

	var forward_riot := _fire_map_fixture(reference_root, Vector2i(20, 20), Tiles.TREES_1)
	_check(
		forward_riot.city.set_text_overlay_id(20, 20, DisasterMap.RIOT_OVERLAY_FORWARD)
		and forward_riot.city.set_building_id(21, 20, Tiles.TUNNEL_ENTRANCE_1),
		"Forward riot fixture adds a supported east rail tile",
	)
	var forward_riot_random := SequenceRandom.new([0, 1, 4, 1, 1, 1])
	var forward_riot_tick := DisasterMapMarkers.run_riot(
		forward_riot.city, forward_riot_random, SequenceLfsrRandom.new([])
	)
	_check(
		forward_riot_tick.ok
		and forward_riot_tick.counters.riot_markers_scanned == 2
		and forward_riot_tick.counters.riot_updates == 1
		and forward_riot_tick.counters.propagated_riots == 1
		and forward_riot.city.text_overlay_id(21, 20) == DisasterMap.RIOT_OVERLAY_FORWARD,
		"A forward riot propagates east and receives a second scan gate later in the pass",
	)
	_check(
		forward_riot_random.position == 6,
		"Forward riot reprocessing preserves the native in-place random order",
	)

	var damaging_riot := _fire_map_fixture(reference_root, Vector2i(20, 20), Tiles.TREES_1)
	_check(
		damaging_riot.city.set_text_overlay_id(20, 20, DisasterMap.RIOT_OVERLAY_REVERSE)
		and damaging_riot.city.set_building_id(19, 20, Tiles.TREES_1),
		"Riot damage fixture adds a combustible west target",
	)
	var damaging_riot_tick := DisasterMapMarkers.run_riot(
		damaging_riot.city,
		SequenceRandom.new([0, 1, 0, 1]),
		SequenceLfsrRandom.new([]),
	)
	_check(
		damaging_riot_tick.ok
		and damaging_riot_tick.counters.damage_attempts == 1
		and damaging_riot_tick.counters.started_fires == 1
		and damaging_riot.city.text_overlay_id(19, 20) == DisasterMap.FIRE_OVERLAY,
		"A low riot damage choice starts fire through the shared disaster helper",
	)

	var fire_dispatch := _dispatch_map_fixture(
		reference_root, Dispatch.TYPE_FIRE, Vector2i(20, 20)
	)
	_check(
		fire_dispatch.city.set_building_id(19, 20, Tiles.TREES_1)
		and fire_dispatch.city.set_text_overlay_id(19, 20, DisasterMap.FIRE_OVERLAY),
		"Fire dispatch fixture adds a burning west network tile",
	)
	var fire_dispatch_random := SequenceRandom.new([0, 1])
	var fire_dispatch_lfsr := SequenceLfsrRandom.new([2])
	var fire_dispatch_tick := DisasterMapScanDispatch.run_dispatch(
		fire_dispatch.city, fire_dispatch_random, fire_dispatch_lfsr
	)
	_check(
		fire_dispatch_tick.ok
		and fire_dispatch_tick.counters.dispatch_markers_scanned == 1
		and fire_dispatch_tick.counters.fire_suppression_attempts == 1
		and fire_dispatch_tick.counters.fire_extinctions == 1
		and fire_dispatch.city.text_overlay_id(19, 20) == 0
		and fire_dispatch.city.building_id(19, 20) == 3,
		"A fire unit extinguishes its selected neighbor and leaves LFSR-selected rubble",
	)
	_check(
		fire_dispatch_random.position == 2 and fire_dispatch_lfsr.position == 1,
		"Fire dispatch preserves direction, demolition, and rubble random order",
	)

	var rail_dispatch := _dispatch_map_fixture(
		reference_root, Dispatch.TYPE_FIRE, Vector2i(20, 20)
	)
	_check(
		rail_dispatch.city.set_building_id(19, 20, Tiles.TUNNEL_ENTRANCE_1)
		and rail_dispatch.city.set_text_overlay_id(19, 20, DisasterMap.FIRE_OVERLAY),
		"Rail dispatch fixture adds a burning west rail tile",
	)
	var rail_dispatch_tick := DisasterMapScanDispatch.run_dispatch(
		rail_dispatch.city, SequenceRandom.new([0]), SequenceLfsrRandom.new([])
	)
	_check(
		rail_dispatch_tick.ok
		and rail_dispatch_tick.counters.fire_extinctions == 1
		and rail_dispatch.city.text_overlay_id(19, 20) == 0
		and rail_dispatch.city.building_id(19, 20) == 0x3f,
		"Dispatch extinguishes rail values 0x3F through 0x42 without demolition",
	)

	var police_dispatch := _dispatch_map_fixture(
		reference_root, Dispatch.TYPE_POLICE, Vector2i(20, 20)
	)
	_check(
		police_dispatch.city.set_building_id(19, 20, Tiles.TUNNEL_ENTRANCE_1)
		and police_dispatch.city.set_text_overlay_id(19, 20, DisasterMap.FIRE_OVERLAY)
		and police_dispatch.city.set_text_overlay_id(21, 20, DisasterMap.RIOT_OVERLAY_FORWARD),
		"Police dispatch fixture adds west fire and east riot markers",
	)
	var police_dispatch_random := SequenceRandom.new([0, 2])
	var police_dispatch_lfsr := SequenceLfsrRandom.new([0])
	var police_dispatch_tick := DisasterMapScanDispatch.run_dispatch(
		police_dispatch.city, police_dispatch_random, police_dispatch_lfsr
	)
	_check(
		police_dispatch_tick.ok
		and police_dispatch_tick.counters.fire_extinctions == 1
		and police_dispatch_tick.counters.riot_suppressions == 1
		and police_dispatch.city.text_overlay_id(19, 20) == 0
		and police_dispatch.city.text_overlay_id(21, 20) == 0,
		"A police unit can pass its LFSR fire gate and always attempts riot suppression",
	)
	_check(
		police_dispatch_random.position == 2 and police_dispatch_lfsr.position == 1,
		"Police dispatch consumes its LFSR gate before two process-random directions",
	)

	var gated_police := _dispatch_map_fixture(
		reference_root, Dispatch.TYPE_POLICE, Vector2i(20, 20)
	)
	_check(
		gated_police.city.set_building_id(19, 20, Tiles.TUNNEL_ENTRANCE_1)
		and gated_police.city.set_text_overlay_id(19, 20, DisasterMap.FIRE_OVERLAY)
		and gated_police.city.set_text_overlay_id(21, 20, DisasterMap.RIOT_OVERLAY_REVERSE),
		"Gated police fixture adds west fire and east riot markers",
	)
	var gated_police_random := SequenceRandom.new([2])
	var gated_police_tick := DisasterMapScanDispatch.run_dispatch(
		gated_police.city, gated_police_random, SequenceLfsrRandom.new([1])
	)
	_check(
		gated_police_tick.ok
		and gated_police_tick.counters.fire_suppression_attempts == 0
		and gated_police_tick.counters.riot_suppressions == 1
		and gated_police.city.text_overlay_id(19, 20) == DisasterMap.FIRE_OVERLAY
		and gated_police.city.text_overlay_id(21, 20) == 0
		and gated_police_random.position == 1,
		"A failed police fire gate does not block its separate riot-suppression attempt",
	)

	var flood := _fire_map_fixture(reference_root, Vector2i(20, 20), Tiles.TREES_1)
	_check(
		flood.city.set_text_overlay_id(20, 20, 0xfc)
		and flood.city.set_building_id(19, 20, Tiles.TREES_1),
		"Flood tick fixture installs its source and west target",
	)
	var flood_random := SequenceRandom.new([0, 0])
	var flood_lfsr := SequenceLfsrRandom.new([])
	var flood_tick := DisasterMapFireFlood.run_flood(flood.city, flood_random, flood_lfsr, 60)
	_check(
		flood_tick.ok
		and flood_tick.active
		and flood_tick.map_counter == 59
		and flood_tick.counters.flood_updates == 1
		and flood_tick.counters.spread_floods == 1
		and flood_tick.counters.remaining_floods == 2
		and SoundEvent.same_arrays(flood_tick.sound_events, SoundEvent.from_ids([DisasterMap.SOUND_FLOOD]))
		and flood.city.text_overlay_id(19, 20) == 0xfc,
		"An early flood tick spreads west and can request the recovered flood sound",
	)
	_check(
		flood_random.position == 2 and flood_lfsr.position == 0,
		"An early flood spread preserves its process-random order",
	)

	var linked_flood := _fire_map_fixture(reference_root, Vector2i(20, 20), Tiles.TREES_1)
	_check(
		linked_flood.city.set_text_overlay_id(20, 20, 0xfc)
		and linked_flood.city.set_building_id(19, 20, Tiles.LOWER_CLASS_HOMES_1X1_1)
		and linked_flood.city.set_text_overlay_id(19, 20, 51),
		"Linked flood fixture installs a west microsimulation building",
	)
	var linked_flood_random := SequenceRandom.new([0, 2, 1, 1])
	var linked_flood_tick := DisasterMapFireFlood.run_flood(
		linked_flood.city,
		linked_flood_random,
		SequenceLfsrRandom.new([]),
		60,
	)
	_check(
		linked_flood_tick.ok
		and linked_flood_tick.counters.spread_floods == 1
		and linked_flood_tick.effect_events.size() == 1
		and linked_flood_tick.effect_events[0].point == Vector2i(19, 20)
		and linked_flood_tick.effect_events[0].sprite_id == 1394
		and linked_flood_tick.effect_events[0].flip
		and SoundEvent.same_arrays(linked_flood_tick.sound_events, SoundEvent.from_ids([DisasterMap.SOUND_EARTHQUAKE]))
		and linked_flood_random.position == 4,
		"Shared flood damage emits native dust and consumes its two visual random values",
	)

	var expired_flood := _fire_map_fixture(reference_root, Vector2i(20, 20), Tiles.TREES_1)
	_check(
		expired_flood.city.set_text_overlay_id(20, 20, 0xfc),
		"Expired flood fixture installs its marker",
	)
	var expired_random := SequenceRandom.new([1])
	var expired_lfsr := SequenceLfsrRandom.new([1])
	var expired_tick := DisasterMapFireFlood.run_flood(
		expired_flood.city, expired_random, expired_lfsr, 1
	)
	var no_flood_tick := DisasterMapFireFlood.run_flood(
		expired_flood.city, SequenceRandom.new([]), SequenceLfsrRandom.new([]), 0
	)
	_check(
		expired_tick.ok
		and expired_tick.active
		and expired_tick.map_counter == 0
		and expired_tick.counters.expired_floods == 1
		and expired_tick.counters.remaining_floods == 0
		and no_flood_tick.ok
		and not no_flood_tick.active,
		"A zero-counter LFSR bit clears flood and the next scan ends it",
	)
	_check(
		expired_random.position == 1 and expired_lfsr.position == 1,
		"Expired flood consumes its LFSR gate before the final sound gate",
	)

	var uphill := _fire_map_fixture(reference_root, Vector2i(20, 20), Tiles.TREES_1)
	_check(
		uphill.city.set_text_overlay_id(20, 20, 0xfc)
		and uphill.city.set_building_id(19, 20, Tiles.TREES_1)
		and uphill.city.set_land_altitude(20, 20, 0)
		and uphill.city.set_land_altitude(19, 20, 1),
		"Uphill flood fixture raises the west target",
	)
	var uphill_tick := DisasterMapFireFlood.run_flood(
		uphill.city, SequenceRandom.new([0, 1]), SequenceLfsrRandom.new([]), 60
	)
	_check(
		uphill_tick.ok
		and uphill_tick.counters.spread_attempts == 1
		and uphill_tick.counters.spread_floods == 0
		and uphill.city.text_overlay_id(19, 20) == 0,
		"Flood cannot spread to a higher low-five-bit altitude",
	)

	var manual_flood := _fire_map_fixture(reference_root, Vector2i(20, 20), Tiles.EMPTY)
	var shoreline := _filled_bytes(CityState.TILE_COUNT, 0)
	shoreline[20 * CityState.MAP_SIZE + 20] = 0x20
	_check(
		manual_flood.city.set_text_overlay_id(20, 20, 0)
		and manual_flood.document.find_chunk("XTER").set_decoded_payload(shoreline),
		"Manual flood fixture installs a clear shoreline point",
	)
	var flood_engine := Simulation.new(manual_flood.city, 1, 7, 13)
	var manual_flood_start := flood_engine.start_disaster(
		DisasterStart.DISASTER_FLOOD, Vector2i(20, 20)
	)
	# the start runs the first disaster update in the same step
	var manual_flood_tick := manual_flood_start.first_update
	_check(
		manual_flood_start.ok
		and manual_flood_start.started
		and flood_engine.active_disaster_type == DisasterStart.DISASTER_FLOOD
		and manual_flood_tick.ok
		and manual_flood_tick.active
		and manual_flood_tick.map_counter == 59
		and flood_engine.disaster_map_counter == 59,
		"The engine keeps the flood lifetime counter from start through recurring ticks",
	)

	var engine_fixture := _fire_map_fixture(reference_root, Vector2i(20, 20), Tiles.TREES_1, true)
	_check(engine_fixture.document.set_misc_u32(0x0004, 2), "Fire engine fixture selects disaster mode")
	var engine := Simulation.new(engine_fixture.city, 3, 7, 13)
	engine.active_disaster_type = DisasterStart.DISASTER_FIRE
	# a police unit on the map leaves at the end. a fire unit without a map label stays
	var things: PackedByteArray = engine_fixture.document.find_chunk("XTHG").decoded_payload.duplicate()
	things[1 * Sc2ThingLayout.RECORD_SIZE] = Sc2ThingLayout.Type.POLICE
	things[2 * Sc2ThingLayout.RECORD_SIZE] = Sc2ThingLayout.Type.FIRE
	_check(
		engine_fixture.document.find_chunk("XTHG").set_decoded_payload(things)
		and engine_fixture.city.set_text_overlay_id(90, 90, OverlayData.thing_id(1)),
		"Fire engine fixture places a police unit",
	)
	# the original keeps the damaged class with the largest story weight and
	# skips tunnel entrances
	var class_buildings := PackedByteArray([Tiles.LOWER_CLASS_HOMES_1X1_1, 0xd2, Tiles.TUNNEL_ENTRANCE_1, 0xc6, 0xe4])
	var class_zones := PackedByteArray([1, 9, 8, 0, 0])
	var classes := PackedInt32Array()
	engine_fixture.city.disaster_damage_class = -1

	for index in class_buildings.size():
		DisasterDamage.record_damage_class(engine_fixture.city, class_buildings, class_zones, index)
		classes.append(engine_fixture.city.disaster_damage_class)

	_check(classes == PackedInt32Array([1, 21, 21, 10, 10]), "Disaster damage keeps the most important building class: %s" % classes)
	engine_fixture.city.disaster_damage_class = 9
	var active_tick := engine.advance_disaster_tick()
	var ended_tick := engine.advance_disaster_tick()
	things = engine_fixture.document.find_chunk("XTHG").decoded_payload
	_check(
		ended_tick.news_items.size() == 1
		and ended_tick.news_items[0].type == 0x16
		and ended_tick.news_items[0].argument == 9
		and engine_fixture.city.disaster_damage_class == -1
		and ended_tick.newspaper_requested
		and ended_tick.newspaper_paper == 0
		and not active_tick.newspaper_requested,
		"The fire end posts its summary story for the damaged class and opens the first newspaper",
	)
	_check(
		engine_fixture.city.text_overlay_id(90, 90) == 0
		and things[1 * Sc2ThingLayout.RECORD_SIZE] == Sc2ThingLayout.Type.NONE
		and things[2 * Sc2ThingLayout.RECORD_SIZE] == Sc2ThingLayout.Type.FIRE,
		"The disaster end removes the dispatched units that have a map label",
	)
	_check(
		active_tick.ok
		and active_tick.active
		and ended_tick.ok
		and ended_tick.complete
		and ended_tick.ended_type == DisasterStart.DISASTER_FIRE
		and engine.active_disaster_type == 0
		and engine_fixture.city.city_mode() == 1,
		"The engine runs fire-map ticks and restores city mode one scan after the last fire: %s %s %d %d"
		% [active_tick, ended_tick, engine.active_disaster_type, engine_fixture.city.city_mode()],
	)

	var dispatch_engine_fixture := _dispatch_map_fixture(
		reference_root, Dispatch.TYPE_FIRE, Vector2i(20, 20)
	)
	_check(
		dispatch_engine_fixture.city.set_building_id(19, 20, Tiles.TUNNEL_ENTRANCE_1)
		and dispatch_engine_fixture.city.set_text_overlay_id(
			19, 20, DisasterMap.FIRE_OVERLAY
		)
		and dispatch_engine_fixture.document.set_misc_u32(0x0004, 2),
		"Dispatch engine fixture adds a burning west rail tile",
	)
	var dispatch_engine := Simulation.new(dispatch_engine_fixture.city, 2, 1, 13)
	dispatch_engine.active_disaster_type = DisasterStart.DISASTER_FIRE
	var dispatch_engine_tick := dispatch_engine.advance_disaster_tick()
	_check(
		dispatch_engine_tick.ok
		and dispatch_engine_tick.active
		and dispatch_engine_tick.dispatch_map.counters.fire_extinctions == 1
		and dispatch_engine_fixture.city.text_overlay_id(19, 20) == 0
		and dispatch_engine_fixture.city.building_id(19, 20) == 0x3f,
		"The active disaster engine applies map-side dispatch suppression after its fire scan",
	)

	var mixed_map := _dispatch_map_fixture(
		reference_root, Dispatch.TYPE_FIRE, Vector2i(5, 5)
	)
	_check(
		mixed_map.city != null
		and mixed_map.city.set_text_overlay_id(
			10, 10, DisasterMap.RIOT_OVERLAY_REVERSE
		)
		and mixed_map.city.set_text_overlay_id(20, 20, DisasterMap.FIRE_OVERLAY)
		and mixed_map.city.set_tile_flag(20, 20, 0x04, true),
		"Mixed disaster fixture orders dispatch, riot, and fire markers by map position",
	)
	var mixed_random := SequenceRandom.new([3, 1, 0, 1])
	var mixed_tick := DisasterMapScanDispatch.run_all(
		mixed_map.city, mixed_random, SequenceLfsrRandom.new([]), 0
	)
	_check(
		mixed_tick.ok
		and mixed_tick.active
		and mixed_tick.dispatch_map.counters.fire_suppression_attempts == 1
		and mixed_tick.counters.riot_markers_scanned == 1
		and mixed_tick.counters.fire_markers_scanned == 1
		and mixed_tick.counters.water_extinctions == 1
		and SoundEvent.same_arrays(mixed_tick.sound_events, SoundEvent.from_ids([DisasterMap.SOUND_FIRE])),
		"The combined scan processes all marker classes and keeps original sound order",
	)
	_check(
		mixed_random.position == 4
		and mixed_map.city.text_overlay_id(10, 10) == DisasterMap.RIOT_OVERLAY_REVERSE
		and mixed_map.city.text_overlay_id(20, 20) == 0,
		"The combined scan consumes random state in X-before-Y marker order",
	)

	var hurricane_tick_fixture := _fire_map_fixture(
		reference_root, Vector2i(20, 21), Tiles.LOWER_CLASS_HOMES_1X1_2
	)
	_check(
		hurricane_tick_fixture.city.set_text_overlay_id(20, 21, 0),
		"Hurricane tick fixture clears its tall-building overlay",
	)
	var hurricane_tick_random := SequenceRandom.new([0, 0, 0, 0])
	var hurricane_tick_lfsr := SequenceLfsrRandom.new([0, 20, 21])
	var hurricane_tick := DisasterMapScanDispatch.run_all(
		hurricane_tick_fixture.city,
		hurricane_tick_random,
		hurricane_tick_lfsr,
		60,
		50,
	)
	_check(
		hurricane_tick.ok
		and hurricane_tick.hurricane_counter == 49
		and hurricane_tick.counters.hurricane_damage_attempts == 1
		and hurricane_tick.counters.hurricane_damaged_structures == 1
		and hurricane_tick_fixture.city.building_id(20, 21) < 5
		and hurricane_tick.view_center_requests == [Vector2i(20, 21)],
		"An active hurricane tick can damage and center a source-qualified tall building",
	)
	_check(
		SoundEvent.same_arrays(hurricane_tick.sound_events, SoundEvent.from_ids([
			DisasterMap.SOUND_HURRICANE, DisasterMap.SOUND_EARTHQUAKE,
		]))
		and hurricane_tick.effect_events.size() == 1
		and hurricane_tick_lfsr.position == 3
		and hurricane_tick_random.position == 4,
		"Hurricane recurring damage preserves its sound, effect, and random order",
	)

	var gated_hurricane_fixture := _fire_map_fixture(
		reference_root, Vector2i(20, 21), Tiles.LOWER_CLASS_HOMES_1X1_2
	)
	_check(
		gated_hurricane_fixture.city.set_text_overlay_id(20, 21, 0),
		"Gated hurricane fixture clears its overlay",
	)
	var gated_hurricane_random := SequenceRandom.new([1])
	var gated_hurricane_lfsr := SequenceLfsrRandom.new([1])
	var gated_hurricane_tick := DisasterMapScanDispatch.run_all(
		gated_hurricane_fixture.city,
		gated_hurricane_random,
		gated_hurricane_lfsr,
		60,
		50,
	)
	_check(
		gated_hurricane_tick.ok
		and gated_hurricane_tick.hurricane_counter == 49
		and gated_hurricane_tick.counters.hurricane_damage_attempts == 0
		and not gated_hurricane_tick.map_changed
		and gated_hurricane_tick.sound_events.is_empty()
		and gated_hurricane_random.position == 1
		and gated_hurricane_lfsr.position == 1,
		"A hurricane tick consumes only its sound and LFSR gates when both reject",
	)

	var toxic_engine_fixture := _fire_map_fixture(reference_root, Vector2i(20, 20), Tiles.TREES_1)
	_check(
		toxic_engine_fixture.city.set_text_overlay_id(20, 20, DisasterMap.TOXIC_OVERLAY)
		and toxic_engine_fixture.document.set_misc_u32(0x0004, 2),
		"Toxic engine fixture selects disaster mode and installs its marker",
	)
	var toxic_engine := Simulation.new(toxic_engine_fixture.city, 0, 0, 13)
	toxic_engine.active_disaster_type = DisasterStart.DISASTER_FIRE
	var active_toxic_tick := toxic_engine.advance_disaster_tick()
	var ended_toxic_tick := toxic_engine.advance_disaster_tick()
	_check(
		active_toxic_tick.ok
		and active_toxic_tick.active
		and active_toxic_tick.counters.lfsr_expirations == 1
		and ended_toxic_tick.ok
		and ended_toxic_tick.complete
		and toxic_engine.active_disaster_type == 0
		and toxic_engine_fixture.city.city_mode() == 1,
		"The engine continues a map disaster through toxic residue and ends one scan later",
	)

	var toxic_spill_fixture := _fire_map_fixture(reference_root, Vector2i(24, 25), Tiles.EMPTY)
	_check(
		toxic_spill_fixture.city.set_text_overlay_id(24, 25, 0),
		"Toxic Spill engine fixture clears its target",
	)
	var toxic_spill_engine := Simulation.new(toxic_spill_fixture.city, 0, 0, 13)
	var toxic_spill_start := toxic_spill_engine.start_disaster(
		DisasterStart.DISASTER_TOXIC_SPILL, Vector2i(24, 25)
	)
	var toxic_spill_tick := toxic_spill_start.first_update
	var toxic_spill_end := toxic_spill_engine.advance_disaster_tick()
	_check(
		toxic_spill_start.ok
		and toxic_spill_start.started
		and toxic_spill_engine.active_disaster_type == 0
		and toxic_spill_tick.ok
		and toxic_spill_tick.active
		and toxic_spill_tick.counters.lfsr_expirations == 1
		and toxic_spill_end.ok
		and toxic_spill_end.complete
		and toxic_spill_fixture.city.city_mode() == 1,
		"Toxic Spill enters disaster mode, runs its map branch, and restores city mode",
	)

	var pollution_engine_fixture := _fire_map_fixture(
		reference_root, Vector2i(24, 25), Tiles.EMPTY
	)
	_check(
		pollution_engine_fixture.city.set_text_overlay_id(24, 25, 0)
		and pollution_engine_fixture.document.set_misc_u32(
			DisasterStart.MISC_NORMAL_POPULATION, 0
		),
		"Pollution engine fixture clears its target and population",
	)
	var pollution_engine := Simulation.new(pollution_engine_fixture.city, 0, 0, 13)
	var pollution_engine_start := pollution_engine.start_disaster(
		DisasterStart.DISASTER_POLLUTION, Vector2i(24, 25)
	)
	var pollution_ticks: Array[DisasterMapResult] = []

	while pollution_engine.active_disaster_type != 0 and pollution_ticks.size() < 128:
		var pollution_result := pollution_engine.advance_disaster_tick()
		pollution_ticks.append(pollution_result)

		if not pollution_result.ok:
			break

	var pollution_tick := pollution_ticks[0] if not pollution_ticks.is_empty() else DisasterMapResult.new()
	var pollution_end := pollution_ticks[-1] if not pollution_ticks.is_empty() else DisasterMapResult.new()
	_check(
		pollution_engine_start.ok
		and pollution_engine_start.started
		and pollution_tick.ok
		and pollution_tick.active
		and pollution_end.ok
		and pollution_end.complete
		and pollution_engine.active_disaster_type == 0
		and pollution_engine_fixture.city.city_mode() == 1,
		"Pollution enters disaster mode, runs toxic clouds, and restores city mode: %s %s %s active=%d mode=%d"
		% [pollution_engine_start, pollution_tick, pollution_end, pollution_engine.active_disaster_type, pollution_engine_fixture.city.city_mode()],
	)

	var riot_engine_document := _load_fixture(
		reference_root.path_join("DEFAULT.SC2")
	)
	_check(
		riot_engine_document.find_chunk("XBLD").set_decoded_payload(
			_filled_bytes(CityState.TILE_COUNT, 0x1d)
		)
		and riot_engine_document.find_chunk("XBIT").set_decoded_payload(
			_filled_bytes(CityState.TILE_COUNT, 0)
		)
		and riot_engine_document.find_chunk("XTXT").set_decoded_payload(
			_filled_bytes(CityState.TILE_COUNT, 0)
		),
		"Riot engine fixture installs a dry road map",
	)
	var riot_engine_city := CityModel.from_document(riot_engine_document)
	var riot_engine := Simulation.new(riot_engine_city, 1, 7, 13)
	var riot_engine_start := riot_engine.start_disaster(
		DisasterStart.DISASTER_RIOT, Vector2i(64, 64)
	)
	var riot_engine_tick := riot_engine.advance_disaster_tick()
	_check(
		riot_engine_start.ok
		and riot_engine_start.started
		and riot_engine_tick.ok
		and riot_engine_tick.active
		and riot_engine_tick.counters.riot_markers_scanned > 0
		and riot_engine.active_disaster_type == DisasterStart.DISASTER_RIOT
		and riot_engine_city.city_mode() == 2,
		"Riot enters disaster mode and runs its recurring map branch",
	)

	var manual := _fire_map_fixture(reference_root, Vector2i(20, 20), Tiles.EMPTY)
	_check(manual.city.set_text_overlay_id(20, 20, 0), "Manual disaster fixture clears fire")
	var manual_engine := Simulation.new(manual.city, 1, 7, 13)
	var manual_start := manual_engine.start_disaster(
		DisasterStart.DISASTER_TORNADO, Vector2i(22, 23)
	)
	var duplicate_start := manual_engine.start_disaster(
		DisasterStart.DISASTER_MONSTER, Vector2i(24, 25)
	)
	_check(
		manual_start.ok
		and manual_start.started
		and manual_engine.active_disaster_type == DisasterStart.DISASTER_TORNADO
		and manual.city.city_mode() == 2
		and manual.city.thing(1).type == 15
		and not duplicate_start.ok,
		"The public engine entry point starts one manual disaster and rejects a second",
	)


func _dispatch_map_fixture(
	reference_root: String, thing_type: int, point: Vector2i
) -> Dictionary:
	var fixture := _fire_map_fixture(reference_root, point, Tiles.EMPTY)

	if fixture.city == null:
		return fixture

	var things: PackedByteArray = fixture.document.find_chunk("XTHG").decoded_payload.duplicate()
	var offset := CityState.THING_RECORD_SIZE
	things[offset] = thing_type
	things[offset + 3] = point.x
	things[offset + 4] = point.y

	if (
		not fixture.document.find_chunk("XTHG").set_decoded_payload(things)
		or not fixture.city.set_text_overlay_id(point.x, point.y, 202)
	):
		fixture.city = null

	return fixture
