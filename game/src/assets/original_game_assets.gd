class_name OriginalGameAssets
extends RefCounted

const PaletteLoader = preload("res://src/assets/sc2_palette.gd")
const SpriteLoader = preload("res://src/assets/sc2_sprite_archive.gd")
const BitmapLoader = preload("res://src/assets/pe_bitmap_resource.gd")
const TextLoader = preload("res://src/assets/text_usa_resource.gd")
const NewspaperLoader = preload("res://src/assets/data_usa_resource.gd")
const LibraryWindows = preload("res://src/ui/city_windows/library_ruminate_windows.gd")

const CREDITS_TEXT_RESOURCE_ID := 128
const FOREST_PROTEST_BITMAP_ID := 403

var forest_protest_image: Image
var library_texts: Dictionary[int, String] = {}
var original_credits := ""
var newspaper_data: DataUsaResource
var toolbar_art: Image
var industry_icons: Image
var city_map_icons: Image
var simnation_sprites: Image
var palette: Sc2Palette
var scenario_palette: Sc2Palette
var large_sprites: Sc2SpriteArchive
var small_medium_sprites: Sc2SpriteArchive
var scurk_graphics: ScurkGraphics
var city_ui_graphics: CityUiGraphics
var desktop_graphics: DesktopGraphics
var scenario_graphics: ScenarioGraphics
var error := ""


static func load_root(reference_root: String) -> OriginalGameAssets:
	var result := OriginalGameAssets.new()
	result.load_ui(reference_root)
	result.load_city_graphics(reference_root)

	return result


func load_ui(reference_root: String) -> void:
	load_text_data(reference_root)
	city_ui_graphics = CityUiGraphics.load_original(reference_root)
	desktop_graphics = DesktopGraphics.load_original(reference_root)

	toolbar_art = _bitmap_image(reference_root, 2)
	industry_icons = _bitmap_image(reference_root, 178)
	city_map_icons = _bitmap_image(reference_root, 247)
	var protest_image := Image.load_from_file(
		reference_root.path_join("BITMAPS/%d.BMP" % FOREST_PROTEST_BITMAP_ID)
	)

	if protest_image != null and not protest_image.is_empty():
		forest_protest_image = protest_image

	simnation_sprites = Image.load_from_file(
		reference_root.path_join("BITMAPS/NEIGHBOR.BMP")
	)


func load_text_data(reference_root: String) -> void:
	load_original_credits(reference_root)
	newspaper_data = NewspaperLoader.load_path(
		reference_root.path_join("DATA/DATA_USA.DAT"),
		reference_root.path_join("DATA/DATA_USA.IDX"),
	)

	var library_resources := TextLoader.load_ids(
		reference_root.path_join("DATA/TEXT_USA.DAT"),
		reference_root.path_join("DATA/TEXT_USA.IDX"),
		PackedInt32Array(LibraryWindows.TEXT_RESOURCE_IDS),
	)

	if library_resources.ok:
		library_texts = library_resources.strings


func load_original_credits(reference_root: String) -> void:
	original_credits = ""
	var credits := TextLoader.load_ids(
		reference_root.path_join("DATA/TEXT_USA.DAT"),
		reference_root.path_join("DATA/TEXT_USA.IDX"),
		PackedInt32Array([CREDITS_TEXT_RESOURCE_ID]),
	)
	if credits.ok:
		original_credits = credits.strings[CREDITS_TEXT_RESOURCE_ID]


func load_city_graphics(reference_root: String) -> void:
	palette = PaletteLoader.load_bmp(reference_root.path_join("BITMAPS/PAL_MSTR.BMP"))

	if not palette.is_valid():
		error = palette.load_error

		return

	scenario_palette = PaletteLoader.load_bmp(
		reference_root.path_join("BITMAPS/PAL_MAC.BMP")
	)

	if not scenario_palette.is_valid():
		error = scenario_palette.load_error

		return

	large_sprites = SpriteLoader.load_path(reference_root.path_join("DATA/LARGE.DAT"))

	if not large_sprites.is_valid():
		error = large_sprites.parse_error

		return

	var small_sprites := SpriteLoader.load_path(
		reference_root.path_join("DATA/SMALLMED.DAT")
	)

	if not small_sprites.is_valid():
		error = small_sprites.parse_error

		return

	var special_sprites := SpriteLoader.load_path(
		reference_root.path_join("DATA/SPECIAL.DAT")
	)

	if not special_sprites.is_valid():
		error = special_sprites.parse_error

		return

	small_medium_sprites = SpriteLoader.combine([small_sprites, special_sprites])


func _bitmap_image(reference_root: String, resource_id: int) -> Image:
	var loaded := BitmapLoader.load_numeric(
		reference_root.path_join("SIMCITY.EXE"), resource_id
	)

	return loaded.image if loaded.ok else null
