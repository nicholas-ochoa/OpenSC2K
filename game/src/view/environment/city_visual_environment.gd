class_name CityVisualEnvironment
extends RefCounted
## Advances only presentation time. The city and simulation clock are read-only.

var app: CityApplication
var phase := 0.5
var season_phase := 1.0
var tint := Color.WHITE
var night := 0.0
var lut: ImageTexture
var lut_size := 0.0
var profiles := CityVisualLuts.new()
var _options := {}
var _city_id := 0
var weather: CityVisualWeather
var clouds: CityVisualClouds
var night_lighting: CityNightLighting
var _whole_mask_signature: Array = []
var _whole_water_signature: Array = []


func _init(application: CityApplication) -> void:
	app = application
	weather = CityVisualWeather.new(application)
	clouds = CityVisualClouds.new(application)
	night_lighting = CityNightLighting.new(application)


func configure() -> void:
	var options := app.preferences.visual_enhancements
	if _options.get("brightmap_folder", "") != options.brightmap_folder:
		reload_brightmaps()
	if _options.get("lut_path", "") != options.lut_path:
		_load_custom_lut(options.lut_path)
	if profiles.atlases.is_empty() or _options.get("lut_folder", "") != options.lut_folder:
		profiles.reload(options.lut_folder)
	_configure_water(options)
	_configure_nature(options)
	_options = options.duplicate()
	process(0.0)


func _load_custom_lut(path: String) -> void:
	lut = null
	lut_size = 0.0
	var image := CityVisualLuts.load_strip(path)
	if image != null:
		image.convert(Image.FORMAT_RGB8)
		lut = ImageTexture.create_from_image(image)
		lut_size = image.get_height()


func reload_luts() -> void:
	if app.main_menu != null:
		app.main_menu.city_background.reload_visual_assets()
	profiles.reload(app.preferences.visual_enhancements.lut_folder)
	_load_custom_lut(app.preferences.visual_enhancements.lut_path)
	process(0.0)
	var message := "LUT profiles reloaded."
	if not profiles.issues.is_empty():
		message += "\n" + "\n".join(profiles.issues)
	if not app.preferences.visual_enhancements.lut_path.is_empty() and lut == null:
		message += "\nOptional color LUT: missing or invalid; neutral fallback"
	app.main_overlays.settings_dialog.show_visual_message(message)


func export_luts() -> void:
	var folder: String = app.preferences.visual_enhancements.lut_folder
	if folder.is_empty():
		folder = AppPaths.path("visual_luts")
	var error := CityVisualLuts.export_profiles(folder)
	if error.is_empty():
		var values := app.preferences.visual_enhancements.duplicate()
		values.lut_folder = folder
		app.main_overlays.settings_dialog.visual_tab.show_values(values)
		app.settings.apply_settings()
	app.main_overlays.settings_dialog.show_visual_message(error if not error.is_empty() else "Editable LUT profiles and neutral template exported to:\n" + folder + "\nExisting files were preserved.")


func _configure_water(options: Dictionary, refresh := true) -> void:
	var indices := CityWaterLayer.blue_indices(app.asset_state.palette)
	var changed := false
	for archive: Sc2SpriteArchive in [app.asset_state.large_sprites, app.asset_state.small_medium_sprites]:
		if archive == null:
			continue
		var enabled := VisualEnhancementOptions.water_pass_enabled(options)
		if archive.water_reflections != enabled or archive.water_indices != indices:
			archive.water_reflections = enabled
			archive.water_indices = indices
			archive.visual_revision += 1
			changed = true
	if changed and refresh and app.document_state.city != null:
		app.static_render.invalidate_rendered_city()
		app.map_render.refresh_map()


