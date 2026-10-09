extends RefCounted
## The golden corpus: hashes of the results of the game for fixed inputs. The
## migration of GDScript rules to the native crates must keep each value. The
## hashes are SHA-256 over byte streams that any language can make again:
##
## - `file`: the bytes of a file.
## - `zip`: the members of a ZIP archive in archive order. Each member adds its
##   name, a line feed, the decimal length, a line feed, and its bytes. The
##   compressed bytes are not part of it, because compressors differ.
## - `chunks`: the chunks of a city document in document order. Each chunk adds
##   its four-letter id, the decimal length of the decoded payload, a line
##   feed, and the decoded payload.
## - `image`: the width and height as decimal text, a line feed, and the RGBA8 pixels.
##
## Values marked `gdscript_` hash GDScript text, such as JSON of result objects.
## They hold only until the code that makes the text moves to Rust.

@warning_ignore_start("integer_division")

const TimingResults = preload("res://tests/support/timing_results.gd")
const REFERENCE := "res://../references/SIMCITY2000"
const FIXTURES := "res://tests/fixtures/cities"
const GOLDEN_PATH := "res://tests/fixtures/corpus/golden.json"
const SEEDS := [123, 456, 789]
const FIXTURE_DAYS := 60
const SUPPLIED_DAYS := 30
# supplied cities that also run days. They have growth, disasters and transit
const SUPPLIED_DAY_CITIES := ["BAYVIEW.SC2", "CAPE.SC2", "HAWAII.SC2", "LASVEGAS.SC2"]
const RENDER_VIEWS := [0, 1, 2]
const RENDER_MODES := ["city", "underground"]


static func reference_path(relative := "") -> String:
	return ProjectSettings.globalize_path(REFERENCE).path_join(relative)


static func has_reference() -> bool:
	return FileAccess.file_exists(reference_path("SIMCITY.EXE"))


# the inputs: the committed fixtures, then the supplied cities and scenarios
static func input_paths() -> PackedStringArray:
	var paths := PackedStringArray()

	for edge in GeneratedCityFixture.SIZES:
		paths.append(ProjectSettings.globalize_path(GeneratedCityFixture.path(edge)))

	paths.append(reference_path("DEFAULT.SC2"))

	for folder in ["CITIES", "SCENARIO"]:
		var names := DirAccess.get_files_at(reference_path(folder))
		names.sort()

		for name in names:
			if name.get_extension().to_upper() in ["SC2", "SCN"]:
				paths.append(reference_path(folder.path_join(name)))

	return paths


static func sha256(data: PackedByteArray) -> String:
	var hashing := HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	hashing.update(data)

	return hashing.finish().hex_encode()


static func zip_hash(bytes: PackedByteArray) -> String:
	var decoded := ZipArchive.decode(bytes, Sc2xDocument.MAX_ARCHIVE_BYTES, Sc2xDocument.MAX_DATA_BYTES)

	if not decoded.ok:
		return "error: " + decoded.error

	var stream := PackedByteArray()

	for name in decoded.order:
		var data: PackedByteArray = decoded.members[name]
		stream.append_array(("%s\n%d\n" % [name, data.size()]).to_utf8_buffer())
		stream.append_array(data)

	return sha256(stream)


static func chunks_hash(document: Sc2File) -> String:
	var stream := PackedByteArray()

	for chunk in document.chunks:
		stream.append_array(("%s%d\n" % [chunk.chunk_id, chunk.decoded_payload.size()]).to_utf8_buffer())
		stream.append_array(chunk.decoded_payload)

	return sha256(stream)


static func saved_hash(document: Sc2File, bytes: PackedByteArray) -> String:
	return zip_hash(bytes) if document.is_sc2x() else sha256(bytes)


static func image_hash(image: Image) -> String:
	var copy := image.duplicate() as Image
	copy.convert(Image.FORMAT_RGBA8)
	var stream := ("%d %d\n" % [copy.get_width(), copy.get_height()]).to_utf8_buffer()
	stream.append_array(copy.get_data())

	return sha256(stream)


# load, save and SC2X conversion of each input
static func capture_files() -> Dictionary:
	var result := {}

	for path in input_paths():
		var entry := {"file": FileAccess.get_sha256(path)}
		var document := Sc2File.load_path(path)

		if document == null or not document.is_valid():
			entry.load = "invalid"
			result[path.get_file()] = entry

			continue

		entry.chunks = chunks_hash(document)
		var saved := document.serialize(true)
		entry.saved = saved_hash(document, saved.data) if saved.ok else "error: " + saved.error

		if not document.is_sc2x():
			var converted := Sc2xDocument.from_legacy(document, path.get_file().get_basename())

			if converted.ok:
				var encoded := Sc2xDocument.encode(converted.document)
				entry.sc2x = zip_hash(encoded.data) if encoded.ok else "error: " + encoded.error
				entry.sc2x_issues = Array(converted.issues)
			else:
				entry.sc2x = "error: " + converted.error

		result[path.get_file()] = entry

	return result


# fixed-seed days, as tools/benchmarks/determinism_probe.gd runs them
static func capture_days() -> Dictionary:
	var result := {}
	var runs: Array = []

	for edge in GeneratedCityFixture.SIZES:
		runs.append([ProjectSettings.globalize_path(GeneratedCityFixture.path(edge)), FIXTURE_DAYS])

	for name: String in SUPPLIED_DAY_CITIES:
		runs.append([reference_path("CITIES".path_join(name)), SUPPLIED_DAYS])

	for run: Array in runs:
		result[String(run[0]).get_file()] = _run_days(run[0], run[1])

	return result


