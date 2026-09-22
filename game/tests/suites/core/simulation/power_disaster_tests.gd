extends "res://tests/support/core_test_suite.gd"

## Simulation: power disaster checks.

@warning_ignore_start("integer_division")

const Random = preload("res://src/simulation/random/sim_random.gd")
const LfsrRandom = preload("res://src/simulation/random/sim_lfsr_random.gd")
const DisasterStart = preload("res://src/simulation/disasters/disaster_start_phase.gd")
const Growth = preload("res://src/simulation/growth/phase/constants.gd")
const ToolAvailability = preload("res://src/tools/shared/tool_availability.gd")
const Buildings = preload("res://src/tools/city/building_command.gd")
const TestRandoms = preload("res://tests/support/test_randoms.gd")
const SequenceLfsrRandom = TestRandoms.SequenceLfsrRandom
const SequenceRandom = TestRandoms.SequenceRandom
const SparseRandom = TestRandoms.SparseRandom


func run(reference_root: String) -> void:
	var meltdown_document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))

	for chunk_id in ["XBLD", "XTER", "XZON", "XUND", "XBIT", "XTXT"]:
		_check(
			meltdown_document.find_chunk(chunk_id).set_decoded_payload(
				_filled_bytes(CityState.TILE_COUNT, 0)
			),
			"Meltdown fixture clears %s" % chunk_id,
		)

	_check(
		meltdown_document.find_chunk("ALTM").set_decoded_payload(
			_filled_bytes(CityState.TILE_COUNT * 2, 0)
		)
		and meltdown_document.find_chunk("XTRF").set_decoded_payload(
			_filled_bytes(64 * 64, 9)
		)
		and meltdown_document.find_chunk("XLAB").set_decoded_payload(
			_filled_bytes(CityState.LABEL_COUNT * CityState.LABEL_RECORD_SIZE, 0)
		)
		and meltdown_document.find_chunk("XMIC").set_decoded_payload(
			_filled_bytes(CityState.MICROSIM_COUNT * CityState.MICROSIM_RECORD_SIZE, 0)
		),
		"Meltdown fixture clears linked map state",
	)
	var meltdown_buildings: PackedByteArray = (
		meltdown_document.find_chunk("XBLD").decoded_payload.duplicate()
	)
	var meltdown_zones: PackedByteArray = (
		meltdown_document.find_chunk("XZON").decoded_payload.duplicate()
	)
	var meltdown_flags: PackedByteArray = (
		meltdown_document.find_chunk("XBIT").decoded_payload.duplicate()
	)
	var military_target := Vector2i(32, 33)
	var fire_target := Vector2i(32, 34)
	var toxic_target := Vector2i(32, 35)
	meltdown_buildings[military_target.x * CityState.MAP_SIZE + military_target.y] = Tiles.RUNWAY
	meltdown_zones[military_target.x * CityState.MAP_SIZE + military_target.y] = 7
	meltdown_buildings[toxic_target.x * CityState.MAP_SIZE + toxic_target.y] = Tiles.SMALL_PARK
	meltdown_flags[toxic_target.x * CityState.MAP_SIZE + toxic_target.y] = 0x04
	_check(
		meltdown_document.find_chunk("XBLD").set_decoded_payload(meltdown_buildings)
		and meltdown_document.find_chunk("XZON").set_decoded_payload(meltdown_zones)
		and meltdown_document.find_chunk("XBIT").set_decoded_payload(meltdown_flags),
		"Meltdown fixture installs military, fire, and water-toxic targets",
	)
	var meltdown_misc: PackedByteArray = (
		meltdown_document.find_chunk("MISC").decoded_payload.duplicate()
	)

	for tile_id in 256:
		_write_u32_be(meltdown_misc, Buildings.MISC_TILE_COUNTS + tile_id * 4, 0)

	for military_index in 16:
		_write_u32_be(
			meltdown_misc,
			Growth.MISC_MILITARY_TILE_COUNTS + military_index * 4,
			0,
		)

	_write_u32_be(meltdown_misc, Buildings.MISC_TILE_COUNTS, CityState.TILE_COUNT - 2)
	_write_u32_be(meltdown_misc, Buildings.MISC_TILE_COUNTS + 0x0d * 4, 1)
	_write_u32_be(meltdown_misc, Growth.MISC_MILITARY_TILE_COUNTS + 4, 1)
	_write_u32_be(meltdown_misc, Buildings.MISC_FUNDS, 50000)
	_write_u32_be(
		meltdown_misc,
		ToolAvailability.MISC_INVENTION_YEARS + 4,
		0,
	)
	_check(
		meltdown_document.find_chunk("MISC").set_decoded_payload(meltdown_misc),
		"Meltdown fixture initializes normal and military tile counts",
	)
	var meltdown_city := CityModel.from_document(meltdown_document)
	var nuclear_placement := Buildings.apply(
		meltdown_city,
		3,
		6,
		Vector2i(64, 64),
		LfsrRandom.new(1),
		Random.new(1),
	)
	_check(
		nuclear_placement.ok
		and nuclear_placement.site == Rect2i(63, 63, 4, 4)
		and nuclear_placement.tile_id == DisasterStart.NUCLEAR_POWER_PLANT,
		"Meltdown fixture places one valid four-by-four nuclear power plant",
	)
	var meltdown_random := SparseRandom.new({
		144: 0,
		145: 1,
		147: 1,
		148: 0,
		149: 0,
		150: 0,
		151: 1,
		153: 1,
	})
	var meltdown_start := DisasterStart.start(
		meltdown_city,
		DisasterStart.DISASTER_MELTDOWN,
		Vector2i.ZERO,
		meltdown_random,
		SequenceLfsrRandom.new([]),
	)
	var meltdown_center := Vector2i(64, 65)
	_check(
		meltdown_start.ok
		and meltdown_start.started
		and meltdown_start.complete
		and meltdown_start.plant_point == Vector2i(63, 63)
		and meltdown_start.plant_site == Rect2i(63, 63, 4, 4)
		and meltdown_start.point == meltdown_center
		and meltdown_start.view_center_requests == [meltdown_center]
		and SoundEvent.same_arrays(meltdown_start.sound_events, SoundEvent.from_ids([
			DisasterStart.SOUND_EARTHQUAKE, DisasterStart.SOUND_SIREN,
		]))
		and meltdown_start.effect_events.size() == 64
		and meltdown_start.effect_events[0].frame == 0
		and meltdown_start.effect_events[16].frame == 1
		and meltdown_start.effect_events[63].frame == 3,
		"Meltdown finds the first nuclear plant, normalizes its center, and reports a start",
	)
	_check(
		meltdown_start.counters.gate_attempts == 4225
		and meltdown_start.counters.gate_hits == 3
		and meltdown_start.counters.fire_damage_attempts == 1
		and meltdown_start.counters.structure_damage_attempts == 2
		and meltdown_start.counters.radioactive_writes == 17
		and meltdown_start.counters.toxic_writes == 1
		and meltdown_start.map_changed
		and meltdown_random.position == 4392,
		"Meltdown preserves the 65-by-65 scan branches and exact process-random order: %s pos=%d"
		% [meltdown_start, meltdown_random.position],
	)
	_check(
		meltdown_city.building_id(military_target.x, military_target.y)
			== DisasterStart.RADIOACTIVITY_TILE
		and meltdown_city.text_overlay_id(fire_target.x, fire_target.y)
			== DisasterMap.FIRE_OVERLAY
		and meltdown_city.text_overlay_id(toxic_target.x, toxic_target.y)
			== DisasterMap.TOXIC_OVERLAY
		and meltdown_city.tile_flags[
			toxic_target.x * CityState.MAP_SIZE + toxic_target.y
		] & 0x04 != 0,
		"Meltdown writes radiation on dry land, fire on an open cell, and toxic waste on water: military=%d fire=%d toxic=%d flags=%d"
		% [
			meltdown_city.building_id(military_target.x, military_target.y),
			meltdown_city.text_overlay_id(fire_target.x, fire_target.y),
			meltdown_city.text_overlay_id(toxic_target.x, toxic_target.y),
			meltdown_city.tile_flags[toxic_target.x * CityState.MAP_SIZE + toxic_target.y],
		],
	)
	var stored_meltdown_misc: PackedByteArray = (
		meltdown_document.find_chunk("MISC").decoded_payload
	)
	_check(
		BuildingState.read_u32_be(
			stored_meltdown_misc, Buildings.MISC_TILE_COUNTS + 0xcb * 4
		) == 0
		and BuildingState.read_u32_be(
			stored_meltdown_misc, Buildings.MISC_TILE_COUNTS + 0x05 * 4
		) == 16
		and BuildingState.read_u32_be(
			stored_meltdown_misc, Growth.MISC_MILITARY_TILE_COUNTS
		) == 1
		and BuildingState.read_u32_be(
			stored_meltdown_misc, Growth.MISC_MILITARY_TILE_COUNTS + 4
		) == 0,
		"Meltdown moves normal and military tile counts to their radiation buckets: nuclear=%d normal=%d military0=%d military1=%d"
		% [
			BuildingState.read_u32_be(
				stored_meltdown_misc, Buildings.MISC_TILE_COUNTS + 0xcb * 4
			),
			BuildingState.read_u32_be(
				stored_meltdown_misc, Buildings.MISC_TILE_COUNTS + 0x05 * 4
			),
			BuildingState.read_u32_be(
				stored_meltdown_misc, Growth.MISC_MILITARY_TILE_COUNTS
			),
			BuildingState.read_u32_be(
				stored_meltdown_misc, Growth.MISC_MILITARY_TILE_COUNTS + 4
			),
		],
	)

	for x in range(63, 67):
		for y in range(63, 67):
			_check(
				meltdown_city.building_id(x, y) == DisasterStart.RADIOACTIVITY_TILE,
				"Meltdown radiation core covers plant tile %d,%d" % [x, y],
			)

	var no_plant_document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))
	_check(
		no_plant_document.find_chunk("XBLD").set_decoded_payload(
			_filled_bytes(CityState.TILE_COUNT, 0)
		),
		"No-plant meltdown fixture clears all nuclear plants",
	)
	var no_plant_random := SparseRandom.new({})
	var no_plant_meltdown := DisasterStart.start(
		CityModel.from_document(no_plant_document),
		DisasterStart.DISASTER_MELTDOWN,
		Vector2i(20, 20),
		no_plant_random,
		SequenceLfsrRandom.new([]),
	)
	_check(
		no_plant_meltdown.ok
		and not no_plant_meltdown.started
		and no_plant_meltdown.complete
		and no_plant_meltdown.sound_events.is_empty()
		and no_plant_random.position == 0,
		"Meltdown does not start or consume random state when the city has no nuclear plant",
	)

	var microwave_document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))

	for chunk_id in ["XBLD", "XTER", "XZON", "XUND", "XBIT", "XTXT"]:
		_check(
			microwave_document.find_chunk(chunk_id).set_decoded_payload(
				_filled_bytes(CityState.TILE_COUNT, 0)
			),
			"Microwave fixture clears %s" % chunk_id,
		)

	_check(
		microwave_document.find_chunk("ALTM").set_decoded_payload(
			_filled_bytes(CityState.TILE_COUNT * 2, 0)
		)
		and microwave_document.find_chunk("XTRF").set_decoded_payload(
			_filled_bytes(64 * 64, 9)
		),
		"Microwave fixture clears altitude and fills traffic",
	)
	var microwave_plant := Vector2i(10, 10)
	var microwave_water := Vector2i(20, 10)
	var microwave_buildings: PackedByteArray = (
		microwave_document.find_chunk("XBLD").decoded_payload.duplicate()
	)
	var microwave_flags: PackedByteArray = (
		microwave_document.find_chunk("XBIT").decoded_payload.duplicate()
	)
	microwave_buildings[microwave_plant.x * CityState.MAP_SIZE + microwave_plant.y] = (
		DisasterStart.MICROWAVE_POWER_PLANT
	)
	microwave_flags[microwave_water.x * CityState.MAP_SIZE + microwave_water.y] = 0x04
	_check(
		microwave_document.find_chunk("XBLD").set_decoded_payload(microwave_buildings)
		and microwave_document.find_chunk("XBIT").set_decoded_payload(microwave_flags),
		"Microwave fixture places its plant and one water path cell",
	)
	var microwave_city := CityModel.from_document(microwave_document)
	var microwave_values: Array[int] = []

	for _step in 40:
		microwave_values.append(2)

	var microwave_random := SequenceRandom.new(microwave_values)
	var microwave_start := DisasterStart.start(
		microwave_city,
		DisasterStart.DISASTER_MICROWAVE,
		Vector2i(99, 99),
		microwave_random,
		SequenceLfsrRandom.new([]),
	)
	_check(
		microwave_start.ok
		and microwave_start.started
		and microwave_start.complete
		and microwave_start.plant_point == microwave_plant
		and microwave_start.point == microwave_plant
		and microwave_start.path_finish == Vector2i(49, 10)
		and microwave_start.counters.path_steps == 39
		and microwave_start.counters.damage_attempts == 38
		and microwave_start.counters.toxic_writes == 1
		and microwave_start.map_changed
		and microwave_random.position == 40,
		"Microwave ignores the requested point and follows 39 random eight-direction steps",
	)
	_check(
		microwave_start.view_center_requests == [
			Vector2i(10, 10),
			Vector2i(19, 10),
			Vector2i(29, 10),
			Vector2i(39, 10),
		]
		and microwave_start.sound_events.size() == 39
		and microwave_start.sound_events[0].equals(SoundEvent.new(DisasterStart.SOUND_MICROWAVE))
		and microwave_start.sound_events[-2].equals(SoundEvent.new(DisasterStart.SOUND_MICROWAVE))
		and microwave_start.sound_events[-1].equals(SoundEvent.new(DisasterStart.SOUND_SIREN)),
		"Microwave requests periodic view centers, one sound per damaged point, and the siren",
	)
	_check(
		microwave_city.building_id(microwave_plant.x, microwave_plant.y)
			== DisasterStart.MICROWAVE_POWER_PLANT
		and microwave_city.text_overlay_id(microwave_plant.x, microwave_plant.y) == 0
		and microwave_city.text_overlay_id(11, 10) == DisasterMap.FIRE_OVERLAY
		and microwave_city.text_overlay_id(microwave_water.x, microwave_water.y)
			== DisasterMap.TOXIC_OVERLAY
		and microwave_city.text_overlay_id(48, 10) == DisasterMap.FIRE_OVERLAY,
		"Microwave preserves its plant, burns dry path cells, and writes toxic waste on water",
	)
	var edge_microwave_document := _load_fixture(
		reference_root.path_join("DEFAULT.SC2")
	)
	var edge_microwave_buildings := _filled_bytes(CityState.TILE_COUNT, Tiles.EMPTY)
	edge_microwave_buildings[127 * CityState.MAP_SIZE + 10] = (
		DisasterStart.MICROWAVE_POWER_PLANT
	)
	_check(
		edge_microwave_document.find_chunk("XBLD").set_decoded_payload(
			edge_microwave_buildings
		),
		"Edge Microwave fixture places one plant at the east boundary",
	)
	var edge_microwave_random := SequenceRandom.new([2, 7])
	var edge_microwave := DisasterStart.start(
		CityModel.from_document(edge_microwave_document),
		DisasterStart.DISASTER_MICROWAVE,
		Vector2i.ZERO,
		edge_microwave_random,
		SequenceLfsrRandom.new([]),
	)
	_check(
		edge_microwave.ok
		and edge_microwave.started
		and edge_microwave.counters.path_steps == 1
		and edge_microwave.path_finish == Vector2i(128, 10)
		and edge_microwave.counters.damage_attempts == 0
		and not edge_microwave.map_changed
		and SoundEvent.same_arrays(edge_microwave.sound_events, SoundEvent.from_ids([DisasterStart.SOUND_SIREN]))
		and edge_microwave_random.position == 2,
		"Microwave stops after an out-of-map move and retains its final random read",
	)
	var no_microwave_document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))
	_check(
		no_microwave_document.find_chunk("XBLD").set_decoded_payload(
			_filled_bytes(CityState.TILE_COUNT, 0)
		),
		"No-plant Microwave fixture clears every microwave plant",
	)
	var no_microwave_random := SparseRandom.new({})
	var no_microwave := DisasterStart.start(
		CityModel.from_document(no_microwave_document),
		DisasterStart.DISASTER_MICROWAVE,
		Vector2i.ZERO,
		no_microwave_random,
		SequenceLfsrRandom.new([]),
	)
	_check(
		no_microwave.ok
		and not no_microwave.started
		and no_microwave.complete
		and no_microwave.sound_events.is_empty()
		and no_microwave_random.position == 0,
		"Microwave does not start or consume random state when no microwave plant exists",
	)
