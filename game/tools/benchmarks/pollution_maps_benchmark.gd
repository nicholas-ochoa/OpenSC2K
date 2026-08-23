extends "res://tools/benchmarks/fixture_paths.gd"


## Read-only legacy coarse-map scan timing. Pass a city path after --.
## Each trial reloads the document so every scan reads identical input.
func _benchmark_initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var trials := int(args[1]) if args.size() > 1 else 5
	var samples := []
	var digest := ""
	var edge := 0

	for trial in trials:
		var load_began := Time.get_ticks_usec()
		var doc := Sc2File.load_path(input_path(reference_path("CITIES/CAPEQUES.SC2")))
		if not (doc.is_valid()):
			printerr(doc.parse_error)
			quit(1)
			return
		if not (not doc.full_resolution_maps()):
			printerr("City uses the native per-tile path")
			quit(1)
			return
		var city := CityState.from_document(doc)
		if not (city.is_valid()):
			printerr(city.load_error)
			quit(1)
			return
		edge = city.map_size
		var load_usec := Time.get_ticks_usec() - load_began
		var began := Time.get_ticks_usec()
		var scan := PollutionPhase.run(city)
		var elapsed := Time.get_ticks_usec() - began
		if not (scan.ok):
			printerr(str(scan))
			quit(1)
			return
		samples.append(elapsed)
		var context := HashingContext.new()
		context.start(HashingContext.HASH_SHA256)

		for id in ["XPLT", "XVAL", "XPLC", "XFIR", "XPOP", "XROG", "XCRM", "XBIT", "MISC"]:
			context.update(doc.find_chunk(id).decoded_payload)

		var trial_digest := context.finish().hex_encode()
		if not (digest == "" or digest == trial_digest):
			printerr("Scan output is not deterministic")
			quit(1)
			return
		digest = trial_digest
		printerr("trial %d load_usec=%d scan_usec=%d" % [trial, load_usec, elapsed])

	samples.sort()
	print(JSON.stringify({"edge": edge, "trials": trials,
		"median_usec": samples[trials / 2], "min_usec": samples[0], "max_usec": samples[-1],
		"samples_usec": samples, "output_sha256": digest}))
	quit()


static func fixture_paths() -> PackedStringArray:
	return PackedStringArray([
		input_path(reference_path("CITIES/CAPEQUES.SC2")),
	])
