class_name OriginalGameInstaller
extends RefCounted

const EXPECTED_SIMCITY_SHA256 := "4f560f7a19586670a8ccb3e0ae69889679699ebf4de706a7a46b2098dd838e69"
const REQUIRED_RELATIVE_PATHS := [
	"DEFAULT.SC2",
	"DATA/DATA_USA.DAT",
	"DATA/DATA_USA.IDX",
	"DATA/TEXT_USA.DAT",
	"DATA/TEXT_USA.IDX",
	"DATA/LARGE.DAT",
	"DATA/SMALLMED.DAT",
	"DATA/SPECIAL.DAT",
	"BITMAPS/403.BMP",
	"BITMAPS/NEIGHBOR.BMP",
	"BITMAPS/PAL_MSTR.BMP",
	"BITMAPS/PAL_MAC.BMP",
	"SCURKART/ORIGINAL.MIF",
	"WINSCURK.EXE",
]


static func validate_executable(
	executable_path: String, expected_hash: String = EXPECTED_SIMCITY_SHA256
) -> Dictionary:
	var path := executable_path.simplify_path()

	if path.get_file().to_upper() != "SIMCITY.EXE":
		return {
			"ok": false,
			"error": "Select SIMCITY.EXE from the original SimCity 2000 installation.",
		}

	if not FileAccess.file_exists(path):
		return {"ok": false, "error": "The selected SIMCITY.EXE does not exist."}

	var actual_hash := FileAccess.get_sha256(path).to_lower()

	if actual_hash.is_empty():
		return {"ok": false, "error": "Cannot read the selected SIMCITY.EXE."}

	if actual_hash != expected_hash.to_lower():
		return {
			"ok": false,
			"error": (
				"The selected SIMCITY.EXE is not the supported 1996 Special Edition file.\n\n"
				+ "Expected SHA-256:\n%s\n\nSelected SHA-256:\n%s"
				% [expected_hash.to_lower(), actual_hash]
			),
			"actual_hash": actual_hash,
		}

	return {"ok": true, "path": path, "hash": actual_hash}


static func validate_install_root(
	install_root: String,
	expected_hash: String = EXPECTED_SIMCITY_SHA256,
	required_paths: Array = REQUIRED_RELATIVE_PATHS,
) -> Dictionary:
	var root := install_root.simplify_path()

	if not DirAccess.dir_exists_absolute(root):
		return {"ok": false, "error": "The original game data directory does not exist."}

	var executable_result := validate_executable(
		root.path_join("SIMCITY.EXE"), expected_hash
	)

	if not executable_result.ok:
		return executable_result

	var required_result := _validate_required_files(root, required_paths)

	if not required_result.ok:
		return required_result

	return {"ok": true, "root": root, "hash": executable_result.hash}


static func install_from_executable(
	executable_path: String,
	destination_root: String,
	expected_hash: String = EXPECTED_SIMCITY_SHA256,
	required_paths: Array = REQUIRED_RELATIVE_PATHS,
) -> Dictionary:
	var executable_result := validate_executable(executable_path, expected_hash)

	if not executable_result.ok:
		return executable_result

	var source_executable_path: String = executable_result.path
	var source_root := source_executable_path.get_base_dir().simplify_path()
	var destination := destination_root.simplify_path()

	if (
		source_root == destination
		or source_root.begins_with(destination + "/")
		or destination.begins_with(source_root + "/")
	):
		return {
			"ok": false,
			"error": "Select SIMCITY.EXE from an original installation outside the app data copy.",
		}

	var required_result := _validate_required_files(source_root, required_paths)

	if not required_result.ok:
		return required_result

	var destination_parent := destination.get_base_dir()
	var make_parent_error := DirAccess.make_dir_recursive_absolute(destination_parent)

	if make_parent_error != OK:
		return {
			"ok": false,
			"error": "Cannot create the app data directory: %s" % error_string(make_parent_error),
		}

	var staging_root := _unique_sibling_path(destination, "installing")
	var copy_result := _copy_tree(source_root, staging_root)

	if not copy_result.ok:
		remove_tree(staging_root)

		return copy_result

	var copied_executable := staging_root.path_join(source_executable_path.get_file())
	var canonical_executable := staging_root.path_join("SIMCITY.EXE")

	if source_executable_path.get_file() != "SIMCITY.EXE":
		var temporary_executable := staging_root.path_join(".simcity-exe-canonicalizing")
		var rename_executable_error := DirAccess.rename_absolute(
			copied_executable, temporary_executable
		)

		if rename_executable_error == OK:
			rename_executable_error = DirAccess.rename_absolute(
				temporary_executable, canonical_executable
			)

		if rename_executable_error != OK:
			remove_tree(staging_root)

			return {
				"ok": false,
				"error": "Cannot prepare SIMCITY.EXE in app data: %s" % error_string(rename_executable_error),
			}

	var staged_result := validate_install_root(
		staging_root, expected_hash, required_paths
	)

	if not staged_result.ok:
		remove_tree(staging_root)

		return {
			"ok": false,
			"error": "The copied installation is not valid. %s" % staged_result.error,
		}

	var previous_root := ""

	if DirAccess.dir_exists_absolute(destination) or FileAccess.file_exists(destination):
		previous_root = _unique_sibling_path(destination, "previous")
		var backup_error := DirAccess.rename_absolute(destination, previous_root)

		if backup_error != OK:
			remove_tree(staging_root)

			return {
				"ok": false,
				"error": "Cannot preserve the existing app data copy: %s" % error_string(backup_error),
			}

	var activate_error := DirAccess.rename_absolute(staging_root, destination)

	if activate_error != OK:
		if not previous_root.is_empty():
			DirAccess.rename_absolute(previous_root, destination)

		remove_tree(staging_root)

		return {
			"ok": false,
			"error": "Cannot activate the copied installation: %s" % error_string(activate_error),
		}

	return {
		"ok": true,
		"root": destination,
		"hash": staged_result.hash,
		"previous_root": previous_root,
	}


