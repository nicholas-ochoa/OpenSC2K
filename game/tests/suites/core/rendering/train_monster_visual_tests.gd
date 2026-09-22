extends "res://tests/support/core_test_suite.gd"

## Rendering: train monster visual checks.

@warning_ignore_start("integer_division")

const Palette = preload("res://src/assets/sc2_palette.gd")
const IsometricRenderer = preload("res://src/view/city_isometric_renderer.gd")
const Power = preload("res://src/simulation/infrastructure/power_phase.gd")


func run(starter: CityState, large: Sc2SpriteArchive, small_medium: Sc2SpriteArchive) -> void:
	_check(starter.set_building_id(64, 64, Tiles.RAIL_SLOPE_1), "Train drawing fixture adds a rail tile")
	var straight_train := IsometricRenderer.train_sprite(starter, 64, 64, ThingRecord.from_fields({
		"type": 10, "dx": 0,
	}))
	_check(
		straight_train.sprite_id == 1377 and straight_train.flip,
		"Train view maps a rail tile to its recovered sprite variant",
	)
	var train_entry := large.find_sprite(straight_train.sprite_id)
	var train_commands_visual := IsometricMovingVisuals.Visual.new()
	train_commands_visual.sprite_id = straight_train.sprite_id
	train_commands_visual.flip = straight_train.flip
	train_commands_visual.type = 10
	train_commands_visual.x = 64
	train_commands_visual.y = 64
	train_commands_visual.z = 0
	train_commands_visual.px = 0
	train_commands_visual.py = 0
	train_commands_visual.train = true
	train_commands_visual.screen_x = straight_train.screen_x
	train_commands_visual.screen_y = straight_train.screen_y
	train_commands_visual.elevation = straight_train.elevation
	train_commands_visual.tornado = false
	train_commands_visual.monster = false
	var train_commands := IsometricRenderer.moving_thing_draw_commands_for_visual(
		starter, large, train_commands_visual, IsometricRenderer.view_configuration(IsometricRenderer.VIEW_LARGE)
	)
	_check(
		train_commands.size() == 1
		and train_commands[0].position == Vector2i(
			2096 - int(train_entry.width / 2), 1553 - train_entry.height
		),
		"Surface train uses the same recovered baseline as its rail tile",
	)
	_check(starter.set_building_id(64, 64, Tiles.RAIL_POWER_CROSSING_2), "Train wire fixture adds a rail-power crossover")
	var crossing_train := IsometricRenderer.train_sprite(starter, 64, 64, ThingRecord.from_fields({
		"type": 10, "dx": 0,
	}))
	var crossing_commands_visual := IsometricMovingVisuals.Visual.new()
	crossing_commands_visual.sprite_id = crossing_train.sprite_id
	crossing_commands_visual.flip = crossing_train.flip
	crossing_commands_visual.type = 10
	crossing_commands_visual.x = 64
	crossing_commands_visual.y = 64
	crossing_commands_visual.z = 0
	crossing_commands_visual.px = 0
	crossing_commands_visual.py = 0
	crossing_commands_visual.train = true
	crossing_commands_visual.screen_x = crossing_train.screen_x
	crossing_commands_visual.screen_y = crossing_train.screen_y
	crossing_commands_visual.elevation = crossing_train.elevation
	crossing_commands_visual.tornado = false
	crossing_commands_visual.monster = false
	var crossing_commands := IsometricRenderer.moving_thing_draw_commands_for_visual(
		starter, large, crossing_commands_visual, IsometricRenderer.view_configuration(IsometricRenderer.VIEW_LARGE)
	)
	_check(
		crossing_commands.size() == 1
		and crossing_commands[0].train
		and crossing_commands[0].same_tile_foreground_indices.is_empty(),
		"Train commands request the dedicated power-line foreground mask",
	)
	_check(
		IsometricStaticOcclusion.train_power_foreground_reference_sprite_id(0x0e) == -1
		and IsometricStaticOcclusion.train_power_foreground_reference_sprite_id(0x48) == 1045
		and IsometricStaticOcclusion.train_power_foreground_reference_sprite_id(0x2d) == 0,
		"Power lines and crossovers select their train foreground source",
	)
	var crossing_foreground_command: CityStaticCommand
	var crossing_depth := (64 + 64) * CityState.MAP_SIZE + 64

	for command in IsometricRenderer.static_occlusion_commands(starter, large):
		if int(command.sprite_id) == 1072 and int(command.depth_order) == crossing_depth:
			crossing_foreground_command = command
			break

	_check(
		crossing_foreground_command != null
		and crossing_foreground_command.train_foreground_reference_sprite_id
			== 1045,
		"Static rail-power crossover commands retain the rail-only reference",
	)
	var index_palette := Palette.index_encoding()
	var crossing_terrain: Image = large.find_sprite(1256).create_image(index_palette).image
	var crossing_surface: Image = large.find_sprite(1072).create_image(index_palette).image
	var crossing_rail: Image = large.find_sprite(1045).create_image(index_palette).image
	var crossing_foreground := IsometricRenderer.foreground_difference_mask(
		crossing_surface, crossing_rail
	)
	var crossing_train_image: Image = (
		large.find_sprite(crossing_train.sprite_id).create_image(index_palette).image.duplicate()
	)

	if crossing_train.flip:
		crossing_train_image.flip_x()

	var crossing_height := maxi(
		crossing_terrain.get_height(),
		maxi(crossing_surface.get_height(), crossing_train_image.get_height()),
	)
	var crossing_fixture := Image.create(
		32, crossing_height, false, Image.FORMAT_RGBA8
	)
	crossing_fixture.fill(Color.TRANSPARENT)
	crossing_fixture.blend_rect(
		crossing_terrain,
		Rect2i(Vector2i.ZERO, crossing_terrain.get_size()),
		Vector2i(0, crossing_height - crossing_terrain.get_height()),
	)
	crossing_fixture.blend_rect(
		crossing_surface,
		Rect2i(Vector2i.ZERO, crossing_surface.get_size()),
		Vector2i(0, crossing_height - crossing_surface.get_height()),
	)
	var crossing_train_position := Vector2i(
		16 + crossing_train.screen_x - int(crossing_train_image.get_width() / 2),
		crossing_height + crossing_train.screen_y - crossing_train_image.get_height(),
	)
	var crossing_surface_position := Vector2i(
		0, crossing_height - crossing_surface.get_height()
	)
	var crossing_train_foreground := Image.create(
		crossing_train_image.get_width(), crossing_train_image.get_height(),
		false, Image.FORMAT_RGBA8
	)
	crossing_train_foreground.fill(Color.TRANSPARENT)
	crossing_train_foreground.blend_rect(
		crossing_foreground,
		Rect2i(Vector2i.ZERO, crossing_foreground.get_size()),
		crossing_surface_position - crossing_train_position,
	)
	var actual_crossing_mask := IsometricRenderer.occlude_dynamic_with_mask(
		crossing_train_image,
		crossing_train_foreground,
		crossing_train_position,
	)
	var crossing_composite: Image = crossing_fixture.duplicate()
	crossing_composite.blend_rect(
		actual_crossing_mask.image,
		Rect2i(Vector2i.ZERO, actual_crossing_mask.image.get_size()),
		crossing_train_position,
	)
	var foreground_overlap := 0
	var foreground_preserved := 0
	var rail_deck_replaced := 0

	for train_y in crossing_train_image.get_height():
		for train_x in crossing_train_image.get_width():
			if crossing_train_image.get_pixel(train_x, train_y).a == 0.0:
				continue

			var map_point := crossing_train_position + Vector2i(train_x, train_y)

			if not Rect2i(Vector2i.ZERO, crossing_fixture.get_size()).has_point(map_point):
				continue

			var static_index := roundi(crossing_fixture.get_pixelv(map_point).r * 255.0)

			if crossing_train_foreground.get_pixel(train_x, train_y).a > 0.0:
				foreground_overlap += 1

				if (
					crossing_composite.get_pixelv(map_point).to_rgba32()
					== crossing_fixture.get_pixelv(map_point).to_rgba32()
				):
					foreground_preserved += 1
			elif (
				static_index in [0xa0, 0x7c]
				and crossing_composite.get_pixelv(map_point).to_rgba32()
				!= crossing_fixture.get_pixelv(map_point).to_rgba32()
			):
				rail_deck_replaced += 1

	_check(
		foreground_overlap > 0
		and foreground_preserved == foreground_overlap
		and rail_deck_replaced > 0
		and actual_crossing_mask.occluded_pixels == foreground_overlap,
		"The train draws over the rail deck but stays behind the full power-line foreground",
	)
	_check(starter.set_building_id(64, 64, Tiles.RAIL_JUNCTION_1), "Train drawing fixture adds a turn tile")
	var turning_train := IsometricRenderer.train_sprite(starter, 64, 64, ThingRecord.from_fields({
		"type": 11, "dx": 1,
	}))
	_check(
		turning_train.variant == 17 and turning_train.sprite_id == 1375,
		"Train view uses the saved transition on a turn tile",
	)
	_check(
		turning_train.screen_y == 6 and not turning_train.flip,
		"Train view applies the recovered turn position and mirror",
	)
	_check(starter.set_building_id(64, 64, Tiles.RAIL_BRIDGE), "Train drawing fixture adds a tunnel tile")
	_check(starter.set_tile_flag(64, 64, 0x02, true), "Train drawing fixture mirrors the tunnel")
	var tunnel_train := IsometricRenderer.train_sprite(starter, 64, 64, ThingRecord.from_fields({
		"type": 10, "dx": 0,
	}))
	_check(
		tunnel_train.variant == 1 and tunnel_train.elevation == 12,
		"Tunnel train view uses the water level, raised track, and flip flag",
	)
	var tornado_visual := IsometricRenderer.tornado_sprite(starter, 64, 64, ThingRecord.from_fields({
		"type": 15, "px": 8, "py": 8,
	}), 1)
	_check(
		tornado_visual.sprite_id == 1498
		and tornado_visual.flip
		and tornado_visual.tornado,
		"Tornado view selects a stable recovered frame and mirror",
	)
	var small_tornado := IsometricRenderer.tornado_sprite(starter, 64, 64, ThingRecord.from_fields({
		"type": 15, "px": 8, "py": 8,
	}), 1, IsometricRenderer.VIEW_SMALL)
	_check(
		small_tornado.sprite_id == 498
		and small_tornado.elevation == 0
		and small_tornado.flip,
		"Tornado view selects its native small frame and altitude scale",
	)
	_check(
		IsometricGeometry.bridge_effect_position(starter, EffectEvent.new(Vector2i(64, 64), 0, Vector2i(16, -8)), 10) == Vector2i(2096, 1518),
		"Bridge debris view uses water altitude and the recovered screen offset",
	)
	var default_effect_position := IsometricRenderer.transient_effect_position(
		starter, EffectEvent.new(Vector2i(64, 64)), 10
	)
	var raised_effect_position := IsometricRenderer.transient_effect_position(
		starter,
		EffectEvent.new(Vector2i(64, 64), 0, Vector2i.ZERO, false, 0,
			starter.water_altitude(64, 64) + 2),
		10
	)
	_check(
		raised_effect_position == default_effect_position + Vector2i(0, -24),
		"Transient effects can preserve their pre-demolition altitude",
	)
	_check(
		IsometricRenderer.effect_sprite_id(1392, IsometricRenderer.VIEW_SMALL) == 392
		and IsometricRenderer.effect_sprite_id(1392, IsometricRenderer.VIEW_MEDIUM) == 892
		and IsometricRenderer.effect_sprite_id(1392, IsometricRenderer.VIEW_LARGE) == 1392,
		"Bridge debris selects its native sprite at each zoom",
	)
	var small_debris := small_medium.find_sprite(392)
	var small_debris_height := small_debris.height if small_debris != null else -1
	var small_debris_position := IsometricGeometry.bridge_effect_position(
		starter,
		EffectEvent.new(Vector2i(64, 64), 0, Vector2i(16, -8)),
		small_debris_height,
		IsometricRenderer.VIEW_SMALL
	)
	_check(
		small_debris != null
		and small_debris_position == Vector2i(524, 382 - small_debris.height),
		"Small bridge debris scales its tile anchor and recovered offset",
	)
	var medium_debris := small_medium.find_sprite(892)
	var medium_debris_height := medium_debris.height if medium_debris != null else -1
	var medium_debris_position := IsometricGeometry.bridge_effect_position(
		starter,
		EffectEvent.new(Vector2i(64, 64), 0, Vector2i(16, -8)),
		medium_debris_height,
		IsometricRenderer.VIEW_MEDIUM
	)
	_check(
		medium_debris != null
		and medium_debris_position == Vector2i(1048, 764 - medium_debris.height),
		"Medium bridge debris scales its tile anchor and recovered offset",
	)
	var monster_layers := IsometricMovingVisuals.monster_layers(starter, 64, 64, ThingRecord.from_fields({
		"type": 5,
		"z": 10,
		"px": 8,
		"py": 8,
		"dx": 0xa5,
		"dy": 0x9b,
	}), 1)
	_check(monster_layers.size() == 15, "Monster view builds all composite sprite layers")
	_check(
		monster_layers[0].sprite_id == 1483
		and monster_layers[0].screen_x == -95
		and monster_layers[0].screen_y == 924
		and not monster_layers[0].flip,
		"Monster view positions the left upper outer layer",
	)
	_check(
		monster_layers[3].sprite_id == 1483
		and monster_layers[3].screen_x == 73
		and monster_layers[3].screen_y == 878
		and monster_layers[3].flip,
		"Monster view mirrors and positions the right upper outer layer",
	)
	_check(
		monster_layers[6].sprite_id == 1385
		and monster_layers[6].screen_x == -2
		and monster_layers[6].screen_y == 886,
		"Monster DX effect bit inserts the recovered effect sprite",
	)
	_check(
		monster_layers[7].sprite_id == 1491
		and monster_layers[7].screen_x == -48
		and monster_layers[7].screen_y == 794,
		"Monster DY effect bit selects a stable alternate head",
	)
	_check(
		monster_layers[14].sprite_id == 1488
		and monster_layers[14].screen_x == 12
		and monster_layers[14].screen_y == 932
		and monster_layers[14].flip,
		"Monster view mirrors and positions the right lower outer layer",
	)
	var ordinary_monster := ThingRecord.from_fields({
		"type": 5, "z": 10, "dx": 0x25, "dy": 0x1b,
	})
	for view_size in [IsometricRenderer.VIEW_SMALL, IsometricRenderer.VIEW_MEDIUM, IsometricRenderer.VIEW_LARGE]:
		var head_base: int = 490 + view_size * 500
		for phase in [0, 19, 20, 39, 40]:
			var eye_layers := IsometricMovingVisuals.monster_layers(
				starter, 64, 64, ordinary_monster, 1, view_size, phase
			)
			var expected_head := head_base + (1 if phase >= 20 and phase < 40 else 0)
			_check(
				eye_layers[6].sprite_id == expected_head
				and eye_layers[7].sprite_id == expected_head
				and not eye_layers[6].flip and eye_layers[7].flip,
				"Monster eye opens and closes at every source size without the unused DY flag",
			)
	_check(ordinary_monster.dx == 0x25 and ordinary_monster.dy == 0x1b,
		"Monster eye animation preserves saved pose bytes")
	var small_monster_layers := IsometricMovingVisuals.monster_layers(starter, 64, 64, ThingRecord.from_fields({
		"type": 5,
		"z": 10,
		"px": 8,
		"py": 8,
		"dx": 0xa5,
		"dy": 0x9b,
	}), 1, IsometricRenderer.VIEW_SMALL)
	_check(
		small_monster_layers.size() == 15,
		"Small monster view keeps every composite layer",
	)
	_check(
		small_monster_layers[0].sprite_id == 483
		and small_monster_layers[0].screen_x == -23
		and small_monster_layers[0].screen_y == 231,
		"Small monster view uses native sprites and signed quarter-scale offsets",
	)
	_check(
		small_monster_layers[6].sprite_id == 385
		and small_monster_layers[7].sprite_id == 491,
		"Small monster view scales the effect and alternate head sprites",
	)
