extends "res://tools/benchmarks/fixture_paths.gd"

## Determinism probe: runs fixed-seed days on populated cities and prints a
## hash of every decoded chunk plus the three RNG states after each city.

const CITIES := [
	"CAPEQUES.SC2", "BAYVIEW.SC2", "CENTERVL.SC2", "FOURCITI.SC2",
	"AMAZINGC.SC2", "349ARCO.SC2", "BRIDGEPO.SC2", "EGYPTFAL.SC2",
]
const DAYS := 60


func _benchmark_initialize() -> void:
	var lines := PackedStringArray()

	for name: String in CITIES:
		var path := reference_path("CITIES/") + name
		var doc := Sc2File.load_path(path)

		if doc == null or not doc.is_valid():
			printerr("%s LOAD_FAILED" % name)
			quit(1)
			return

		var city := CityState.from_document(doc)
		var engine := SimulationEngine.new(city, 123, 456, 789)
		var day_hashes := PackedStringArray()

		for day in DAYS:
			var result := engine.advance_day()
			day_hashes.append("%d:%s" % [day, "ok" if result.ok else "FAIL"])

		lines.append("%s %s r=%d l=%d g=%d days=%s" % [
			name, _state_hash(city), engine.random.state,
			engine.lfsr_random.state, engine.game_random.state,
			_digest(day_hashes),
		])

	for line in lines:
		print(line)

	quit()


func _state_hash(city: CityState) -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)

	for chunk in city.document.chunks:
		ctx.update(chunk.chunk_id.to_utf8_buffer())
		ctx.update(chunk.decoded_payload if chunk.decoded_payload.size() > 0 else chunk.stored_payload)

	return ctx.finish().hex_encode()


func _digest(values: PackedStringArray) -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update("|".join(values).to_utf8_buffer())

	return ctx.finish().hex_encode().substr(0, 16)


static func fixture_paths() -> PackedStringArray:
	var paths := PackedStringArray()
	for city in CITIES:
		paths.append(reference_path("CITIES/" + city))
	return paths
