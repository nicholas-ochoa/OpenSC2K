class_name CityTrafficMotion
extends RefCounted
## Interpolate completed moving-object positions. Never predict or write a route.

const STEP_SECONDS := GameSpeedController.BASE_TICK_MSEC / 1000.0
const OPTION_BY_TYPE := {1: "traffic_vehicles_enabled", 2: "traffic_vehicles_enabled", 3: "traffic_vehicles_enabled", 9: "traffic_vehicles_enabled",
	10: "traffic_vehicles_enabled", 11: "traffic_vehicles_enabled", 15: "disaster_motion"}

var tracks: Dictionary[int, Track] = {}
var _signature: Array = []
var _observation: Array = []


func reset() -> void:
	tracks.clear()
	_signature.clear()
	_observation.clear()


func observe(city: CityState, options: Dictionary, vehicles_visible := true) -> void:
	var signature := [city.document.get_instance_id(), city.compass_rotation(), city.visible_altitude_levels,
		city.chunk_revision("ALTM"), city.chunk_revision("XTER")]
	var observation := [signature, city.mirror_signature(["XTHG", "XTXT", "XBLD"]), vehicles_visible,
		options.traffic_vehicles_enabled, options.disaster_enabled, options.disaster_motion]
	if observation == _observation:
		return
	_observation = observation
	if signature != _signature:
		tracks.clear()
		_signature = signature
	var seen: Dictionary[int, bool] = {}
	for record in city.thing_count():
		var thing := city.thing(record)
		if thing == null or not OPTION_BY_TYPE.has(thing.type) or not options[OPTION_BY_TYPE[thing.type]]:
			continue
		if not vehicles_visible and thing.type != 15:
			continue
		if thing.type == 15 and not options.disaster_enabled:
			continue
		# Type 9 with a state is Nessie, not a sailboat.
		if (thing.type == 9 and thing.state != 0) or city.index_of(thing.x, thing.y) < 0 \
				or city.text_overlay_id(thing.x, thing.y) != OverlayData.thing_id(record):
			continue
		seen[record] = true
		var tile := Vector2(thing.x, thing.y) + Vector2(thing.px, thing.py) / 16.0
		var point := Vector3((tile.x - tile.y) * 16.0,
			(tile.x + tile.y) * 8.0 - city.object_altitude(thing.x, thing.y) * 12.0, thing.z * 8.0)
		if thing.type == 15:
			# Tornado bytes are not sub-tile motion; interpolate completed tiles only.
			tile = Vector2(thing.x, thing.y)
			point = Vector3((tile.x - tile.y) * 16.0, (tile.x + tile.y) * 8.0 - city.object_altitude(thing.x, thing.y) * 12.0,
				0.0)
		if thing.type in [10, 11]:
			# Trains use whole-tile records and artwork-specific rail offsets, not px/py/z.
			var train := IsometricMovingVisuals.train_sprite(city, thing.x, thing.y, thing)
			if train == null:
				seen.erase(record)
				continue
			tile = Vector2(thing.x, thing.y)
			point = Vector3((tile.x - tile.y) * 16.0 + train.screen_x,
				(tile.x + tile.y) * 8.0 + train.screen_y - train.elevation, 0.0)
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
		track.subtile = Vector2.ZERO if thing.type in [10, 11, 15] else Vector2(thing.px - thing.py, (thing.px + thing.py) * 0.5)
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


func command_position(source: CityDynamicCommand, divisor: int) -> Vector2i:
	var track: Track = tracks.get(source.record)
	if track == null or track.current == track.target:
		return source.position
	var difference := track.current - track.target
	var offset := Vector2(difference.x, difference.y - (0.0 if source.shadow else difference.z))
	# Raster masks and water reflections use the same native pixel position.
	return source.position + Vector2i((offset / divisor).round())


func draw_command(source: CityDynamicCommand, divisor: int, map_size: int) -> CityDynamicCommand:
	var track: Track = tracks.get(source.record)
	if track == null or (track.current == track.target and not source.train):
		return source
	var position := command_position(source, divisor)
	var tile := Vector2i(floori(track.tile.x), floori(track.tile.y)).clamp(Vector2i.ZERO, Vector2i.ONE * (map_size - 1))
	var order := (tile.x + tile.y) * map_size + tile.y
	if position == source.position and order == source.depth_order and not source.train:
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
	if source.train:
		# A train spans the two completed rail positions throughout the blend.
		# Flooring its anchor alone puts its own track in front of the body.
		var supports := [track.target_tile] if track.current == track.target else [track.start_tile.round(), track.target_tile]
		for support in supports:
			var point := Vector2i(support)
			var support_order := (point.x + point.y) * map_size + point.y
			if not command.train_support_orders.has(support_order):
				command.train_support_orders.append(support_order)
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
