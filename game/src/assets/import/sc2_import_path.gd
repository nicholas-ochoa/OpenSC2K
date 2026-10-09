class_name Sc2ImportPath
extends RefCounted
## Find original game files when the case of their names differs from the documented names.
## Case-sensitive file systems, Wine installs, and Linux CD-ROM mounts often show lowercase
## or mixed-case names. A raw ISO 9660 mount can also show a ";1" version suffix.


## Return the name that compares equal for each spelling of one original file name.
static func key(name: String) -> String:
	return original_name(name).to_upper()


## Return the file name without an ISO 9660 version suffix or a final dot. Keep its case.
static func original_name(name: String) -> String:
	return NativeImportSource.original_name(name)


## Return the existing file or folder at the relative path below root, or an empty string.
## Each path component matches its stored name without case. An exact match has priority.
## The result keeps the stored names, also on a file system that ignores case.
static func find(root: String, relative: String) -> String:
	var current := root
	var parts := relative.split("/", false)

	for index in parts.size():
		var directory := DirAccess.open(current)

		if directory == null:
			return ""

		directory.include_hidden = true
		var part := parts[index]
		var names := directory.get_directories()

		if index == parts.size() - 1:
			names.append_array(directory.get_files())

		var found := part if part in names else ""

		if found.is_empty():
			var wanted := key(part)

			for name in names:
				if key(name) == wanted:
					found = name
					break

		if found.is_empty():
			return ""

		current = current.path_join(found)

	return current


## Return the existing file at the relative path below root, or an empty string.
static func find_file(root: String, relative: String) -> String:
	var path := find(root, relative)

	return path if FileAccess.file_exists(path) else ""


## Return the existing file at the relative path, or the exact path when no file matches.
## Use it where a missing file must produce the normal "cannot read" error of the caller.
static func resolve(root: String, relative: String) -> String:
	var path := find_file(root, relative)

	return path if not path.is_empty() else root.path_join(relative)


static func has_file(root: String, relative: String) -> bool:
	return not find_file(root, relative).is_empty()
