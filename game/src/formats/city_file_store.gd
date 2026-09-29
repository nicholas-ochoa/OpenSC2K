class_name CityFileStore
extends RefCounted
# Saves write a new temporary file beside the target, close it, read it back,
# and check it before they replace the target. A failure keeps the last save.


static func save_copy(
	document: Sc2File, requested_path: String, reference_root: String, controller: GameSpeedController = null
) -> FileWriteResult:
	if document == null:
		return FileWriteResult.failure("No city is loaded.")

	var compatibility_error := OriginalCompatibility.save_error(document, requested_path)

	if not compatibility_error.is_empty():
		return FileWriteResult.failure(compatibility_error)

	# new files use SC2X version 4. an SCLG city converts to it first
	if document.is_extended() and not document.is_sc2x():
		var converted := Sc2xDocument.from_legacy(document, requested_path.get_file().get_basename())

		if not converted.ok:
			return FileWriteResult.failure("Cannot convert the city to SC2X version 4: %s" % converted.error)

		converted.document.sc2x_converted_from = document.source_path
		document = converted.document

	var output_path := requested_path

	if output_path.get_extension().is_empty():
		output_path += ".SC2" if not document.is_extended() else ".sc2x"

	if document.is_extended() and output_path.get_extension().to_lower() != "sc2x":
		return FileWriteResult.failure("Experimental cities must use .sc2x. The original game cannot open them.")

	output_path = output_path.simplify_path()

	if is_reference_path(output_path, reference_root):
		return FileWriteResult.failure("Choose a location outside the read-only original support-data directory.")

	if document.is_sc2x():
		var error := document.compatibility_error()

		if error.is_empty():
			error = Sc2xCheckpoint.save_error(controller)

		if error.is_empty() and _same_path(output_path, document.sc2x_converted_from):
			error = "Choose a new file name. The converted city keeps its original file unchanged."

		if not error.is_empty():
			return FileWriteResult.failure(error)

		Sc2xCheckpoint.capture(controller, document.sc2x_metadata)

	var serialized := document.serialize()

	if not serialized.ok:
		return FileWriteResult.failure(serialized.error)

	var written := write_verified(output_path, serialized.data, document)

	if not written.ok:
		return written

	written.data = serialized.data

	return written


# Write `bytes` to a temporary file beside `path`, read it back, check it, and
# then replace `path`. An SC2X file must load again with the same content.
static func write_verified(path: String, bytes: PackedByteArray, document: Sc2File = null) -> FileWriteResult:
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

	var check := _verify(temporary, bytes, document)

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


static func _verify(path: String, bytes: PackedByteArray, document: Sc2File) -> String:
	var stored := FileAccess.get_file_as_bytes(path)

	if FileAccess.get_open_error() != OK or stored != bytes:
		return "The saved file does not match the city data. The previous save is unchanged."

	if document == null or not document.is_sc2x():
		return ""

	var reloaded := Sc2File.new()

	if not reloaded.parse(stored):
		return "The saved file does not load again: %s. The previous save is unchanged." % reloaded.parse_error

	var expected := Sc2xDocument.entries(document)
	var actual := Sc2xDocument.entries(reloaded)

	if not expected.ok or not actual.ok or expected.order != actual.order or expected.members != actual.members:
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
