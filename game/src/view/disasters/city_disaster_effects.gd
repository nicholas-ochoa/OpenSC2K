class_name CityDisasterEffects
extends RefCounted
## Read-only presentation of confirmed markers, objects and completed events.
## The layer sits below dispatch sprites and the selection/placement overlay.

@warning_ignore_start("integer_division")

const SHADER := preload("res://src/view/disasters/disaster_effect.gdshader")
const EXTENT := Vector2i(96, 144)
const ANCHOR := Vector2(48, 128)
const MAX_MARKERS := 512
const MAX_PULSES := 96
const FRAME_SECONDS := 1.0 / 15.0
const SHAKE_SECONDS := 2.0
const FIRE := 0
const FLOOD := 1
const TOXIC := 2
const RIOT := 3
const TORNADO := 4
const DUST := 5
const MICROWAVE := 6
const VOLCANO := 7
const MONSTER := 8
const RADIATION := 9
const HURRICANE := 10
const EXPLOSION := 11
const TRAIL := 12
const DEBRIS := 13

var app: CityApplication
var canvas: Node2D
var clock := 0.0
var markers: Dictionary[String, Visual] = {}
var pulses: Array[Visual] = []
var _seen: Dictionary[String, bool] = {}
var _city_signature: Array = []
var _settings_signature: Array = []
var _texture: ImageTexture
var _people: ImageTexture
var _elapsed := 0.0
var _storm: Visual
var _trails: Dictionary[int, Vector2] = {}
var _shake_remaining := 0.0
var lighting := CityDisasterLighting.new()
var earthquake_blur := CityEarthquakeBlur.new()
var _tornado_sites: Dictionary[Vector2i, int] = {}


func _init(application: CityApplication) -> void:
	app = application


func enabled() -> bool:
	return app.preferences.visual_enhancements.disaster_enabled and app.preferences.visual_enhancements.disaster_strength > 0.0


func active() -> bool:
	return enabled() and app.document_state.city != null and app.map_view != null and app.map_view.city_source != null \
		and app.view_state.overlay_mode == CityViewMode.Mode.CITY and not app.tool_state.landscape_editor


func process(delta: float) -> void:
	_sync_city()
	app.moving_sprites.tornado_renderer.sync_transform()
	var options := app.preferences.visual_enhancements
	var settings := [enabled(), options.disaster_crowds, options.disaster_dust, options.disaster_motion]
	if settings != _settings_signature:
		_settings_signature = settings
		if app.document_state.city != null and app.map_view != null:
			app.moving_sprites.refresh_moving_things()
	if not active():
		_clear()
		return
	var controller := app.simulation_state.speed_controller
	var frozen: bool = options.pause_freezes and controller != null and \
		(controller.speed == GameSpeedController.Speed.PAUSED or app.frame._simulation_suspended())
	var elapsed := clampf(delta, 0.0, 0.25)
	if not frozen:
		clock += elapsed
		if _shake_remaining > 0.0:
			_shake_remaining = maxf(0.0, _shake_remaining - elapsed)
			var age := SHAKE_SECONDS - _shake_remaining
			var fade := shake_envelope(age)
			app.map_view.presentation.shake_offset = Vector2(sin(age * 95.0), sin(age * 71.0) * 0.3) \
				* 4.0 * options.disaster_shake * fade * maxf(1.0, app.map_view.zoom_factor) * app.map_view.map_pixel_ratio
			earthquake_blur.update(app.map_view, fade * options.disaster_shake)
			app.map_view.layers._sync_base_layer()
			app.map_view.queue_redraw()
	# User-triggered demolition still settles when the game is paused.
	for pulse in pulses:
		if not frozen or pulse.user_action:
			pulse.age += elapsed
		pulse.sprite.visible = pulse.age >= 0.0
	for i in range(pulses.size() - 1, -1, -1):
		if pulses[i].age >= pulses[i].duration:
			pulses[i].sprite.queue_free()
			pulses.remove_at(i)
	_elapsed += elapsed
	if _elapsed >= FRAME_SECONDS:
		_elapsed = 0.0
		for visual in markers.values():
			_update_material(visual)
		for pulse in pulses:
			_update_material(pulse)
		_sync_storm()
	if canvas != null:
		var scale_value := app.map_view.camera._view_scale()
		canvas.position = app.map_view.camera._draw_offset(scale_value)
		canvas.scale = Vector2.ONE * scale_value
		canvas.show()
		_sync_lighting(scale_value)