static func _run_days(path: String, days: int) -> Dictionary:
	var document := Sc2File.load_path(path)
	var city := CityState.from_document(document)
	var engine := SimulationEngine.new(city, SEEDS[0], SEEDS[1], SEEDS[2])
	var day_texts := PackedStringArray()
	var schedules := PackedStringArray()

	for day in days:
		var outcome := engine.advance_day()

		if not outcome.ok:
			return {"error": "day %d: %s" % [day, outcome.error]}

		day_texts.append(JSON.stringify(TimingResults.without_timings(outcome)))
		schedules.append(",".join(outcome.applied))

		while not engine.pending_interaction.is_empty():
			outcome = _resolve_interaction(engine)

			if not outcome.ok:
				return {"error": "interaction on day %d: %s" % [day, outcome.error]}

			day_texts.append(JSON.stringify(TimingResults.without_timings(outcome)))

	var saved := city.document.serialize(true)

	return {
		"days": days,
		"age": city.age_in_days(),
		"funds": city.funds(),
		"chunks": chunks_hash(city.document),
		"saved": saved_hash(city.document, saved.data) if saved.ok else "error: " + saved.error,
		"random": engine.random.state,
		"lfsr_random": engine.lfsr_random.state,
		"game_random": engine.game_random.state,
		"schedules": sha256("|".join(schedules).to_utf8_buffer()),
		"gdscript_days": sha256("|".join(day_texts).to_utf8_buffer()),
	}


static func _resolve_interaction(engine: SimulationEngine) -> SimulationDayResult:
	match engine.pending_interaction:
		"annual_budget":
			return engine.resolve_annual_budget(BudgetPhase.funding_values(engine.city), engine.city.auto_budget_enabled())
		"military_proposal":
			return engine.resolve_military_proposal(false)

	return SimulationDayResult.failure("unsupported interaction: " + engine.pending_interaction)


# the terrain and the founding records of new cities
static func capture_new_cities() -> Dictionary:
	var result := {}
	var cases := {
		"classic-128": _options(128, "classic", [], false),
		"island-128": _options(128, "island", [], false),
		"canyon-native-128": _options(128, "classic", ["canyon"], true),
		"classic-256": _options(256, "classic", [], false),
		"bay-native-256": _options(256, "classic", ["bay", "meander"], true),
	}

	for key: String in cases:
		var options: NewCityTerrain.Options = cases[key]
		var session := NewCityTerrainSession.new()
		session.begin(SEEDS[0] + key.length(), SEEDS[1])
		var preview := session.generate_preview(options, false)

		if not preview.ok:
			result[key] = {"error": preview.error}

			continue

		var created := session.create_city("Corpus", "Mayor", 2, 1950, options, PackedByteArray())

		if not created.ok:
			result[key] = {"preview": chunks_hash(preview.document), "error": created.error}

			continue

		result[key] = {"preview": chunks_hash(preview.document), "city": chunks_hash(created.document)}

	return result


static func _options(size: int, layout: String, features: Array[String], native_maps: bool) -> NewCityTerrain.Options:
	var options := NewCityTerrain.Options.new()
	options.size = size
	options.layout = layout
	options.features = features
	options.native_maps = native_maps

	return options


# the City Map images of each mode, and whole-city images of the CPU painter
static func capture_images(graphics: GraphicsPack) -> Dictionary:
	var result := {}
	var paths := [ProjectSettings.globalize_path(GeneratedCityFixture.path(128)), reference_path("CITIES/BAYVIEW.SC2")]

	for path: String in paths:
		var city := CityState.from_document(Sc2File.load_path(path))
		var entry := {}

		for mode: String in CityMinimap.MODES:
			entry["minimap_" + mode] = image_hash(CityMinimap.create_image(city, graphics.palette, mode))

		for view: int in RENDER_VIEWS:
			var sprites := graphics.small_medium_sprites if view < 2 else graphics.large_sprites

			for mode: String in RENDER_MODES:
				var options := ScurkCityOutput.Options.new()
				options.view = mode
				options.moving_things = true
				options.special_overlays = true
				var rendered := ScurkCityOutput.render(city, graphics.palette, sprites, view, options)
				entry["render_%s_%d" % [mode, view]] = image_hash(rendered.image) if rendered.ok else "error: " + rendered.error

		result[path.get_file()] = entry

	return result


static func capture() -> Dictionary:
	var graphics := GraphicsPack.load_root(ProjectSettings.globalize_path("res://../ext/graphics"))

	return {
		"format": "opensc2k-golden-corpus",
		"version": 1,
		"files": capture_files(),
		"days": capture_days(),
		"new_cities": capture_new_cities(),
		"images": capture_images(graphics),
	}


# the differences between two corpus values, as readable paths. Keys that
# start with `gdscript_` are skipped unless `include_gdscript` is set
static func differences(expected: Variant, actual: Variant, path := "", include_gdscript := false) -> PackedStringArray:
	var found := PackedStringArray()

	if expected is Dictionary and actual is Dictionary:
		for key: Variant in expected:
			if str(key).begins_with("gdscript_") and not include_gdscript:
				continue

			if not actual.has(key):
				found.append("%s/%s: missing" % [path, key])
			else:
				found.append_array(differences(expected[key], actual[key], "%s/%s" % [path, key], include_gdscript))

		for key: Variant in actual:
			if not expected.has(key):
				found.append("%s/%s: not in the corpus" % [path, key])

		return found

	# JSON keeps numbers as floats
	if JSON.stringify(expected) != JSON.stringify(actual):
		found.append("%s: expected %s, got %s" % [path, JSON.stringify(expected), JSON.stringify(actual)])

	return found
