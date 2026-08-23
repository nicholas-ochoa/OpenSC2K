extends "res://tools/benchmarks/fixture_paths.gd"

## Growth partition wall time over all sixteen step/substep partitions.
## Each partition runs on a fresh city so the scan sees identical input.

const ROUNDS := 5


func _benchmark_initialize() -> void:
	var doc := Sc2File.load_path(reference_path("CITIES/CAPEQUES.SC2"))
	var totals := PackedInt64Array()

	for round in ROUNDS:
		var elapsed := 0
		var scanned := 0

		for step in 4:
			for substep in 4:
				var city := CityState.from_document(Sc2File.load_path(reference_path("CITIES/CAPEQUES.SC2")))
				var random := SimRandom.new(1)
				var lfsr := SimLfsrRandom.new(1)
				var game := GameLcgRandom.new(1)
				var started := Time.get_ticks_usec()
				var result := GrowthScan.run(city, random, step, substep, lfsr, game)
				elapsed += Time.get_ticks_usec() - started
				scanned += result.scanned_tiles

		totals.append(elapsed)
		print("round %d: %d usec, %d tiles scanned" % [round, elapsed, scanned])

	var sorted_totals := Array(totals)
	sorted_totals.sort()
	print("growth partition best=%d usec median=%d usec" % [
		sorted_totals[0], sorted_totals[sorted_totals.size() / 2]])
	quit()


static func fixture_paths() -> PackedStringArray:
	return PackedStringArray([
		reference_path("CITIES/CAPEQUES.SC2"),
	])
