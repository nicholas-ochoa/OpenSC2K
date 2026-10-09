class_name CityHazardAnimation
extends RefCounted
## Display-only sprite loops and short-lived fire afterimages. Never writes city data.

const FRAME_SECONDS := 0.1
const FADE_IN := 0.25
const FADE_OUT := 0.35
const MAX_ENTRIES := 512
var app: CityApplication
var clock := 0.0
var entries: Dictionary[int, Entry] = {}
var seen: Dictionary[int, bool] = {}
var signature: Array = []


func _init(application: CityApplication) -> void:
	app = application


func active() -> bool:
	var options := app.preferences.visual_enhancements
	return options.disaster_enabled and options.disaster_blending and app.document_state.city != null \
		and app.map_view != null and app.map_view.city_source != null \
		and app.view_state.overlay_mode == CityViewMode.Mode.CITY and not app.tool_state.landscape_editor


func frozen() -> bool:
	var controller := app.simulation_state.speed_controller
	return app.preferences.visual_enhancements.pause_freezes and controller != null \
		and (controller.speed == GameSpeedController.Speed.PAUSED or app.frame._simulation_suspended())


func process(delta: float) -> void:
	if not active():
		if not entries.is_empty():
			app.moving_sprites.refresh_moving_things()
		return
	if not frozen():
		clock += clampf(delta, 0.0, 0.25)
	var expired := false
	for entry in entries.values():
		entry.animation.phase = fposmod(clock / FRAME_SECONDS, 8.0)
		entry.animation.opacity = envelope(entry)
		expired = expired or (entry.retired >= 0.0 and entry.animation.opacity <= 0.0)
	if expired:
		app.moving_sprites.refresh_moving_things()
	if not entries.is_empty() and app.map_view.layers.dynamic_canvas != null:
		app.map_view.layers.dynamic_canvas.queue_redraw()


func begin() -> void:
	seen.clear()
	var city := app.document_state.city
	var next: Array = [] if not active() else [city.document.get_instance_id(), city.compass_rotation(),
		city.visible_altitude_levels, app.static_render.city_view_size(), app.asset_state.palette]
	if next != signature:
		entries.clear()
		signature = next


func observe(command: CityDynamicCommand, archive: Sc2SpriteArchive, view: int) -> CityDynamicVisual:
	if not active() or command.overlay not in [0xff, 0xfb]:
		return null
	var entry: Entry = entries.get(command.depth_order)
	if entry != null and entry.overlay != command.overlay:
		entries.erase(command.depth_order)
		entry = null
	if entry == null:
		if entries.size() >= MAX_ENTRIES:
			return null
		entry = Entry.new()
		entry.overlay = command.overlay
		entry.born = clock
		entry.tile = IsometricFloatingOcclusion.depth_tile(command.depth_order, app.document_state.city.map_size)
		entry.visual = CityDynamicVisual.new()
		entry.visual.depth_order = command.depth_order
		entry.visual.hazard_animation = entry.animation
		entry.visual.fullbright = command.overlay == 0xff
		entries[command.depth_order] = entry
	var style := app.disaster_effects.cloud_style(entry.tile) if command.overlay == 0xfb else 0
	entry.visual.toxic_cloud = style == 1
	entry.visual.warm_cloud = style == 2
	# A renewed fire reverses its fade continuously.
	if entry.retired >= 0.0:
		entry.start_opacity = entry.animation.opacity
		entry.born = clock
		entry.retired = -1.0
	seen[command.depth_order] = true
	var key := [archive.get_instance_id(), archive.visual_revision, view,
		app.document_state.city.object_altitude(entry.tile.x, entry.tile.y)]
	if entry.source_signature != key:
		if not _build(entry, archive, view):
			entries.erase(command.depth_order)
			return null
		entry.source_signature = key
	_refresh_mask(entry)
	entry.animation.phase = fposmod(clock / FRAME_SECONDS, 8.0)
	entry.animation.opacity = envelope(entry)
	return entry.visual


