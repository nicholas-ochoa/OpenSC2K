extends SceneTree

const TestRandoms = preload("res://tests/support/test_randoms.gd")
const DocumentState = preload("res://tests/support/document_state.gd")
const OFFSETS := [Vector2i.ZERO, Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1)]


func _initialize() -> void:
	# 0x00463c40 selects the axis from the section flags, not the deck/pylon ID.
	for horizontal in [false, true]:
		for first_tile in [0x6a, 0x6b]:
			check_span(Vector2i(2, 20), horizontal, first_tile)

	check_span(Vector2i(122, 20), true, 0x6a)
	check_span(Vector2i(2, 122), false, 0x6b)
	check_mixed_span()
	check_banks()
	check_single_width_banks()
	check_funded_bridge()
	check_tool_undo()
	print("PASS: bridge collapse axes, banks, underground counts, debris, map edges and undo")
	quit()


func fixture() -> Dictionary:
	var city := CityState.from_document(EmptyCityTemplate.create(128))
	var p: Dictionary = {}
	p.merge(GrowthState.payloads(city))
	p.ALTM.fill(0)
	p.XTER.fill(0)
	p.XBIT.fill(0)
	p.XZON.fill(0)
	p.XBLD.fill(0)
	p.XUND.fill(0)
	BinaryData.write_u32_be(p.MISC, 0x01f0, 16384)
	BinaryData.write_u32_be(p.MISC, Sc2MiscLayout.WATER_LEVEL, 0)

	for budget in range(10, 16):
		BinaryData.write_u32_be(p.MISC, 0x077c + budget * 0x6c + 4, 100)

	BinaryData.write_u32_be(p.MISC, 0x077c + 12 * 0x6c + 4, 0)
	p.city = city
	return p


func store(p: Dictionary) -> CityState:
	var city: CityState = p.city

	for chunk_id in p:
		if chunk_id != "city":
			assert(city.document.find_chunk(chunk_id).set_decoded_payload(p[chunk_id]))

	city.resync_mirrors(CityState.MIRRORED_CHUNKS)
	return city


func section(p: Dictionary, anchor: Vector2i, tile: int, horizontal: bool) -> void:
	for offset in OFFSETS:
		var point: Vector2i = anchor + offset
		var index := point.x * 128 + point.y
		NetworkState.replace_building(p.XBLD, p.XZON, p.MISC, index, tile)
		p.XBIT[index] = 6 if horizontal else 4
		p.XTER[index] = TerrainTileIds.DEEP_WATER_FLAT

	BuildingSites.set_corners(p.XZON, Rect2i(anchor, Vector2i(2, 2)), 2, 0)


func check_span(anchor: Vector2i, horizontal: bool, first_tile: int) -> void:
	var p := fixture()
	var direction := Vector2i(2, 0) if horizontal else Vector2i(0, 2)

	for part in 3:
		section(p, anchor + direction * part, first_tile if part != 1 else (0xd5 - first_tile), horizontal)

	var city := store(p)
	var result := GrowthScan.run(city, TestRandoms.ZeroRandom.new(), 3, 0, TestRandoms.ZeroLfsrRandom.new())
	assert(result.ok and result.collapsed_bridges == 1)
	assert(result.bridge_effects.size() == 12, "Every connected section emits four debris effects")

	for part in 3:
		for offset in OFFSETS:
			var point: Vector2i = anchor + direction * part + offset
			assert(city.building_id(point.x, point.y) == 0, "The complete span collapses along its flags")

	assert(city.document.misc_u32(0x01f0 + 0x6a * 4) == 0)
	assert(city.document.misc_u32(0x01f0 + 0x6b * 4) == 0)
	assert(result.view_center_requests.size() == 1 and result.news_items.size() == 1)
	assert(SoundEvent.same_arrays(result.sound_events, SoundEvent.from_ids([504])))
	var offsets := [Vector2i.ZERO, Vector2i(16, -8), Vector2i(32, 0), Vector2i(16, 8)]

	for i in 4:
		assert(result.bridge_effects[i].screen_offset == offsets[i], "Debris follows the original two-wide layout")


func check_mixed_span() -> void:
	var p := fixture()
	section(p, Vector2i(2, 20), 0x6a, true)

	for anchor in [Vector2i(4, 20), Vector2i(6, 20)]:
		section(p, anchor, 0x4a, true)

		for offset in OFFSETS:
			var point: Vector2i = anchor + offset
			p.XZON[point.x * 128 + point.y] = 0xf0

	var city := store(p)
	var result := GrowthScan.run(city, TestRandoms.ZeroRandom.new(), 3, 0, TestRandoms.ZeroLfsrRandom.new())
	assert(result.ok and result.collapsed_bridges == 1 and result.bridge_effects.size() == 12)
	assert(city.document.misc_u32(0x01f0 + 0x4a * 4) == 0, "The original classifier includes connected water highway sections")


