class_name DebugSaveCheck
extends RefCounted
## The save round trip of the open city. A copy of the document saves to a
## temporary file with the normal save path, loads again, and each chunk is
## compared with the copy. The saved file then encodes again, and the second
## encoding must equal the first. The open city, its save path and its saved
## state do not change; the temporary file is deleted.

const FILE_PREFIX := "opensc2k_save_check"


# copy the document on the main thread. `run` reads only the copy
static func prepare(document: Sc2File, reference_root: String, controller: GameSpeedController) -> Job:
	var job := Job.new()

	if document == null:
		job.error = "Load a city before you check the save."

		return job

	var copy := document.duplicate_document()
	var extension := "sc2x" if copy.is_extended() else ("scn" if copy.find_chunk("SCEN") != null
		and document.source_path.get_extension().to_lower() == "scn" else "SC2")
	var path := OS.get_temp_dir().path_join("%s_%d_%d.%s" % [FILE_PREFIX, OS.get_process_id(), Time.get_ticks_usec(), extension])
	var prepared := CityFileStore.prepare(copy, path, reference_root, controller)

	if not prepared.ok:
		job.error = "The city cannot be saved now: %s" % prepared.error

		return job

	job.prepared = prepared
	job.format = DebugFileInfo.format_name(document)
	job.converted = document.is_extended() and not document.is_sc2x()
	var seen: Dictionary[String, int] = {}

	for chunk in copy.chunks:
		job.chunks.append([ApplicationDebugTools.chunk_key(chunk.chunk_id, seen), chunk.decoded_payload])

	job.extra_entries = copy.sc2x_extra_entries.duplicate()

	return job


class Job extends RefCounted:
	var prepared: CityFileStore.PreparedSave
	var format := ""
	# an SCLG city converts to SC2X version 4 when it saves
	var converted := false
	# [key, decoded payload] of each chunk of the copy
	var chunks: Array = []
	var extra_entries: Dictionary[String, PackedByteArray] = {}
	var error := ""
	var report := Report.new()

	func run() -> void:
		var started := Time.get_ticks_usec()
		report.format = format
		report.converted = converted
		var written := CityFileStore.write(prepared)

		if not written.ok:
			report.failures.append("The save failed: %s" % written.error)
			report.usec = Time.get_ticks_usec() - started

			return

		report.path = written.path
		report.bytes = written.data.size()
		var reloaded := Sc2File.load_path(written.path)
		DirAccess.remove_absolute(written.path)

		if not reloaded.is_valid():
			report.failures.append("The saved file does not load: %s" % reloaded.parse_error)
			report.usec = Time.get_ticks_usec() - started

			return

		_compare_chunks(reloaded)
		_compare_entries(reloaded)
		_compare_encoding(reloaded, written.data)
		report.usec = Time.get_ticks_usec() - started

	func _compare_chunks(reloaded: Sc2File) -> void:
		var after: Dictionary[String, PackedByteArray] = {}
		var seen: Dictionary[String, int] = {}

		for chunk in reloaded.chunks:
			after[ApplicationDebugTools.chunk_key(chunk.chunk_id, seen)] = chunk.decoded_payload

		for pair in chunks:
			var key: String = pair[0]
			var before: PackedByteArray = pair[1]
			var row := [key, before.size(), -1, "Missing after load", -1]

			if after.has(key):
				var loaded := after[key]
				row[2] = loaded.size()

				if loaded == before:
					row[3] = "Same"
				else:
					var found: Dictionary = NativeDebugTiles.byte_differences(before, loaded, 1)
					row[3] = "%d bytes differ" % int(found.count)
					row[4] = int(found.offsets[0]) if not (found.offsets as PackedInt32Array).is_empty() else -1

				after.erase(key)

			if row[3] != "Same":
				report.failures.append("%s: %s%s" % [key, row[3], " at 0x%X" % row[4] if row[4] >= 0 else ""])

			report.rows.append(row)

		for key in after:
			report.rows.append([key, -1, after[key].size(), "Added by the save", -1])
			report.failures.append("%s: added by the save" % key)

	func _compare_entries(reloaded: Sc2File) -> void:
		for name in extra_entries:
			if not reloaded.sc2x_extra_entries.has(name):
				report.failures.append("Extra entry %s: missing after load" % name)
			elif reloaded.sc2x_extra_entries[name] != extra_entries[name]:
				report.failures.append("Extra entry %s: bytes differ" % name)

	# a second save of the loaded file must write the same content
	func _compare_encoding(reloaded: Sc2File, first: PackedByteArray) -> void:
		if reloaded.is_sc2x():
			var entries := Sc2xDocument.entries(reloaded)
			report.stable = entries.ok and Sc2xDocument.digest_entries(entries) == prepared.snapshot
		else:
			var encoded := reloaded.serialize(true)
			report.stable = encoded.ok and encoded.data == first

		if not report.stable:
			report.failures.append("A second save of the loaded file writes different content")


class Report extends RefCounted:
	var format := ""
	var converted := false
	var path := ""
	var bytes := 0
	var usec := 0
	var stable := false
	# [chunk, bytes before, bytes after, result, first differing offset]
	var rows: Array = []
	var failures := PackedStringArray()

	func ok() -> bool:
		return failures.is_empty()

	func summary() -> String:
		var conversion := " The city converts from SCLG, so some chunks can differ." if converted else ""

		if ok():
			return "Save check passed: %d chunks of the %s city load with the same bytes, and a second save is the same.%s" % [
				rows.size(), format, conversion]

		return "Save check found %d problems in the %s city. %s%s" % [failures.size(), format, failures[0], conversion]

	func text() -> String:
		var lines := PackedStringArray([summary(), "", "Saved %d bytes in %.0f ms." % [bytes, usec / 1000.0], ""])
		lines.append("%-10s %12s %12s  %s" % ["Chunk", "Before", "After", "Result"])

		for row in rows:
			lines.append("%-10s %12s %12s  %s%s" % [row[0], str(row[1]) if row[1] >= 0 else "-", str(row[2]) if row[2] >= 0 else "-",
				row[3], " (first at 0x%X)" % row[4] if row[4] >= 0 else ""])

		if not failures.is_empty():
			lines.append("")
			lines.append_array(failures)

		return "\n".join(lines)
