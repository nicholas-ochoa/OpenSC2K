class_name CityFileStore
extends RefCounted
# Saves write a new temporary file beside the target, close it, read it back,
# and check it before they replace the target. A failure keeps the last save.
# `prepare` runs on the main thread and copies the saved content; `write` only
# reads that copy, so a worker thread can compress and write a large city.


static func save_copy(
	document: Sc2File, requested_path: String, reference_root: String, controller: GameSpeedController = null
) -> FileWriteResult:
	var prepared := prepare(document, requested_path, reference_root, controller)

	if not prepared.ok:
		return FileWriteResult.failure(prepared.error)

	return write(prepared)


# Check the target and copy the content that the save writes. An SCLG city
# converts to SC2X version 4 first; the document itself stays unchanged.
static func prepare(
	document: Sc2File, requested_path: String, reference_root: String, controller: GameSpeedController = null
) -> PreparedSave:
	if document == null:
		return PreparedSave.failure("No city is loaded.")

	var compatibility_error := OriginalCompatibility.save_error(document, requested_path)

	if not compatibility_error.is_empty():
		return PreparedSave.failure(compatibility_error)

	# new files use SC2X version 4. an SCLG city converts to it first
	if document.is_extended() and not document.is_sc2x():
		var converted := Sc2xDocument.from_legacy(document, requested_path.get_file().get_basename())

		if not converted.ok:
			return PreparedSave.failure("Cannot convert the city to SC2X version 4: %s" % converted.error)

		converted.document.sc2x_converted_from = document.source_path
		document = converted.document

	var output_path := requested_path

	if output_path.get_extension().is_empty():
		output_path += ".SC2" if not document.is_extended() else ".sc2x"

	if document.is_extended() and output_path.get_extension().to_lower() != "sc2x":
		return PreparedSave.failure("Experimental cities must use .sc2x. The original game cannot open them.")

	output_path = output_path.simplify_path()

	if is_reference_path(output_path, reference_root):
		return PreparedSave.failure("Choose a location outside the read-only original support-data directory.")

	var result := PreparedSave.new()
	result.path = output_path

	if not document.is_sc2x():
		var serialized := document.serialize()

		if not serialized.ok:
			return PreparedSave.failure(serialized.error)

		result.ok = true
		result.bytes = serialized.data
		result.snapshot = serialized.data

		return result

	var error := document.compatibility_error()

	if error.is_empty():
		error = Sc2xCheckpoint.save_error(controller)

	if error.is_empty() and _same_path(output_path, document.sc2x_converted_from):
		error = "Choose a new file name. The converted city keeps its original file unchanged."

	if not error.is_empty():
		return PreparedSave.failure(error)

	Sc2xCheckpoint.capture(controller, document.sc2x_metadata)
	var entries := Sc2xDocument.entries(document)

	if not entries.ok:
		return PreparedSave.failure(entries.error)

	# packed arrays are shared by reference. copy them so that later edits of
	# the city cannot reach a save that a worker thread writes
	for name in entries.order:
		entries.members[name] = entries.members[name].duplicate()

	result.ok = true
	result.entries = entries
	result.snapshot = Sc2xDocument.digest_entries(entries)

	return result


# Compress, write, and check a prepared save. This reads only `prepared`.
static func write(prepared: PreparedSave) -> FileWriteResult:
	var bytes := prepared.bytes

	if prepared.entries != null:
		var archive := ZipArchive.encode(
			prepared.entries.order, prepared.entries.members, Sc2xDocument.MAX_ARCHIVE_BYTES, Sc2xDocument.MAX_DATA_BYTES, true)

		if not archive.ok:
			return FileWriteResult.failure(archive.error)

		bytes = archive.bytes

	var written := write_verified(prepared.path, bytes, prepared.entries)

	if written.ok:
		written.data = bytes

	return written


# Write `bytes` to a temporary file beside `path`, read it back, check it, and
# then replace `path`. An SC2X file must load again with the `expected` entries.
static func write_verified(path: String, bytes: PackedByteArray, expected: Sc2xDocument.EntriesResult = null) -> FileWriteResult:
	var temporary := "%s.%d.tmp" % [path, Time.get_ticks_usec()]
	var output := FileAccess.open(temporary, FileAccess.WRITE)

	if output == null:
		return FileWriteResult.failure("Cannot open save output: %s" % error_string(FileAccess.get_open_error()))

	output.store_buffer(bytes)
	output.flush()
	var write_error := output.get_error()
	output.close()

	if write_error != OK:
		DirAccess.remove_absolute(temporary)

		return FileWriteResult.failure("Cannot write save output: %s" % error_string(write_error))

	var check := _verify(temporary, bytes, expected)

	if not check.is_empty():
		DirAccess.remove_absolute(temporary)

		return FileWriteResult.failure(check)

	var rename_error := DirAccess.rename_absolute(temporary, path)

	if rename_error != OK:
		DirAccess.remove_absolute(temporary)

		return FileWriteResult.failure("Cannot replace the saved city: %s" % error_string(rename_error))

	var outcome := FileWriteResult.new()
	outcome.ok = true
	outcome.path = path

	return outcome


static func _verify(path: String, bytes: PackedByteArray, expected: Sc2xDocument.EntriesResult) -> String:
	var stored := FileAccess.get_file_as_bytes(path)

	if FileAccess.get_open_error() != OK or stored != bytes:
		return "The saved file does not match the city data. The previous save is unchanged."

	if expected == null:
		return ""

	var reloaded := Sc2File.new()

	if not reloaded.parse(stored):
		return "The saved file does not load again: %s. The previous save is unchanged." % reloaded.parse_error

	var actual := Sc2xDocument.entries(reloaded)

	if not actual.ok or actual.order != expected.order or actual.members != expected.members:
		return "The saved file loads with different city data. The previous save is unchanged."

	return ""


static func _same_path(path: String, other: String) -> bool:
	if other.is_empty():
		return false

	return ProjectSettings.globalize_path(path).simplify_path() == ProjectSettings.globalize_path(other).simplify_path()


static func is_reference_path(path: String, reference_root: String) -> bool:
	if reference_root.is_empty():
		return false

	var normalized := ProjectSettings.globalize_path(path).simplify_path()
	var protected_root := ProjectSettings.globalize_path(reference_root).simplify_path()

	return normalized == protected_root or normalized.begins_with(protected_root + "/")


# The checked target and a private copy of the content to write. `snapshot`
# is the saved-content snapshot of Sc2File.content_snapshot.
class PreparedSave extends RefCounted:
	var ok := false
	var error := ""
	var path := ""
	var bytes := PackedByteArray()
	var entries: Sc2xDocument.EntriesResult
	var snapshot := PackedByteArray()

	static func failure(message: String) -> PreparedSave:
		var result := PreparedSave.new()
		result.error = message

		return result
