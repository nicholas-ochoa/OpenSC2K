extends "res://tools/benchmarks/fixture_paths.gd"
## CPU overlay preparation only. Fixture creation and route analysis are untimed.

const Fixtures = preload("res://tests/support/trip_overlay_fixtures.gd")
const BATCHES := {"road": 100, "mixed": 20, "modes": 100, "dense_128": 1, "dense_512": 1}


func _benchmark_initialize() -> void:
	var samples := int(OS.get_environment("CITY_BENCH_SAMPLES")) if OS.has_environment("CITY_BENCH_SAMPLES") else 5
	var warmup := int(OS.get_environment("CITY_BENCH_WARMUP")) if OS.has_environment("CITY_BENCH_WARMUP") else 2
	if samples < 1 or warmup < 0:
		printerr("Invalid sample or warmup count")
		quit(1)
		return

	report_metadata({"samples": samples, "warmup": warmup, "batches": BATCHES,
		"timed_work": "overlay construction and rebuild; excludes analysis and drawing"})
	for fixture: Fixtures.Fixture in [Fixtures.road(), Fixtures.mixed(), Fixtures.modes(), Fixtures.dense(128), Fixtures.dense(512)]:
		var saved := fixture.city.document.serialize(true)
		if not saved.ok or not fixture.result.ok:
			printerr("Cannot prepare the %s fixture" % fixture.name)
			quit(1)
			return
		var expected := ""
		print("FIXTURE ", JSON.stringify({"name": fixture.name, "map_edge": fixture.city.map_size,
			"city_sha256": bytes_sha256(saved.data), "nodes": fixture.result.reachable.size(), "links": fixture.result.links.size()}))
		for sample in range(-warmup, samples):
			var overlay: TripReachOverlay
			var started := Time.get_ticks_usec()
			for batch in BATCHES[fixture.name]:
				overlay = TripReachOverlay.new()
				overlay.rebuild(fixture.city, fixture.result)
			var elapsed := Time.get_ticks_usec() - started
			var digest := Fixtures.digest(overlay)
			if expected.is_empty():
				expected = digest
			elif digest != expected:
				printerr("Repeated %s overlays changed geometry or colors" % fixture.name)
				quit(1)
				return
			if sample >= 0:
				print(JSON.stringify({"fixture": fixture.name, "sample": sample,
					"usec_per_rebuild": float(elapsed) / BATCHES[fixture.name], "overlay_sha256": digest}))
	quit()


static func fixture_paths() -> PackedStringArray:
	return PackedStringArray(["res://src/view/trip_reach_overlay.gd", "res://tests/support/trip_overlay_fixtures.gd",
		"res://tests/support/trip_query_fixture.gd"])
