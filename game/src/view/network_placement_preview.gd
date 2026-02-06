class_name NetworkPlacementPreview
extends CanvasGroup

var worker: Thread
var pending: Dictionary = {}
var request_key := ""
var generation := 0
var worker_generation := 0
var visuals: Array[Dictionary] = []
var divisor := 1
var map_view: CityMapControl
var context_key := ""
var render_key := ""
var sprite_cache: Dictionary = {}
var texture_cache: Dictionary = {}
var painter := Node2D.new()

func _init() -> void:
	modulate.a = 0.75
	add_child(painter)
	painter.draw.connect(_draw_preview)

static func supports_tool(group: int, tool: int) -> bool:
	return NetworkCommand.supports_tool(group, tool) or HighwayCommand.supports_tool(group, tool) or TunnelCommand.supports_tool(group, tool) or OnrampCommand.supports_tool(group, tool) or SubwayToRailCommand.supports_tool(group, tool)

func clear() -> void:
	if request_key.is_empty() and visuals.is_empty():
		return
	generation += 1
	request_key = ""
	context_key = ""
	render_key = ""
	pending.clear()
	visuals.clear()
	if map_view != null:
		map_view.network_preview_active = false
		map_view.queue_redraw()
	painter.queue_redraw()

func request(city: CityState, group: int, tool: int, start: Vector2i, finish: Vector2i, view: int, palette: Sc2Palette, sprites: Sc2SpriteArchive, underground: bool) -> void:
	# include chunk revisions so simulation and edits invalidate an idle preview
	var revisions := ""
	for chunk in city.document.chunks:
		revisions += ":%d" % chunk.mutation_revision
	var appearance := "%d:%d:%d:%d:%d:%d:%s" % [city.get_instance_id(), group, tool, view, palette.get_instance_id(), sprites.get_instance_id(), underground]
	var context := appearance + revisions
	var key := "%s:%s:%s" % [context, start, finish]
	if key == request_key:
		return
	if context != context_key:
		generation += 1
		context_key = context
	if appearance != render_key:
		render_key = appearance
		# replace caches rather than mutating a cache still owned by the worker
		sprite_cache = {}
		texture_cache = {}
		visuals.clear()
		painter.queue_redraw()
	request_key = key
	if map_view != null and not map_view.network_preview_active:
		map_view.network_preview_active = true
		map_view.queue_redraw()
	pending = {"city": city, "group": group, "tool": tool, "start": start, "finish": finish, "view": view, "palette": palette, "sprites": sprites, "underground": underground, "cache": sprite_cache}

func _process(_delta: float) -> void:
	if worker != null and not worker.is_alive():
		var result: Dictionary = worker.wait_to_finish()
		worker = null
		if worker_generation == generation and not request_key.is_empty():
			visuals.clear()
			divisor = int(result.get("divisor", 1))
			for draw: Dictionary in result.get("draws", []):
				var source: Image = draw.image
				var key := source.get_instance_id()
				if not texture_cache.has(key):
					texture_cache[key] = ImageTexture.create_from_image(source)
				visuals.append({"texture": texture_cache[key], "source": draw.source, "position": draw.position})
			if map_view != null:
				map_view.queue_redraw()
			painter.queue_redraw()
	if worker == null and not pending.is_empty():
		var job := pending.duplicate()
		pending.clear()
		# copy on the main thread; the worker never reads live simulation data
		job.document = job.city.document.duplicate_document()
		job.erase("city")
		worker_generation = generation
		worker = Thread.new()
		if worker.start(build.bind(job), Thread.PRIORITY_LOW) != OK:
			worker = null
			clear()

	if map_view != null:
		var view_scale := map_view._view_scale()
		position = map_view._draw_offset(view_scale)
		scale = Vector2.ONE * view_scale * divisor

func _exit_tree() -> void:
	if worker != null:
		worker.wait_to_finish()

