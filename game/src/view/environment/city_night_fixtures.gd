class_name CityNightFixtures
extends RefCounted
## Small cosmetic street fixtures, clipped against existing foreground art.
## Signal phases are presentation time only; vehicles never read them.

const TILES = preload("res://src/tools/shared/building_tile_ids.gd")
const SIGNAL_COLORS := [Color("ff4836"), Color("ffc34b"), Color("5aff8b")]


static func street_layout(city: CityState, tile: Vector2i, spacing: int) -> Array[Dictionary]:
	var id := city.building_id(tile.x, tile.y)
	var ordinary := id >= TILES.ROAD_STRAIGHT_1 and id <= TILES.ROAD_CROSSROADS
	var crossing := id >= TILES.ROAD_POWER_CROSSING_1 and id <= TILES.ROAD_RAIL_CROSSING_2
	var bridge := id >= TILES.SUSPENSION_BRIDGE_1 and id <= TILES.RAISING_BRIDGE_CLOSED
	var highway := (id >= TILES.HIGHWAY_STRAIGHT_1 and id <= TILES.HIGHWAY_POWER_CROSSING_2) \
		or (id >= TILES.HIGHWAY_ONRAMP_1 and id <= TILES.REINFORCED_HIGHWAY_BRIDGE)
	if not (ordinary or crossing or bridge or highway):
		return []
	var ports := CityLifePaths.ports(city, tile)
	if id >= TILES.ROAD_JUNCTION_1 and id <= TILES.ROAD_CROSSROADS:
		return [{"offset": Vector2(0.34, 0.34), "enter": 0}, {"offset": Vector2(-0.34, -0.34), "enter": 0}]
	var diagonal := CityLifePaths.diagonal(city, tile)
	var coordinate := tile.x + tile.y
	var period := maxi(1, spacing)
	if diagonal:
		# A diagonal crosses two alternating half-tiles per full street step.
		# Follow its longitudinal axis, including the x-y diagonals.
		var rotation := id - (TILES.HIGHWAY_CURVE_1 if highway else TILES.ROAD_CURVE_1)
		coordinate = tile.x + tile.y if rotation % 2 == 0 else tile.x - tile.y
		period *= 2
	if posmod(coordinate, period) != 0:
		return []
	if id in [TILES.HIGHWAY_ROAD_CROSSING_1, TILES.HIGHWAY_ROAD_CROSSING_2]:
		return [{"offset": Vector2(0.32, 0), "enter": 0}, {"offset": Vector2(0, 0.32), "enter": 1}]
	if diagonal:
		var result: Array[Dictionary] = []
		for enter in 4:
			if not ports & (1 << enter):
				continue
			var exit := CityLifePaths.paired_exit(city, tile, enter)
			if enter > exit:
				continue
			var a := Vector2(CityLifePaths.DIRECTIONS[enter]) * 0.5
			var b := Vector2(CityLifePaths.DIRECTIONS[exit]) * 0.5
			var center := (a + b) * 0.5
			var side := Vector2(a.y - b.y, b.x - a.x).normalized()
			if side.dot(center) < 0:
				side = -side
			result.append({"offset": center + side * 0.32, "center": center, "enter": enter})
		return result
	for direction in 4:
		if ports & (1 << direction):
			var forward := Vector2(CityLifePaths.DIRECTIONS[direction])
			var side := Vector2(-forward.y, forward.x)
			return [{"offset": side * 0.32, "enter": direction}]
	return []


static func signal_directions(city: CityState, tile: Vector2i) -> Array[int]:
	var id := city.building_id(tile.x, tile.y)
	if id < TILES.ROAD_JUNCTION_1 or id > TILES.ROAD_CROSSROADS:
		return []
	var result: Array[int] = []
	for direction in 4:
		if CityLifePaths.connected(city, tile, direction):
			result.append(direction)
	# Disconnected junction artwork is not a working intersection.
	return result if result.size() >= 3 else []


static func signal_lens(tile: Vector2i, axis: int, seconds: float) -> int:
	var phase := fposmod(seconds + posmod(tile.x * 3 + tile.y * 5, 14), 14.0)
	phase = fposmod(phase - float(axis) * 7.0, 14.0)
	if phase < 5.0:
		return 2 # Green, then amber, then all-red before the other axis.
	return 1 if phase < 6.0 else 0


