extends SceneTree

@warning_ignore_start("integer_division")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var large := Sc2SpriteArchive.load_path("res://../references/SIMCITY2000/DATA/LARGE.DAT")
	var small := Sc2SpriteArchive.combine([Sc2SpriteArchive.load_path("res://../references/SIMCITY2000/DATA/SMALLMED.DAT"), Sc2SpriteArchive.load_path("res://../references/SIMCITY2000/DATA/SPECIAL.DAT")])
	var palette := Sc2Palette.index_encoding()

	for edge in [128, 512]:
		var path := "res://../references/SIMCITY2000/CITIES/SYDNEY.SC2" if edge == 128 else "res://../local/large-cities/stitched-512.sc2x"
		var city := CityState.from_document(Sc2File.load_path(path))

		for view in [0, 1, 2]:
			var sprites := large if view == 2 else small
			var cache := CityRegionCache.new()
			cache.gpu_enabled = true
			cache.configure(city, palette, sprites, [1], view, CityViewMode.Mode.CITY, {}, true, true)
			var origin := Vector2i((cache.native_size / 2) / CityRegionCache.GPU_REGION_EDGE) * CityRegionCache.GPU_REGION_EDGE * cache.divisor
			var bounds := Rect2i(origin - Vector2i(13, 9), Vector2i(83, 127))
			cache.set_sign_requests([
				CitySignRequest.new(1, bounds, -1),
				CitySignRequest.new(2, bounds, edge * edge * 2),
			])
			cache.update_viewport(Rect2(bounds).grow(64))
			var deadline := Time.get_ticks_msec() + 30000

			while not cache.ready() and Time.get_ticks_msec() < deadline:
				cache.tick()
				assert(cache.last_error.is_empty())
				await process_frame

			assert(cache.ready())
			var masks: Array[CitySignForeground.Mask] = []
			var images := {}

			for command in cache.occlusion_candidates(bounds):
				var mask := CityIsometricRenderer.sprite_image(sprites, palette, images, command.sprite_id, command.flip)

				if cache.divisor > 1:
					mask = mask.duplicate()
					mask.resize(mask.get_width() * cache.divisor, mask.get_height() * cache.divisor, Image.INTERPOLATE_NEAREST)

				masks.append(CitySignForeground.Mask.new(mask, command.position * cache.divisor))

			var expected := CitySignForeground.static_pixels(cache.image_region(bounds), masks, bounds)
			var actual := cache.sign_foreground(1, bounds, -1)
			assert(actual != null and actual.get_data() == expected.get_data(), "Worker sign pixels differ from main-thread output")
			assert(cache.sign_foreground(2, bounds, edge * edge * 2).is_invisible())
			assert(cache.sign_foreground(1, bounds, 99) == null)
			assert(cache.sign_foreground(1, Rect2i(bounds.position, Vector2i(1, 1)), -1) == null)
			cache.close()

	print("PASS: worker sign masks match main-thread composition across borders, zoom scaling, empty masks and stale requests")
	quit()
