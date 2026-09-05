extends SceneTree
const CommandCache = preload("res://src/view/city_dynamic_command_cache.gd")


func _initialize() -> void:
	var city := CityState.from_document(Sc2File.load_path("res://../local/large-cities/stitched-512.sc2x"))
	var sprites := Sc2SpriteArchive.load_path("res://../references/SIMCITY2000/DATA/LARGE.DAT")
	var cache := CommandCache.new()
	assert(_dynamic_command_values(cache.get_commands(city, sprites, 2, 0)) == _dynamic_command_values(CityIsometricRenderer.dynamic_draw_commands(city, sprites, 2, 0)))
	var count: int = cache.rebuilds
	cache.get_commands(city, sprites, 2, 0)
	assert(cache.rebuilds == count)

	for field in ["altitude_words", "terrain", "buildings", "zones", "text_overlays", "tile_flags"]:
		var original: int = city.get(field)[100]
		city.get(field)[100] = original ^ 1
		assert(_dynamic_command_values(cache.get_commands(city, sprites, 2, 0)) == _dynamic_command_values(CityIsometricRenderer.dynamic_draw_commands(city, sprites, 2, 0)))
		assert(cache.rebuilds > count)
		count = cache.rebuilds
		city.get(field)[100] = original

	var things := city.document.find_chunk("XTHG")
	things.decoded_payload[1] ^= 1
	assert(_dynamic_command_values(cache.get_commands(city, sprites, 2, 1)) == _dynamic_command_values(CityIsometricRenderer.dynamic_draw_commands(city, sprites, 2, 1)))
	assert(cache.rebuilds > count)
	city.visible_altitude_levels = 8
	assert(_dynamic_command_values(cache.get_commands(city, sprites, 2, 1)) == _dynamic_command_values(CityIsometricRenderer.dynamic_draw_commands(city, sprites, 2, 1)))
	_check_display_clock(city, sprites)
	print("PASS: unchanged dynamic command reuse, packed state changes, animation and cutaway parity")
	quit()


func _check_display_clock(city: CityState, sprites: Sc2SpriteArchive) -> void:
	city.visible_altitude_levels = 32
	city.text_overlays.fill(0)
	var things := city.document.find_chunk("XTHG")
	things.decoded_payload.fill(0)
	var cache := CommandCache.new()
	assert(cache.get_commands(city, sprites, 2, 0).is_empty())
	cache.get_commands(city, sprites, 2, 10)
	assert(cache.rebuilds == 1, "Display clock rebuilt a city with no animated sprites")
	assert(city.set_text_overlay_id(20, 20, 0xff))

	for phase in [0, 4, 7]:
		var expected := CityIsometricRenderer.dynamic_draw_commands(city, sprites, 2, phase)
		assert(not expected.is_empty())
		assert(_dynamic_command_values(cache.get_commands(city, sprites, 2, phase)) == _dynamic_command_values(expected))

	assert(cache.rebuilds == 4, "Special overlays stopped animating")
	assert(city.set_text_overlay_id(20, 20, OverlayData.thing_id(1)))
	var offset := CityState.THING_RECORD_SIZE
	things.decoded_payload[offset] = 6
	ThingData.write(things.decoded_payload, offset + 3, 20)
	ThingData.write(things.decoded_payload, offset + 4, 20)

	for phase in [0, 1]:
		var expected := CityIsometricRenderer.dynamic_draw_commands(city, sprites, 2, phase)
		assert(not expected.is_empty())
		assert(_dynamic_command_values(cache.get_commands(city, sprites, 2, phase)) == _dynamic_command_values(expected))

	assert(cache.rebuilds == 6, "Type 6 sprite stopped mirroring")
	assert(cache.get_commands(CityState.new(), sprites, 2, 0).is_empty())


func _dynamic_command_values(commands: Array[CityDynamicCommand]) -> Array:
	var values: Array = []

	for command in commands:
		values.append([command.sprite_id, command.flip, command.position,
			command.shadow, command.depth_order, command.record, command.overlay,
			command.static_occlusion, command.train, command.same_tile_foreground_indices])

	return values
