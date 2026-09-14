extends SceneTree
## Mac TSET storage differs from Windows MIF. Check pixels with an independent digest.

const CORPUS := "res://../references/all-versions"
const PIXEL_HASH := "553f22fd39a550d1916841d6daf04ae7218c362df15f91339791ccf2c21be1fd"


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	_test_bounds()
	var records: Array = JSON.parse_string(FileAccess.get_file_as_string(CORPUS.path_join("catalog/mac-resource-versions.json")))
	var checked := 0
	var imports := 0
	var temporary := ProjectSettings.globalize_path("res://../local/sc2-import-mac-tiles-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()])

	for record: Dictionary in records:
		if not record.resource_types.has("TSET") or not str(record.path).get_file().begins_with("SimCity"):
			continue

		var path := CORPUS.path_join(record.path)
		var source_hash := FileAccess.get_sha256(path)
		var parsed := Sc2ImportContainer.macintosh(FileAccess.get_file_as_bytes(path), path)
		assert(parsed.error.is_empty(), parsed.error)

		for resource in parsed.resources:
			if resource.type != "TSET" or resource.id != 1:
				continue

			var decoded := Sc2ImportSprites.mac_tile_set(resource.bytes)
			assert(decoded.error.is_empty() and decoded.warnings.is_empty(), str(decoded.warnings))
			assert(decoded.archive.entries.size() == 1448)
			var digest := HashingContext.new()
			digest.start(HashingContext.HASH_SHA256)

			for entry in decoded.archive.entries:
				var bytes := PackedByteArray()
				bytes.resize(6)
				bytes.encode_u16(0, entry.sprite_id)
				bytes.encode_u16(2, entry.width)
				bytes.encode_u16(4, entry.height)
				digest.update(bytes)
				digest.update(entry.decode_indices().pixels.to_byte_array())

			assert(digest.finish().hex_encode() == PIXEL_HASH, path)
			checked += 1

		# These two applications have TSET instead of any SPRT resources.
		if str(record.path).contains("web-mac-german-cd/") or str(record.path).contains("web-french-19733/"):
			var result := Sc2MediaImporter.import_assets(path, temporary)
			assert(result.ok and result.counts.graphics == 1448 and result.counts.sound == 28 and result.counts.music == 19, result.summary())
			assert(result.platform == "Macintosh")
			var assets := GameAssetSource.load_source("", "folder", result.graphics)
			assert(assets.error.is_empty(), assets.error)
			assert(assets.assets.large_sprites.find_sprite(1001) != null)
			assert(FileAccess.get_sha256(path) == source_hash)
			imports += 1

	assert(checked == 5 and imports == 2)
	assert(OriginalGameInstaller.remove_tree(temporary) == OK)
	print("PASS: Mac TSET placeholders, lengths, bounds, partial recovery; independent pixel digest across five application forks; French and German CD all-category imports")
	quit()


func _test_bounds() -> void:
	var pixels := PackedByteArray([4, 1, 2, 4, 7, 9, 2, 1, 2, 2])
	var shape := PackedByteArray()
	_put16(shape, 1001)
	_put16(shape, 2)
	_put16(shape, 1)
	_put32(shape, pixels.size())
	shape.append_array(pixels)
	var body := "SC2KINFO".to_ascii_buffer()
	_put32(body, 4)
	body.append_array("_MACTILE".to_ascii_buffer())
	_put32(body, 2)
	_put16(body, 3)
	body.append_array("SHAP".to_ascii_buffer())
	_put32(body, 0)
	body.append_array("SHAP".to_ascii_buffer())
	_put32(body, shape.size())
	body.append_array(shape)
	# Keep the valid shape when its neighbor is malformed.
	body.append_array("SHAP".to_ascii_buffer())
	_put32(body, 1)
	body.append(0)
	var bytes := "MIFF".to_ascii_buffer()
	_put32(bytes, body.size())
	bytes.append_array(body)
	var result := Sc2ImportSprites.mac_tile_set(bytes)
	assert(result.error.is_empty() and result.archive.entries.size() == 1 and result.warnings.size() == 1)
	assert(result.archive.find_sprite(1001).decode_indices().pixels == PackedInt32Array([7, 9]))
	assert(not Sc2ImportSprites.mac_tile_set(bytes.slice(0, bytes.size() - 1)).error.is_empty())
	bytes[4] = 127
	assert(not Sc2ImportSprites.mac_tile_set(bytes).error.is_empty())
	assert(not Sc2ImportSprites.mac_tile_set(PackedByteArray()).error.is_empty())


func _put16(bytes: PackedByteArray, value: int) -> void:
	bytes.append((value >> 8) & 255)
	bytes.append(value & 255)


func _put32(bytes: PackedByteArray, value: int) -> void:
	_put16(bytes, value >> 16)
	_put16(bytes, value & 65535)
