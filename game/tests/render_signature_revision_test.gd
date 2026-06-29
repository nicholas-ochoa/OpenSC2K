extends SceneTree
## The render change signature reads chunk revisions instead of hashing the map.
## Prove that it never misses a drawn change and that a running simulation does
## not invalidate it while the drawn city stays the same.

const CITY_PATH := "res://../references/SIMCITY2000/CITIES/SYDNEY.SC2"
const DAY_COUNT := 24

# Chunks whose revision replaced a whole-map content hash in the signature.
const SURFACE_CHUNKS := ["ALTM", "XTER", "XBLD", "XZON", "XTRF"]
const UNDERGROUND_CHUNKS := ["ALTM", "XTER", "XUND"]

var failures := 0


func _initialize() -> void:
	var city := CityState.from_document(Sc2File.load_path(CITY_PATH))
	check(city.is_valid(), "The supplied city loads: %s" % city.load_error)
	check(
		CityIsometricRenderer.static_visual_signature(city) == CityIsometricRenderer.static_visual_signature(city),
		"Reading the signature twice without an edit reports no change",
	)
	check(
		CityUndergroundView.visual_signature(city, CityIsometricRenderer.VIEW_LARGE)
		== CityUndergroundView.visual_signature(city, CityIsometricRenderer.VIEW_LARGE),
		"Reading the underground signature twice without an edit reports no change",
	)
	_check_edits(city)
	_check_view_state(city)
	_check_quiet_phases()
	_check_simulation_run()
	print("Render signature checks: %d failures" % failures)
	quit(1 if failures else 0)


# Check one tile edit for each chunk used by the render signature.
func _check_edits(city: CityState) -> void:
	var edits := [
		["ALTM", func() -> bool: return city.set_land_altitude(40, 40, 6)],
		["XTER", func() -> bool: return city.set_terrain_id(41, 41, 0x1e)],
		["XBLD", func() -> bool: return city.set_building_id(42, 42, 0x1d)],
		["XZON", func() -> bool: return city.set_zone_id(43, 43, 3)],
		["XBIT", func() -> bool: return city.set_tile_flag(44, 44, 0x40, (city.tile_flags[city.index_of(44, 44)] & 0x40) == 0)],
		["XTXT", func() -> bool: return city.set_text_overlay_id(45, 45, 1)],
	]

	for edit in edits:
		var before := CityIsometricRenderer.static_visual_signature(city)
		check(edit[1].call(), "Signature fixture edits %s" % edit[0])
		check(
			CityIsometricRenderer.static_visual_signature(city) != before,
			"A %s tile edit invalidates the drawn city" % edit[0],
		)

	var underground_before := CityUndergroundView.visual_signature(city, CityIsometricRenderer.VIEW_LARGE)
	check(city.set_underground_id(46, 46, 0x01), "Signature fixture edits XUND")
	check(
		CityUndergroundView.visual_signature(city, CityIsometricRenderer.VIEW_LARGE) != underground_before,
		"An XUND tile edit invalidates the underground view",
	)


# View state is not stored in a chunk. It keeps its own signature entries.
func _check_view_state(city: CityState) -> void:
	var before := CityIsometricRenderer.static_visual_signature(city)
	check(
		CityIsometricRenderer.static_visual_signature(city, CityIsometricRenderer.VIEW_MEDIUM) != before,
		"A changed view size invalidates the drawn city",
	)
	var stored_rotation := city.document.misc_u32(0x08)
	var rotated := (stored_rotation & ~0x03) | ((city.compass_rotation() + 1) & 0x03)
	check(city.document.set_misc_u32(0x08, rotated), "Signature fixture rotates the compass")
	check(
		CityIsometricRenderer.static_visual_signature(city) != before,
		"A compass rotation invalidates the drawn city",
	)
	check(city.document.set_misc_u32(0x08, stored_rotation), "Signature fixture restores the compass")
	var levels := city.visible_altitude_levels
	city.visible_altitude_levels = levels - 1
	check(
		CityIsometricRenderer.static_visual_signature(city) != before,
		"A changed visible altitude range invalidates the drawn city",
	)
	city.visible_altitude_levels = levels


