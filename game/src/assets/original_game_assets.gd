class_name OriginalGameAssets
extends RefCounted

const PaletteLoader = preload("res://src/assets/sc2_palette.gd")
const SpriteLoader = preload("res://src/assets/sc2_sprite_archive.gd")
const BitmapLoader = preload("res://src/assets/pe_bitmap_resource.gd")
const StringLoader = preload("res://src/assets/pe_string_resource.gd")
const TextLoader = preload("res://src/assets/text_usa_resource.gd")
const NewspaperLoader = preload("res://src/assets/data_usa_resource.gd")
const Queries = preload("res://src/tools/query_info.gd")
const LibraryWindows = preload("res://src/ui/library_ruminate_windows.gd")

const FOREST_PROTEST_BITMAP_ID := 403
const FOREST_PROTEST_STRING_ID := 236
const BUILDING_OBJECTION_STRING_ID := 106
const INDUSTRY_STRING_FIRST := 422
const INDUSTRY_STRING_LAST := 432
const CITY_MAP_STRING_FIRST := 327
const CITY_MAP_STRING_LAST := 344
const SIMNATION_FORMAT_STRING_ID := 421
const NEIGHBOR_NAME_STRING_FIRST := 548
const NEIGHBOR_NAME_STRING_LAST := 583
const NEWSPAPER_STRING_FIRST := 347
const NEWSPAPER_STRING_LAST := 391

const DEFAULT_FOREST_PROTEST_TEXT := "Citizens are protesting forest demolition."
const DEFAULT_BUILDING_OBJECTION_TEXT := "Residents objected to this facility site."

var strings: Dictionary = {}
var forest_protest_text := DEFAULT_FOREST_PROTEST_TEXT
var building_objection_text := DEFAULT_BUILDING_OBJECTION_TEXT
var forest_protest_image: Image
var library_texts: Dictionary = {}
var newspaper_data: DataUsaResource
var toolbar_art: Image
var industry_icons: Image
var city_map_icons: Image
var simnation_sprites: Image
var palette: Sc2Palette
var scenario_palette: Sc2Palette
var large_sprites: Sc2SpriteArchive
var small_medium_sprites: Sc2SpriteArchive
var error := ""


static func load_root(reference_root: String) -> OriginalGameAssets:
	var result := OriginalGameAssets.new()
	result.load_ui(reference_root)
	result.load_city_graphics(reference_root)
	return result


static func required_string_ids() -> PackedInt32Array:
	var result := Queries.resource_string_ids()
	result.append(FOREST_PROTEST_STRING_ID)
	result.append(BUILDING_OBJECTION_STRING_ID)
	for resource_id in range(INDUSTRY_STRING_FIRST, INDUSTRY_STRING_LAST + 1):
		result.append(resource_id)
	for resource_id in range(CITY_MAP_STRING_FIRST, CITY_MAP_STRING_LAST + 1):
		result.append(resource_id)
	result.append(SIMNATION_FORMAT_STRING_ID)
	for resource_id in range(
		NEIGHBOR_NAME_STRING_FIRST, NEIGHBOR_NAME_STRING_LAST + 1
	):
		result.append(resource_id)
	for resource_id in range(NEWSPAPER_STRING_FIRST, NEWSPAPER_STRING_LAST + 1):
		result.append(resource_id)
	return result


func load_ui(reference_root: String) -> void:
	newspaper_data = NewspaperLoader.load_path(
		reference_root.path_join("DATA/DATA_USA.DAT"),
		reference_root.path_join("DATA/DATA_USA.IDX"),
	)
	var string_resources := StringLoader.load_ids(
		reference_root.path_join("SIMCITY.EXE"), required_string_ids()
	)
	if string_resources.ok:
		strings = string_resources.strings
		forest_protest_text = strings.get(
			FOREST_PROTEST_STRING_ID, forest_protest_text
		)
		building_objection_text = strings.get(
			BUILDING_OBJECTION_STRING_ID, building_objection_text
		)
	var library_resources := TextLoader.load_ids(
		reference_root.path_join("DATA/TEXT_USA.DAT"),
		reference_root.path_join("DATA/TEXT_USA.IDX"),
		PackedInt32Array(LibraryWindows.TEXT_RESOURCE_IDS),
	)
	if library_resources.ok:
		library_texts = library_resources.strings

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
	return loaded.get("image") as Image if loaded.ok else null