func check_banks() -> void:
	var p := fixture()
	section(p, Vector2i(2, 20), 0x6b, true)
	var banks := [Vector2i(0, 20), Vector2i(4, 20)]

	for bank in banks:
		for i in 4:
			var point: Vector2i = bank + OFFSETS[i]
			var index := point.x * 128 + point.y
			p.ALTM[index * 2 + 1] = 5
			BuildingUnderground._replace_underground(p.XUND, p.XZON, p.MISC, index, [1, 0x10, 0x1f, 0x23][i])

	# A station at the rear bank also exercises labels during the growth commit.
	var rear_index := 20
	NetworkState.replace_building(p.XBLD, p.XZON, p.MISC, rear_index, BuildingTileIds.SUBWAY_STATION)
	p.XZON[rear_index] = 0xf0
	OverlayData.write(p.XTXT, rear_index, 1)
	p.XLAB[CityState.LABEL_RECORD_SIZE] = 65

	# The forward bank is a complete highway section. Terrain processing must
	# demolish the full structure, then clear the underground in all four cells.
	for offset in OFFSETS:
		var point: Vector2i = banks[1] + offset
		var index := point.x * 128 + point.y
		NetworkState.replace_building(p.XBLD, p.XZON, p.MISC, index, 0x49)
		p.XZON[index] = 0xf0

	var city := store(p)
	var result := GrowthScan.run(city, TestRandoms.ZeroRandom.new(), 3, 0, TestRandoms.ZeroLfsrRandom.new())
	assert(result.ok and result.collapsed_bridges == 1)

	for bank in banks:
		for offset in OFFSETS:
			var point: Vector2i = bank + offset
			assert(city.land_altitude(point.x, point.y) == 5, "Reinforced bridge banks are not lowered")
			assert(city.underground_id(point.x, point.y) == 0, "Both complete bank sections lose underground infrastructure")

	assert(city.document.misc_u32(0x0fe8) == 0, "Bank removal updates the subway count")
	assert(city.document.misc_u32(0x01f0 + 0x49 * 4) == 0, "Bank highway demolition updates all four tile counts")
	assert(city.document.misc_u32(0x01f0 + 0xe9 * 4) == 0)
	assert(city.text_overlay_id(0, 20) == 0)
	assert(city.document.find_chunk("XLAB").decoded_payload[CityState.LABEL_RECORD_SIZE] == 0, "Growth saves the released bank label")


func check_single_width_banks() -> void:
	var p := fixture()
	var index := 3 * 128 + 20
	NetworkState.replace_building(p.XBLD, p.XZON, p.MISC, index, 0x51)
	p.XBIT[index] = 6

	for point in [Vector2i(2, 20), Vector2i(4, 20)]:
		index = point.x * 128 + point.y
		p.ALTM[index * 2 + 1] = 5
		BuildingUnderground._replace_underground(p.XUND, p.XZON, p.MISC, index, 1)

	var city := store(p)
	var result := GrowthScan.run(city, TestRandoms.ZeroRandom.new(), 3, 0, TestRandoms.ZeroLfsrRandom.new())
	assert(result.ok and result.collapsed_bridges == 1)

	for point in [Vector2i(2, 20), Vector2i(4, 20)]:
		assert(city.land_altitude(point.x, point.y) == 4, "Single-width banks still lose one altitude level")
		assert(city.underground_id(point.x, point.y) == 0)

	assert(city.document.misc_u32(0x0fe8) == 0)


func check_funded_bridge() -> void:
	var p := fixture()
	section(p, Vector2i(2, 20), 0x6a, true)
	BinaryData.write_u32_be(p.MISC, 0x077c + 12 * 0x6c + 4, 100)
	var city := store(p)
	var result := GrowthScan.run(city, TestRandoms.ZeroRandom.new(), 3, 0, TestRandoms.ZeroLfsrRandom.new())
	assert(result.ok and result.collapsed_bridges == 0 and result.bridge_effects.is_empty())
	assert(city.building_id(3, 20) == 0x6a)


func check_tool_undo() -> void:
	var p := fixture()
	section(p, Vector2i(2, 20), 0x6a, true)
	section(p, Vector2i(4, 20), 0x6b, true)
	BuildingUnderground._replace_underground(p.XUND, p.XZON, p.MISC, 20, 1)
	var city := store(p)
	assert(city.set_funds(100))
	var before: Array = DocumentState.capture(city.document)
	var random := SimRandom.new(17)
	var command := DemolishEdit.apply_path(city, DemolishConstants.GROUP_BULLDOZER, DemolishConstants.SUBTOOL_DEMOLISH, [Vector2i(3, 20)], random)
	assert(command.ok, command.error)
	assert(city.building_id(5, 20) == 0 and city.underground_id(0, 20) == 0)
	assert(DemolishEdit.undo(city, command, random).ok)
	assert(DocumentState.capture(city.document) == before and random.state == 17, "Undo restores the span, both banks and random state")
