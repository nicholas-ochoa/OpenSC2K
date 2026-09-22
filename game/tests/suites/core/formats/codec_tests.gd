extends "res://tests/support/core_test_suite.gd"

## Formats: codec checks.

@warning_ignore_start("integer_division")

const RleCodec = preload("res://src/formats/maxis_rle.gd")
const OriginalInstaller = preload("res://src/assets/original_game_installer.gd")


func test_rle() -> void:
	var cases: Array[PackedByteArray] = [
		PackedByteArray(),
		PackedByteArray([1]),
		PackedByteArray([7, 7]),
		PackedByteArray([1, 2, 3, 4, 5]),
		_filled_bytes(128, 0xaa),
		_filled_bytes(300, 0x00),
		_filled_bytes(128, 0xaa) + PackedByteArray([1, 2, 3]) + _filled_bytes(3, 0x55),
	]

	for original in cases:
		var encoded := RleCodec.encode(original)
		var result := RleCodec.decode(encoded, original.size())
		_check(result.ok, "RLE round trip decodes")

		if result.ok:
			_check(result.data == original, "RLE round trip preserves bytes")

		var unsized := RleCodec.decode(encoded)
		_check(unsized.ok and unsized.data == original, "RLE decodes without an expected size")


func test_invalid_rle() -> void:
	_check(not RleCodec.decode(PackedByteArray([0x80])).ok, "RLE rejects 0x80")
	_check(not RleCodec.decode(PackedByteArray([2, 1])).ok, "RLE rejects short literal")
	_check(not RleCodec.decode(PackedByteArray([0x81])).ok, "RLE rejects short run")
	_check(
		not RleCodec.decode(PackedByteArray([0x82, 4]), 2).ok,
		"RLE rejects output overflow"
	)


func test_original_game_installer(reference_root: String) -> void:
	var reference_result := OriginalInstaller.validate_install_root(reference_root)
	_check(reference_result.ok, "Original game installer accepts the supplied install")

	var scratch_root := ProjectSettings.globalize_path(
		"user://test_original_installer_%d" % OS.get_process_id()
	)
	OriginalInstaller.remove_tree(scratch_root)
	var source_root := scratch_root.path_join("source")
	var source_data := source_root.path_join("DATA")
	var destination_root := scratch_root.path_join("installed")
	var make_error := DirAccess.make_dir_recursive_absolute(source_data)
	_check(make_error == OK, "Original game installer test directory is created")

	if make_error != OK:
		return

	var executable_path := source_root.path_join("simcity.exe")
	var executable_file := FileAccess.open(executable_path, FileAccess.WRITE)
	_check(executable_file != null, "Original game installer test executable opens")

	if executable_file == null:
		OriginalInstaller.remove_tree(scratch_root)

		return

	executable_file.store_buffer(PackedByteArray([0x53, 0x43, 0x32, 0x4b]))
	executable_file.close()
	var data_path := source_data.path_join("EXTRA.DAT")
	var data_file := FileAccess.open(data_path, FileAccess.WRITE)
	_check(data_file != null, "Original game installer test data opens")

	if data_file == null:
		OriginalInstaller.remove_tree(scratch_root)

		return

	data_file.store_buffer(PackedByteArray([1, 2, 3, 4]))
	data_file.close()
	var expected_hash := FileAccess.get_sha256(executable_path)
	var wrong_hash_result := OriginalInstaller.validate_executable(
		executable_path, "0".repeat(64)
	)
	_check(not wrong_hash_result.ok, "Original game installer rejects a wrong hash")
	DirAccess.make_dir_recursive_absolute(destination_root)
	var old_file := FileAccess.open(destination_root.path_join("OLD.DAT"), FileAccess.WRITE)

	if old_file != null:
		old_file.store_8(0x7f)
		old_file.close()

	var install_result := OriginalInstaller.install_from_executable(
		executable_path,
		destination_root,
		expected_hash,
		["DATA/EXTRA.DAT"],
	)
	_check(install_result.ok, "Original game installer copies a complete test install")

	if install_result.ok:
		_check(
			not str(install_result.previous_root).is_empty()
			and FileAccess.file_exists(
				str(install_result.previous_root).path_join("OLD.DAT")
			),
			"Original game installer preserves an existing app data copy",
		)
		_check(
			FileAccess.file_exists(destination_root.path_join("SIMCITY.EXE")),
			"Original game installer gives the copied executable its canonical name",
		)
		_check(
			FileAccess.get_file_as_bytes(destination_root.path_join("DATA/EXTRA.DAT"))
			== PackedByteArray([1, 2, 3, 4]),
			"Original game installer copies nested support files",
		)
		var installed_result := OriginalInstaller.validate_install_root(
			destination_root, expected_hash, ["DATA/EXTRA.DAT"]
		)
		_check(installed_result.ok, "Original game installer validates its installed copy")

	var cleanup_error := OriginalInstaller.remove_tree(scratch_root)
	_check(cleanup_error == OK, "Original game installer test data is removed")
