class_name GraphicsPack
extends RefCounted

const Png = preload("res://src/assets/indexed_png.gd")
const UI_FIELDS := ["toolbar_art", "industry_icons", "city_map_icons", "simnation_sprites", "forest_protest_image"]

var error := ""
var pack_name := ""
var partial := false
var import_revision := ImportedPackRevision.NOT_IMPORTED
var palette: Sc2Palette
var scenario_palette: Sc2Palette
var large_sprites := Sc2SpriteArchive.new()
var small_medium_sprites := Sc2SpriteArchive.new()
var ui_images: Dictionary[String, Image] = {}
var scurk_graphics: ScurkGraphics
var city_ui_graphics: CityUiGraphics
var desktop_graphics: DesktopGraphics
var scenario_graphics: ScenarioGraphics
var _root := ""


static func load_root(root: String) -> GraphicsPack:
	var pack := GraphicsPack.new()
	pack._root = (root.get_base_dir() if root.get_file() == "pack.json" else root).simplify_path()
	pack._load()

	return pack


func apply_to(assets: OriginalGameAssets) -> bool:
	if not error.is_empty():
		return false

	var has_large := not large_sprites.entries.is_empty()
	var has_small := not small_medium_sprites.entries.is_empty()

	# one palette for both sizes; replacing half the art mustn't recolor the other half
	# all city sprites use one indexed palette. do not recolor a retained archive
	# when a partial pack only replaces the other size group
	if partial and has_large != has_small and assets.palette != null and assets.palette.colors != palette.colors:
		return _fail("This partial pack needs both city sprite size groups to change the active palette.")

	if not partial or has_large or has_small:
		assets.palette = palette

	if scenario_palette != null:
		assets.scenario_palette = scenario_palette

	if not partial or has_large:
		assets.large_sprites = large_sprites

	if not partial or has_small:
		assets.small_medium_sprites = small_medium_sprites

	if scurk_graphics != null:
		assets.scurk_graphics = scurk_graphics

	if city_ui_graphics != null:
		assets.city_ui_graphics = city_ui_graphics

	if desktop_graphics != null:
		assets.desktop_graphics = desktop_graphics

	if scenario_graphics != null:
		assets.scenario_graphics = scenario_graphics

	for field in ui_images:
		assets.set(field, ui_images[field])

	return true


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

	if manifest.get("format") != "opensc2k-graphics" or manifest.get("version") != 1:
		_fail("Unsupported graphics pack format or version")

		return

	if not manifest.get("name") is String or str(manifest.name).strip_edges().is_empty():
		_fail("Graphics pack name is required")

		return

	pack_name = manifest.name
	import_revision = ImportedPackRevision.read(manifest)

	if import_revision == ImportedPackRevision.INVALID:
		_fail("import_revision must be a whole number that is not negative")

		return

	var partial_value: Variant = manifest.get("partial", false)

	if not partial_value is bool:
		_fail("partial must be a boolean")
		return

	partial = partial_value
	var redraw: Variant = manifest.get("redraw_small_highway_ground", false)

	if not redraw is bool:
		_fail("redraw_small_highway_ground must be a boolean")

		return

	large_sprites.redraw_small_highway_ground = redraw
	small_medium_sprites.redraw_small_highway_ground = redraw
	var palette_image := _read_png(manifest.get("palette"))

	if not error.is_empty():
		return

	palette = palette_image.palette
	if not partial or manifest.has("scenario_palette"):
		var scenario_image := _read_png(manifest.get("scenario_palette"))

		if not error.is_empty():
			return

		scenario_palette = scenario_image.palette

	if not _load_sprites(manifest.get("large_sprites", []), large_sprites):
		return

	if not _load_sprites(manifest.get("small_medium_sprites", []), small_medium_sprites):
		return

	var ui: Variant = manifest.get("ui", {} if partial else null)

	if not ui is Dictionary:
		_fail("ui must be an object")

		return

	for field in ui:
		if not field in UI_FIELDS:
			_fail("Unknown UI image: %s" % field)

			return

	for field in UI_FIELDS:
		if partial and not ui.has(field):
			continue

		var decoded := _read_png(ui.get(field))

		if not error.is_empty():
			return

		var entry := Sc2SpriteArchive.entry_from_indices(0, decoded.width, decoded.height, decoded.pixels)
		var rendered := entry.create_image(decoded.palette)
		ui_images[field] = rendered.image

	if manifest.has("scurk"):
		scurk_graphics = ScurkGraphics.load_manifest(manifest.scurk, _read_png, palette)

		if error.is_empty() and not scurk_graphics.error.is_empty():
			_fail(scurk_graphics.error)

	if error.is_empty() and manifest.has("city_ui"):
		city_ui_graphics = CityUiGraphics.load_manifest(manifest.city_ui, _read_png, palette)

		if error.is_empty() and not city_ui_graphics.error.is_empty():
			_fail(city_ui_graphics.error)

	if error.is_empty() and manifest.has("desktop"):
		desktop_graphics = DesktopGraphics.load_manifest(manifest.desktop, _read_png, palette)

		if error.is_empty() and not desktop_graphics.error.is_empty():
			_fail(desktop_graphics.error)

	if error.is_empty() and manifest.has("scenario_pictures"):
		if scenario_palette == null:
			_fail("scenario_palette is required for scenario pictures")
			return

		scenario_graphics = ScenarioGraphics.load_manifest(manifest.scenario_pictures, _read_png, scenario_palette)

		if error.is_empty() and not scenario_graphics.error.is_empty():
			_fail(scenario_graphics.error)

	if error.is_empty() and large_sprites.entries.is_empty() and small_medium_sprites.entries.is_empty() and ui_images.is_empty() and scurk_graphics == null and city_ui_graphics == null and desktop_graphics == null and scenario_graphics == null:
		_fail("Graphics pack contains no assets")


