extends SceneTree

var failures := 0
var checks := 0


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)


func _initialize() -> void:
	# the native aging rule has its own unit test
	for edge in Sc2File.MAP_SIZES:
		for native in [false, true]:
			var doc := EmptyCityTemplate.create(edge)
			if native:
				doc.enable_full_resolution_maps()
			var city := CityState.from_document(doc)
			doc.set_misc_u32(0x102c, 600)
			doc.set_misc_u32(0x007c + 4 * 12, 600)
			doc.set_misc_u32(0x0084 + 4 * 12, 48000)
			var random := SimRandom.new(123)
			for month in 120:
				var result := EducationHealthPhase.run(city, random)
				check(result.ok and result.workforce_eq <= 100, "Unfunded stable city EQ does not wrap")
				for cohort in 20:
					check(doc.misc_u32(0x0080 + cohort * 12) <= doc.misc_u32(0x007c + cohort * 12) * 100,
						"Saved cohort education remains bounded during repeated decay")
	print("EQ decay regression: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
