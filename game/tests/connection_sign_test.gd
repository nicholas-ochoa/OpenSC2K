extends SceneTree
## Each neighbor connection marker shows a sign with the name of the neighbor
## on that map edge and a digit, as the original sign painter FUN_0044d9a0 does.


func _initialize() -> void:
	var city := CityState.from_document(EmptyCityTemplate.create(128))

	for slot_name in [[0, 36], [1, 1], [2, 2], [3, 3]]:
		city.document.set_misc_u32(Sc2MiscLayout.NEIGHBORS + slot_name[0] * CityNeighbors.STRIDE, slot_name[1])

	for point in [Vector2i(127, 40), Vector2i(40, 127), Vector2i(1, 43), Vector2i(11, 1), Vector2i(0, 0)]:
		assert(city.set_text_overlay_id(point.x, point.y, Sc2OverlayLayout.CONNECTION_MARKER))

	var texts := CityNeighbors.connection_sign_texts(city)
	assert(texts.size() == 5, "Each connection marker has a sign")
	assert(texts[city.index_of(127, 40)] == "Lister 5", "The high x edge names neighbor slot 0")
	assert(texts[city.index_of(40, 127)] == "Oak Creek 7", "The high y edge names neighbor slot 1")
	assert(texts[city.index_of(1, 43)] == "Denmont 9", "The low x edge names neighbor slot 2")
	assert(texts[city.index_of(11, 1)] == "Fort Verdegris 6", "The low y edge names neighbor slot 3")
	assert(texts[city.index_of(0, 0)] == "Denmont 7", "The low x edge wins at a corner")

	city.document.set_misc_u32(Sc2MiscLayout.COMPASS, 1)
	texts = CityNeighbors.connection_sign_texts(city)
	assert(texts[city.index_of(127, 40)] == "Oak Creek 5", "The compass rotation turns the neighbor slots")
	city.document.set_misc_u32(Sc2MiscLayout.COMPASS, 0)

	var map := CityMapControl.new()
	map.city = city
	map.set_signs_visible(true)
	var keys: Array[int] = []

	for entry in map.sign_source_entries():
		keys.append(entry.key)

	keys.sort()
	var expected: Array[int] = []

	for index in texts:
		expected.append(index)

	expected.sort()
	assert(keys == expected, "The map draws a sign at each connection marker")
	map.set_signs_visible(false)
	assert(map.sign_source_entries().is_empty(), "Hidden signs hide connection signs")
	map.free()

	print("PASS: connection markers show neighbor signs")
	quit()
