extends "res://tests/support/core_test_suite.gd"

## Tools: dispatch rotation checks.

@warning_ignore_start("integer_division")

const Sc2Document = preload("res://src/formats/sc2_file.gd")
const IsometricRenderer = preload("res://src/view/city_isometric_renderer.gd")
const Simulation = preload("res://src/simulation/core/simulation_engine.gd")
const Dispatch = preload("res://src/tools/city/dispatch_command.gd")
const CityRotation = preload("res://src/tools/city/city_rotation_command.gd")


func test_dispatch_command(reference_root: String) -> void:
	_check(Dispatch.supports_tool(2, 0), "Dispatch command supports Police")
	_check(Dispatch.supports_tool(2, 1), "Dispatch command supports Fire")
	_check(Dispatch.supports_tool(2, 2), "Dispatch command supports Military")
	_check(not Dispatch.supports_tool(3, 0), "Dispatch command rejects another tool group")
	var document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))

	for chunk_id in ["XBIT", "XTXT", "XTHG"]:
		var size := 480 if chunk_id == "XTHG" else 128 * 128
		_check(
			document.find_chunk(chunk_id).set_decoded_payload(_filled_bytes(size, 0)),
			"Dispatch fixture clears %s" % chunk_id,
		)

	_check(document.set_misc_u32(0x01f0 + 0xd2 * 4, 9), "Dispatch fixture counts one police station")
	_check(document.set_misc_u32(0x01f0 + 0xd3 * 4, 18), "Dispatch fixture counts two fire stations")
	_check(document.set_misc_u32(0x0e4c, 4), "Dispatch fixture selects a navy base")
	var things: PackedByteArray = document.find_chunk("XTHG").decoded_payload.duplicate()
	things[5 * 12] = 7
	things[5 * 12 + 3] = 5
	things[5 * 12 + 4] = 5
	_check(document.find_chunk("XTHG").set_decoded_payload(things), "Dispatch fixture stores an old police unit")
	var text: PackedByteArray = document.find_chunk("XTXT").decoded_payload.duplicate()
	text[5 * 128 + 5] = 206
	_check(document.find_chunk("XTXT").set_decoded_payload(text), "Dispatch fixture labels the old police unit")
	var city := CityModel.from_document(document)
	var available := Dispatch.availability(city)
	_check(available.ok and available.police == 1, "Police availability is station tile count divided by eight")
	_check(available.fire == 2, "Fire availability is station tile count divided by eight")
	_check(available.military == 3, "A navy base supplies three military units")

	var police := Dispatch.apply(city, 2, 0, Vector2i(10, 10), 0, true)
	_check(police.ok and police.slot_index == 1 and police.thing_index == 1, "Police dispatch resets old units and uses the first record")
	_check(city.thing(1).type == 7 and city.thing(1).x == 10 and city.thing(1).y == 10, "Police dispatch stores the XTHG unit")
	_check(city.text_overlay_id(10, 10) == 202 and city.text_overlay_id(5, 5) == 0, "Police dispatch moves the XTXT unit marker")
	_check(IsometricStaticVisuals.dispatch_sprite_id(city, 10, 10) == 1382, "Police dispatch selects the recovered large sprite")
	_check(
		IsometricStaticVisuals.dispatch_sprite_id(
			city, 10, 10, IsometricRenderer.VIEW_MEDIUM
		) == 882,
		"Police dispatch selects the native medium sprite",
	)
	_check(
		IsometricStaticVisuals.dispatch_sprite_id(
			city, 10, 10, IsometricRenderer.VIEW_SMALL
		) == 382,
		"Police dispatch selects the native small sprite",
	)
	_check(Dispatch.undo(city, police).ok, "Police dispatch can be undone")
	_check(city.thing(5).type == 7 and city.text_overlay_id(5, 5) == 206, "Dispatch undo restores units cleared at session start")
	police = Dispatch.apply(city, 2, 0, Vector2i(10, 10), 0, true)
	var moved_police := Dispatch.apply(city, 2, 0, Vector2i(11, 10), police.slot_index, false)
	_check(moved_police.ok and moved_police.slot_index == 1, "A second Police action wraps its one-unit cycle")
	_check(city.text_overlay_id(10, 10) == 0 and city.text_overlay_id(11, 10) == 202, "Wrapped Police dispatch relocates its unit")
	_check(Dispatch.undo(city, moved_police).ok, "Relocated Police dispatch can be undone")

	var fire := Dispatch.apply(city, 2, 1, Vector2i(20, 20), 0, false)
	_check(fire.ok and fire.available == 2 and city.thing(fire.thing_index).type == 8, "Fire dispatch adds an XTHG fire unit")
	var military := Dispatch.apply(city, 2, 2, Vector2i(21, 20), 0, false)
	_check(military.ok and military.available == 3 and city.thing(military.thing_index).type == 14, "Military dispatch adds an XTHG military unit")
	_check(Dispatch.undo(city, military).ok, "Military dispatch can be undone")
	_check(city.set_tile_flag(30, 30, 0x04, true), "Dispatch water fixture marks a water tile")
	var water := Dispatch.apply(city, 2, 1, Vector2i(30, 30), fire.slot_index, false)
	_check(not water.ok and not water.error.is_empty(), "Dispatch rejects a water target")
	_check(document.set_misc_u32(0x01f0 + 0xd2 * 4, 0), "Dispatch unavailable fixture removes police capacity")
	var no_police := Dispatch.apply(city, 2, 0, Vector2i(31, 30), police.slot_index, false)
	_check(not no_police.ok and not no_police.error.is_empty(), "Dispatch rejects an unavailable unit type")


