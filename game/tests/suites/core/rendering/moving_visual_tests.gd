extends "res://tests/support/core_test_suite.gd"

## Rendering: moving visual checks.

@warning_ignore_start("integer_division")

const IsometricRenderer = preload("res://src/view/city_isometric_renderer.gd")
const UndergroundView = preload("res://src/view/city_underground_view.gd")


func run(
	starter_document: Sc2File, starter: CityState, large: Sc2SpriteArchive
) -> CityState:
	var plane_visual := IsometricRenderer.moving_thing_sprite(ThingRecord.from_fields({
		"type": 1, "direction": 4, "state": 2,
	}))
	_check(
		plane_visual.sprite_id == 1362 and plane_visual.flip,
		"Airplane view uses the recovered direction offset and mirror",
	)
	var medium_plane := IsometricRenderer.moving_thing_sprite(ThingRecord.from_fields({
		"type": 1, "direction": 4, "state": 2,
	}), IsometricRenderer.VIEW_MEDIUM)
	_check(
		medium_plane.sprite_id == 862 and medium_plane.flip,
		"Airplane view selects the native medium direction sprite",
	)
	var small_plane := IsometricRenderer.moving_thing_sprite(ThingRecord.from_fields({
		"type": 1, "direction": 4, "state": 2,
	}), IsometricRenderer.VIEW_SMALL)
	_check(
		small_plane.sprite_id == 362 and small_plane.flip,
		"Airplane view selects the native small direction sprite",
	)
	var ship_visual := IsometricRenderer.moving_thing_sprite(ThingRecord.from_fields({
		"type": 3, "direction": 7, "state": 0,
	}))
	_check(
		ship_visual.sprite_id == 1369 and not ship_visual.flip,
		"Cargo-ship view uses the recovered north-west sprite",
	)
	_check(
		IsometricRenderer.moving_thing_sprite(ThingRecord.from_fields({
			"type": 3, "direction": 7, "state": 0,
		}), IsometricRenderer.VIEW_SMALL).sprite_id == 369,
		"Cargo-ship view selects the native small sprite",
	)
	_check(
		IsometricRenderer.moving_thing_sprite(ThingRecord.from_fields({
			"type": 4, "direction": 2, "state": 0,
		}), IsometricRenderer.VIEW_MEDIUM).sprite_id == 891,
		"Bulldozer view selects the native medium direction sprite",
	)
	var sail_visual := IsometricRenderer.moving_thing_sprite(ThingRecord.from_fields({
		"type": 9, "direction": 2, "state": 0,
	}))
	_check(
		sail_visual.sprite_id == 1381 and sail_visual.flip,
		"Sailboat view uses the recovered cardinal offset and mirror",
	)
	_check(
		IsometricRenderer.moving_thing_sprite(ThingRecord.from_fields({
			"type": 9, "direction": 2, "state": 1,
		})).sprite_id == 1379,
		"A distressed sailboat uses the Nessie sprite",
	)
	_check(
		IsometricRenderer.moving_thing_sprite(ThingRecord.from_fields({
			"type": 6, "direction": 2, "state": 0,
		})).sprite_id == 1389,
		"Explosion frame two uses the third recovered sprite",
	)
	_check(
		IsometricRenderer.moving_thing_sprite(ThingRecord.from_fields({
			"type": 6, "direction": 2, "state": 0,
		}), IsometricRenderer.VIEW_MEDIUM).sprite_id == 889,
		"Explosion view selects the native medium frame",
	)
	_check(
		IsometricRenderer.moving_thing_sprite(ThingRecord.from_fields({
			"type": 6, "direction": 2, "state": 0,
		}), IsometricRenderer.VIEW_SMALL) == null,
		"Explosion stays hidden below its recovered minimum view",
	)
	_check(
		IsometricRenderer.moving_thing_sprite(ThingRecord.from_fields({
			"type": 2, "direction": 2, "state": 0,
		}), IsometricRenderer.VIEW_MEDIUM) == null,
		"Helicopter stays hidden below its recovered minimum view",
	)
	_check(
		IsometricRenderer.moving_thing_sprite(ThingRecord.from_fields({
			"type": 10, "direction": 0, "state": 0,
		})) == null,
		"The generic view defers trains to their custom renderer",
	)
	_check(
		starter_document.find_chunk("ALTM").set_decoded_payload(_filled_bytes(128 * 128 * 2, 0)),
		"Isometric lookup fixture clears altitude",
	)
	_check(
		starter_document.find_chunk("XTER").set_decoded_payload(_filled_bytes(128 * 128, 0)),
		"Isometric lookup fixture clears terrain",
	)
	starter = CityModel.from_document(starter_document)
	_check(starter.set_building_id(64, 64, Tiles.EMPTY), "Moving overlay fixture clears its tile")
	_check(starter.set_tile_flag(64, 64, 0x04, false), "Moving overlay fixture uses dry land")
	var plane_entry := large.find_sprite(plane_visual.sprite_id)
	var plane_commands_visual := IsometricMovingVisuals.Visual.new()
	plane_commands_visual.sprite_id = plane_visual.sprite_id
	plane_commands_visual.flip = plane_visual.flip
	plane_commands_visual.type = 1
	plane_commands_visual.x = 64
	plane_commands_visual.y = 64
	plane_commands_visual.z = 2
	plane_commands_visual.px = 8
	plane_commands_visual.py = 8
	plane_commands_visual.train = false
	plane_commands_visual.tornado = false
	plane_commands_visual.monster = false
	var plane_commands := IsometricRenderer.moving_thing_draw_commands_for_visual(
		starter, large, plane_commands_visual, IsometricRenderer.view_configuration(IsometricRenderer.VIEW_LARGE)
	)
	var expected_plane_position := Vector2i(
		2096 - int(plane_entry.width / 2), 1545 - plane_entry.height
	)
	_check(
		plane_commands.size() == 2
		and plane_commands[0].shadow
		and plane_commands[0].position == expected_plane_position
		and not plane_commands[1].shadow
		and plane_commands[1].position == expected_plane_position,
		"Moving overlay commands use the recovered baseline and shadow positions",
	)
	var moving_fixture := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	moving_fixture.fill(Color.WHITE)
	var occluder_fixture := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	occluder_fixture.fill(Color.TRANSPARENT)
	occluder_fixture.set_pixel(1, 1, Color.WHITE)
	var occluded := IsometricRenderer.occlude_dynamic_with_mask(
		moving_fixture, occluder_fixture, Vector2i(1, 1)
	)
	_check(
		occluded.occluded_pixels == 1
		and occluded.image.get_pixel(1, 1).a == 0.0,
		"Dynamic occlusion hides a pixel painted by a later map sprite",
	)
	var unobscured := IsometricRenderer.occlude_dynamic_with_mask(
		moving_fixture, null, Vector2i(1, 1)
	)
	_check(
		unobscured.occluded_pixels == 0 and unobscured.image == moving_fixture,
		"Dynamic occlusion keeps pixels without a later map sprite",
	)
	var index_fixture := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	index_fixture.fill(Color8(0xa1, 0xa1, 0xa1, 255))
	index_fixture.set_pixel(2, 2, Color8(0, 0, 0, 255))
	var wire_occluded := IsometricRenderer.occlude_dynamic_with_mask(
		moving_fixture, null, Vector2i(1, 1), index_fixture,
		PackedInt32Array([0x00, 0x2a])
	)
	_check(
		wire_occluded.occluded_pixels == 1
		and wire_occluded.image.get_pixel(1, 1).a == 0.0,
		"Same-tile wire masking keeps rail crossover cables in front",
	)
	var static_occluders := IsometricRenderer.static_occlusion_commands(starter, large)
	_check(
		static_occluders.size() >= CityState.TILE_COUNT
		and int(static_occluders[0].depth_order) <= int(static_occluders[-1].depth_order),
		"Static occlusion commands keep the isometric map order",
	)
	var occlusion_grid := IsometricRenderer.build_occlusion_grid(static_occluders, 1)
	var occlusion_target_index := int(static_occluders.size() / 2)
	var occlusion_target: CityStaticCommand = static_occluders[occlusion_target_index]
	var occlusion_target_bounds := Rect2i(
		Vector2i(occlusion_target.position), Vector2i(occlusion_target.size)
	)
	var occlusion_candidates := IsometricRenderer.occlusion_candidate_indices(
		occlusion_grid, occlusion_target_bounds
	)
	var occlusion_candidates_complete := true

	for occluder_index in static_occluders.size():
		var candidate: CityStaticCommand = static_occluders[occluder_index]
		var candidate_bounds := Rect2i(
			Vector2i(candidate.position), Vector2i(candidate.size)
		)

		if (
			occlusion_target_bounds.intersects(candidate_bounds)
			and not occlusion_candidates.has(occluder_index)
		):
			occlusion_candidates_complete = false
			break

	_check(
		occlusion_candidates_complete
		and occlusion_candidates.has(occlusion_target_index)
		and occlusion_candidates.size() < static_occluders.size(),
		"The occlusion grid keeps all local overlaps and rejects distant sprites",
	)
	var static_signature := IsometricRenderer.static_visual_signature(starter)
	_check(
		starter.set_text_overlay_id(64, 64, 201),
		"Static-signature fixture adds an inactive moving-object link",
	)
	_check(
		IsometricRenderer.static_visual_signature(starter) == static_signature,
		"Moving-object links do not invalidate the static city image",
	)
	_check(
		starter.set_text_overlay_id(64, 64, 0xfb),
		"Static-signature fixture adds a special map marker",
	)
	_check(
		IsometricRenderer.static_visual_signature(starter) == static_signature,
		"A dynamic special marker does not invalidate the static city image",
	)
	var signature_flag_index := starter.index_of(64, 64)
	var original_signature_flags := starter.tile_flags[signature_flag_index]
	starter.set_tile_flag(64, 64, 0x08, (starter.tile_flags[signature_flag_index] & 0x08) == 0)
	_check(
		IsometricRenderer.static_visual_signature(starter) == static_signature,
		"A simulation-only tile flag does not invalidate the static city image",
	)
	var underground_signature := UndergroundView.visual_signature(
		starter, IsometricRenderer.VIEW_LARGE
	)
	starter.set_tile_flag(64, 64, 0x08, (starter.tile_flags[signature_flag_index] & 0x08) == 0)
	_check(
		UndergroundView.visual_signature(starter, IsometricRenderer.VIEW_LARGE)
		== underground_signature,
		"A simulation-only tile flag does not invalidate the underground image",
	)
	starter.set_tile_flag(64, 64, 0x10, (starter.tile_flags[signature_flag_index] & 0x10) == 0)
	_check(
		UndergroundView.visual_signature(starter, IsometricRenderer.VIEW_LARGE)
		!= underground_signature,
		"A water-network tile flag invalidates the underground image",
	)
	starter.set_tile_flag(64, 64, 0xff, false)
	starter.set_tile_flag(64, 64, original_signature_flags, true)
	starter.set_tile_flag(64, 64, 0x04, (starter.tile_flags[signature_flag_index] & 0x04) == 0)
	_check(
		IsometricRenderer.static_visual_signature(starter) != static_signature,
		"A visible water tile flag invalidates the static city image",
	)
	starter.set_tile_flag(64, 64, 0xff, false)
	starter.set_tile_flag(64, 64, original_signature_flags, true)
	var dynamic_specials := IsometricRenderer.dynamic_draw_commands(
		starter, large, IsometricRenderer.VIEW_LARGE, 0
	)
	var found_dynamic_special := false

	for command in dynamic_specials:
		if int(command.overlay) == 0xfb:
			found_dynamic_special = true
			break

	_check(found_dynamic_special, "The dynamic city layer draws a special map marker")
	_check(starter.set_text_overlay_id(64, 64, 0), "Static-signature fixture clears its marker")

	for expected in [Vector2i.ZERO, Vector2i(24, 93), Vector2i(64, 64), Vector2i(127, 127)]:
		var polygon := IsometricRenderer.tile_polygon(starter, expected.x, expected.y)
		var center := (polygon[0] + polygon[1] + polygon[2] + polygon[3]) * 0.25
		_check(
			IsometricRenderer.screen_to_tile(starter, center) == expected,
			"Isometric screen lookup finds tile %s" % expected,
		)
	return starter
