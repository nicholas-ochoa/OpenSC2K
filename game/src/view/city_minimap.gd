class_name CityMinimap
extends RefCounted
## City Map window images. The native library selects each tile color.

const MODES := [
	"structures",
	"zones",
	"roads",
	"rail",
	"traffic",
	"power",
	"water",
	"density",
	"growth",
	"crime",
	"police_power",
	"police_stations",
	"pollution",
	"land_value",
	"fire_power",
	"fire_stations",
	"schools",
	"colleges",
]


# one pixel per tile up to 1024 tiles. a larger map samples every second or
# fourth tile, since the map window never shows more than 1024 pixels
static func create_image(city: CityState, palette: Sc2Palette, mode := "structures") -> Image:
	var map_edge: int = city.map_size if city != null else 128
	var image_edge := NativeCityMinimap.image_edge(map_edge)

	if city != null and city.is_valid() and palette != null and palette.is_valid():
		var image := NativeCityMinimap.create_image(_request(city, mode), _palette_rgba(palette))

		if image != null:
			return image

	return Image.create(image_edge, image_edge, false, Image.FORMAT_RGBA8)


# the palette index of one tile. tiles outside the map are 0
static func color_index(city: CityState, x: int, y: int, mode := "structures") -> int:
	if city == null or not city.is_valid():
		return 0

	return maxi(0, NativeCityMinimap.color_index(_request(city, mode), x, y))


static func _request(city: CityState, mode: String) -> Dictionary:
	var chunk_id := NativeCityMinimap.data_chunk(mode)
	var data := PackedByteArray()

	# a data map of an unexpected size reads as zero
	if not chunk_id.is_empty():
		var chunk := city.document.find_chunk(chunk_id)

		if chunk != null and chunk.decoded_payload.size() == city.document.decoded_size(chunk_id):
			data = chunk.decoded_payload

	return {"edge": city.map_size, "buildings": city.buildings, "zones": city.zones, "flags": city.tile_flags,
		"underground": city.underground, "altitude": city.altitude_words, "mode": mode, "data": data}


static func _palette_rgba(palette: Sc2Palette) -> PackedByteArray:
	var bytes := PackedByteArray()
	bytes.resize(1024)

	for index in 256:
		var color := palette.color(index)
		bytes.encode_u32(index * 4, color.to_abgr32())

	return bytes
