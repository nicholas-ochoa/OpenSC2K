extends SceneTree
const CommandCache = preload("res://src/view/city_dynamic_command_cache.gd")

func _initialize() -> void:
	var city := CityState.from_document(Sc2File.load_path("res://../local/large-cities/stitched-512.sc2x"))
	var sprites := Sc2SpriteArchive.load_path("res://../references/DATA/LARGE.DAT")
	var cache := CommandCache.new()
	assert(cache.get_commands(city, sprites, 2, 0) == CityIsometricRenderer.dynamic_draw_commands(city, sprites, 2, 0))
	var count: int = cache.rebuilds
	cache.get_commands(city, sprites, 2, 0)
	assert(cache.rebuilds == count)
	for field in ["altitude_words", "terrain", "buildings", "zones", "text_overlays", "tile_flags"]:
		var original: int = city.get(field)[100]
		city.get(field)[100] = original ^ 1
		assert(cache.get_commands(city, sprites, 2, 0) == CityIsometricRenderer.dynamic_draw_commands(city, sprites, 2, 0))
		assert(cache.rebuilds > count)
		count = cache.rebuilds
		city.get(field)[100] = original
	var things := city.document.find_chunk("XTHG")
	things.decoded_payload[1] ^= 1
	assert(cache.get_commands(city, sprites, 2, 1) == CityIsometricRenderer.dynamic_draw_commands(city, sprites, 2, 1))
	assert(cache.rebuilds > count)
	city.visible_altitude_levels = 8
	assert(cache.get_commands(city, sprites, 2, 1) == CityIsometricRenderer.dynamic_draw_commands(city, sprites, 2, 1))
	print("PASS: unchanged dynamic command reuse, packed state changes, animation and cutaway parity")
	quit()
