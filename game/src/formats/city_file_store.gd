class_name CityFileStore
extends RefCounted


static func save_copy(
	document: Sc2File, requested_path: String, reference_root: String
) -> FileWriteResult:
	if document == null:
		return FileWriteResult.failure("No city is loaded.")

	var compatibility_error := OriginalCompatibility.save_error(document, requested_path)

	if not compatibility_error.is_empty():
		return FileWriteResult.failure(compatibility_error)

	var output_path := requested_path

	if output_path.get_extension().is_empty():
		output_path += ".SC2" if not document.is_extended() else ".sc2x"

	if document.is_extended() and output_path.get_extension().to_lower() != "sc2x":
		return FileWriteResult.failure("Experimental cities must use .sc2x. The original game cannot open them.")

	output_path = output_path.simplify_path()

	if is_reference_path(output_path, reference_root):
		return FileWriteResult.failure("Choose a location outside the read-only original support-data directory.")

	var serialized := document.serialize()

	if not serialized.ok:
		return FileWriteResult.failure(serialized.error)

	var output := FileAccess.open(output_path, FileAccess.WRITE)

	if output == null:
		return FileWriteResult.failure("Cannot open save output: %s" % error_string(FileAccess.get_open_error()))

	output.store_buffer(serialized.data)
	output.flush()
	var write_error := output.get_error()
	output.close()

	if write_error != OK:
		return FileWriteResult.failure("Cannot write save output: %s" % error_string(write_error))

	var outcome := FileWriteResult.new()
	outcome.ok = true
	outcome.path = output_path
	outcome.data = serialized.data

	return outcome


static func is_reference_path(path: String, reference_root: String) -> bool:
	if reference_root.is_empty():
		return false

	var normalized := ProjectSettings.globalize_path(path).simplify_path()
	var protected_root := ProjectSettings.globalize_path(reference_root).simplify_path()

	return normalized == protected_root or normalized.begins_with(protected_root + "/")