static func build(app: CityApplication, tile: Vector2i, origin: Vector2i, layout: Array[Dictionary], masker: CityLifeCanvas,
		texture_lookup := Callable()) -> Dictionary:
	var city := app.document_state.city
	var art := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	for fixture in layout:
		var occluders := masker._candidates(app, tile, fixture.enter)
		var foot := _foot(city, tile, fixture.offset, fixture.enter)
		var head := foot + Vector2i(0, -7)
		for y in range(head.y, foot.y + 1):
			_pixel(art, origin, Vector2i(foot.x, y), Color("6d7378"), occluders)
		# A short arm bends toward the carriageway.
		var inward := (Vector2(fixture.get("center", Vector2.ZERO)) - Vector2(fixture.offset)).normalized() * 0.12
		var arm := Vector2i(roundi((inward.x - inward.y) * 16.0), roundi((inward.x + inward.y) * 8.0))
		for step in 4:
			_pixel(art, origin, head + Vector2i(Vector2(arm) * step / 3.0), Color("8c8d80"), occluders)
		head += arm
		_halo(art, origin, head, Color("ffd890"), 3.0, occluders)
		_pixel(art, origin, head, Color("fff4d4"), occluders)
		_pixel(art, origin, head + Vector2i.RIGHT, Color("ffe5a2"), occluders)
	var signals: Array[Dictionary] = []
	for direction in signal_directions(city, tile):
		var forward := Vector2(CityLifePaths.DIRECTIONS[direction])
		var side := Vector2(-forward.y, forward.x)
		var foot := _foot(city, tile, forward * 0.36 + side * 0.30, direction)
		var head := foot + Vector2i(0, -6)
		var occluders := masker._candidates(app, tile, direction)
		for y in range(head.y, foot.y + 1):
			_pixel(art, origin, Vector2i(foot.x, y), Color("687075"), occluders)
		for x in range(-1, 2):
			for y in range(-1, 4):
				_pixel(art, origin, head + Vector2i(x, y), Color("24292e"), occluders)
		var lenses: Array[Texture2D] = []
		var lamp_origin := head - Vector2i(4, 4)
		for lens in 3:
			var image := Image.create(9, 11, false, Image.FORMAT_RGBA8)
			var point := head + Vector2i(0, lens)
			_halo(image, lamp_origin, point, SIGNAL_COLORS[lens], 2.5, occluders)
			_pixel(image, lamp_origin, point, SIGNAL_COLORS[lens], occluders)
			lenses.append(_texture(image, texture_lookup))
		signals.append({"origin": lamp_origin, "lenses": lenses, "axis": direction % 2})
	return {"fixtures": _texture(art, texture_lookup), "signals": signals}


static func _texture(image: Image, lookup: Callable) -> Texture2D:
	return lookup.call(image) if lookup.is_valid() else ImageTexture.create_from_image(image)


static func _foot(city: CityState, tile: Vector2i, offset: Vector2, enter: int) -> Vector2i:
	if CityLifePaths.diagonal(city, tile):
		var exit := CityLifePaths.paired_exit(city, tile, enter)
		var a := Vector2(CityLifePaths.DIRECTIONS[enter]) * 0.5
		var b := Vector2(CityLifePaths.DIRECTIONS[exit]) * 0.5
		var progress := clampf((offset - a).dot(b - a) / a.distance_squared_to(b), 0, 1)
		var height := lerpf(CityLifePaths.edge_height(city, tile, enter), CityLifePaths.edge_height(city, tile, exit), progress)
		return Vector2i(CityLifeLights._project(city, tile, offset, height).round())
	var ports := CityLifePaths.ports(city, tile)
	var exit := (enter + 2) % 4
	if not ports & (1 << exit):
		for direction in 4:
			if direction != enter and ports & (1 << direction) and CityLifePaths.can_turn(city, tile, enter, direction):
				exit = direction
				break
	var middle := (CityLifePaths.edge_height(city, tile, enter) + CityLifePaths.edge_height(city, tile, exit)) * 0.5
	var height := middle
	var progress := 0.0
	# Follow the same two half-road planes as the receiver, including bent onramps.
	for direction in 4:
		if not ports & (1 << direction) or (direction != enter and not CityLifePaths.can_turn(city, tile, enter, direction)):
			continue
		var along := clampf(offset.dot(Vector2(CityLifePaths.DIRECTIONS[direction])) * 2.0, 0.0, 1.0)
		if along > progress:
			progress = along
			height = lerpf(middle, CityLifePaths.edge_height(city, tile, direction), progress)
	return Vector2i(CityLifeLights._project(city, tile, offset, height).round())


static func _halo(image: Image, origin: Vector2i, center: Vector2i, color: Color, radius: float, occluders: Array) -> void:
	var extent := ceili(radius)
	for y in range(-extent, extent + 1):
		for x in range(-extent, extent + 1):
			var glow := color
			glow.a = 0.28 * pow(maxf(0.0, 1.0 - Vector2(x, y).length() / radius), 1.5)
			_pixel(image, origin, center + Vector2i(x, y), glow, occluders)


static func _pixel(image: Image, origin: Vector2i, point: Vector2i, color: Color, occluders: Array) -> void:
	var local := point - origin
	if color.a <= 0.0 or not Rect2i(Vector2i.ZERO, image.get_size()).has_point(local) or CityLifeCanvas.hidden_at(point, occluders):
		return
	image.set_pixelv(local, image.get_pixelv(local).blend(color))