func reload_brightmaps(refresh := true) -> void:
	if refresh and app.main_menu != null:
		app.main_menu.city_background.reload_visual_assets()
	for pair in [[app.asset_state.large_sprites, "large"], [app.asset_state.small_medium_sprites, "small-medium"]]:
		var archive: Sc2SpriteArchive = pair[0]
		if archive != null:
			CityBrightmaps.load_archive(archive, app.preferences.visual_enhancements.brightmap_folder, pair[1])
			if app.asset_state.palette != null:
				CityDispatchLights.prepare(archive, app.asset_state.palette)
				CitySeasonColors.prepare(archive, app.asset_state.palette)
				if app.preferences.visual_enhancements.nature_forests_enabled or app.preferences.visual_enhancements.nature_terrain_enabled:
					CityNatureArtwork.prepare(archive, app.asset_state.palette)
					archive.visual_seasons.merge(archive.visual_nature_masks)
			archive.visual_revision += 1
	_configure_water(app.preferences.visual_enhancements, refresh)
	_configure_nature(app.preferences.visual_enhancements, refresh)
	if not refresh:
		return
	if app.map_view != null:
		app.map_view.layers._visual_materials.clear()
	if app.document_state.city != null:
		app.static_render.invalidate_rendered_city()
		app.map_render.refresh_map()


func export_brightmaps() -> void:
	var folder: String = app.preferences.visual_enhancements.brightmap_folder
	var error := CityBrightmaps.export_originals(app.asset_state.asset_source.assets, folder)
	app.assets.show_graphics_source_error(error if not error.is_empty() else "Original PNGs and transparent Brightmap templates exported to:\n" + folder, "Visual Enhancements")


func _configure_nature(options: Dictionary, refresh := true) -> void:
	var changed := false
	for archive: Sc2SpriteArchive in [app.asset_state.large_sprites, app.asset_state.small_medium_sprites]:
		if archive == null or app.asset_state.palette == null:
			continue
		if options.nature_forests_enabled or options.nature_terrain_enabled:
			CityNatureArtwork.prepare(archive, app.asset_state.palette)
			archive.visual_seasons.merge(archive.visual_nature_masks)
		if archive.visual_nature_enabled != options.nature_forests_enabled or archive.visual_terrain_enabled != options.nature_terrain_enabled:
			archive.visual_nature_enabled = options.nature_forests_enabled
			archive.visual_terrain_enabled = options.nature_terrain_enabled
			archive.visual_revision += 1
			changed = true
	if changed and refresh and app.document_state.city != null:
		app.static_render.invalidate_rendered_city()
		app.map_render.refresh_map()


func _nature_projection() -> Basis:
	var city := app.document_state.city
	if city == null:
		return Basis.IDENTITY
	var scale := app.map_view.camera._view_scale()
	var offset := app.map_view.camera._draw_offset(scale)
	var canvas := app.map_view.get_global_transform() * Transform2D(Vector2(scale, 0), Vector2(0, scale), offset)
	return CityVisualClouds.shader_basis(CityVisualClouds.source_to_grid(city.map_size, city.compass_rotation()) * canvas.affine_inverse())


