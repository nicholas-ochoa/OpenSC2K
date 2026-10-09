extends SceneTree
# A project export instantiates each scene in the editor and packs it again.
# Controls with a missing or wrong layout_mode can lose their anchors and
# offsets in that pass, and the packaged game then shows a wrong layout. This
# test exports a pack, opens each scene from the pack in a child process, and
# compares each control layout with the source scene.

const LAYOUT_ARGUMENT := "--export-layout-output="

var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var paths := PackedStringArray()
	_collect("res://src", paths)
	var output := _argument_value(LAYOUT_ARGUMENT)

	# the child process writes the layout of each scene in the pack
	if not output.is_empty():
		_write_layouts(paths, output)
		quit()

		return

	var folder := OS.get_temp_dir().path_join("opensc2k_export_layout_%d" % OS.get_process_id())
	DirAccess.make_dir_recursive_absolute(folder)
	var pack := folder.path_join("game.pck")
	var exported_layouts := folder.path_join("layouts.txt")
	var project := ProjectSettings.globalize_path("res://")
	var godot := OS.get_executable_path()
	var messages := []
	var exported := OS.execute(godot, ["--headless", "--audio-driver", "Dummy", "--path", project,
		"--export-pack", _export_preset(), pack], messages, true)
	_check(exported == 0 and FileAccess.file_exists(pack), "export failed\n%s" % "\n".join(messages))

	# the export leaves out the tests, so the child process loads this script
	# from its file
	if failures == 0:
		var opened := OS.execute(godot, ["--headless", "--audio-driver", "Dummy", "--path", project, "--main-pack", pack,
			"-s", ProjectSettings.globalize_path(get_script().resource_path), "--", LAYOUT_ARGUMENT + exported_layouts], messages, true)
		_check(opened == 0 and FileAccess.file_exists(exported_layouts), "pack layout dump failed\n%s" % "\n".join(messages))

	if failures == 0:
		var actual := _read_layouts(exported_layouts)
		var expected := {}

		for path in paths:
			expected[path] = _layout(path)

		for path in paths:
			_check(actual.get(path, PackedStringArray()) == expected[path],
				"%s: layout changed in the exported pack\n%s" % [path, _difference(expected[path], actual.get(path, PackedStringArray()))])

	for file in DirAccess.get_files_at(folder):
		DirAccess.remove_absolute(folder.path_join(file))

	DirAccess.remove_absolute(folder)

	if failures > 0:
		quit(1)

		return

	print("PASS: Control anchors and offsets survive the project export (%d scenes)" % paths.size())
	quit()


# the preset of this platform, so the pack loads the native extensions of this platform
func _export_preset() -> String:
	var arm := Engine.get_architecture_name() == "arm64"

	match OS.get_name():
		"macOS":
			return "macOS"
		"Windows":
			return "Windows Desktop arm64" if arm else "Windows Desktop"

	return "Linux arm64" if arm else "Linux"


func _argument_value(prefix: String) -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with(prefix):
			return argument.trim_prefix(prefix)

	return ""


func _collect(directory: String, paths: PackedStringArray) -> void:
	for file in DirAccess.get_files_at(directory):
		if file.ends_with(".tscn") or file.ends_with(".tscn.remap"):
			paths.append(directory.path_join(file.trim_suffix(".remap")))

	for child in DirAccess.get_directories_at(directory):
		_collect(directory.path_join(child), paths)


func _write_layouts(paths: PackedStringArray, output: String) -> void:
	var file := FileAccess.open(output, FileAccess.WRITE)

	for path in paths:
		for line in _layout(path):
			file.store_line("%s\t%s" % [path, line])

	file.close()


func _read_layouts(input: String) -> Dictionary:
	var layouts := {}
	var file := FileAccess.open(input, FileAccess.READ)

	while not file.eof_reached():
		var line := file.get_line()
		if line.is_empty():
			continue
		var path := line.get_slice("\t", 0)
		var lines: PackedStringArray = layouts.get(path, PackedStringArray())
		lines.append(line.get_slice("\t", 1))
		layouts[path] = lines

	return layouts


func _layout(path: String) -> PackedStringArray:
	var lines := PackedStringArray()
	var node := (load(path) as PackedScene).instantiate()
	_append_layout(node, node, lines)
	node.free()

	return lines


# scripts add children with generated names at run time. these are not
# stored in the scene, and their names differ between instances
func _append_layout(node: Node, root: Node, lines: PackedStringArray) -> void:
	if node.name.begins_with("@"):
		return

	if node is Control:
		var control := node as Control
		lines.append("%s %s %s" % [
			root.get_path_to(node),
			[control.anchor_left, control.anchor_top, control.anchor_right, control.anchor_bottom],
			[control.offset_left, control.offset_top, control.offset_right, control.offset_bottom],
		])

	for child in node.get_children():
		_append_layout(child, root, lines)


func _difference(expected: PackedStringArray, actual: PackedStringArray) -> String:
	var lines := PackedStringArray()

	for index in mini(expected.size(), actual.size()):
		if expected[index] != actual[index]:
			lines.append("  expected %s\n  actual   %s" % [expected[index], actual[index]])

	if expected.size() != actual.size():
		lines.append("  control count %d -> %d" % [expected.size(), actual.size()])

	return "\n".join(lines)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
