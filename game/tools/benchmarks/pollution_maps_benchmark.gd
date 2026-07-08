extends SceneTree


## Read-only legacy coarse-map scan timing. Pass a city path after --.
## Each trial reloads the document so every scan reads identical input.
func _init() -> void:
	var args := OS.get_cmdline_user_args()
	assert(args.size() >= 1, "Pass a legacy coarse-map city path")
	var trials := int(args[1]) if args.size() > 1 else 5
	var samples := []
	var digest := ""
	var edge := 0

	for trial in trials:
		var load_began := Time.get_ticks_usec()
		var doc := Sc2File.load_path(args[0])
		assert(doc.is_valid(), doc.parse_error)
		assert(not doc.full_resolution_maps(), "City uses the native per-tile path")
		var city := CityState.from_document(doc)
		assert(city.is_valid(), city.load_error)
		edge = city.map_size
		var load_usec := Time.get_ticks_usec() - load_began
		var began := Time.get_ticks_usec()
		var scan := PollutionPhase.run(city)
		var elapsed := Time.get_ticks_usec() - began
		assert(scan.ok, str(scan))
		samples.append(elapsed)
		var context := HashingContext.new()
		context.start(HashingContext.HASH_SHA256)

		for id in ["XPLT", "XVAL", "XPLC", "XFIR", "XPOP", "XROG", "XCRM", "XBIT", "MISC"]:
			context.update(doc.find_chunk(id).decoded_payload)

		var trial_digest := context.finish().hex_encode()
		assert(digest == "" or digest == trial_digest, "Scan output is not deterministic")
		digest = trial_digest
		printerr("trial %d load_usec=%d scan_usec=%d" % [trial, load_usec, elapsed])

	samples.sort()
	print(JSON.stringify({"edge": edge, "trials": trials,
		"median_usec": samples[trials / 2], "min_usec": samples[0], "max_usec": samples[-1],
		"samples_usec": samples, "output_sha256": digest}))
	quit()