func process(delta: float) -> void:
	if app.map_view == null:
		return
	var city := app.document_state.city
	var active := city != null and app.view_state.overlay_mode == CityViewMode.Mode.CITY and not app.tool_state.landscape_editor
	if city != null and city.document.get_instance_id() != _city_id:
		_city_id = city.document.get_instance_id()
		phase = 0.5
		season_phase = 1.0
		weather.reset()
		profiles.reset()
		clouds.reset()
		night_lighting.reset()
	var options := app.preferences.visual_enhancements
	var speed := app.simulation_state.speed_controller.speed if app.simulation_state.speed_controller != null else 1
	var elapsed := maxf(delta, 0.0)
	var paused := speed == GameSpeedController.Speed.PAUSED or app.frame._simulation_suspended()
	if options.pause_freezes and paused:
		elapsed = 0.0
	var weather_delta := 0.0 if paused else maxf(delta, 0.0)
	var factor := VisualEnhancementOptions.speed_factor(speed) if options.speed_link and speed > 1 else 1.0
	if active and options.day_enabled and options.day_mode == 0:
		phase = fposmod(phase + elapsed * factor / float(options.day_seconds), 1.0)
	var hour := phase * 24.0 if options.day_mode == 0 else float(options.day_hour)
	var lighting := light_at_hour(hour, options.night_strength)
	if active and options.season_enabled and options.season_mode == 1:
		season_phase = fposmod(season_phase + elapsed * factor * 4.0 / float(options.season_seconds), 4.0)
	var season := season_phase
	if options.season_mode == 0 and city != null:
		season = fposmod(float(city.age_in_days() % CityCalendar.DAYS_PER_YEAR) / CityCalendar.DAYS_PER_YEAR * 4.0 - 2.0 / 3.0, 4.0)
	elif options.season_mode == 2:
		season = float(options.season_fixed)
	var previous_weather := weather.kind
	weather.process(delta, weather_delta * factor, active, season, paused)
	if profiles.atlases.is_empty():
		profiles.reload(options.lut_folder)
	var grading_delta: float = options.weather_transition if paused and weather.kind != previous_weather else weather_delta
	profiles.advance_weather(weather.kind, grading_delta, options.weather_transition, active and options.weather_enabled)
	var daytime_lights: bool = options.brightmaps and options.night_daytime_enabled
	# The auxiliary mask also identifies fullbright warning icons, even with
	# all environment effects disabled.
	if active:
		_sync_whole_masks()
	if active and VisualEnhancementOptions.water_pass_enabled(options):
		_sync_whole_water()
	tint = lighting.tint if options.day_enabled else Color.WHITE
	var ambient_night: float = lighting.night if options.day_enabled else 0.0
	# Artificial lights can stay on without changing daylight, grading or cloud shadows.
	var light_level := 1.0 if daytime_lights else ambient_night
	night = light_level * float(options.night_light_strength) / 100.0 if options.brightmaps else 0.0
	clouds.process(delta, weather_delta * factor, active, tint * weather.tint, lighting.night if options.day_enabled else 0.0, weather.kind)
	weather.set_cloud_cover(clouds.precipitation_readiness)
	var parameters := {
		"nature_terrain_enabled": active and options.nature_terrain_enabled,
		"nature_terrain_strength": options.nature_terrain_strength,
		"nature_forests_enabled": active and options.nature_forests_enabled,
		"nature_ground": CityNatureArtwork.ground_texture(),
		"nature_canvas_to_grid": _nature_projection(),
		"water_enabled": active and VisualEnhancementOptions.water_pass_enabled(options),
		"water_reflections_enabled": active and options.water_reflections == 1,
		"water_topography": options.water_topography,
		"water_waves_enabled": options.water_waves_enabled,
		"water_season_strength": options.season_water_strength if active and options.season_enabled else 0.0,
		"water_rain": weather.rain * clouds.precipitation_readiness,
		"water_frozen": options.pause_freezes and (speed == 1 or app.frame._simulation_suspended()),
		"environment_enabled": active and (options.day_enabled or options.season_enabled or options.weather_enabled or daytime_lights),
		"environment_weather": Vector3(weather.tint.r, weather.tint.g, weather.tint.b),
		"environment_frost": weather.frost,
		"environment_seasons": CitySeasonColors.weights(season, options.season_transition) if options.season_enabled else Vector4(0, 1, 0, 0),
		"environment_tint": Vector3(tint.r, tint.g, tint.b),
		"environment_saturation": lerpf(1.0, 0.78, ambient_night),
		"environment_night": night,
		"environment_ambient_lift": float(options.night_ambient) / 100.0 * ambient_night,
		"environment_lut": lut,
		"environment_lut_size": lut_size,
	}
	parameters.merge(clouds.parameters)
	parameters.merge(profiles.parameters(options, hour, parameters.environment_seasons, app.map_view.get_viewport().use_hdr_2d))
	app.map_view.layers.set_environment(parameters)
	if app.map_view.layers.dynamic_canvas != null:
		var detail := VisualEnhancementOptions.detail_lights_visible(options, app.map_view.zoom_factor)
		var changed := detail != app.map_view.layers.dynamic_canvas.detail_lights_visible
		app.map_view.layers.dynamic_canvas.set_detail_lights_visible(detail)
		if changed and active:
			# Restore or remove moving emission masks even when simulation is paused.
			app.moving_sprites.refresh_moving_things()
	# Appearance fades finish in real time, also when the simulation is paused.
	night_lighting.process(active, night, options, elapsed * factor, maxf(delta, 0.0))
	if clouds.layer != null and clouds.layer.visible:
		app.map_view.layers._apply_environment(clouds.material)


