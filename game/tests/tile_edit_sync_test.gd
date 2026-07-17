extends SceneTree
## Tile edits update the saved chunk and the CityState mirror together.
## Check that rejected edits leave both copies unchanged.

# Narrow byte overlays at 128, and the wide SC2X two-plane layout at 256.
const EDGES := [128, 256]
const MIRRORS := {
	"XTER": "terrain", "XBLD": "buildings", "XZON": "zones",
	"XUND": "underground", "XTXT": "text_overlays", "XBIT": "tile_flags",
}

var checks := 0
var failures := 0


func _init() -> void:
	for edge in EDGES:
		check_layout(edge)
		check_mutators(edge)
		check_rejections(edge)
		print("PASS: tile edit cases completed at %d" % edge)

	check_flag_signature_cache()
	print("Tile edit sync: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func check(ok: bool, label: String) -> void:
	checks += 1

	if not ok:
		failures += 1
		push_error(label)
		print("FAIL: %s" % label)


func fixture(edge: int) -> CityState:
	var city := CityState.from_document(EmptyCityTemplate.create(edge))
	check(city.is_valid(), "Fixture city at %d is valid: %s" % [edge, city.load_error])

	return city


# The XTXT layout the mutator has to detect, stated where the cases can read it.
func check_layout(edge: int) -> void:
	var city := fixture(edge)
	var cells := edge * edge
	var wide := edge > 128
	check(city.text_overlays.size() == cells * (2 if wide else 1),
		"Overlay payload at %d uses the expected plane count" % edge)
	check(OverlayData.count(city.text_overlays) == cells,
		"Overlay cell count at %d matches the map area" % edge)


func check_mutators(edge: int) -> void:
	var city := fixture(edge)
	var overlay_id := 0x1234 if edge > 128 else 0x2a

	# Both corners plus an interior tile. index_of is x * map_size + y, so the
	# corners are the first and last cell of every plane.
	for point in [Vector2i(0, 0), Vector2i(7, 11), Vector2i(edge - 1, edge - 1)]:
		var index := city.index_of(point.x, point.y)
		apply(city, "set_terrain_id", city.set_terrain_id(point.x, point.y, 0x1e),
			city.terrain_id(point.x, point.y) == 0x1e, index, edge)
		apply(city, "set_building_id", city.set_building_id(point.x, point.y, 0x1d),
			city.building_id(point.x, point.y) == 0x1d, index, edge)
		apply(city, "set_underground_id", city.set_underground_id(point.x, point.y, 0x05),
			city.underground_id(point.x, point.y) == 0x05, index, edge)

		# Zones and corners share one byte with complementary masks. Write both
		# and prove neither mutator clears the other's nibble.
		apply(city, "set_zone_id", city.set_zone_id(point.x, point.y, 0x03),
			city.zone_id(point.x, point.y) == 0x03, index, edge)
		apply(city, "set_building_corners", city.set_building_corners(point.x, point.y, 0x50),
			city.building_corners(point.x, point.y) == 0x50, index, edge)
		check(city.zone_id(point.x, point.y) == 0x03,
			"Corner bits keep the zone nibble at %d %s" % [edge, point])
		apply(city, "set_zone_id", city.set_zone_id(point.x, point.y, 0x06),
			city.zone_id(point.x, point.y) == 0x06, index, edge)
		check(city.building_corners(point.x, point.y) == 0x50,
			"Zone bits keep the corner nibble at %d %s" % [edge, point])

		apply(city, "set_text_overlay_id", city.set_text_overlay_id(point.x, point.y, overlay_id),
			city.text_overlay_id(point.x, point.y) == overlay_id, index, edge)

		if edge > 128:
			# The high byte of a wide ID lives one whole plane past the low byte.
			var cells := edge * edge
			check(city.text_overlays[index] == 0x34 and city.text_overlays[cells + index] == 0x12,
				"Wide overlay writes both planes at %d %s" % [edge, point])

		apply(city, "set_tile_flag", city.set_tile_flag(point.x, point.y, 0x41, true),
			city.tile_flags[index] == 0x41, index, edge)
		apply(city, "set_tile_flag", city.set_tile_flag(point.x, point.y, 0x01, false),
			city.tile_flags[index] == 0x40, index, edge)

		apply(city, "set_land_altitude", city.set_land_altitude(point.x, point.y, 0x0b),
			city.land_altitude(point.x, point.y) == 0x0b, index, edge)
		apply(city, "set_water_altitude", city.set_water_altitude(point.x, point.y, 0x07),
			city.water_altitude(point.x, point.y) == 0x07, index, edge)
		apply(city, "set_tunnel_levels", city.set_tunnel_levels(point.x, point.y, 0x25),
			city.tunnel_levels(point.x, point.y) == 0x25, index, edge)
		check(city.land_altitude(point.x, point.y) == 0x0b
			and city.water_altitude(point.x, point.y) == 0x07,
			"Altitude fields share one word without clobbering at %d %s" % [edge, point])

	# Repeat the same writes and check that the mirrors still agree.
	check(city.set_building_id(7, 11, 0x1d) and city.set_zone_id(7, 11, 0x06)
		and city.set_land_altitude(7, 11, 0x0b),
		"A redundant tile edit still reports success at %d" % edge)
	check(planes_match(city), "A redundant tile edit keeps the mirror in sync at %d" % edge)
	check(every_altitude_word_matches(city),
		"Every altitude word matches the ALTM payload at %d" % edge)


# One mutator call: it succeeded, it reads back, and both sides still agree.
func apply(city: CityState, label: String, wrote: bool, reads_back: bool, index: int, edge: int) -> void:
	check(wrote, "%s writes at %d index %d" % [label, edge, index])
	check(reads_back, "%s reads back at %d index %d" % [label, edge, index])
	check(planes_match(city), "%s keeps the mirrored planes in sync at %d index %d" % [label, edge, index])
	check(altitude_word_matches(city, index),
		"%s keeps the mirrored altitude word in sync at %d index %d" % [label, edge, index])


# A rejected edit writes nothing, so no payload changes and no chunk repaints.
func check_rejections(edge: int) -> void:
	var city := fixture(edge)
	check(city.set_terrain_id(3, 4, 0x11) and city.set_zone_id(3, 4, 0x02)
		and city.set_building_corners(3, 4, 0x30) and city.set_tile_flag(3, 4, 0x80, true)
		and city.set_text_overlay_id(3, 4, 0x2a) and city.set_land_altitude(3, 4, 0x0c),
		"Rejection fixture at %d starts from written tiles" % edge)
	var payloads := {}
	var revisions := {}

	for chunk_id in MIRRORS.keys() + ["ALTM"]:
		var chunk := city.document.find_chunk(chunk_id)
		payloads[chunk_id] = chunk.decoded_payload.duplicate()
		revisions[chunk_id] = chunk.mutation_revision

	var words := city.altitude_words.duplicate()
	var outside := [Vector2i(-1, 0), Vector2i(0, -1), Vector2i(edge, 0), Vector2i(0, edge)]

	for point in outside:
		check(not city.set_terrain_id(point.x, point.y, 1), "Terrain rejects %s at %d" % [point, edge])
		check(not city.set_building_id(point.x, point.y, 1), "Building rejects %s at %d" % [point, edge])
		check(not city.set_zone_id(point.x, point.y, 1), "Zone rejects %s at %d" % [point, edge])
		check(not city.set_building_corners(point.x, point.y, 0x10), "Corners reject %s at %d" % [point, edge])
		check(not city.set_underground_id(point.x, point.y, 1), "Underground rejects %s at %d" % [point, edge])
		check(not city.set_text_overlay_id(point.x, point.y, 1), "Overlay rejects %s at %d" % [point, edge])
		check(not city.set_tile_flag(point.x, point.y, 1, true), "Tile flag rejects %s at %d" % [point, edge])
		check(not city.set_land_altitude(point.x, point.y, 1), "Land altitude rejects %s at %d" % [point, edge])
		check(not city.set_water_altitude(point.x, point.y, 1), "Water altitude rejects %s at %d" % [point, edge])
		check(not city.set_tunnel_levels(point.x, point.y, 1), "Tunnel levels reject %s at %d" % [point, edge])

	check(not city.set_terrain_id(3, 4, 0x100), "Terrain rejects an oversize ID at %d" % edge)
	check(not city.set_building_id(3, 4, -1), "Building rejects a negative ID at %d" % edge)
	check(not city.set_underground_id(3, 4, 0x100), "Underground rejects an oversize ID at %d" % edge)
	check(not city.set_zone_id(3, 4, 0x10), "Zone rejects an ID outside its nibble at %d" % edge)
	check(not city.set_building_corners(3, 4, 0x11), "Corners reject low-nibble bits at %d" % edge)
	check(not city.set_building_corners(3, 4, 0xf1), "Corners reject a mixed byte at %d" % edge)
	check(not city.set_tile_flag(3, 4, 0x100, true), "Tile flag rejects an oversize mask at %d" % edge)
	check(not city.set_text_overlay_id(3, 4, 0x10000 if edge > 128 else 0x100),
		"Overlay rejects an ID beyond its storage at %d" % edge)
	check(not city.set_land_altitude(3, 4, 0x20), "Land altitude rejects an oversize level at %d" % edge)
	check(not city.set_water_altitude(3, 4, 0x20), "Water altitude rejects an oversize level at %d" % edge)
	check(not city.set_tunnel_levels(3, 4, 0x40), "Tunnel levels reject an oversize value at %d" % edge)

	for chunk_id in payloads:
		var chunk := city.document.find_chunk(chunk_id)
		check(chunk.decoded_payload == payloads[chunk_id],
			"A rejected edit leaves %s alone at %d" % [chunk_id, edge])
		check(chunk.mutation_revision == revisions[chunk_id],
			"A rejected edit keeps the %s revision at %d" % [chunk_id, edge])

	check(city.altitude_words == words, "A rejected edit leaves the altitude words alone at %d" % edge)
	check(planes_match(city), "A rejected edit keeps the mirror in sync at %d" % edge)


# masked_tile_flag_signature caches on the content of the mirrored flag array.
# In-place writes change that content, so the cache still invalidates.
func check_flag_signature_cache() -> void:
	var city := fixture(128)
	var before := city.masked_tile_flag_signature(0xc6)
	check(city.masked_tile_flag_signature(0xc6) == before,
		"A repeated masked flag signature reuses its cache")
	check(city.set_tile_flag(9, 9, 0x04, true), "Flag signature fixture sets a visible flag")
	check(city.masked_tile_flag_signature(0xc6) != before,
		"An in-place flag write invalidates the masked signature cache")
	var visible := city.masked_tile_flag_signature(0xc6)
	check(city.set_tile_flag(9, 9, 0x08, true), "Flag signature fixture sets a masked-out flag")
	check(city.masked_tile_flag_signature(0xc6) == visible,
		"A flag outside the mask keeps the masked signature")


func planes_match(city: CityState) -> bool:
	for chunk_id in MIRRORS:
		var chunk := city.document.find_chunk(chunk_id)

		if chunk == null or chunk.decoded_payload != city.get(MIRRORS[chunk_id]):
			return false

	return true


func altitude_word_matches(city: CityState, index: int) -> bool:
	var payload := city.document.find_chunk("ALTM").decoded_payload

	if payload.size() != city.altitude_words.size() * 2:
		return false

	return city.altitude_words[index] == ((payload[index * 2] << 8) | payload[index * 2 + 1])


func every_altitude_word_matches(city: CityState) -> bool:
	var payload := city.document.find_chunk("ALTM").decoded_payload

	if payload.size() != city.altitude_words.size() * 2:
		return false

	for index in city.altitude_words.size():
		if city.altitude_words[index] != ((payload[index * 2] << 8) | payload[index * 2 + 1]):
			return false

	return true