func _load_sprites(records: Variant, archive: Sc2SpriteArchive) -> bool:
	if not records is Array or (records.is_empty() and not partial):
		return _fail("Sprite lists must be nonempty arrays")

	var duplicate_counts: Dictionary[int, int] = {}

	for record in records:
		if not record is Dictionary:
			return _fail("Sprite record must be an object")

		var identifier: Variant = record.get("id")

		if not (identifier is int or identifier is float):
			return _fail("Sprite id must be an integer")

		if identifier != int(identifier) or identifier < 0 or identifier > 65535:
			return _fail("Sprite id must be 0 through 65535")

		var decoded := _read_png(record.get("png"))

		if not error.is_empty():
			return false

		if decoded.palette.colors != palette.colors:
			return _fail("Sprite palette differs from the pack palette: %s" % record.png)

		var entry := Sc2SpriteArchive.entry_from_indices(int(identifier), decoded.width, decoded.height, decoded.pixels)
		entry.duplicate_index = int(duplicate_counts.get(entry.sprite_id, 0))
		duplicate_counts[entry.sprite_id] = entry.duplicate_index + 1
		archive.entries.append(entry)
		archive.entries_by_id[entry.sprite_id] = entry

	return true


func _read_png(relative_path: Variant) -> IndexedImageResult:
	if not relative_path is String or relative_path.is_empty():
		_fail("PNG path must be a nonempty string")

		return null

	var path: String = relative_path

	if path.is_absolute_path() or path.contains(":") or path.contains("\\"):
		_fail("PNG paths must be relative and use forward slashes")

		return null

	for component in path.split("/"):
		if component in ["", ".", ".."]:
			_fail("PNG paths must not contain empty, dot, or parent components")

			return null

	if path.get_extension().to_lower() != "png":
		_fail("Graphics files must be PNG")

		return null

	var decoded := Png.load_path(_root.path_join(path))

	if not decoded.ok:
		_fail("%s: %s" % [path, decoded.error])

		return null

	return decoded


func _fail(message: String) -> bool:
	error = message

	return false