func test_city_rotation(reference_root: String) -> void:
	_check(
		CityRotation.rotate_point(Vector2i(10, 20), 128, true) == Vector2i(20, 117),
		"Counter-clockwise rotation transforms a full-map point",
	)
	_check(
		CityRotation.rotate_point(Vector2i(10, 20), 128, false) == Vector2i(107, 10),
		"Clockwise rotation transforms a full-map point",
	)
	_check(
		CityRotation.surface_tile_after_rotation(Tiles.ROAD_SLOPE_1, true) == 0x22
		and CityRotation.surface_tile_after_rotation(Tiles.ROAD_SLOPE_1, false) == 0x20,
		"Rotation uses the recovered surface-network lookup tables",
	)
	_check(
		CityRotation.terrain_tile_after_rotation(0x01, true) == 0x04
		and CityRotation.terrain_tile_after_rotation(0x01, false) == 0x02,
		"Rotation uses the recovered terrain lookup tables",
	)
	_check(
		CityRotation.underground_tile_after_rotation(UnderTiles.SUBWAY_HTB, true) == 0x06
		and CityRotation.underground_tile_after_rotation(UnderTiles.SUBWAY_HTB, false) == 0x04,
		"Rotation uses the recovered underground lookup tables",
	)

	var document := _load_fixture(reference_root.path_join("CITIES/STARTER.SC2"))
	var things: PackedByteArray = document.find_chunk("XTHG").decoded_payload.duplicate()
	things.fill(0)
	var airplane := 1 * CityModel.THING_RECORD_SIZE
	things[airplane] = 1
	things[airplane + 1] = 0
	things[airplane + 2] = 0x24
	things[airplane + 3] = 10
	things[airplane + 4] = 20
	things[airplane + 8] = 40
	things[airplane + 9] = 50
	var train := 2 * CityModel.THING_RECORD_SIZE
	things[train] = 10
	things[train + 1] = 0
	things[train + 3] = 30
	things[train + 4] = 40
	things[train + 6] = 60
	things[train + 7] = 70
	things[train + 8] = 0
	_check(document.find_chunk("XTHG").set_decoded_payload(things), "Rotation fixture stores moving things")
	var city := CityModel.from_document(document)
	_check(city.set_building_id(10, 10, Tiles.SUSPENSION_BRIDGE_1), "Rotation fixture stores an unflipped bridge")
	_check(city.set_tile_flag(10, 10, 0x02, false), "Rotation fixture clears the first bridge flip")
	_check(city.set_building_id(11, 10, Tiles.SUSPENSION_BRIDGE_1), "Rotation fixture stores a flipped bridge")
	_check(city.set_tile_flag(11, 10, 0x02, true), "Rotation fixture sets the second bridge flip")
	_check(city.set_building_id(12, 10, Tiles.HIGHWAY_ONRAMP_1), "Rotation fixture stores an unflipped on-ramp")
	_check(city.set_tile_flag(12, 10, 0x02, false), "Rotation fixture clears the first ramp flip")
	_check(city.set_building_id(13, 10, Tiles.HIGHWAY_ONRAMP_1), "Rotation fixture stores a flipped on-ramp")
	_check(city.set_tile_flag(13, 10, 0x02, true), "Rotation fixture sets the second ramp flip")
	_check(city.set_terrain_id(14, 10, 0x01), "Rotation fixture stores directional terrain")
	_check(city.set_underground_id(15, 10, UnderTiles.SUBWAY_HTB), "Rotation fixture stores a directional subway")
	var old_payloads := {}

	for specification in CityRotation.REQUIRED_CHUNKS:
		var chunk_id: String = specification[0]
		old_payloads[chunk_id] = document.find_chunk(chunk_id).decoded_payload.duplicate()

	var old_compass := city.compass_rotation()
	var rotated := CityRotation.apply(city, true)
	_check(rotated.ok, "Counter-clockwise city rotation succeeds: %s" % rotated.error)
	_check(
		city.compass_rotation() == ((old_compass + 1) & 3),
		"Counter-clockwise rotation increments the saved compass",
	)
	_check(
		city.building_id(10, 117) == 0x51 and city.is_flipped(10, 117),
		"Counter-clockwise rotation toggles an unflipped bridge",
	)
	_check(
		city.building_id(10, 116) == 0x55 and not city.is_flipped(10, 116),
		"Counter-clockwise rotation retiles a flipped bridge",
	)
	_check(
		city.building_id(10, 115) == 0x5e and city.is_flipped(10, 115),
		"Counter-clockwise rotation retiles an unflipped on-ramp",
	)
	_check(
		city.building_id(10, 114) == 0x60 and not city.is_flipped(10, 114),
		"Counter-clockwise rotation retiles a flipped on-ramp",
	)
	_check(
		city.terrain_id(10, 113) == 0x04 and city.underground_id(10, 112) == 0x06,
		"Counter-clockwise rotation retiles terrain and underground networks",
	)
	var old_traffic: PackedByteArray = old_payloads.XTRF
	var rotated_traffic: PackedByteArray = document.find_chunk("XTRF").decoded_payload
	_check(
		rotated_traffic[7 * 64 + 58] == old_traffic[5 * 64 + 7],
		"Counter-clockwise rotation transforms a coarse-map coordinate",
	)
	var rotated_airplane := city.thing(1)
	_check(
		rotated_airplane.x == 20 and rotated_airplane.y == 117
		and rotated_airplane.direction == 6,
		"Counter-clockwise rotation transforms an airplane position and direction",
	)
	_check(
		rotated_airplane.dx == 50 and rotated_airplane.dy == 87
		and rotated_airplane.state == 0x04,
		"Counter-clockwise rotation transforms an airplane target and runway axis",
	)
	var rotated_train := city.thing(2)
	_check(
		rotated_train.x == 40 and rotated_train.y == 97
		and rotated_train.direction == 3,
		"Counter-clockwise rotation transforms a train position and direction",
	)
	_check(
		rotated_train.px == 70 and rotated_train.py == 67 and rotated_train.dx == 6,
		"Counter-clockwise rotation transforms a train route state",
	)
	var serialized := document.serialize()
	var reloaded_document := Sc2Document.new()
	_check(serialized.ok and reloaded_document.parse(serialized.data), "A rotated city serializes and reloads")
	var reloaded := CityModel.from_document(reloaded_document)
	_check(
		reloaded.is_valid() and reloaded.compass_rotation() == city.compass_rotation(),
		"A reloaded city retains its rotated compass",
	)
	var restored := CityRotation.apply(city, false)
	_check(restored.ok, "Inverse clockwise city rotation succeeds: %s" % restored.error)

	for specification in CityRotation.REQUIRED_CHUNKS:
		var chunk_id: String = specification[0]
		_check(
			document.find_chunk(chunk_id).decoded_payload == old_payloads[chunk_id],
			"Opposite rotations restore %s bytes" % chunk_id,
		)

	var engine := Simulation.new(city, 1, 1, 1)
	engine.ship_home = Vector2i(10, 20)
	engine.pending_disaster_type = 1
	engine.pending_disaster_point = Vector2i(30, 40)
	engine.rotate_runtime_coordinates(true)
	_check(
		engine.ship_home == Vector2i(20, 117)
		and engine.pending_disaster_point == Vector2i(40, 97),
		"Rotation transforms process-local simulation coordinates",
	)
