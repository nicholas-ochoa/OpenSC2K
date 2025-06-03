extends SceneTree

const RleCodec = preload("res://src/formats/maxis_rle.gd")
const Sc2Document = preload("res://src/formats/sc2_file.gd")

var failures := 0
var checks := 0


func _init() -> void:
	var arguments := OS.get_cmdline_user_args()
	var reference_root := ProjectSettings.globalize_path("res://../references")
	if not arguments.is_empty():
		reference_root = arguments[0]

	_test_rle()
	_test_invalid_rle()
	_test_reference_corpus(reference_root)

	if failures == 0:
		print("PASS: %d checks" % checks)
		quit(0)
	else:
		printerr("FAIL: %d of %d checks failed" % [failures, checks])
		quit(1)


func _test_rle() -> void:
	var cases: Array[PackedByteArray] = [
		PackedByteArray(),
		PackedByteArray([1]),
		PackedByteArray([7, 7]),
		PackedByteArray([1, 2, 3, 4, 5]),
		_filled_bytes(128, 0xaa),
		_filled_bytes(300, 0x00),
	]
	for original in cases:
		var encoded := RleCodec.encode(original)
		var result := RleCodec.decode(encoded, original.size())
		_check(result.ok, "RLE round trip decodes")
		if result.ok:
			_check(result.data == original, "RLE round trip preserves bytes")


func _test_invalid_rle() -> void:
	_check(not RleCodec.decode(PackedByteArray([0x80])).ok, "RLE rejects 0x80")
	_check(not RleCodec.decode(PackedByteArray([2, 1])).ok, "RLE rejects short literal")
	_check(not RleCodec.decode(PackedByteArray([0x81])).ok, "RLE rejects short run")
	_check(
		not RleCodec.decode(PackedByteArray([0x82, 4]), 2).ok,
		"RLE rejects output overflow"
	)


func _test_reference_corpus(reference_root: String) -> void:
	var paths := PackedStringArray([reference_root.path_join("DEFAULT.SC2")])
	paths.append_array(_files_with_extension(reference_root.path_join("CITIES"), "SC2"))
	paths.append_array(_files_with_extension(reference_root.path_join("SCENARIO"), "SCN"))
	_check(paths.size() >= 80, "Reference corpus contains at least 80 city and scenario files")

	for path in paths:
		var document := Sc2Document.load_path(path)
		_check(document.is_valid(), "%s parses: %s" % [path.get_file(), document.parse_error])
		if not document.is_valid():
			continue

		var rebuilt := document.serialize(true)
		_check(rebuilt.ok, "%s rebuilds" % path.get_file())
		if rebuilt.ok:
			_check(
				rebuilt.data == FileAccess.get_file_as_bytes(path),
				"%s rebuild is byte-identical" % path.get_file()
			)

		for chunk in document.chunks:
			if not chunk.is_compressed:
				continue
			var reencoded := RleCodec.encode(chunk.decoded_payload)
			var decoded := RleCodec.decode(reencoded, chunk.expected_decoded_size)
			_check(decoded.ok, "%s %s re-encodes" % [path.get_file(), chunk.chunk_id])
			if decoded.ok:
				_check(
					decoded.data == chunk.decoded_payload,
					"%s %s re-encode preserves bytes" % [path.get_file(), chunk.chunk_id]
				)

	var default_city := Sc2Document.load_path(reference_root.path_join("DEFAULT.SC2"))
	_check(default_city.is_valid(), "Default city parses")
	if default_city.is_valid():
		_check(default_city.city_name() == "New City", "Default city name is New City")
		_check(default_city.misc_u32(0) == 0x122, "Default MISC marker is 0x122")


func _files_with_extension(directory: String, extension: String) -> PackedStringArray:
	var paths := PackedStringArray()
	for filename in DirAccess.get_files_at(directory):
		if filename.get_extension().to_upper() == extension:
			paths.append(directory.path_join(filename))
	paths.sort()
	return paths


func _filled_bytes(size: int, value: int) -> PackedByteArray:
	var result := PackedByteArray()
	result.resize(size)
	result.fill(value)
	return result


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: %s" % message)