func _sync_city() -> void:
	var city := app.document_state.city
	var signature: Array = [] if city == null else [city.document.get_instance_id(), city.compass_rotation(), city.visible_altitude_levels]
	if signature != _city_signature:
		_clear()
		_city_signature = signature
		clock = 0.0


func _clear() -> void:
	if _shake_remaining > 0.0 and app.map_view != null:
		app.map_view.presentation.shake_offset = Vector2.ZERO
		app.map_view.layers._sync_base_layer()
		app.map_view.queue_redraw()
	_shake_remaining = 0.0
	if app.map_view != null:
		earthquake_blur.update(app.map_view, 0.0)
	for visual in markers.values():
		visual.sprite.queue_free()
	markers.clear()
	for pulse in pulses:
		pulse.sprite.queue_free()
	pulses.clear()
	_trails.clear()
	_tornado_sites.clear()
	lighting.clear()
	if _storm != null:
		_storm.sprite.queue_free()
		_storm = null
	if canvas != null:
		canvas.hide()


func _ensure_canvas() -> void:
	if canvas != null:
		return
	canvas = Node2D.new()
	canvas.name = "DisasterEffects"
	canvas.show_behind_parent = true
	canvas.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	app.map_view.add_child(canvas)
	var dynamic := app.map_view.layers.dynamic_canvas
	if dynamic != null:
		app.map_view.move_child(canvas, dynamic.get_index())
	lighting.setup(app.map_view, canvas)
	var image := Image.create(EXTENT.x, EXTENT.y, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	_texture = ImageTexture.create_from_image(image)
	_people = ImageTexture.create_from_image(crowd_atlas())


static func crowd_atlas() -> Image:
	var image := Image.create(EXTENT.x * 8, EXTENT.y * 2, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	# Reuse actual city-life people. Independent short loops break the marching grid.
	var positions: Array[Vector2i] = []
	for row in 5:
		var count := 6 - absi(row - 2) * 2
		for column in count:
			positions.append(Vector2i(column * 4 - (count - 1) * 2, row * 3 - 6))
	for phase in 8:
		for i in positions.size():
			var step_phase := (phase + i * 3) % 8
			var direction := (i + step_phase / 4) % 4
			var person := CityLifeSprites._person(i, direction, step_phase)
			var movement := Vector2i(roundi(sin(step_phase * TAU / 8.0)), 0)
			var offset := Vector2i(phase * EXTENT.x, -5) + Vector2i(ANCHOR) + positions[i] + movement
			image.blend_rect(person, Rect2i(Vector2i.ZERO, person.get_size()), offset)
			if i in [3, 14]:
				image.blend_rect(person, Rect2i(Vector2i.ZERO, person.get_size()), offset + Vector2i(0, EXTENT.y))
	return image


func begin_commands() -> void:
	_sync_city()
	_seen.clear()
	_tornado_sites.clear()


## Return true only when a visible replacement was actually installed.
func observe_command(command: CityDynamicCommand) -> bool:
	if not active() or command.shadow:
		return false
	var city := app.document_state.city
	var tile := Vector2i(command.depth_order / city.map_size - command.depth_order % city.map_size, command.depth_order % city.map_size)
	if city.index_of(tile.x, tile.y) < 0 or not city.tile_is_visible(tile.x, tile.y):
		return false
	var kind := -1
	match command.overlay:
		0xff: kind = FIRE
		0xfc: kind = FLOOD
		0xfb: kind = TOXIC
		0xfd, 0xfe:
			if app.preferences.visual_enhancements.disaster_crowds:
				kind = RIOT
	if kind >= 0:
		var visual := _marker("tile:%d:%d" % [tile.x, tile.y], kind, tile, ground_point(city, tile))
		if visual != null and kind == FLOOD:
			visual.material.set_shader_parameter("flood_edges", flood_edges(city, tile))
		if visual != null and kind == FIRE:
			var neighbours := 0
			for x in range(tile.x - 1, tile.x + 2):
				for y in range(tile.y - 1, tile.y + 2):
					if city.index_of(x, y) >= 0 and city.marker_overlay_id(x, y) == 0xff:
						neighbours += 1
			visual.material.set_shader_parameter("smoke_density", 1.0 / (1.0 + neighbours * 0.18))
		if visual != null and kind == RIOT:
			visual.material.set_shader_parameter("sparse_crowd", false)
			_riot_neighbours(city, tile)
		# Keep the original hazard cloud as a clear tile-local treatment target.
		return visual != null and kind not in [FIRE, TOXIC]
	if command.record < 0:
		return false
	var thing := city.thing(command.record)
	if thing == null:
		return false
	if thing.type in [1, 2] and not app.view_state.show_vehicles:
		return false
	var location := ground_point(city, tile)
	match thing.type:
		15: kind = TORNADO
		5: kind = MONSTER
		6: kind = EXPLOSION
		1, 2:
			if (thing.type == 1 and thing.state == 7) or (thing.type == 2 and thing.state == 5):
				kind = TRAIL
				location += Vector2(thing.px - thing.py, (thing.px + thing.py) * 0.5 - thing.z * 8.0)
	if kind >= 0:
		if kind == MONSTER:
			# The original pose, movement and beam remain untouched.
			if thing.dx & 0x80:
				_marker("thing:%d:beam" % command.record, MONSTER, tile, location)
			return false
		if kind == TORNADO:
			_tornado_sites[tile] = city.building_id(tile.x, tile.y)
		var visual := _marker("thing:%d" % command.record, kind, tile, location, command.record if kind == TORNADO else -1)
		if visual != null and kind == EXPLOSION:
			visual.material.set_shader_parameter("impact_phase", clampf(thing.direction / 2.0, 0.0, 1.0))
		if kind == TRAIL and _trails.get(command.record, Vector2.INF).distance_to(location) > 5.0:
			_trails[command.record] = location
			_pulse(TRAIL, tile, location, 1.0)
		return false
	return false


func end_commands() -> void:
	for key in markers.keys():
		if not _seen.has(key):
			markers[key].sprite.queue_free()
			markers.erase(key)
	for record in _trails.keys():
		if not _seen.has("thing:%d" % record):
			_trails.erase(record)


func _riot_neighbours(city: CityState, tile: Vector2i) -> void:
	for direction in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		var next: Vector2i = tile + direction
		if city.index_of(next.x, next.y) < 0 or city.is_water(next.x, next.y) or city.marker_overlay_id(next.x, next.y) != 0:
			continue
		var building := city.building_id(next.x, next.y)
		if building != 0 and not (building >= 0x1d and building <= 0x2b):
			continue
		var extra := _marker("riot-edge:%d:%d" % [next.x, next.y], RIOT, next, ground_point(city, next))
		if extra != null:
			extra.material.set_shader_parameter("sparse_crowd", true)


func observe_simulation_result(result: SimulationTickResult) -> void:
	if not active():
		return
	var demolished := false
	for moving in result.moving_results:
		if moving.tornado_demolitions > 0:
			demolished = true
	if not demolished:
		return
	var city := app.document_state.city
	for tile in _tornado_sites:
		# Only structures changed to rubble/empty by a completed tornado tick.
		if _tornado_sites[tile] >= 0x70 and city.building_id(tile.x, tile.y) <= 4:
			_pulse(DEBRIS, tile, ground_point(city, tile), 0.95)
	_tornado_sites.clear()


func _sync_lighting(scale_value: float) -> void:
	var sources: Array[Dictionary] = []
	var cells: Dictionary[Vector3i, bool] = {}
	# Pulses first: a brief impact must not be displaced by a large firestorm.
	var visuals: Array[Visual] = pulses.duplicate()
	visuals.append_array(markers.values())
	for visual in visuals:
		if not visual.kind in [FIRE, TOXIC, EXPLOSION, MICROWAVE, MONSTER] or not visual.sprite.visible:
			continue
		var cell := Vector3i(visual.tile.x / 2, visual.tile.y / 2, visual.kind)
		if cells.has(cell):
			continue
		cells[cell] = true
		var tint := Color(1.0, 0.24, 0.025)
		if visual.kind == TOXIC:
			tint = Color(0.28, 1.0, 0.035)
		elif visual.kind == MICROWAVE:
			tint = Color(0.025, 0.35, 1.0)
		elif visual.kind == MONSTER:
			# Red component of the original 1385/885/385 beam artwork.
			tint = Color("ff0f11")
		var fade := 1.0
		if visual.duration > 0.0:
			fade = 1.0 - smoothstep(0.45, 1.0, visual.age / visual.duration)
		if visual.kind == EXPLOSION:
			fade *= 1.0 - float(visual.material.get_shader_parameter("impact_phase")) * 0.55
		sources.append({"position": visual.sprite.position + ANCHOR, "color": tint, "fade": fade,
			"heat": 1.0 if visual.kind == FIRE else (0.3 if visual.kind == TOXIC else 0.0), "seed": float(visual.tile.x * 7 + visual.tile.y * 3)})
	lighting.update(sources, canvas.position, scale_value, clock, app.preferences.visual_enhancements.disaster_lights)


func _marker(key: String, kind: int, tile: Vector2i, location: Vector2, record := -1, anchor_offset := Vector2.ZERO) -> Visual:
	if not _visible(tile, location):
		return null
	_seen[key] = true
	var visual: Visual = markers.get(key)
	if visual == null:
		if markers.size() >= MAX_MARKERS:
			return null
		visual = _create(kind, tile, location)
		markers[key] = visual
	visual.kind = kind
	visual.tile = tile
	visual.record = record
	visual.anchor_offset = anchor_offset
	visual.sprite.position = (location - ANCHOR).round()
	_update_material(visual)
	return visual


func _create(kind: int, tile: Vector2i, location: Vector2) -> Visual:
	_ensure_canvas()
	var visual := Visual.new()
	visual.kind = kind
	visual.tile = tile
	visual.sprite = Sprite2D.new()
	visual.sprite.centered = false
	visual.sprite.texture = _texture
	visual.sprite.position = (location - ANCHOR).round()
	visual.material = ShaderMaterial.new()
	visual.material.shader = SHADER
	visual.material.set_shader_parameter("people", _people)
	visual.material.set_shader_parameter("effect_seed", float(posmod(tile.x * 73 + tile.y * 37, 101)) / 13.0)
	visual.sprite.material = visual.material
	canvas.add_child(visual.sprite)
	_update_material(visual)
	return visual


func _visible(tile: Vector2i, location: Vector2) -> bool:
	return app.document_state.city.tile_is_visible(tile.x, tile.y) \
		and app.map_view.visible_source_rect().intersects(Rect2(location - ANCHOR, Vector2(EXTENT)))


func _update_material(visual: Visual) -> void:
	var material := visual.material
	if visual.record >= 0:
		var track: CityTrafficMotion.Track = app.moving_sprites.traffic_motion.tracks.get(visual.record)
		var offset := Vector2.ZERO if track == null else Vector2(track.current.x - track.target.x, track.current.y - track.target.y)
		visual.sprite.position = (ground_point(app.document_state.city, visual.tile) - ANCHOR + offset + visual.anchor_offset).round()
	material.set_shader_parameter("world_origin", visual.sprite.position + ANCHOR)
	material.set_shader_parameter("effect_kind", visual.kind)
	material.set_shader_parameter("effect_time", clock)
	material.set_shader_parameter("effect_strength", app.preferences.visual_enhancements.disaster_strength)
	material.set_shader_parameter("light_strength", app.preferences.visual_enhancements.disaster_lights)
	material.set_shader_parameter("progress", clampf(visual.age / visual.duration, 0.0, 1.0) if visual.duration > 0.0 else -1.0)
	app.map_view.layers._apply_environment(material)
	if visual.kind == HURRICANE:
		return
	var bounds := Rect2i(Vector2i(visual.sprite.position), EXTENT)
	if visual.record >= 0:
		bounds = Rect2i(Vector2i(ground_point(app.document_state.city, visual.tile) - ANCHOR) - Vector2i(48, 48), EXTENT + Vector2i(96, 96))
	material.set_shader_parameter("foreground_scale", Vector2(EXTENT) / Vector2(bounds.size))
	material.set_shader_parameter("foreground_offset", (visual.sprite.position - Vector2(bounds.position)) / Vector2(bounds.size))
	var signature := [bounds, visual.tile, app.static_render_state.epoch, app.static_render.city_view_size()]
	if signature != visual.mask_signature:
		visual.mask_signature = signature
		var mask := app.moving_sprites.effect_occluder_mask(bounds.position, bounds.size, visual.tile, app.static_render.city_view_size())
		material.set_shader_parameter("has_foreground", mask != null)
		if mask != null:
			material.set_shader_parameter("foreground", ImageTexture.create_from_image(mask))


func invalidate_occlusion(changes: Array[Rect2i]) -> void:
	for visual in markers.values():
		for rect in changes:
			if rect.intersects(Rect2i(Vector2i(visual.sprite.position), EXTENT)):
				visual.mask_signature.clear()
	for pulse in pulses:
		pulse.mask_signature.clear()


func _pulse(kind: int, tile: Vector2i, location: Vector2, duration: float, delay := 0.0, user_action := false) -> bool:
	if not active() or pulses.size() >= MAX_PULSES or not _visible(tile, location):
		return false
	var visual := _create(kind, tile, location)
	visual.duration = duration
	visual.age = -delay
	visual.user_action = user_action
	visual.sprite.visible = delay <= 0.0
	pulses.append(visual)
	return true


func consume_effects(events: Array[EffectEvent], simulation: bool) -> Array[EffectEvent]:
	_sync_city()
	if not active() or not app.preferences.visual_enhancements.disaster_dust:
		return events
	var result: Array[EffectEvent] = []
	var handled: Dictionary[Vector2i, bool] = {}
	for event in events:
		if not is_dust(event):
			result.append(event)
			continue
		if not handled.has(event.point):
			var depth := event.depth_point if event.depth_point.x >= 0 else event.point
			handled[event.point] = _pulse(DUST, depth, ground_point(app.document_state.city, event.point, event.altitude),
				1.05, maxf(0.0, event.frame * 0.1), not simulation)
		if not handled[event.point]:
			result.append(event)
	return result


func shake_view() -> void:
	app.map_view.presentation._shake_generation += 1
	_shake_remaining = SHAKE_SECONDS


static func shake_envelope(age: float) -> float:
	return smoothstep(0.0, 0.15, age) * (1.0 - smoothstep(1.3, SHAKE_SECONDS, age))


static func is_dust(event: EffectEvent) -> bool:
	return event.type.is_empty() and event.sprite_id >= 1392 and event.sprite_id <= 1395 and event.point.x >= 0


func disaster_started(result: DisasterStartResult) -> void:
	_sync_city()
	if not active() or result == null or not result.ok or not result.started:
		return
	var city := app.document_state.city
	match result.disaster_type:
		9:
			_pulse(VOLCANO, result.point, ground_point(city, result.point), 5.0)
			for x in range(maxi(0, result.point.x - 32), mini(city.map_size, result.point.x + 33)):
				for y in range(maxi(0, result.point.y - 32), mini(city.map_size, result.point.y + 33)):
					if city.building_id(x, y) == BuildingTileIds.RADIOACTIVE_WASTE:
						var tile := Vector2i(x, y)
						_pulse(RADIATION, tile, ground_point(city, tile), 5.0)
		10:
			for i in mini(result.damage_points.size(), 32):
				var tile := result.damage_points[i]
				_pulse(MICROWAVE, tile, ground_point(city, tile), 0.38, i * 0.035)
		11:
			_pulse(VOLCANO, result.point, ground_point(city, result.point), 5.0)


func _sync_storm() -> void:
	var engine := app.simulation_state.simulation_engine
	var hurricane := engine != null and engine.active_disaster_type == 16 and engine.disaster_hurricane_counter > 0
	if not hurricane:
		if _storm != null:
			_storm.sprite.queue_free()
			_storm = null
		return
	if _storm == null:
		_storm = _create(HURRICANE, Vector2i.ZERO, Vector2.ZERO)
	var bounds := app.map_view.visible_source_rect()
	_storm.sprite.position = bounds.position
	_storm.sprite.scale = bounds.size / Vector2(EXTENT)
	_update_material(_storm)


static func ground_point(city: CityState, tile: Vector2i, altitude := -1) -> Vector2:
	var height := city.object_altitude(tile.x, tile.y) if altitude < 0 else altitude
	return Vector2(32 + city.map_size * 16 + (tile.x - tile.y) * 16 + 16,
		512 + (tile.x + tile.y) * 8 - height * 12 + 8)


static func flood_edges(city: CityState, tile: Vector2i) -> Vector4:
	var result := Vector4.ONE
	var directions: Array[Vector2i] = [Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0)]
	for i in 4:
		var next := tile + directions[i]
		if city.index_of(next.x, next.y) >= 0 and (city.marker_overlay_id(next.x, next.y) == 0xfc or city.is_water(next.x, next.y)):
			result[i] = 0.0
	return result


class Visual extends RefCounted:
	var sprite: Sprite2D
	var material: ShaderMaterial
	var tile := Vector2i.ZERO
	var kind := 0
	var record := -1
	var anchor_offset := Vector2.ZERO
	var age := 0.0
	var duration := 0.0
	var user_action := false
	var mask_signature: Array = []
