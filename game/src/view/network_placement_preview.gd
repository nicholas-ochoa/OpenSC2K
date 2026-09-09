class_name NetworkPlacementPreview
extends CanvasGroup


@warning_ignore_start("integer_division")

class Request extends RefCounted:
	var city: CityState
	var group: int
	var tool: int
	var start: Vector2i
	var finish: Vector2i
	var view: int
	var palette: Sc2Palette
	var sprites: Sc2SpriteArchive
	var underground: bool
	var free_mode: bool
	var cache: Dictionary

	func _init(source: CityState, tool_group: int, subtool: int, first: Vector2i, last: Vector2i,
		graphics_size: int, colors: Sc2Palette, artwork: Sc2SpriteArchive, below_ground: bool,
		free := false, images: Dictionary = {}) -> void:
		city = source
		group = tool_group
		tool = subtool
		start = first
		finish = last
		view = graphics_size
		palette = colors
		sprites = artwork
		underground = below_ground
		free_mode = free
		cache = images


class Result extends RefCounted:
	var draws: Array[CityGpuDrawList.Draw] = []
	var command: EditCommandResult
	var divisor := 1
	var candidate_count := 0
	var tile_count := 0


class Visual extends RefCounted:
	var texture: ImageTexture
	var source: Rect2i
	var position: Vector2i

	func _init(image_texture: ImageTexture, area: Rect2i, destination: Vector2i) -> void:
		texture = image_texture
		source = area
		position = destination


var worker: Thread
var pending: Request
var request_key := ""
var generation := 0
var worker_generation := 0
var visuals: Array[Visual] = []
var divisor := 1
# planned price for the pending route, anchored at the drag start tile
var cost := -1
var affordable := true
var map_view: CityMapControl
var context_key := ""
var render_key := ""
var sprite_cache: Dictionary = {}
var texture_cache: Dictionary[int, ImageTexture] = {}
var painter := Node2D.new()


func _init() -> void:
	modulate.a = 0.75
	add_child(painter)
	painter.draw.connect(_draw_preview)


static func supports_tool(group: int, tool: int) -> bool:
	return (NetworkCommand.supports_tool(group, tool) or HighwayCommand.supports_tool(group, tool) or TunnelCommand.supports_tool(group, tool)
			or OnrampCommand.supports_tool(group, tool) or SubwayToRailCommand.supports_tool(group, tool))


func clear() -> void:
	if request_key.is_empty() and visuals.is_empty() and cost < 0:
		return

	generation += 1
	request_key = ""
	context_key = ""
	render_key = ""
	pending = null
	visuals.clear()
	cost = -1
	affordable = true

	if map_view != null:
		map_view.network_preview_active = false
		map_view.clear_selection_price()
		map_view.queue_redraw()

	painter.queue_redraw()


func request(city: CityState, group: int, tool: int, start: Vector2i, finish: Vector2i, view: int, palette: Sc2Palette,
		sprites: Sc2SpriteArchive, underground: bool, free_mode := false) -> void:
	# include chunk revisions so simulation and edits invalidate an idle preview
	var revisions := ""

	for chunk in city.document.chunks:
		revisions += ":%d" % chunk.mutation_revision

	var appearance := ("%d:%d:%d:%d:%d:%d:%s:%s"
			% [city.get_instance_id(), group, tool, view, palette.get_instance_id(), sprites.get_instance_id(), underground, free_mode])
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

	pending = Request.new(city, group, tool, start, finish, view, palette,
			sprites, underground, free_mode, sprite_cache)


func _process(_delta: float) -> void:
	if worker != null and not worker.is_alive():
		# release the slot before checking the return value. a script failure can
		# return null; a typed assignment here used to leave a joined worker stuck
		var completed := worker
		worker = null
		var value: Variant = completed.wait_to_finish()
		var result: Result = value if value is Result else Result.new()

		if worker_generation == generation and not request_key.is_empty():
			visuals.clear()
			_read_price(result.command)
			divisor = result.divisor
			for draw in result.draws:
				var source: Image = draw.image
				var key := source.get_instance_id()

				if not texture_cache.has(key):
					texture_cache[key] = ImageTexture.create_from_image(source)

				visuals.append(Visual.new(texture_cache[key], draw.source, draw.position))

			if map_view != null:
				map_view.queue_redraw()

			painter.queue_redraw()

	if worker == null and pending != null:
		var job := pending
		pending = null
		# copy on the main thread; the worker never reads live simulation data
		job.city = snapshot_city(job.city)
		worker_generation = generation
		worker = Thread.new()

		if worker.start(build.bind(job), Thread.PRIORITY_LOW) != OK:
			worker = null
			clear()

	if map_view != null:
		var view_scale := map_view.camera._view_scale()
		position = map_view.camera._draw_offset(view_scale)
		scale = Vector2.ONE * view_scale * divisor

		# only an active request owns the anchored price. an idle preview must
		# leave a zone or other tool price alone
		if not request_key.is_empty():
			if cost < 0:
				map_view.clear_selection_price()
			else:
				map_view.set_selection_price(cost, affordable)