func _draw_preview() -> void:
	for visual in visuals:
		painter.draw_texture_rect_region(visual.texture, Rect2(visual.position, visual.source.size), visual.source)

static func apply_preview(city: CityState, group: int, tool: int, start: Vector2i, finish: Vector2i) -> Dictionary:
	if NetworkCommand.supports_tool(group, tool) or HighwayCommand.supports_tool(group, tool):
		var bridge := -1
		var connection := -1
		for attempt in 3:
			var result: Dictionary
			if HighwayCommand.supports_tool(group, tool):
				result = HighwayCommand.apply(city, group, tool, start, finish, connection, bridge)
			else:
				result = NetworkCommand.apply(city, group, tool, start, finish, bridge, connection)
			if result.get("bridge_selection_required", false):
				bridge = int(result.bridge_choices[0].type)
			elif result.get("connection_selection_required", false):
				connection = 1
			else:
				return result
	if TunnelCommand.supports_tool(group, tool):
		return TunnelCommand.apply(city, group, tool, finish, TunnelCommand.CONFIRMATION_CONFIRMED)
	if OnrampCommand.supports_tool(group, tool):
		return OnrampCommand.apply(city, group, tool, finish)
	if SubwayToRailCommand.supports_tool(group, tool):
		return SubwayToRailCommand.apply(city, group, tool, finish)
	return {"ok": false}

static func build(job: Dictionary) -> Dictionary:
	var city: CityState = job.city if job.has("city") else CityState.from_document(job.document)
	var before_buildings := city.buildings
	var before_terrain := city.terrain
	var before_underground := city.underground
	var before_flags := city.tile_flags
	var before_altitude := city.altitude_words
	var result := apply_preview(city, job.group, job.tool, job.start, job.finish)
	if not result.get("ok", false):
		return {"draws": []}
	var tiles := {}
	# command footprints include bridge decks and tunnel paths. check adjacent
	# cells for connection shapes and terrain grading, not the entire map
	var candidates := candidate_indices(result, job.start, job.finish, city.map_size)
	for index: int in candidates:
		if before_buildings[index] == city.buildings[index] and before_terrain[index] == city.terrain[index] and before_underground[index] == city.underground[index] and before_flags[index] == city.tile_flags[index] and before_altitude[index] == city.altitude_words[index]:
			continue
		var point := Vector2i(index / city.map_size, index % city.map_size)
		tiles[(point.x + point.y) * city.map_size + point.y] = point
	var order := tiles.keys()
	order.sort()
	var config := CityIsometricRenderer.view_configuration(job.view)
	var origin := int(config.side_margin) + city.map_size * int(config.half_width)
	var draws := CityGpuDrawList.new()
	var cache: Dictionary = job.get("cache", {})
	for key in order:
		var point: Vector2i = tiles[key]
		if job.underground:
			CityUndergroundView._draw_tile(draws, city, job.palette, job.sprites, cache, config, origin, point.x, point.y, true, true)
		else:
			CityIsometricRenderer._draw_tile(draws, city, job.palette, job.sprites, cache, config, origin, point.x, point.y, 0, false, true)
	return {"draws": draws.draws, "divisor": config.divisor, "command": result, "candidate_count": candidates.size(), "tile_count": tiles.size()}

static func candidate_indices(command: Dictionary, start: Vector2i, finish: Vector2i, edge: int) -> Dictionary:
	var points: Array = [start, finish]
	points.append_array(command.get("points", []))
	for index: int in command.get("tile_indices", []):
		points.append(Vector2i(index / edge, index % edge))
	if command.has("road_point"):
		points.append(command.road_point)
	var candidates := {}
	for point: Vector2i in points:
		for x in range(maxi(0, point.x - 2), mini(edge, point.x + 3)):
			for y in range(maxi(0, point.y - 2), mini(edge, point.y + 3)):
				candidates[x * edge + y] = true
	return candidates
