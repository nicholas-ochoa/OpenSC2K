extends SceneTree
## Debug view rules without the application: the tile layer catalog, color
## tables and values, native network labels and tile differences, tile windows,
## the Tile Inspector text, the Debug menu and the saved debug mode choice.

const Layer = DebugTileLayers.Layer


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_catalog()
	var city := CityState.from_document(EmptyCityTemplate.create(16))
	_values(city)
	_networks()
	_differences(city)
	_windows(city)
	_inspection(city)
	_menu()
	_settings()
	print("PASS: debug layers, values, networks, tile differences, windows, inspection, menu and debug mode setting")
	quit()


func _catalog() -> void:
	var listed: Array = []

	for group in DebugTileLayers.GROUPS:
		listed.append_array(group[1])

	for layer: Layer in Layer.values():
		if layer == Layer.NONE:
			continue

		assert(listed.count(layer) == 1, "Layer %d is in one menu group" % layer)
		assert(not DebugTileLayers.title(layer).is_empty())
		assert(not DebugTileLayers.source_chunks(layer).is_empty() or DebugTileLayers.kind(layer) == DebugTileLayers.Kind.FLAG,
			"Layer %d names its source chunks" % layer)
		assert(not DebugLayerColors.legend(layer).is_empty(), "Layer %d has a key" % layer)
		var table := DebugLayerColors.table(layer)
		assert(table.get_width() == 256 and table.get_format() == Image.FORMAT_RGBA8)

	# value zero leaves the city visible in raw, flag, data map and analysis layers
	for layer in [Layer.BUILDING_ID, Layer.POWERED, Layer.TRAFFIC, Layer.POWER_GRIDS, Layer.UNUSUAL_VALUES, Layer.CHANGED_TILES,
			Layer.ZONE_TYPE]:
		assert(DebugLayerColors.color(layer, 0).a == 0.0, "Layer %d clears value zero" % layer)

	# the zone table masks the building corners
	assert(DebugLayerColors.color(Layer.ZONE_TYPE, 0x13) == DebugLayerColors.color(Layer.ZONE_TYPE, 0x03))
	assert(DebugLayerColors.color(Layer.ZONE_TYPE, 0x0c) == DebugLayerColors.UNKNOWN)
	assert(DebugLayerColors.color(Layer.POWERED, Sc2TileFlags.POWERED | Sc2TileFlags.WATER).a > 0.0)
	assert(DebugLayerColors.color(Layer.POWERED, Sc2TileFlags.POWERABLE).a == 0.0)
	assert(DebugLayerColors.color(Layer.LAND_ALTITUDE, 40) == DebugLayerColors.UNKNOWN)
	# a tile with several changes shows its lowest bit
	assert(DebugLayerColors.color(Layer.CHANGED_TILES, 0x41) == DebugLayerColors.CHANGE_COLORS[0])
	assert(DebugTileLayers.describe(Layer.CHANGED_TILES, 0x41) == "Building, Flags")
	assert(DebugTileLayers.describe(Layer.ZONE_TYPE, 0x23).begins_with("Light commercial (3), corners 0x2"))
	assert(DebugTileLayers.describe(Layer.POWERED, 0) == "Clear")
	assert(DebugTileLayers.describe(Layer.BUILDING_ID, -1) == "No value")


func _values(city: CityState) -> void:
	city.set_building_id(5, 6, 0x2b)
	# the zone layer keeps the corner bits; its color table masks them
	var zone_source := DebugLayerValues.source(city, Layer.ZONE_TYPE)
	var zone_bytes: PackedByteArray = zone_source.zones.duplicate()
	zone_bytes[city.index_of(3, 4)] = 0x15
	zone_source.zones = zone_bytes
	var zones := DebugLayerValues.build(zone_source, Layer.ZONE_TYPE)
	assert(zones.edge == 16 and zones.image.get_size() == Vector2i(16, 16) and zones.image.get_format() == Image.FORMAT_R8)
	assert(DebugLayerValues.value_at(zones, 16, Vector2i(3, 4)) == 0x15)
	assert(DebugLayerValues.value_at(zones, 16, Vector2i(16, 0)) == -1)
	var buildings := DebugLayerValues.build(DebugLayerValues.source(city, Layer.BUILDING_ID), Layer.BUILDING_ID)
	assert(DebugLayerValues.value_at(buildings, 16, Vector2i(5, 6)) == 0x2b)

	# a coarse data map keeps its size; each value covers its cell of tiles
	var chunk := city.document.find_chunk("XPLT")
	var coarse := PackedByteArray()
	coarse.resize(8 * 8)
	coarse[1 * 8 + 2] = 77
	chunk.set_decoded_payload(coarse)
	var pollution := DebugLayerValues.build(DebugLayerValues.source(city, Layer.POLLUTION), Layer.POLLUTION)
	assert(pollution.edge == 8)
	assert(DebugLayerValues.value_at(pollution, 16, Vector2i(3, 5)) == 77)
	assert(DebugLayerValues.value_at(pollution, 16, Vector2i(4, 5)) == 0)

	var words := city.altitude_words
	words[0] = 5 | (7 << Sc2AltitudeLayout.WATER_SHIFT) | (3 << Sc2AltitudeLayout.TUNNEL_SHIFT)
	var source := { "edge": 16, "flags": city.tile_flags, "altitude": words }
	assert(DebugLayerValues.build(source, Layer.LAND_ALTITUDE).values[0] == 5)
	assert(DebugLayerValues.build(source, Layer.WATER_ALTITUDE).values[0] == 7)
	assert(DebugLayerValues.build(source, Layer.TUNNEL_LEVELS).values[0] == 3)

	# a missing input gives a clear layer of map size, not an error
	var missing := DebugLayerValues.build({ "edge": 16, "flags": PackedByteArray() }, Layer.POWERED)
	assert(missing.edge == 16 and missing.values.count(0) == 256)
	city.set_building_id(5, 6, 0)

	var flags := city.tile_flags.duplicate()
	flags[0] = Sc2TileFlags.MARK
	var unusual := NativeDebugTiles.unusual_values(city.zones, city.terrain, city.underground, flags)
	assert(unusual[0] == NativeDebugTiles.UNUSUAL_MARK and unusual.count(0) == 255)


