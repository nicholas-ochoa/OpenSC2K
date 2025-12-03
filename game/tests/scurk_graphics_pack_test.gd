extends SceneTree
## Validate the optional SCURK pack section and reject invalid sets atomically.

var directory := ""


func _initialize() -> void:
	directory = "user://scurk-graphics-pack-test-%d" % Time.get_ticks_usec()
	assert(DirAccess.make_dir_recursive_absolute(directory) == OK)
	var files := {"tile.png": "scurk/textures/25000.png", "background.png": "scurk/backgrounds/20015.png", "other-palette.png": "palettes/scenario.png"}
	for name in files:
		var size: Vector2i = files[name]
		var pixels := PackedInt32Array()
		pixels.resize(size.x * size.y)
		pixels.fill(1)
		if name == "workspace-22005.png":
			for y in 256:
				for x in 256:
					pixels[y * 256 + x] = (y / 16) * 16 + x / 16
		_write_png(name, pixels, palette, size.x, size.y)
	var manifest := {
		"format": "opensc2k-graphics", "version": 1, "name": "SCURK fixture",
		"palette": "tile.png", "scenario_palette": "other-palette.png",
		"large_sprites": [{"id": 1001, "png": "tile.png"}],
		"small_medium_sprites": [{"id": 1, "png": "tile.png"}], "ui": {},
	}
	for field in GraphicsPack.UI_FIELDS:
		manifest.ui[field] = "tile.png"
	var no_scurk := _load(manifest)
	assert(no_scurk.error.is_empty() and no_scurk.scurk_graphics == null)
	manifest.scurk = {"textures": [], "backgrounds": []}
	for id in ScurkGraphics.TEXTURE_IDS:
		manifest.scurk.textures.append({"id": id, "name": "Material %d" % id, "png": "tile.png"})
	for id in ScurkGraphics.BACKGROUND_IDS:
		manifest.scurk.backgrounds.append({"id": id, "png": "background.png"})
	var valid := _load(manifest)
	assert(valid.error.is_empty() and valid.scurk_graphics.patterns.size() == 42)
	var assets := OriginalGameAssets.new()
	assert(valid.apply_to(assets) and assets.scurk_graphics == valid.scurk_graphics)
	for change in ["section_type", "missing_backgrounds", "extra_field", "short_textures", "duplicate_id", "fractional_id", "empty_name", "bad_path", "wrong_size", "transparent", "palette"]:
		var bad: Dictionary = manifest.duplicate(true)
		match change:
			"section_type": bad.scurk = []
			"missing_backgrounds": bad.scurk.erase("backgrounds")
			"extra_field": bad.scurk.extra = []
			"short_textures": bad.scurk.textures.pop_back()
			"duplicate_id": bad.scurk.textures[1].id = 25039
			"fractional_id": bad.scurk.textures[0].id = 25039.5
			"empty_name": bad.scurk.textures[0].name = " "
			"bad_path": bad.scurk.textures[0].png = "../tile.png"
			"wrong_size": bad.scurk.backgrounds[0].png = "tile.png"
			"palette":
				var png := IndexedPng.load_path(directory.path_join("tile.png"))
				png.palette.colors[1] = Color.MAGENTA
				_write_png("invalid.png", png.pixels, png.palette)
				bad.scurk.textures[0].png = "invalid.png"
			"transparent":
				var png := IndexedPng.load_path(directory.path_join("tile.png"))
				png.pixels[0] = -1
				_write_png("invalid.png", png.pixels, png.palette)
				bad.scurk.textures[0].png = "invalid.png"
		var rejected := _load(bad)
		assert(not rejected.error.is_empty(), change)
		assert(not rejected.apply_to(assets), change)
		assert(assets.scurk_graphics == valid.scurk_graphics and assets.large_sprites == valid.large_sprites)
	assert(no_scurk.apply_to(assets) and assets.scurk_graphics == null)
	for name in files.keys() + ["invalid.png", "pack.json"]:
		assert(DirAccess.remove_absolute(directory.path_join(name)) == OK)
	assert(DirAccess.remove_absolute(directory) == OK)
	print("PASS: optional SCURK pack loading, atomic application, exact resource order, names, palette, dimensions, opaque instructions, safe paths and invalid-set rejection")
	quit()


func _load(manifest: Dictionary) -> GraphicsPack:
	var file := FileAccess.open(directory.path_join("pack.json"), FileAccess.WRITE)
	assert(file != null)
	file.store_string(JSON.stringify(manifest))
	file.close()
	return GraphicsPack.load_root(directory)


func _write_png(name: String, pixels: PackedInt32Array, palette: Sc2Palette) -> void:
	var encoded := IndexedPng.encode(8, 8, pixels, palette)
	assert(encoded.ok)
	var file := FileAccess.open(directory.path_join(name), FileAccess.WRITE)
	assert(file != null)
	file.store_buffer(encoded.bytes)
	file.close()