func _sync_whole_water() -> void:
	if app.render_caches.region_cache != null or app.map_view.city_source == null or app.render_caches.static_display_city == null or app.map_view.layers.water_layer == null:
		return
	var source := app.map_view.city_source
	var view := app.static_render.city_view_size()
	var sprites := app.static_render.sprite_archive_for_view(view)
	var signature := [source.get_instance_id(), app.static_render_state.epoch, sprites.visual_revision, view]
	if signature == _whole_water_signature:
		return
	_whole_water_signature = signature
	var context := CityGpuBuildContext.new()
	var error := context.prepare(app.render_caches.static_display_city, app.asset_state.palette_index_encoding, sprites,
		view, CityViewMode.Mode.CITY, true, true, true, 0, false)
	if not error.is_empty():
		return
	app.map_view.layers.water_layer.configure_whole(context, sprites, CityIsometricRenderer.view_configuration(view).divisor,
		source.get_instance_id())
	app.map_view.layers._sync_base_layer()


func _sync_whole_masks() -> void:
	# CPU cities up to 128 retain the existing whole-image/patch renderer.
	# Auxiliary masks follow its publication epoch without replacing that path.
	if app.render_caches.region_cache != null or app.map_view.city_source == null or app.render_caches.static_display_city == null:
		return
	var source := app.map_view.city_source
	var view := app.static_render.city_view_size()
	var sprites := app.static_render.sprite_archive_for_view(view)
	var signature := [source.get_instance_id(), app.static_render_state.epoch, sprites.visual_revision]
	if signature == _whole_mask_signature:
		return
	_whole_mask_signature = signature
	var city := app.render_caches.static_display_city
	var context := CityGpuBuildContext.new()
	var error := context.prepare(city, app.asset_state.palette_index_encoding, sprites, view, CityViewMode.Mode.CITY, true, true, true, 0, false)
	if not error.is_empty():
		return
	var bounds := Rect2i(Vector2i.ZERO, CityIsometricRenderer.output_size_for_view(view, city.map_size))
	for pair in [[sprites.visual_emission, "emission"], [sprites.visual_seasons, "seasons"]]:
		var artwork: Dictionary = {}
		artwork.merge(pair[0])
		var image: Image = context.builder.auxiliary_raster(bounds, artwork)
		if image == null:
			source.set(pair[1], null)
			for tile in source.tiles:
				tile.set(pair[1], null)
			continue
		if image.get_size() != source.size:
			image.resize(source.size.x, source.size.y, Image.INTERPOLATE_NEAREST)
		if source.texture != null:
			source.set(pair[1], ImageTexture.create_from_image(image))
		for tile in source.tiles:
			var part := image.get_region(Rect2i(Vector2i(tile.position), Vector2i(tile.size)))
			tile.set(pair[1], ImageTexture.create_from_image(part))
	app.map_view.layers._tiled_source = null
	app.map_view.layers._sync_base_layer()


static func light_at_hour(hour: float, strength := 1.0) -> Dictionary:
	var h := fposmod(hour, 24.0)
	var keys := [0.0, 5.0, 7.0, 10.0, 16.0, 19.0, 22.0, 24.0]
	var colors := [Color(0.28, 0.34, 0.52), Color(0.28, 0.34, 0.52), Color(0.86, 0.93, 1.04),
		Color.WHITE, Color.WHITE, Color(1.06, 0.83, 0.57), Color(0.28, 0.34, 0.52), Color(0.28, 0.34, 0.52)]
	var levels := [1.0, 1.0, 0.1, 0.0, 0.0, 0.45, 1.0, 1.0]
	for i in range(keys.size() - 1):
		if h <= keys[i + 1]:
			var weight := smoothstep(keys[i], keys[i + 1], h)
			return {"tint": Color.WHITE.lerp(colors[i].lerp(colors[i + 1], weight), clampf(strength, 0.0, 1.0)),
				"night": lerpf(levels[i], levels[i + 1], weight)}
	return {"tint": Color.WHITE, "night": 0.0}
