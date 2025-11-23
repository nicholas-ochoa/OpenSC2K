extends SceneTree

const Fixture = preload("res://tests/indexed_png_test.gd")
const Pack = preload("res://src/assets/graphics_pack.gd")


func _initialize() -> void:
	var root := "user://graphics-pack-test-%d" % Time.get_ticks_usec()
	assert(DirAccess.make_dir_recursive_absolute(root) == OK)
	var png := FileAccess.open(root.path_join("sprite.png"), FileAccess.WRITE)
	png.store_buffer(Fixture.FIXTURE.hex_decode())
	png.close()
	var manifest := {
		"format": "opensc2k-graphics", "version": 1, "name": "Independent test",
		"palette": "sprite.png", "scenario_palette": "sprite.png",
		"large_sprites": [{"id": 1001, "png": "sprite.png"}, {"id": 1001, "png": "sprite.png"}],
		"small_medium_sprites": [{"id": 1, "png": "sprite.png"}], "ui": {},
	}
	for field in Pack.UI_FIELDS:
		manifest.ui[field] = "sprite.png"
	_write_manifest(root, manifest)
	var loaded := Pack.load_root(root)
	assert(loaded.error.is_empty(), loaded.error)
	assert(loaded.large_sprites.entries.size() == 2)
	var sprite: Sc2SpriteArchive.SpriteEntry = loaded.large_sprites.find_sprite(1001)
	assert(sprite.duplicate_index == 1)
	assert(sprite.decode_indices().pixels == PackedInt32Array([-1, 1, 171, 172]))
	var indices: Dictionary = sprite.create_image(Sc2Palette.index_encoding())
	assert(indices.image.get_pixel(2, 0).r8 == 171)
	assert(indices.image.get_pixel(0, 0).a8 == 0)
	var returned: PackedInt32Array = sprite.decode_indices().pixels
	returned[1] = 9
	assert(sprite.decode_indices().pixels[1] == 1)
	var other := Sc2SpriteArchive.entry_from_indices(1001, 4, 1, returned)
	assert(sprite.pixel_hash() != other.pixel_hash())
	assert(Sc2SpriteArchive.entry_from_indices(1, 2, 1, PackedInt32Array([256, 0])) == null)
	assert(loaded.ui_images.toolbar_art.get_pixel(2, 0) == Color8(40, 80, 120))
	var assets := OriginalGameAssets.new()
	assert(loaded.apply_to(assets))
	assert(assets.large_sprites == loaded.large_sprites)
	for bad_path in ["../sprite.png", "/sprite.png", "res://sprite.png", "a\\sprite.png", "./sprite.png"]:
		manifest.palette = bad_path
		_write_manifest(root, manifest)
		var bad := Pack.load_root(root)
		assert(not bad.error.is_empty())
		assert(not bad.apply_to(assets))
		assert(assets.large_sprites == loaded.large_sprites)
	manifest.palette = "missing.png"
	_write_manifest(root, manifest)
	assert(not Pack.load_root(root).error.is_empty())
	manifest.palette = "sprite.png"
	manifest.large_sprites[0].id = 1.5
	_write_manifest(root, manifest)
	assert(not Pack.load_root(root).error.is_empty())
	manifest.large_sprites[0].id = 1001
	manifest.ui.erase("toolbar_art")
	_write_manifest(root, manifest)
	assert(not Pack.load_root(root).error.is_empty())
	DirAccess.remove_absolute(root.path_join("sprite.png"))
	DirAccess.remove_absolute(root.path_join("pack.json"))
	DirAccess.remove_absolute(root)
	print("PASS: graphics pack loading, duplicate IDs, indexed rendering, UI, invalid packs")
	quit()


func _write_manifest(root: String, manifest: Dictionary) -> void:
	var file := FileAccess.open(root.path_join("pack.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(manifest))
	file.close()