func _read_price(command: EditCommandResult) -> void:
	if command != null and command.ok:
		cost = command.cost
		affordable = true

		return

	# a rejected plan still reports its price when only the funds fall short
	if command != null and command.error == "insufficient funds":
		cost = maxi(0, command.cost)
		affordable = false

		return

	cost = -1
	affordable = true


func _exit_tree() -> void:
	if worker != null:
		worker.wait_to_finish()


func _draw_preview() -> void:
	for visual in visuals:
		painter.draw_texture_rect_region(visual.texture, Rect2(visual.position, visual.source.size), visual.source)


static func apply_preview(city: CityState, group: int, tool: int, start: Vector2i, finish: Vector2i, free_mode := false) -> EditCommandResult:
	if NetworkCommand.supports_tool(group, tool) or HighwayCommand.supports_tool(group, tool):
		var bridge := -1
		var connection := -1

		for attempt in 3:
			var result: RouteEditResult

			if HighwayCommand.supports_tool(group, tool):
				result = HighwayCommand.apply(city, group, tool, start, finish, connection, bridge, free_mode)
			else:
				result = NetworkCommand.apply(city, group, tool, start, finish, bridge, connection, free_mode)

			if result.bridge_selection_required:
				bridge = int(result.bridge_choices[0].type)
			elif result.connection_selection_required:
				connection = 1
			else:
				return result

	if TunnelCommand.supports_tool(group, tool):
		return TunnelCommand.apply(city, group, tool, finish, TunnelCommand.CONFIRMATION_CONFIRMED, free_mode)

	if OnrampCommand.supports_tool(group, tool):
		return OnrampCommand.apply(city, group, tool, finish, free_mode)

	if SubwayToRailCommand.supports_tool(group, tool):
		return SubwayToRailCommand.apply(city, group, tool, finish)

	return EditCommandResult.new()


static func build(job: Request) -> Result:
	var city: CityState = job.city
	var before_buildings := city.buildings
	var before_terrain := city.terrain
	var before_underground := city.underground
	var before_flags := city.tile_flags
	var before_altitude := city.altitude_words.duplicate()
	var result := apply_preview(city, job.group, job.tool, job.start, job.finish, job.free_mode)

	var artwork := Result.new()
	artwork.command = result

	if not result.ok:
		return artwork

	var tiles := {}
	# command footprints include bridge decks and tunnel paths. check adjacent
	# cells for connection shapes and terrain grading, not the entire map
	var candidates := candidate_indices(result, job.start, job.finish, city.map_size)
	for index: int in candidates:
		if (before_buildings[index] == city.buildings[index] and before_terrain[index] == city.terrain[index]
				and before_underground[index] == city.underground[index] and before_flags[index] == city.tile_flags[index]
				and before_altitude[index] == city.altitude_words[index]):
			continue

		var point := Vector2i(index / city.map_size, index % city.map_size)
		tiles[(point.x + point.y) * city.map_size + point.y] = point
	var order := tiles.keys()
	order.sort()
	var config := CityIsometricRenderer.view_configuration(job.view)
	var origin := config.side_margin + city.map_size * config.half_width
	var draws := CityGpuDrawList.new()
	var cache := job.cache

	for key in order:
		var point: Vector2i = tiles[key]

		if job.underground:
			CityUndergroundView.draw_tile(draws, city, job.palette, job.sprites, cache, config, origin, point.x, point.y, true, true)
		else:
			CityIsometricRenderer.draw_tile(draws, city, job.palette, job.sprites, cache, config, origin, point.x, point.y, 0, false, true)

	artwork.draws = draws.draws
	artwork.divisor = config.divisor
	artwork.candidate_count = candidates.size()
	artwork.tile_count = tiles.size()

	return artwork


static func candidate_indices(command: EditCommandResult, start: Vector2i, finish: Vector2i, edge: int) -> Dictionary[int, bool]:
	var points: Array = [start, finish]
	points.append_array(command.points)
	for index: int in command.tile_indices:
		points.append(Vector2i(index / edge, index % edge))

	if command is OnrampEditResult:
		points.append((command as OnrampEditResult).road_point)

	var candidates: Dictionary[int, bool] = {}
	for point: Vector2i in points:
		for x in range(maxi(0, point.x - 2), mini(edge, point.x + 3)):
			for y in range(maxi(0, point.y - 2), mini(edge, point.y + 3)):
				candidates[x * edge + y] = true

	return candidates


static func snapshot_city(source: CityState) -> CityState:
	return CityState.copy_for_edit(source)
