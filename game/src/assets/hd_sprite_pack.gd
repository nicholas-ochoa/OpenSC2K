class_name HdSpritePack
extends RefCounted
## A pack of full-color city sprites that replaces the look of the indexed
## sprites of the active graphics pack. It contains no palettes, interface
## images, or indexed sprites. Refer to docs/hd-sprite-pack-format.md.

@warning_ignore_start("integer_division")

const FORMAT := "opensc2k-hd-sprites"
const MAX_EDGE := 4096
# Each frame of a strip has two more rows in the GPU atlas.
const MAX_STRIP_HEIGHT := 8190
const MAX_FRAMES := 32
const FRAME_RATES: Array[int] = [5, 8]
# Decoded RGBA bytes of all images. Each image counts one time.
const MAX_DECODED_BYTES := 512 * 1024 * 1024

var error := ""
var pack_name := ""
var redraw_small_highway_ground := false
# Sprite ID to art. Each record also keeps the indexed size that it needs.
var sprites: Dictionary[int, HdSprite] = {}
var logical_sizes: Dictionary[int, Vector2i] = {}
var _root := ""
var _images: Dictionary[String, Image] = {}
var _decoded_bytes := 0


static func load_root(root: String) -> HdSpritePack:
	var pack := HdSpritePack.new()
	pack._root = (root.get_base_dir() if root.get_file() == "pack.json" else root).simplify_path()
	pack._load()

	if not pack.error.is_empty():
		pack.sprites.clear()
		pack.logical_sizes.clear()

	pack._images.clear()

	return pack


# A copy of `archive` that shows the art of each sprite whose indexed size
# matches its record. The copy shares the indexed entries. Returns `archive`
# when no record applies.
func apply_to(archive: Sc2SpriteArchive) -> Sc2SpriteArchive:
	if not error.is_empty() or archive == null or not archive.is_valid():
		return archive

	var art: Dictionary[int, HdSprite] = {}

	for id: int in sprites:
		var entry := archive.find_sprite(id)

		if entry != null and Vector2i(entry.width, entry.height) == logical_sizes[id]:
			art[id] = sprites[id]

	if art.is_empty():
		return archive

	var result := Sc2SpriteArchive.combine([archive])
	result.high_resolution = art
	result.redraw_small_highway_ground = archive.redraw_small_highway_ground or redraw_small_highway_ground

	return result


func _load() -> void:
	var manifest_path := _root.path_join("pack.json")

	if not FileAccess.file_exists(manifest_path):
		_fail("Missing pack.json")

		return

	var json := JSON.new()

	if json.parse(FileAccess.get_file_as_string(manifest_path)) != OK or not json.data is Dictionary:
		_fail("pack.json must contain a JSON object")

		return

	var manifest: Dictionary = json.data

	if manifest.get("format") != FORMAT or manifest.get("version") != 1:
		_fail("Unsupported HD sprite pack format or version")

		return

	if not manifest.get("name") is String or str(manifest.name).strip_edges().is_empty():
		_fail("HD sprite pack name is required")

		return

	pack_name = manifest.name
	var redraw: Variant = manifest.get("redraw_small_highway_ground", false)

	if not redraw is bool:
		_fail("redraw_small_highway_ground must be a boolean")

		return

	redraw_small_highway_ground = redraw
	var records: Variant = manifest.get("sprites")

	if not records is Array or records.is_empty():
		_fail("sprites must be a nonempty array")

		return

	for record: Variant in records:
		if not _load_sprite(record):
			return


