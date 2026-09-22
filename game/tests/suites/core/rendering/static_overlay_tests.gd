extends "res://tests/support/core_test_suite.gd"

## Rendering: static overlay checks.

@warning_ignore_start("integer_division")

const Palette = preload("res://src/assets/sc2_palette.gd")
const IsometricRenderer = preload("res://src/view/city_isometric_renderer.gd")
const Power = preload("res://src/simulation/infrastructure/power_phase.gd")
const Traffic = preload("res://src/simulation/infrastructure/traffic_phase.gd")


func run(reference_root: String, large: Sc2SpriteArchive) -> void:
	var overlay_document := _load_fixture(reference_root.path_join("CITIES/STARTER.SC2"))
	var overlay_city := CityModel.from_document(overlay_document)
	var overlay_point := Vector2i(64, 64)
	var traffic_index := 32 * CityModel.COARSE_MAP_SIZE + 32
	var traffic_data: PackedByteArray = (
		overlay_document.find_chunk("XTRF").decoded_payload.duplicate()
	)
	_check(
		overlay_city.set_building_id(overlay_point.x, overlay_point.y, Tiles.ROAD_STRAIGHT_1),
		"Traffic view fixture installs a straight road",
	)
	traffic_data[traffic_index] = 85
	_check(
		overlay_document.find_chunk("XTRF").set_decoded_payload(traffic_data),
		"Traffic view fixture stores the first threshold",
	)
	_check(
		overlay_city.traffic_density(overlay_point.x, overlay_point.y) == 85,
		"City model reads the shared 64 by 64 traffic cell",
	)
	_check(
		IsometricStaticVisuals.traffic_overlay_visual(
			overlay_city, overlay_point.x, overlay_point.y
		) == null,
		"Normal road traffic does not draw at density 85",
	)
	traffic_data[traffic_index] = 86
	_check(
		overlay_document.find_chunk("XTRF").set_decoded_payload(traffic_data),
		"Traffic view fixture crosses the first threshold",
	)
	var low_traffic := IsometricStaticVisuals.traffic_overlay_visual(
		overlay_city, overlay_point.x, overlay_point.y
	)
	_check(
		low_traffic.sprite_id == 1400
		and low_traffic.variant == 1
		and not low_traffic.flip,
		"Normal road traffic selects the recovered low-density large sprite",
	)
	var traffic_base := Image.create(2, 1, false, Image.FORMAT_RGBA8)
	traffic_base.set_pixel(0, 0, Color8(0xa1, 0xa1, 0xa1, 255))
	traffic_base.set_pixel(1, 0, Color8(0xa0, 0xa0, 0xa0, 255))
	var traffic_pixels := Image.create(2, 1, false, Image.FORMAT_RGBA8)
	traffic_pixels.fill(Color8(0xc8, 0xc8, 0xc8, 255))
	var masked_traffic := IsometricPixelOperations._traffic_masked_image(
		traffic_pixels, traffic_base, Palette.index_encoding()
	)
	_check(
		masked_traffic.get_pixel(0, 0).a == 1.0
		and masked_traffic.get_pixel(1, 0).a == 0.0,
		"Traffic pixels replace only the recovered road-deck palette index",
	)
	_check(
		IsometricStaticVisuals.traffic_overlay_visual(
			overlay_city, overlay_point.x, overlay_point.y, IsometricRenderer.VIEW_MEDIUM
		).sprite_id == 900,
		"Medium traffic uses its native sprite set",
	)
	_check(
		IsometricStaticVisuals.traffic_overlay_visual(
			overlay_city, overlay_point.x, overlay_point.y, IsometricRenderer.VIEW_SMALL
		).sprite_id == 400,
		"Small traffic uses its native sprite set",
	)
	traffic_data[traffic_index] = 171
	_check(
		overlay_document.find_chunk("XTRF").set_decoded_payload(traffic_data),
		"Traffic view fixture crosses the second threshold",
	)
	_check(
		IsometricStaticVisuals.traffic_overlay_visual(
			overlay_city, overlay_point.x, overlay_point.y
		).sprite_id == 1427,
		"Normal road traffic selects the recovered high-density variant",
	)
	_check(
		IsometricStaticVisuals.traffic_overlay_visual(
			overlay_city, overlay_point.x, overlay_point.y, IsometricRenderer.VIEW_SMALL
		) == null,
		"Small view omits high-density variants absent from its source archive",
	)
	_check(
		overlay_city.set_building_id(overlay_point.x, overlay_point.y, Tiles.POWER_LINE_STRAIGHT_1),
		"Traffic exclusion fixture installs a power line",
	)
	_check(
		IsometricStaticVisuals.traffic_overlay_visual(
			overlay_city, overlay_point.x, overlay_point.y
		) == null,
		"Busy traffic cells do not draw traffic sprites on power lines",
	)
	_check(
		overlay_city.set_building_id(overlay_point.x, overlay_point.y, Tiles.HIGHWAY_STRAIGHT_1),
		"Traffic view fixture installs a highway",
	)
	traffic_data[traffic_index] = 29
	_check(
		overlay_document.find_chunk("XTRF").set_decoded_payload(traffic_data),
		"Traffic view fixture crosses the highway threshold",
	)
	_check(
		IsometricStaticVisuals.traffic_overlay_visual(
			overlay_city, overlay_point.x, overlay_point.y
		).sprite_id == 1410,
		"Highway traffic uses the recovered lower threshold and lane sprite",
	)
	traffic_data[traffic_index] = 57
	_check(
		overlay_document.find_chunk("XTRF").set_decoded_payload(traffic_data),
		"Traffic view fixture crosses the second highway threshold",
	)
	_check(
		IsometricStaticVisuals.traffic_overlay_visual(
			overlay_city, overlay_point.x, overlay_point.y
		).sprite_id == 1437,
		"Highway traffic selects the recovered high-density lane sprite",
	)
	_check(
		overlay_city.set_building_id(overlay_point.x, overlay_point.y, Tiles.HIGHWAY_SLOPE_1),
		"Traffic view fixture installs an elevated highway",
	)
	traffic_data[traffic_index] = 29
	_check(
		overlay_document.find_chunk("XTRF").set_decoded_payload(traffic_data),
		"Traffic view fixture restores the first highway threshold",
	)
	_check(
		IsometricStaticVisuals.traffic_overlay_visual(
			overlay_city, overlay_point.x, overlay_point.y
		) != null,
		"Elevated highway traffic uses the recovered lower threshold",
	)
	_check(
		overlay_city.set_building_corners(overlay_point.x, overlay_point.y, 0),
		"Highway coverage fixture clears zone anchor bits",
	)
	_check(
		not IsometricStaticVisuals._should_draw_building(
			overlay_city, overlay_point.x, overlay_point.y, Tiles.HIGHWAY_SLOPE_1
		),
		"Elevated highway waits for its compass-selected anchor",
	)
	_check(
		IsometricStaticVisuals._should_draw_building(
			overlay_city, overlay_point.x, overlay_point.y, Tiles.RAIL_SUBWAY_ENTRANCE_1
		),
		"Subway-to-rail tiles draw without zone anchor bits",
	)
	var compass_masks := [0x80, 0x10, 0x20, 0x40]
	_check(
		overlay_city.set_building_corners(
			overlay_point.x, overlay_point.y,
			compass_masks[overlay_city.compass_rotation()]
		),
		"Highway coverage fixture sets the active anchor bit",
	)
	_check(
		IsometricStaticVisuals._should_draw_building(
			overlay_city, overlay_point.x, overlay_point.y, Tiles.HIGHWAY_SLOPE_1
		),
		"Elevated highway draws from its compass-selected anchor",
	)
	var highway_ground := IsometricStaticVisuals.highway_ground_visuals(
		overlay_city, overlay_point.x, overlay_point.y
	)
	_check(
		highway_ground.size() == 4
		and highway_ground[0].source == Vector2i(64, 64)
		and highway_ground[1].source == Vector2i(64, 63)
		and highway_ground[2].source == Vector2i(65, 63)
		and highway_ground[3].source == Vector2i(65, 64)
		and highway_ground[3].offset == Vector2i(16, 8),
		"Elevated highway redraws the recovered four-cell ground diamond",
	)
	var small_highway_ground := IsometricStaticVisuals.highway_ground_visuals(
		overlay_city, overlay_point.x, overlay_point.y, IsometricRenderer.VIEW_SMALL
	)
	_check(
		small_highway_ground.is_empty(),
		"Small elevated highways omit the large and medium ground-redraw pass",
	)
	_check(
		IsometricStaticVisuals.highway_ground_visuals(overlay_city, 127, 0).size() == 1
		and IsometricStaticVisuals.highway_ground_visuals(overlay_city, 64, 0).size() == 2
		and IsometricStaticVisuals.highway_ground_visuals(overlay_city, 127, 64).size() == 2,
		"Malformed edge highway anchors clip ground reads to valid map cells",
	)
	_check(
		overlay_document.set_misc_u32(0x0008, 3),
		"Network orientation fixture sets an odd compass rotation",
	)
	_check(
		overlay_city.set_tile_flag(overlay_point.x, overlay_point.y, 0x02, false),
		"Network orientation fixture clears the saved mirror",
	)
	_check(
		not IsometricStaticVisuals.building_sprite_flip(
			overlay_city, overlay_point.x, overlay_point.y, 0x1d
		),
		"Compass rotation does not add a mirror to a network sprite",
	)
	_check(
		IsometricStaticVisuals.building_sprite_flip(
			overlay_city, overlay_point.x, overlay_point.y, 0x70
		),
		"Odd compass rotation adds the original mirror to a building sprite",
	)
	_check(
		overlay_city.set_tile_flag(overlay_point.x, overlay_point.y, 0x02, true),
		"Network orientation fixture sets the saved mirror",
	)
	_check(
		IsometricStaticVisuals.building_sprite_flip(
			overlay_city, overlay_point.x, overlay_point.y, 0x2c
		)
		and not IsometricStaticVisuals.building_sprite_flip(
			overlay_city, overlay_point.x, overlay_point.y, 0x70
		),
		"Saved mirror stays direct for rail and combines with compass for buildings",
	)
	_check(
		IsometricRenderer.building_baseline_offset(Tiles.ROAD_STRAIGHT_1, 0x0d, 32) == -12
		and IsometricRenderer.building_baseline_offset(Tiles.ROAD_STRAIGHT_1, 0x00, 32) == 0,
		"A network on terrain shape 0x0d uses the recovered raised baseline",
	)
	_check(
		IsometricRenderer.building_baseline_offset(Tiles.LOWER_CLASS_HOMES_1X1_1, 0x00, 128) == 24
		and IsometricRenderer.building_baseline_offset(
			Tiles.LOWER_CLASS_HOMES_1X1_1, 0x00, 64, IsometricRenderer.VIEW_MEDIUM
		) == 12
		and IsometricRenderer.building_baseline_offset(
			Tiles.LOWER_CLASS_HOMES_1X1_1, 0x00, 32, IsometricRenderer.VIEW_SMALL
		) == 6,
		"Large footprints use the native quarter-width baseline at every zoom",
	)
	_check(
		overlay_city.set_building_id(overlay_point.x, overlay_point.y, Tiles.LOWER_CLASS_HOMES_1X1_1),
		"Power-marker fixture installs a zone building",
	)
	_check(
		overlay_city.set_tile_flag(overlay_point.x, overlay_point.y, 0x80, true),
		"Power-marker fixture marks the building as powerable",
	)
	_check(
		overlay_city.set_tile_flag(overlay_point.x, overlay_point.y, 0x40, false),
		"Power-marker fixture clears the powered flag",
	)
	_check(
		IsometricStaticVisuals.power_marker_visual(
			overlay_city, overlay_point.x, overlay_point.y
		).sprite_id == 1386,
		"Unpowered zone building selects the recovered large marker",
	)
	_check(
		IsometricStaticVisuals.power_marker_visual(
			overlay_city, overlay_point.x, overlay_point.y, IsometricRenderer.VIEW_SMALL
		).sprite_id == 386,
		"Small view selects its native unpowered marker",
	)
	_check(
		overlay_city.set_tile_flag(overlay_point.x, overlay_point.y, 0x40, true),
		"Power-marker fixture sets the powered flag",
	)
	_check(
		IsometricStaticVisuals.power_marker_visual(
			overlay_city, overlay_point.x, overlay_point.y
		) == null,
		"Powered zone building does not draw an unpowered marker",
	)
	_check(
		overlay_city.set_text_overlay_id(overlay_point.x, overlay_point.y, 0xff),
		"Fire view fixture installs the fire marker",
	)
	_check(
		overlay_city.set_tile_flag(overlay_point.x, overlay_point.y, 0x04, false),
		"Fire view fixture uses a land tile",
	)
	var fire_visual := IsometricStaticVisuals.fire_overlay_visual(
		overlay_city, overlay_point.x, overlay_point.y, IsometricRenderer.VIEW_LARGE, 3
	)
	_check(
		fire_visual.sprite_id >= 1396 and fire_visual.sprite_id <= 1399,
		"Fire view selects a native large frame from its visual phase",
	)
	var fire_command := IsometricDynamicCommands.special_overlay_draw_command(
		overlay_city,
		large,
		overlay_point,
		fire_visual,
		IsometricRenderer.view_configuration(IsometricRenderer.VIEW_LARGE),
	)
	_check(
		fire_command.static_occlusion,
		"Foreground buildings occlude dynamic fire markers",
	)
	var flipped_fire := IsometricStaticVisuals.fire_overlay_visual(
		overlay_city, overlay_point.x, overlay_point.y, IsometricRenderer.VIEW_LARGE, 4
	)
	_check(
		flipped_fire.sprite_id == 1396 + (int(fire_visual.sprite_id) - 1396 + 1) % 4,
		"Fire advances to the next native frame",
	)
	var fire_frames := {}
	var fire_differences := {}
	var previous_frame := -1

	for fire_x in range(32, 64):
		var original_overlay := overlay_city.text_overlay_id(fire_x, overlay_point.y)
		var original_water := overlay_city.is_water(fire_x, overlay_point.y)
		overlay_city.set_text_overlay_id(fire_x, overlay_point.y, 0xff)
		overlay_city.set_tile_flag(fire_x, overlay_point.y, 0x04, false)
		var visual := IsometricStaticVisuals.fire_overlay_visual(overlay_city, fire_x, overlay_point.y)
		fire_frames[visual.sprite_id] = true
		var repeated := IsometricStaticVisuals.fire_overlay_visual(overlay_city, fire_x, overlay_point.y)
		_check(visual.sprite_id == repeated.sprite_id and visual.flip == repeated.flip and visual.overlay == repeated.overlay,
			"Fire animation is stable for the same tile and display time")
		overlay_city.set_text_overlay_id(fire_x, overlay_point.y, original_overlay)
		overlay_city.set_tile_flag(fire_x, overlay_point.y, 0x04, original_water)

		if previous_frame >= 0:
			fire_differences[(int(visual.sprite_id) - previous_frame + 4) % 4] = true

		previous_frame = int(visual.sprite_id)

	_check(fire_frames.size() == 4 and fire_differences.size() == 4,
		"Adjacent fires use varied phases instead of a constant wave step")
	_check(
		overlay_city.set_tile_flag(overlay_point.x, overlay_point.y, 0x04, true),
		"Fire view fixture changes to a water tile",
	)
	_check(
		IsometricStaticVisuals.fire_overlay_visual(
			overlay_city, overlay_point.x, overlay_point.y
		) == null,
		"Fire does not draw on a saved water tile",
	)
	_check(
		overlay_city.set_text_overlay_id(overlay_point.x, overlay_point.y, 0xfb),
		"Special-overlay fixture installs marker 0xfb",
	)
	_check(
		IsometricStaticVisuals.special_overlay_visual(
			overlay_city, overlay_point.x, overlay_point.y
		).sprite_id == 1496,
		"Special marker 0xfb uses its recovered large sprite on water",
	)
	_check(
		overlay_city.set_text_overlay_id(overlay_point.x, overlay_point.y, 0xfc),
		"Special-overlay fixture installs marker 0xfc",
	)
	_check(
		IsometricStaticVisuals.special_overlay_visual(
			overlay_city, overlay_point.x, overlay_point.y,
			IsometricRenderer.VIEW_MEDIUM
		).sprite_id == 992,
		"Special marker 0xfc uses its native medium sprite on water",
	)
	_check(
		overlay_city.set_text_overlay_id(overlay_point.x, overlay_point.y, 0xfd),
		"Special-overlay fixture installs marker 0xfd",
	)
	_check(
		IsometricStaticVisuals.special_overlay_visual(
			overlay_city, overlay_point.x, overlay_point.y
		) == null,
		"Special marker 0xfd does not draw on a saved water tile",
	)
	_check(
		overlay_city.set_tile_flag(overlay_point.x, overlay_point.y, 0x04, false),
		"Special-overlay fixture changes back to dry land",
	)
	var launch_effect := IsometricStaticVisuals.special_overlay_visual(
		overlay_city, overlay_point.x, overlay_point.y,
		IsometricRenderer.VIEW_LARGE, 1
	)
	_check(
		launch_effect.sprite_id == 1494 and launch_effect.overlay == 0xfd,
		"Special marker 0xfd selects one of the recovered two-frame effects",
	)
	_check(
		overlay_city.set_text_overlay_id(overlay_point.x, overlay_point.y, 0xfe),
		"Special-overlay fixture installs marker 0xfe",
	)
	_check(
		IsometricStaticVisuals.special_overlay_visual(
			overlay_city, overlay_point.x, overlay_point.y,
			IsometricRenderer.VIEW_SMALL, 0
		).sprite_id == 493,
		"Special marker 0xfe uses its native small effect frame",
	)
	var edge_point := Vector2i(127, 64)
	_check(
		overlay_city.set_land_altitude(edge_point.x, edge_point.y, 3),
		"Edge-stack fixture sets three land levels",
	)
	var land_edges := IsometricStaticVisuals.edge_stack_visuals(
		overlay_city, edge_point.x, edge_point.y
	)
	_check(
		land_edges.size() == 3
		and land_edges[0].sprite_id == 1269
		and land_edges[0].elevation == 0
		and land_edges[2].elevation == 24,
		"Large map edge repeats the land-side sprite at 12-pixel steps",
	)
	_check(
		overlay_city.set_water_altitude(edge_point.x, edge_point.y, 5),
		"Edge-stack fixture sets five water levels",
	)
	_check(
		overlay_city.set_tile_flag(edge_point.x, edge_point.y, 0x04, true),
		"Edge-stack fixture marks the edge as water",
	)
	var water_edges := IsometricStaticVisuals.edge_stack_visuals(
		overlay_city, edge_point.x, edge_point.y
	)
	_check(
		water_edges.size() == 5
		and water_edges[3].sprite_id == 1284
		and water_edges[3].elevation == 36
		and water_edges[4].sprite_id == 1284,
		"Large map edge adds water-side sprites above the land stack",
	)
	var small_edges := IsometricStaticVisuals.edge_stack_visuals(
		overlay_city, edge_point.x, edge_point.y, IsometricRenderer.VIEW_SMALL
	)
	_check(
		small_edges.size() == 5
		and small_edges[0].sprite_id == 269
		and small_edges[4].sprite_id == 284
		and small_edges[4].elevation == 12,
		"Small map edge uses native side sprites at three-pixel steps",
	)
	_check(
		IsometricStaticVisuals.edge_stack_visuals(
			overlay_city, 126, 64, IsometricRenderer.VIEW_LARGE
		).is_empty(),
		"Interior tiles do not draw map-edge stacks",
	)