# Redundant writes advance chunk revisions and trigger repaints. Check
# that empty traffic decay and a month without tree growth leave revisions alone.
func _check_quiet_phases() -> void:
	var city := CityState.from_document(Sc2File.load_path(CITY_PATH))
	var traffic := city.document.find_chunk("XTRF")
	var empty := PackedByteArray()
	empty.resize(traffic.decoded_payload.size())
	check(traffic.set_decoded_payload(empty), "Traffic fixture clears the traffic map")
	var revision := traffic.mutation_revision
	check(TrafficPhase.run(city).get("ok", false), "The traffic phase runs on a quiet city")
	check(
		traffic.mutation_revision == revision,
		"Decaying an empty traffic map keeps the XTRF revision",
	)
	check(traffic.decoded_payload == empty, "The quiet traffic phase leaves the map alone")
	empty[0] = 0xff
	check(traffic.set_decoded_payload(empty), "Traffic fixture adds one busy tile")
	revision = traffic.mutation_revision
	check(TrafficPhase.run(city).get("ok", false), "The traffic phase runs on a busy city")
	check(
		traffic.mutation_revision != revision,
		"Decaying real traffic invalidates the drawn city",
	)


# Compare signature changes with changes to the drawn chunks over a simulation run.
func _check_simulation_run() -> void:
	var city := CityState.from_document(Sc2File.load_path(CITY_PATH))
	var engine := SimulationEngine.new(city, 123, 456, 789)
	var signature := CityIsometricRenderer.static_visual_signature(city)
	var underground := CityUndergroundView.visual_signature(city, CityIsometricRenderer.VIEW_LARGE)
	var content := _content_signature(city)
	var missed := 0
	var spurious := 0
	var underground_spurious := 0
	var changed_days := 0

	for day in DAY_COUNT:
		check(engine.advance_day().get("ok", false), "Simulation day %d advances" % day)
		check(
			engine.advance_moving_things(day * 200).get("ok", false),
			"Moving things advance on day %d" % day,
		)
		var next_signature := CityIsometricRenderer.static_visual_signature(city)
		var next_underground := CityUndergroundView.visual_signature(city, CityIsometricRenderer.VIEW_LARGE)
		var next_content := _content_signature(city)

		if next_content != content:
			changed_days += 1

			if next_signature == signature:
				missed += 1
		elif next_signature != signature:
			spurious += 1

		if next_content.underground == content.underground and next_underground != underground:
			underground_spurious += 1

		signature = next_signature
		underground = next_underground
		content = next_content

	check(changed_days > 0, "The simulation run changes the drawn city at least once")
	check(missed == 0, "Every drawn change invalidates the signature; missed %d" % missed)
	check(
		spurious == 0,
		"An unchanged drawn city keeps the signature; %d of %d days repainted for nothing"
		% [spurious, DAY_COUNT],
	)
	check(
		underground_spurious == 0,
		"An unchanged underground keeps its signature; %d spurious days" % underground_spurious,
	)


# What the replaced hashes covered: the payload bytes the signature stands for.
func _content_signature(city: CityState) -> Dictionary:
	var result := {"flags": city.masked_tile_flag_signature(0xc6), "overlays": CityIsometricRenderer._static_text_overlay_signature(city)}

	for chunk_id in SURFACE_CHUNKS + UNDERGROUND_CHUNKS:
		var chunk := city.document.find_chunk(chunk_id)
		result[chunk_id] = hash(chunk.decoded_payload) if chunk != null else 0

	result["underground"] = [result.ALTM, result.XTER, result.XUND, city.masked_tile_flag_signature(0x30)]

	return result


func check(passed: bool, message: String) -> void:
	if passed:
		return

	failures += 1
	push_error("FAIL: %s" % message)
	print("FAIL: %s" % message)
