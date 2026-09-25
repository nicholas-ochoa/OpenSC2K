extends SceneTree
## Check fixed inputs without running the generator or reading supplied files.


func _init() -> void:
	for edge in GeneratedCityFixture.SIZES:
		var path := GeneratedCityFixture.path(edge)
		var report: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path + ".json"))
		assert(report.output_sha256 == FileAccess.get_sha256(path), "Fixture hash mismatch: " + path)
		assert(int(report.size) == edge)
		assert(report.format == ("SC2" if edge == 128 else "SC2X"))
		assert(int(report.simulation_days) == 1500 and int(report.starting_year) == 2050)
		var document := Sc2File.load_path(path)
		var coverage := GeneratedCityFixture.validate(document, edge)
		assert(not coverage.is_empty())
		# JSON stores numeric values as floats. Compare both dictionaries after JSON conversion.
		var normalized: Dictionary = JSON.parse_string(JSON.stringify(coverage))
		assert(normalized == report.counts, "Report counts must match saved data")
		assert(document.serialize(true).data == FileAccess.get_file_as_bytes(path))
		assert(CityState.from_document(document).age_in_days() == 1500)
		print("PASS: generated %d hash, format, round trip, facility records, and coverage" % edge)

	quit()