func _networks() -> void:
	# two power lines on a 4 x 4 map. only the second one holds a powered tile
	var flags := PackedByteArray()
	flags.resize(16)

	for index in [0, 1, 2]:
		flags[index] = Sc2TileFlags.POWERABLE

	flags[10] = Sc2TileFlags.POWERABLE | Sc2TileFlags.POWERED
	flags[14] = Sc2TileFlags.POWERABLE
	var result := DebugLayerValues.build({ "edge": 4, "flags": flags }, Layer.POWER_GRIDS)
	assert(result.summary == "2 networks, 1 supplied, largest 3 tiles", result.summary)
	assert(result.values[0] == result.values[2] and result.values[0] < NativeDebugTiles.SUPPLIED_BASE)
	assert(result.values[10] == result.values[14] and result.values[10] > NativeDebugTiles.SUPPLIED_BASE)
	assert(result.values[3] == 0)


func _differences(city: CityState) -> void:
	var before := NativeTileSnapshot.new()
	assert(before.is_empty())
	before.capture(ApplicationDebugTileViews.tiles(city))
	assert(not before.is_empty() and before.edge() == 16)
	var after := CityState.copy_for_edit(city)
	after.set_building_id(2, 3, 0x0e)
	after.set_tile_flag(2, 3, Sc2TileFlags.POWERED, true)
	after.set_tile_flag(4, 4, Sc2TileFlags.MARK, true)
	var difference := before.difference(ApplicationDebugTileViews.tiles(after), Sc2TileFlags.MARK)
	var index := after.index_of(2, 3)
	assert(int(difference.tiles) == 1, "MARK is ignored")
	assert(difference.values[index] == NativeTileSnapshot.CHANGED_BUILDING | NativeTileSnapshot.CHANGED_FLAGS)
	assert(difference.counts[0] == 1 and difference.counts[6] == 1 and difference.counts[1] == 0)
	assert(int(before.difference(ApplicationDebugTileViews.tiles(after), 0).tiles) == 2)
	var copy := NativeTileSnapshot.new()
	copy.copy_from(before)
	assert(int(copy.difference(ApplicationDebugTileViews.tiles(city), 0).tiles) == 0)


func _windows(city: CityState) -> void:
	var built := NativeDebugTiles.window_mesh(city.map_size, 32, city.altitude_words, city.terrain, city.tile_flags,
		Rect2i(2, 3, 4, 5))
	assert(int(built.tiles) == 20 and (built.vertices as PackedVector2Array).size() == 80)
	assert((built.indices as PackedInt32Array).size() == 120)
	var invalid := NativeDebugTiles.window_mesh(city.map_size, 32, PackedInt32Array(), city.terrain, city.tile_flags,
		Rect2i(0, 0, 4, 4))
	assert(invalid.has("error"))

	# the window covers the outline and the margin, inside the map
	var window := CityDebugTileLayer.visible_window(PackedVector2Array([Vector2(60, 60), Vector2(70, 65)]), 256)
	assert(window == Rect2i(60 - 48, 60 - 48, 11 + 96, 6 + 96))
	assert(CityDebugTileLayer.visible_window(PackedVector2Array(), 256) == Rect2i())
	assert(CityDebugTileLayer.visible_window(PackedVector2Array([Vector2(-5, -5), Vector2(300, 300)]), 256) == Rect2i(0, 0, 256, 256))

	var layer := CityDebugTileLayer.new()
	var big := CityState.from_document(EmptyCityTemplate.create(16))
	layer.build_window(big, Rect2i(0, 0, 16, 16), [1])
	assert(layer.window_tiles == 256 and not layer.clipped)
	assert(not layer.needs_window(Rect2i(2, 2, 8, 8), [1]))
	assert(layer.needs_window(Rect2i(2, 2, 8, 8), [2]), "New terrain needs a new window")
	layer.clear()
	assert(layer.layer == Layer.NONE and layer.mesh == null)
	layer.free()


