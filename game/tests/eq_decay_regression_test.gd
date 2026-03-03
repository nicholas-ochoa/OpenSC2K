extends SceneTree

class FixedRandom extends RefCounted:
	func next_u15() -> int:
		return 32767

var failures := 0
var checks := 0


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)


func _initialize() -> void:
	for points in [0, 30, 60, 120]:
		for pro_reading in [false, true]:
			var population := PackedInt64Array()
			var education := PackedInt64Array()
			var life := PackedInt64Array()
			population.resize(20)
			education.resize(20)
			life.resize(20)
			population[4] = 60
			education[4] = points
			life[4] = 4800
			education[5] = 7
			EducationHealthPhase._apply_aging(population, education, life, 0, 0, 0,
				EducationHealthPhase.ORDINANCE_PRO_READING if pro_reading else 0, FixedRandom.new())
			var transferred := IntegerMath.div_trunc(points, 60)
			check(education[5] == 7 + (transferred if pro_reading else maxi(transferred - 1, 0)),
				"Decay floors transferred education without consuming the destination's points")
			check(education[4] == points - transferred, "Source loses only transferred points")

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