func _load_sprite(record: Variant) -> bool:
	if not record is Dictionary:
		return _fail("Sprite record must be an object")

	var id := _whole_number(record.get("id"))

	if id < 0 or id > 65535:
		return _fail("Sprite id must be 0 through 65535")

	if sprites.has(id):
		return _fail("Sprite %d occurs more than one time" % id)

	var logical: Variant = record.get("logical_size")
	var width := _whole_number(logical[0]) if logical is Array and logical.size() == 2 else -1
	var height := _whole_number(logical[1]) if logical is Array and logical.size() == 2 else -1

	if width < 1 or height < 1:
		return _fail("Sprite %d: logical_size must be two positive integers" % id)

	var sprite := HdSprite.new()
	sprite.height = _whole_number(record.get("display_height", height))

	if sprite.height < height or sprite.height > MAX_EDGE:
		return _fail("Sprite %d: display_height must be from the logical height through %d" % [id, MAX_EDGE])

	sprite.image = _read_image(record.get("png"))

	if sprite.image == null:
		return false

	if sprite.image.get_width() > MAX_EDGE or sprite.image.get_height() > MAX_EDGE:
		return _fail("Sprite %d: images must be at most %d pixels on each side" % [id, MAX_EDGE])

	if record.has("animation") and not _load_animation(id, record.animation, sprite):
		return false

	sprites[id] = sprite
	logical_sizes[id] = Vector2i(width, height)

	return true


func _load_animation(id: int, animation: Variant, sprite: HdSprite) -> bool:
	if not animation is Dictionary:
		return _fail("Sprite %d: animation must be an object" % id)

	sprite.frames = _whole_number(animation.get("frames"))
	sprite.fps = _whole_number(animation.get("fps", 8))

	if sprite.frames < 2 or sprite.frames > MAX_FRAMES:
		return _fail("Sprite %d: an animation has 2 through %d frames" % [id, MAX_FRAMES])

	if not sprite.fps in FRAME_RATES:
		return _fail("Sprite %d: the animation rate must be 5 or 8 frames each second" % id)

	sprite.animation = _read_image(animation.get("png"))

	if sprite.animation == null:
		return false

	if (sprite.animation.get_width() != sprite.image.get_width()
			or sprite.animation.get_height() != sprite.image.get_height() * sprite.frames):
		return _fail("Sprite %d: the animation must stack frames of the size of the still image" % id)

	if sprite.animation.get_height() + sprite.frames * 2 > MAX_STRIP_HEIGHT:
		return _fail("Sprite %d: the animation is too tall for the sprite atlas" % id)

	return true


# The RGBA image at a pack path. Records can share one file.
func _read_image(value: Variant) -> Image:
	if not value is String or value.is_empty():
		_fail("PNG path must be a nonempty string")

		return null

	var path: String = value

	if path.is_absolute_path() or path.contains(":") or path.contains("\\"):
		_fail("PNG paths must be relative and use forward slashes")

		return null

	for component in path.split("/"):
		if component in ["", ".", ".."]:
			_fail("PNG paths must not contain empty, dot, or parent components")

			return null

	if path.get_extension().to_lower() != "png":
		_fail("HD sprites must be PNG files")

		return null

	if _images.has(path):
		return _images[path]

	if not FileAccess.file_exists(_root.path_join(path)):
		_fail("Cannot read %s" % path)

		return null

	# the native formats library decodes the file; see native/core/formats/src/png.rs
	var decoded := NativeIndexedPng.decode_rgba(FileAccess.get_file_as_bytes(_root.path_join(path)))

	if not decoded.ok:
		_fail("Cannot read %s" % path)

		return null

	if decoded.width > MAX_EDGE or decoded.height > MAX_STRIP_HEIGHT:
		_fail("%s is too large" % path)

		return null

	var image := Image.create_from_data(decoded.width, decoded.height, false, Image.FORMAT_RGBA8, decoded.pixels)
	_decoded_bytes += image.get_width() * image.get_height() * 4

	if _decoded_bytes > MAX_DECODED_BYTES:
		_fail("The HD sprites use more than %d MiB of memory" % (MAX_DECODED_BYTES / 1048576))

		return null

	_images[path] = image

	return image


static func _whole_number(value: Variant) -> int:
	if (value is int or value is float) and value == int(value):
		return int(value)

	return -1


func _fail(message: String) -> bool:
	error = message

	return false
