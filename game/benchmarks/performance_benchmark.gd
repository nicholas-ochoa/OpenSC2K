extends SceneTree

const Sc2Document = preload("res://src/formats/sc2_file.gd")
const CityModel = preload("res://src/model/city_state.gd")
const Palette = preload("res://src/assets/sc2_palette.gd")
const SpriteArchive = preload("res://src/assets/sc2_sprite_archive.gd")
const Renderer = preload("res://src/view/city_isometric_renderer.gd")
const RenderJob = preload("res://src/view/city_render_job.gd")


func _init() -> void:
	var reference_root := ProjectSettings.globalize_path("res://../references")
	var city := CityModel.from_document(
		Sc2Document.load_path(reference_root.path_join("CITIES/CAPEQUES.SC2"))
	)
	var index_palette := Palette.index_encoding()
	var sprites := SpriteArchive.load_path(
		reference_root.path_join("DATA/LARGE.DAT")
	)
	if not city.is_valid() or not index_palette.is_valid() or not sprites.is_valid():
		printerr("Cannot load the Capeques benchmark input.")
		quit(1)
		return

	var started := Time.get_ticks_usec()
	var asset_errors := Renderer.validate_assets(city, sprites)
	_print_measurement("asset_validation", started, asset_errors.is_empty())
	if not asset_errors.is_empty():
		printerr(asset_errors[0])
		quit(1)
		return

	started = Time.get_ticks_usec()
	var initial := Renderer.create_image(
		city, index_palette, sprites, Renderer.VIEW_LARGE, 0, false, true
	)
	_print_measurement("initial_index_render", started, initial.ok)
	if not initial.ok:
		printerr(initial.error)
		quit(1)
		return

	var job := RenderJob.new()
	job.city_snapshot = city
	job.index_palette = index_palette
	job.sprites = sprites
	started = Time.get_ticks_usec()
	var rebuilt := job.run()
	_print_measurement("warm_worker_render", started, rebuilt.ok)

	var points := PackedVector2Array()
	for x in range(0, CityModel.MAP_SIZE, 8):
		for y in range(0, CityModel.MAP_SIZE, 8):
			var polygon := Renderer.tile_polygon(city, x, y)
			points.append(
				(polygon[0] + polygon[1] + polygon[2] + polygon[3]) * 0.25
			)
	started = Time.get_ticks_usec()
	var checksum := Vector2i.ZERO
	for point in points:
		checksum += Renderer.screen_to_tile(city, point)
	var elapsed := Time.get_ticks_usec() - started
	print(
		"map_hit_test: %d us for %d points; checksum=%s"
		% [elapsed, points.size(), checksum]
	)
	quit(0 if rebuilt.ok else 1)


func _print_measurement(label: String, started: int, ok: bool) -> void:
	print("%s: %d us; ok=%s" % [label, Time.get_ticks_usec() - started, ok])
