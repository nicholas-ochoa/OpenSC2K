extends SceneTree
var cache: CityRegionCache
var city: CityState
var sprites: Sc2SpriteArchive
var medium: Sc2SpriteArchive
var palette := Sc2Palette.index_encoding()
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	city = CityState.from_document(Sc2File.load_path("res://../local/large-cities/stitched-512.sc2x"))
	sprites = Sc2SpriteArchive.load_path("res://../references/DATA/LARGE.DAT")
	medium = Sc2SpriteArchive.combine([Sc2SpriteArchive.load_path("res://../references/DATA/SMALLMED.DAT"), Sc2SpriteArchive.load_path("res://../references/DATA/SPECIAL.DAT")])
	cache = CityRegionCache.new()
	configure([1])
	var viewport := Rect2(7300, 4000, 1600, 900)
	cache.update_viewport(viewport)
	var first_requested := cache.wanted.duplicate()
	var first_published := Vector2i(-1, -1)
	var deadline := Time.get_ticks_msec() + 30000
	while not cache.ready() and Time.get_ticks_msec() < deadline:
		cache.tick()
		if first_published.x < 0 and not cache.entries.is_empty():
			first_published = cache.entries.keys()[0]
		assert(cache.last_error.is_empty())
		await process_frame
	assert(cache.ready())
	assert(first_published == first_requested[0], "Paint the visible center first")
	assert(cache.completed_regions == cache.visible.size(), "Do not complete off-screen work before visible regions")
	var before_bytes := int(cache.metrics().cpu_image_bytes)
	assert(before_bytes <= (cache.visible.size() + cache.OFFSCREEN_LIMIT) * 512 * 512 * 2)
	var saved: PackedByteArray = city.document.serialize().data
	for jump in 5:
		cache.update_viewport(Rect2(viewport.position + Vector2(jump * 1000, jump * 200), viewport.size))
		cache.tick()
		assert(cache.entries.size() <= cache.visible.size() + cache.OFFSCREEN_LIMIT)
		for key in cache.entries:
			assert(key in cache.wanted, "Evict distant regions")
		await process_frame
	# Change the view while a job runs, then check that its old result is discarded.
	configure([2], 1)
	cache.update_viewport(viewport)
	deadline = Time.get_ticks_msec() + 30000
	while not cache.ready() and Time.get_ticks_msec() < deadline:
		cache.tick()
		await process_frame
	assert(cache.ready() and cache.last_error.is_empty())
	for entry: Dictionary in cache.entries.values():
		assert(entry.generation == cache.generation)
		assert(not entry.has("display_city"), "Region still holds an old city snapshot")
		assert(entry.image.get_width() <= 512 and entry.image.get_height() <= 512)
		var p: Vector2i = entry.bounds.position * cache.divisor
		assert(cache.pixel(p) == entry.image.get_pixel(0, 0), "Native pixel sampling uses display scale")
	# Sample across native-pixel and chunk boundaries, including unaligned display coordinates.
	var sample_bounds := Rect2i(Vector2i(viewport.position) + Vector2i(31, 17), Vector2i(541, 289))
	var sampled := cache.image_region(sample_bounds)
	for y in range(0, sampled.get_height(), 7):
		for x in range(0, sampled.get_width(), 11):
			assert(sampled.get_pixel(x, y) == cache.pixel(sample_bounds.position + Vector2i(x, y)))
	cache.entries.clear()
	var revision := 3
	deadline = Time.get_ticks_msec() + 15000
	while not cache.covered() and Time.get_ticks_msec() < deadline:
		configure([revision], 1)
		revision += 1
		cache.tick()
		await process_frame
	assert(cache.covered(), "Visible region never finished during simulation")
	deadline = Time.get_ticks_msec() + 30000
	while not cache.ready() and Time.get_ticks_msec() < deadline:
		cache.tick()
		await process_frame
	assert(cache.ready())
	var keys := cache.entries.keys()
	assert(keys.size() >= 3)
	var dirty: Rect2i = cache.entries[keys[0]].bounds
	cache.entries[keys[1]].generation = cache.generation - 1
	var stale_generation: int = cache.entries[keys[1]].generation
	var retained_texture: Texture2D = cache.entries[keys[2]].texture
	configure([100000], 1, dirty)
	assert(cache.entries[keys[1]].generation == stale_generation, "A local edit cannot mark an older simulation region current")
	assert(cache.entries[keys[2]].generation == cache.generation and cache.entries[keys[2]].texture == retained_texture, "Local edit replaced an unaffected region")
	var expected_signs := PackedInt32Array()
	for index in city.map_size * city.map_size:
		if OverlayData.is_sign(OverlayData.read(city.text_overlays, index)):
			expected_signs.append(index)
	var actual_signs := OverlayData.sign_indices(city.text_overlays)
	actual_signs.sort()
	assert(actual_signs == expected_signs, "Indexed signs match a complete scan")
	assert(city.document.serialize().data == saved, "Rendering cannot mutate the source city")
	cache.update_viewport(Rect2(-10000, -10000, 10, 10))
	assert(cache.entries.is_empty())
	cache.close()
	print("PASS: visible-first scheduling, bounded residency, pan eviction, zoom invalidation, native sampling, continuous updates and indexed signs")
	quit()
func configure(signature: Array, view := 2, dirty := Rect2i()) -> void:
	var archive := sprites if view == 2 else medium
	cache.configure(city, palette, archive, signature, view, "city", CityViewFilter.DEFAULT_VISIBILITY, true, true, dirty)
