class_name CityTrafficMotion
extends RefCounted
## Interpolate completed moving-object positions. Never predict or write a route.

const STEP_SECONDS := GameSpeedController.BASE_TICK_MSEC / 1000.0
const OPTION_BY_TYPE := {1: "traffic_planes_enabled", 2: "traffic_helicopters_enabled", 3: "traffic_ships_enabled", 9: "traffic_ships_enabled"}

var tracks: Dictionary[int, Track] = {}
var _signature: Array = []


func reset() -> void:
	tracks.clear()
	_signature.clear()


func observe(city: CityState, options: Dictionary) -> void:
	var signature := [city.document.get_instance_id(), city.compass_rotation(), city.visible_altitude_levels,
		city.chunk_revision("ALTM"), city.chunk_revision("XTER")]
	if signature != _signature:
		tracks.clear()
		_signature = signature
	var seen: Dictionary[int, bool] = {}
	for record in city.thing_count():
		var thing := city.thing(record)
		if thing == null or not OPTION_BY_TYPE.has(thing.type) or not options[OPTION_BY_TYPE[thing.type]]:
			continue
		# Type 9 with a state is Nessie, not a sailboat.
		if (thing.type == 9 and thing.state != 0) or city.index_of(thing.x, thing.y) < 0 \
				or city.text_overlay_id(thing.x, thing.y) != OverlayData.thing_id(record):
			continue
		seen[record] = true
		var tile := Vector2(thing.x, thing.y) + Vector2(thing.px, thing.py) / 16.0
		var point := Vector3((tile.x - tile.y) * 16.0,
			(tile.x + tile.y) * 8.0 - city.object_altitude(thing.x, thing.y) * 12.0, thing.z * 8.0)
		var track: Track = tracks.get(record)
		if track == null or track.type != thing.type or track.target.distance_to(point) > 64.0:
			# New records and teleports appear at their actual position.
			track = Track.new()
			track.type = thing.type
			track.current = point
			track.target = point
			track.tile = tile
			track.target_tile = tile
			tracks[record] = track
		elif track.target != point:
			track.start = track.current
			track.start_tile = track.tile
			track.target = point
			track.target_tile = tile
			track.elapsed = 0.0
		track.subtile = Vector2(thing.px - thing.py, (thing.px + thing.py) * 0.5)
	for record in tracks.keys():
		if not seen.has(record):
			tracks.erase(record)


func advance(delta: float) -> bool:
	var changed := false
	for track: Track in tracks.values():
		if track.current == track.target:
			continue
		track.elapsed = minf(STEP_SECONDS, track.elapsed + maxf(delta, 0.0))
		var weight := track.elapsed / STEP_SECONDS
		track.current = track.start.lerp(track.target, weight)
		track.tile = track.start_tile.lerp(track.target_tile, weight)
		changed = true
	return changed


func draw_command(source: CityDynamicCommand, divisor: int, map_size: int) -> CityDynamicCommand:
	var track: Track = tracks.get(source.record)
	if track == null or track.current == track.target:
		return source
	var difference := track.current - track.target
	var offset := Vector2(difference.x, difference.y - (0.0 if source.shadow else difference.z))
	# Raster masks and water reflections use the same native pixel position.
	var position := source.position + Vector2i((offset / divisor).round())
	var tile := Vector2i(floori(track.tile.x), floori(track.tile.y)).clamp(Vector2i.ZERO, Vector2i.ONE * (map_size - 1))
	var order := (tile.x + tile.y) * map_size + tile.y
	if position == source.position and order == source.depth_order:
		return source
	var command := CityDynamicCommand.new()
	command.sprite_id = source.sprite_id
	command.flip = source.flip
	command.position = position
	command.shadow = source.shadow
	command.depth_order = order
	command.record = source.record
	command.overlay = source.overlay
	command.static_occlusion = source.static_occlusion
	command.train = source.train
	command.same_tile_foreground_indices = source.same_tile_foreground_indices
	command.floating_altitude = source.floating_altitude
	return command


func display_offset(source: CityDynamicCommand, divisor: int) -> Vector2:
	var track: Track = tracks.get(source.record)
	if track == null:
		return Vector2.ZERO
	var difference := track.current - track.target
	var offset := Vector2(difference.x, difference.y - (0.0 if source.shadow else difference.z))
	# Recover fractions discarded by classic sprite geometry at each artwork size.
	var snapped := Vector2(int(track.subtile.x / divisor), int(track.subtile.y / divisor)) * divisor
	return offset + track.subtile - snapped


class Track extends RefCounted:
	var type := 0
	var current := Vector3.ZERO
	var start := Vector3.ZERO
	var target := Vector3.ZERO
	var tile := Vector2.ZERO
	var start_tile := Vector2.ZERO
	var target_tile := Vector2.ZERO
	var elapsed := STEP_SECONDS
	var subtile := Vector2.ZERO
