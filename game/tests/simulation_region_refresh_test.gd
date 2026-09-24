extends SceneTree
## A simulation refresh redraws only the regions that show a changed tile.

const VIEW := CityIsometricRenderer.VIEW_LARGE
const SPRITE_LIMIT := Vector2i(64, 96)


func _payloads(city: CityState) -> Dictionary[String, PackedByteArray]:
	var result: Dictionary[String, PackedByteArray] = {}

	for chunk_id in CityRegionCache.SOURCE_CHUNKS:
		var chunk := city.document.find_chunk(chunk_id)

		if chunk != null:
			result[chunk_id] = chunk.decoded_payload

	return result


func _write(city: CityState, chunk_id: String, index: int, value: int) -> void:
	var chunk := city.document.find_chunk(chunk_id)
	var bytes := chunk.decoded_payload.duplicate()

	if chunk_id == "XTXT":
		OverlayData.write(bytes, index, value)
	else:
		bytes[index] = value

	assert(chunk.set_decoded_payload(bytes, true))
	city.resync_mirrors([chunk_id])


func _changed(city: CityState, old_payloads: Dictionary, sprites: Sc2SpriteArchive) -> Array[Rect2i]:
	var rects: Array[Rect2i] = []
	assert(ApplicationStaticRender.changed_source_rects(city, old_payloads, sprites, VIEW, rects))

	return rects


func _tile_rect(x: int, y: int) -> Rect2i:
	var configuration := CityIsometricRenderer.view_configuration(VIEW)
	var bounds := CityIsometricRenderer.potential_tile_bounds(configuration, SPRITE_LIMIT, x, y, 128)
	bounds = bounds.grow_individual(configuration.half_width, configuration.half_height, configuration.half_width, configuration.half_height)

	return bounds.intersection(Rect2i(Vector2i.ZERO, CityIsometricRenderer.output_size_for_view(VIEW, 128)))


func _command(order: int, sprite_id: int, position: Vector2i) -> CityStaticCommand:
	var command := CityStaticCommand.new()
	command.region_order = order
	command.depth_order = order >> 16
	command.sprite_id = sprite_id
	command.position = position
	command.size = Vector2i(8, 8)

	return command


