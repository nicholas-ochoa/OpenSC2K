extends "res://tests/support/core_test_suite.gd"

## Tools: zones signs checks.

@warning_ignore_start("integer_division")

const Zones = preload("res://src/tools/city/zone_command.gd")
const Signs = preload("res://src/tools/city/sign_command.gd")


func test_zone_command(reference_root: String) -> void:
	var document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))

	for chunk_id in ["XBLD", "XTER", "XZON", "XBIT"]:
		_check(
			document.find_chunk(chunk_id).set_decoded_payload(_filled_bytes(128 * 128, 0)),
			"Zone command test clears %s" % chunk_id
		)

	var buildings := document.find_chunk("XBLD").decoded_payload.duplicate()
	buildings[11 * 128 + 11] = Tiles.ROAD_STRAIGHT_1
	_check(document.find_chunk("XBLD").set_decoded_payload(buildings), "Zone test places a road")
	var flags := document.find_chunk("XBIT").decoded_payload.duplicate()
	flags[12 * 128 + 12] = 0x04
	_check(document.find_chunk("XBIT").set_decoded_payload(flags), "Zone test places water")
	var zones := document.find_chunk("XZON").decoded_payload.duplicate()
	zones[10 * 128 + 10] = 0xa0
	zones[12 * 128 + 11] = 0x07
	_check(document.find_chunk("XZON").set_decoded_payload(zones), "Zone test installs corner and military bits")
	_check(document.set_misc_i32(0x14, 100), "Zone test sets city funds")
	var city := CityModel.from_document(document)
	_check(
		city.set_terrain_id(12, 12, 0x10),
		"Zone test gives its water tile a saved water terrain shape",
	)
	var rectangle_preview := Zones.preview_rectangle(
		city, 9, 0, Vector2i(10, 10), Vector2i(12, 12), true
	)
	_check(
		rectangle_preview.ok
		and rectangle_preview.charged_tiles == 6
		and rectangle_preview.changed_tiles == 6
		and rectangle_preview.cost == 30,
		"Zone drag preview counts only eligible changed tiles",
	)
	_check(city.set_terrain_id(10, 10, 9), "Zone click preview installs a terrain slope")
	var slope_click_preview := Zones.preview_rectangle(
		city, 9, 0, Vector2i(10, 10), Vector2i(10, 10), false
	)
	_check(
		slope_click_preview.ok
		and slope_click_preview.charged_tiles == 1
		and slope_click_preview.changed_tiles == 0
		and slope_click_preview.terrain_surcharges == 1
		and slope_click_preview.cost == 30,
		"Zone click preview includes the recovered slope surcharge",
	)
	_check(city.set_terrain_id(10, 10, 0), "Zone click preview restores flat terrain")
	_check(
		not Zones.preview_rectangle(
			city, 9, 0, Vector2i(12, 12), Vector2i(10, 10), true
		).ok,
		"Zone selection cannot start on water",
	)
	_check(
		not Zones.preview_rectangle(
			city, 9, 0, Vector2i(12, 11), Vector2i(10, 10), true
		).ok,
		"Zone selection cannot start in a military zone",
	)
	var command := Zones.apply_rectangle(city, 9, 0, Vector2i(10, 10), Vector2i(12, 12))
	_check(command.ok, "Residential zone rectangle applies: %s" % command.error)

	if not command.ok:
		return

	_check(command.zone_type == 1, "Light residential maps to zone type one")
	_check(command.tile_indices.size() == 6, "Zone command skips road, water, and military tiles")
	_check(command.cost == 30 and city.funds() == 70, "Zone command charges per changed tile")
	_check(city.zones[10 * 128 + 10] == 0xa1, "Zone command preserves building-corner bits")
	_check(city.zone_id(11, 11) == 0, "Zone command leaves a road unchanged")
	_check(city.zone_id(12, 12) == 0, "Zone command leaves water unchanged")
	_check(city.zone_id(12, 11) == 7, "Zone command leaves a military zone unchanged")
	var same_zone_preview := Zones.preview_rectangle(
		city, 9, 0, Vector2i(10, 10), Vector2i(10, 10), true
	)
	_check(
		same_zone_preview.ok and same_zone_preview.cost == 0,
		"Zone drag preview omits a tile that already has the selected zone",
	)
	var charged_click := Zones.apply_rectangle(
		city, 9, 0, Vector2i(10, 10), Vector2i(10, 10), false
	)
	_check(
		charged_click.ok
		and charged_click.cost == 5
		and charged_click.tile_indices.is_empty()
		and city.funds() == 65,
		"A true click keeps the executable's charge when the zone does not change",
	)
	_check(
		Zones.undo(city, charged_click).ok and city.funds() == 70,
		"Charge-only zone click can be undone",
	)
	var undo := Zones.undo(city, command)
	_check(undo.ok and undo.restored_tiles == 6, "Zone command undo restores all changed tiles")
	_check(city.funds() == 100, "Zone command undo restores funds")
	_check(city.zones[10 * 128 + 10] == 0xa0, "Zone command undo restores original XZON bytes")
	var later := Zones.apply_rectangle(city, 11, 1, Vector2i(10, 10), Vector2i(12, 12))
	_check(later.ok, "Later zoning command succeeds")
	_check(later.cost == 60, "Later zoning command uses changed-tile cost")
	var stale := Zones.undo(city, command)
	_check(not stale.ok, "Undo rejects a command after later zone changes")
	_check(city.set_building_id(10, 10, Tiles.RUBBLE_3), "De-zone test places rubble")
	var dezone := Zones.apply_rectangle(city, 0, 4, Vector2i(10, 10), Vector2i(12, 12))
	_check(dezone.ok and dezone.cost == 6, "De-zone removes six zones for one dollar each")
	_check(city.zone_id(10, 10) == 0, "De-zone clears the zone nibble")
	_check(city.building_id(10, 10) == 0, "De-zone clears rubble tile IDs one through four")
	var undo_dezone := Zones.undo(city, dezone)
	_check(undo_dezone.ok, "De-zone command can be undone")
	_check(city.zone_id(10, 10) == 6, "De-zone undo restores the zone")
	_check(city.building_id(10, 10) == 3, "De-zone undo restores rubble")
	_check(city.set_funds(3), "Insufficient-funds fixture sets city funds")
	var zones_before_failure := city.zones.duplicate()
	var buildings_before_failure := city.buildings.duplicate()
	var rejected := Zones.apply_rectangle(city, 10, 0, Vector2i(10, 10), Vector2i(12, 12))
	_check(not rejected.ok and rejected.cost == 30, "Zone command reports insufficient funds")
	_check(city.funds() == 3, "Rejected zone command preserves funds")
	_check(
		city.zones == zones_before_failure and city.buildings == buildings_before_failure,
		"Rejected zone command preserves map data",
	)