func _inspection(city: CityState) -> void:
	city.set_building_id(7, 8, 0x2b)
	city.set_tile_flag(7, 8, Sc2TileFlags.POWERED, true)
	var rows := TileInspection.rows(city, Vector2i(7, 8))
	var by_caption := {}

	for row in rows:
		by_caption[row[0]] = row[1]

	assert(by_caption.Tile.begins_with("7, 8"))
	assert(by_caption.Building == "0x2B (43)")
	assert(by_caption.XBIT.ends_with("POWERED"))
	assert(TileInspection.rows(city, Vector2i(-1, 0)).is_empty())

	# a pinned tile with a moving object lists its decoded fields
	var things := city.document.find_chunk("XTHG")
	var payload := things.decoded_payload.duplicate()
	payload[CityState.THING_RECORD_SIZE + Sc2ThingLayout.Field.TYPE] = Sc2ThingLayout.Type.HELICOPTER
	ThingData.write(payload, CityState.THING_RECORD_SIZE + Sc2ThingLayout.Field.X, 7)
	ThingData.write(payload, CityState.THING_RECORD_SIZE + Sc2ThingLayout.Field.Y, 8)
	things.set_decoded_payload(payload)
	city.set_text_overlay_id(7, 8, OverlayData.thing_id(1))
	assert(TileInspection.thing_text(city, Vector2i(7, 8)).begins_with("#1 "), TileInspection.thing_text(city, Vector2i(7, 8)))
	var fields := TileInspection.thing_field_rows(city, Vector2i(7, 8))
	assert(fields.size() == ThingRecord.FIELDS.size() and fields[0][0] == "  type")
	assert(TileInspection.rows(city, Vector2i(7, 8), true).size() == TileInspection.rows(city, Vector2i(7, 8)).size() + fields.size())
	assert(TileInspection.thing_field_rows(city, Vector2i(1, 1)).is_empty())
	city.set_text_overlay_id(7, 8, 0)
	assert(TileInspection.flag_names(0) == "none")
	assert(TileInspection.text(city, Vector2i(7, 8), [["Debug layer", "value"]]).ends_with("Debug layer  value"))
	city.set_building_id(7, 8, 0)


func _menu() -> void:
	var popup := PopupMenu.new()
	var pressed: Array[int] = []
	CityDebugMenu.populate(popup, func(id: int) -> void: pressed.append(id))
	var state := DebugViewState.new()
	state.tile_layer = Layer.WATER_NETWORKS
	state.change_baseline = DebugViewState.ChangeBaseline.PREVIOUS_DAY
	state.occluders = true
	CityDebugMenu.sync(popup, state, true, false)
	assert(popup.is_item_checked(popup.get_item_index(CityDebugMenu.MENU_OCCLUDERS)))
	assert(not popup.is_item_checked(popup.get_item_index(CityDebugMenu.MENU_SPRITE_BOUNDS)))
	assert(popup.is_item_checked(popup.get_item_index(CityDebugMenu.MENU_TILE_INSPECTOR)))
	var layers := popup.get_item_submenu_node(popup.get_item_index(CityDebugMenu.MENU_TILE_LAYERS))
	assert(layers.is_item_checked(layers.get_item_index(CityDebugMenu.LAYER_BASE + Layer.WATER_NETWORKS)))
	assert(not layers.is_item_checked(layers.get_item_index(CityDebugMenu.LAYER_BASE + Layer.NONE)))
	var baselines := popup.get_item_submenu_node(popup.get_item_index(CityDebugMenu.MENU_BASELINES))
	assert(baselines.is_item_checked(2) and not baselines.is_item_checked(0))
	layers.id_pressed.emit(CityDebugMenu.LAYER_BASE + Layer.MARK)
	assert(pressed == [CityDebugMenu.LAYER_BASE + Layer.MARK], "Submenus use the Debug menu handler")
	popup.free()


func _settings() -> void:
	var path := OS.get_temp_dir().path_join("opensc2k_debug_mode_%d.cfg" % OS.get_process_id())
	DirAccess.remove_absolute(path)
	assert(not AppSettingsStore.load_values(path).debug_mode)
	assert(AppSettingsStore.save_debug_mode(true, path) == OK)
	assert(AppSettingsStore.load_values(path).debug_mode)
	assert(AppSettingsStore.save_debug_mode(false, path) == OK)
	assert(not AppSettingsStore.load_values(path).debug_mode)
	DirAccess.remove_absolute(path)

	DebugMode.enabled = false
	assert(DebugMode.is_debug_tool(CityToolIds.Group.QUERY, CityToolIds.Query.TILE_INSPECTOR))
	assert(not DebugMode.is_debug_tool(CityToolIds.Group.QUERY, CityToolIds.Query.QUERY))
	assert(not DebugMode.allows_tool(CityToolIds.Group.QUERY, CityToolIds.Query.TRIP_REACH))
	DebugMode.enabled = true
	assert(DebugMode.allows_tool(CityToolIds.Group.QUERY, CityToolIds.Query.TRIP_REACH))
	DebugMode.enabled = false