func _initialize() -> void:
	var sprites := Sc2SpriteArchive.new()
	var entry := Sc2SpriteArchive.SpriteEntry.new()
	entry.width = SPRITE_LIMIT.x
	entry.height = SPRITE_LIMIT.y
	entry.sprite_id = 1000 + BuildingTileIds.HIGHWAY_STRAIGHT_1
	sprites.entries.append(entry)
	sprites.entries_by_id[entry.sprite_id] = entry
	var city := CityState.from_document(EmptyCityTemplate.create(128))
	assert(city.set_building_id(40, 50, BuildingTileIds.HIGHWAY_STRAIGHT_1))
	var tile := 40 * 128 + 50
	var old := _payloads(city)
	assert(_changed(city, old, sprites).is_empty())

	# regions do not draw special overlays or moving objects, so their text overlay changes skip the redraw
	for overlay in [0xfb, 0xfd, 0xff, OverlayData.thing_id(3)]:
		_write(city, "XTXT", tile, overlay)
		assert(_changed(city, old, sprites).is_empty(), "Overlay %d does not change a region" % overlay)

	_write(city, "XTXT", tile, 1)
	assert(_changed(city, old, sprites) == [_tile_rect(40, 50)], "A sign change redraws its tile and neighbors")
	_write(city, "XTXT", tile, 0)

	# traffic uses one cell for four tiles, and only a threshold crossing changes the traffic sprite
	var cell := 20 * 64 + 25
	_write(city, "XTRF", cell, IsometricStaticVisuals.HIGHWAY_TRAFFIC_THRESHOLDS.x)
	assert(_changed(city, old, sprites).is_empty(), "Traffic at a threshold draws no traffic")
	_write(city, "XTRF", cell, IsometricStaticVisuals.HIGHWAY_TRAFFIC_THRESHOLDS.x + 1)
	var traffic_rects := _changed(city, old, sprites)
	assert(traffic_rects.size() == 1 and traffic_rects[0].size == SPRITE_LIMIT and _tile_rect(40, 50).encloses(traffic_rects[0]),
		"Traffic redraws its road sprite, not all four tiles or the full altitude range")
	var busy := _payloads(city)
	_write(city, "XTRF", cell, IsometricStaticVisuals.HIGHWAY_TRAFFIC_THRESHOLDS.y - 1)
	assert(_changed(city, busy, sprites).is_empty(), "Traffic that stays at one level on every road type skips the redraw")
	_write(city, "XTRF", cell, 0)

	# Surface redraws exclude utility workspace bits. Cutaways still show pipes.
	_write(city, "XBIT", tile, Sc2TileFlags.WATERED | Sc2TileFlags.PIPED | Sc2TileFlags.MARK)
	_write(city, "XUND", tile, 1)
	assert(_changed(city, old, sprites).is_empty())
	city.visible_altitude_levels = 16
	assert(_changed(city, old, sprites) == [_tile_rect(40, 50)])
	city.visible_altitude_levels = 32
	_write(city, "XBIT", tile, Sc2TileFlags.POWERABLE)
	assert(_changed(city, old, sprites) == [_tile_rect(40, 50)])
	_write(city, "XBIT", tile, 0)
	_write(city, "XUND", tile, 0)

	_write(city, "XBLD", tile, 1)
	assert(_changed(city, old, sprites) == [_tile_rect(40, 50)])

	# a payload that cannot be compared asks for a full redraw
	var rects: Array[Rect2i] = []
	var missing := old.duplicate()
	missing.erase("XUND")
	assert(not ApplicationStaticRender.changed_source_rects(city, missing, sprites, VIEW, rects))
	var crowded := city.document.find_chunk("XBLD").decoded_payload.duplicate()
	crowded.fill(2)
	assert(city.document.find_chunk("XBLD").set_decoded_payload(crowded, true))
	assert(not ApplicationStaticRender.changed_source_rects(city, old, sprites, VIEW, rects), "Large changes redraw every region")

	# listed changes keep the regions they do not touch
	var cache := CityRegionCache.new()
	cache.gpu_enabled = false
	var palette := Sc2Palette.new()
	cache.configure(city, palette, sprites, ["first"], VIEW, CityViewMode.Mode.CITY, {}, false, false)
	var generation := cache.generation

	for key in [Vector2i(0, 0), Vector2i(1, 0)]:
		var region := CityRegionResult.new()
		region.bounds = Rect2i(key * cache.region_edge, Vector2i.ONE * cache.region_edge)
		region.generation = generation
		cache.entries[key] = region

	cache.visible.assign([Vector2i(0, 0), Vector2i(1, 0)])
	var none: Array[Rect2i] = []
	var snapshot := cache.display_city
	cache.configure(city, palette, sprites, ["second"], VIEW, CityViewMode.Mode.CITY, {}, false, false, Rect2i(), true, none, true)
	assert(cache.generation == generation and cache.signature == ["second"] and cache.display_city == snapshot,
		"A change that no region shows keeps the drawn snapshot")
	var second_region: Array[Rect2i] = [Rect2i(cache.region_edge + 5, 5, 10, 10)]
	cache.configure(city, palette, sprites, ["third"], VIEW, CityViewMode.Mode.CITY, {}, false, false, Rect2i(), true, second_region, true)
	assert(cache.entries[Vector2i(0, 0)].generation == cache.generation and cache.entries[Vector2i(1, 0)].generation < cache.generation)
	assert(not cache.ready(), "The changed region draws again")
	cache.close()

	# a republished region reports only its changed foreground silhouettes
	var before := CityRegionResult.new()
	var after := CityRegionResult.new()
	before.occlusion_commands.assign([_command(1 << 16, 10, Vector2i(0, 0)), _command(2 << 16, 11, Vector2i(20, 0)),
		_command(3 << 16, 12, Vector2i(40, 0))])
	after.occlusion_commands.assign([_command(1 << 16, 10, Vector2i(0, 0)), _command(2 << 16, 13, Vector2i(20, 4)),
		_command(4 << 16, 14, Vector2i(60, 0))])
	assert(CityRegionCache.changed_foreground(before, after) == [Rect2i(20, 0, 8, 8), Rect2i(20, 4, 8, 8), Rect2i(60, 0, 8, 8),
		Rect2i(40, 0, 8, 8)], "Changed, added and removed silhouettes report; unchanged ones do not")

	print("PASS: simulation refreshes redraw only regions with visible tile changes")
	quit()