static func remove_tree(path: String) -> Error:
	var target := path.simplify_path()

	if not DirAccess.dir_exists_absolute(target):
		if FileAccess.file_exists(target):
			return DirAccess.remove_absolute(target)

		return OK

	var directory := DirAccess.open(target)

	if directory == null:
		return DirAccess.get_open_error()

	directory.include_hidden = true
	directory.include_navigational = false
	var list_error := directory.list_dir_begin()

	if list_error != OK:
		return list_error

	var entry_name := directory.get_next()

	while not entry_name.is_empty():
		var entry_path := target.path_join(entry_name)
		var remove_error := OK

		if directory.current_is_dir() and not directory.is_link(entry_name):
			remove_error = remove_tree(entry_path)
		else:
			remove_error = DirAccess.remove_absolute(entry_path)

		if remove_error != OK:
			directory.list_dir_end()

			return remove_error

		entry_name = directory.get_next()

	directory.list_dir_end()

	return DirAccess.remove_absolute(target)


static func _validate_required_files(
	install_root: String, required_paths: Array
) -> Dictionary:
	for relative_path in required_paths:
		if not FileAccess.file_exists(install_root.path_join(relative_path)):
			return {
				"ok": false,
				"error": "The selected installation is missing %s." % relative_path,
			}

	return {"ok": true}


static func _copy_tree(source_root: String, destination_root: String) -> Dictionary:
	var source := DirAccess.open(source_root)

	if source == null:
		return {
			"ok": false,
			"error": "Cannot read the selected installation: %s" % error_string(DirAccess.get_open_error()),
		}

	var make_error := DirAccess.make_dir_recursive_absolute(destination_root)

	if make_error != OK:
		return {
			"ok": false,
			"error": "Cannot create the installation copy: %s" % error_string(make_error),
		}

	source.include_hidden = true
	source.include_navigational = false
	var list_error := source.list_dir_begin()

	if list_error != OK:
		return {
			"ok": false,
			"error": "Cannot list the selected installation: %s" % error_string(list_error),
		}

	var entry_name := source.get_next()

	while not entry_name.is_empty():
		if source.is_link(entry_name):
			source.list_dir_end()

			return {
				"ok": false,
				"error": "The selected installation contains an unsupported link: %s" % entry_name,
			}

		var source_path := source_root.path_join(entry_name)
		var destination_path := destination_root.path_join(entry_name)

		if source.current_is_dir():
			var child_result := _copy_tree(source_path, destination_path)

			if not child_result.ok:
				source.list_dir_end()

				return child_result
		else:
			var copy_error := DirAccess.copy_absolute(source_path, destination_path)

			if copy_error != OK:
				source.list_dir_end()

				return {
					"ok": false,
					"error": "Cannot copy %s: %s" % [entry_name, error_string(copy_error)],
				}

		entry_name = source.get_next()

	source.list_dir_end()

	return {"ok": true}


static func _unique_sibling_path(path: String, purpose: String) -> String:
	var suffix := "%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]

	return "%s.%s-%s" % [path, purpose, suffix]
