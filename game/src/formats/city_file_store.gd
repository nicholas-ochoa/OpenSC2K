class_name CityFileStore
extends RefCounted


static func save_copy(
	document: Sc2File, requested_path: String, reference_root: String
) -> Dictionary:
	if document == null:
		return {"ok": false, "error": "No city is loaded."}
	var output_path := requested_path
	if output_path.get_extension().is_empty():
		output_path += ".SC2"
	output_path = output_path.simplify_path()
	if is_reference_path(output_path, reference_root):
		return {
			"ok": false,
			"error": "Choose a location outside the read-only references directory.",
		}

	var serialized := document.serialize()
	if not serialized.ok:
		return {"ok": false, "error": serialized.error}
	var output := FileAccess.open(output_path, FileAccess.WRITE)
	if output == null:
		return {
			"ok": false,
			"error": "Cannot open save output: %s" % error_string(FileAccess.get_open_error()),
		}
	output.store_buffer(serialized.data)
	output.flush()
	var write_error := output.get_error()
	output.close()
	if write_error != OK:
		return {
			"ok": false,
			"error": "Cannot write save output: %s" % error_string(write_error),
		}
	return {
		"ok": true,
		"path": output_path,
		"data": serialized.data,
	}


static func is_reference_path(path: String, reference_root: String) -> bool:
	var normalized := ProjectSettings.globalize_path(path).simplify_path()
	for root_path in [reference_root, ProjectSettings.globalize_path("res://../references")]:
		var protected_root := ProjectSettings.globalize_path(root_path).simplify_path()
		if normalized == protected_root or normalized.begins_with(protected_root + "/"):
			return true
	return false