func finish(visuals: Array[CityDynamicVisual]) -> void:
	var city := app.document_state.city
	for order in entries.keys():
		if seen.has(order):
			continue
		var entry := entries[order]
		var bounds := Rect2(entry.visual.position, entry.visual.size)
		if not active() or entry.overlay != 0xff or not city.tile_is_visible(entry.tile.x, entry.tile.y) \
				or not app.map_view.visible_source_rect().intersects(bounds) \
				or city.marker_overlay_id(entry.tile.x, entry.tile.y) != 0:
			entries.erase(order)
			continue
		if entry.retired < 0.0:
			entry.retired = clock
			entry.retired_opacity = entry.animation.opacity
		entry.animation.opacity = envelope(entry)
		if entry.animation.opacity <= 0.0:
			entries.erase(order)
			continue
		_refresh_mask(entry)
		# Preserve painter order, including dispatch sprites at the same depth.
		var index := 0
		while index < visuals.size() and visuals[index].depth_order <= order:
			index += 1
		visuals.insert(index, entry.visual)


func envelope(entry: Entry) -> float:
	if entry.overlay != 0xff:
		return 1.0
	if entry.retired >= 0.0:
		return entry.retired_opacity * (1.0 - smoothstep(0.0, FADE_OUT, clock - entry.retired))
	return lerpf(entry.start_opacity, 1.0, smoothstep(0.0, FADE_IN, clock - entry.born))


func _build(entry: Entry, archive: Sc2SpriteArchive, view: int) -> bool:
	var city := app.document_state.city
	var configuration := CityIsometricRenderer.view_configuration(view)
	var frames: Array[CitySpriteResource] = []
	var positions: Array[Vector2i] = []
	var bounds := Rect2i()
	for phase in 8:
		var source := IsometricStaticVisuals.special_overlay_visual(city, entry.tile.x, entry.tile.y, view, phase)
		var command := IsometricDynamicCommands.special_overlay_draw_command(city, archive, entry.tile, source, configuration)
		if command == null:
			return false
		var resource := app.moving_sprites.dynamic_sprite_resource(archive, command.sprite_id, command.flip, configuration.divisor)
		if resource == null:
			return false
		frames.append(resource)
		positions.append(command.position * configuration.divisor)
		var rect := Rect2i(positions[-1], resource.native_size)
		bounds = rect if phase == 0 else bounds.merge(rect)
	entry.original = Image.create(bounds.size.x, bounds.size.y * 8, false, Image.FORMAT_RGBA8)
	for phase in 8:
		entry.original.blit_rect(frames[phase].image, Rect2i(Vector2i.ZERO, frames[phase].native_size),
			positions[phase] - bounds.position + Vector2i(0, bounds.size.y * phase))
	entry.visual.position = Vector2(bounds.position)
	entry.visual.size = Vector2(bounds.size)
	entry.mask_epoch = -1
	_refresh_mask(entry)
	return true


func _refresh_mask(entry: Entry) -> void:
	if entry.mask_epoch == app.static_render_state.epoch:
		return
	entry.mask_epoch = app.static_render_state.epoch
	var size := Vector2i(entry.visual.size)
	var position := Vector2i(entry.visual.position)
	var mask := app.moving_sprites.effect_occluder_mask(position, size, entry.tile, app.static_render.city_view_size())
	var image := entry.original
	if mask != null:
		image = entry.original.duplicate()
		for phase in 8:
			var frame := entry.original.get_region(Rect2i(0, size.y * phase, size.x, size.y))
			var clipped := CityIsometricRenderer.occlude_dynamic_with_mask(frame, mask, position).image
			image.blit_rect(clipped, Rect2i(Vector2i.ZERO, size), Vector2i(0, size.y * phase))
	entry.visual.texture = ImageTexture.create_from_image(image)


class Entry extends RefCounted:
	var animation := CitySpriteFrameBlend.new()
	var start_opacity := 0.0
	var visual: CityDynamicVisual
	var tile := Vector2i.ZERO
	var overlay := 0
	var born := 0.0
	var retired := -1.0
	var retired_opacity := 1.0
	var source_signature: Array = []
	var mask_epoch := -1
	var original: Image