func test_sign_command(reference_root: String) -> void:
	var document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))
	_check(
		document.find_chunk("XTXT").set_decoded_payload(_filled_bytes(128 * 128, 0)),
		"Sign fixture clears text overlays",
	)
	var city := CityModel.from_document(document)
	_check(city.set_label(1, ""), "Sign fixture clears first user label")
	var created := Signs.set_sign(city, Vector2i(4, 5), "Harbor District")
	_check(created.ok, "Sign command creates a sign: %s" % created.error)
	_check(created.label_id == 1, "Sign command allocates the first free user label")
	_check(city.text_overlay_id(4, 5) == 1, "Sign command stores the XTXT label ID")
	_check(city.label(1) == "Harbor District", "Sign command stores XLAB text")
	var edited := Signs.set_sign(city, Vector2i(4, 5), "New Harbor")
	_check(edited.ok and edited.label_id == 1, "Sign command edits its existing label")
	_check(Signs.undo(city, edited).ok, "Sign edit can be undone")
	_check(city.label(1) == "Harbor District", "Sign undo restores the exact text")
	var removed := Signs.set_sign(city, Vector2i(4, 5), "")
	_check(removed.ok, "Empty sign text removes the sign")
	_check(city.text_overlay_id(4, 5) == 0 and city.label(1).is_empty(), "Sign removal clears XTXT and XLAB")
	_check(Signs.undo(city, removed).ok, "Sign removal can be undone")
	_check(city.text_overlay_id(4, 5) == 1 and city.label(1) == "Harbor District", "Sign removal undo restores both chunks")
	_check(city.set_text_overlay_id(9, 9, 51), "Sign fixture sets a protected label")
	var protected := Signs.set_sign(city, Vector2i(9, 9), "Blocked")
	_check(not protected.ok, "Sign command rejects a protected simulation label")
