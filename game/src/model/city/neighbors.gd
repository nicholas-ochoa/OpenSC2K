class_name CityNeighbors
extends RefCounted
# The four neighboring cities in MISC, and the signs at neighbor connections.
# The original stores no sign record for a connection. Its sign painter
# FUN_0044d9a0 shows a sign at each XTXT connection marker when signs are
# visible, with the name of the neighbor on that map edge and a digit.

@warning_ignore_start("integer_division")

const COUNT := 4
const STRIDE := 0x10
const NAMES: Array[String] = [
	"Oak Creek", "Denmont", "Fort Verdegris", "Schwinton", "Mill Valley", "Petaluma",
	"PortVille", "Ashland", "Eubancs", "Aurac", "Tent Pegs", "Cherryton",
	"Blake", "Pioneers", "Fortune", "Phippsville", "Jeromi", "Harpersville",
	"Washers Grove", "Stars County", "Villa", "Serviland", "Newton", "Avon",
	"Dexter", "Sinistrel", "Jenna", "Yestonia", "New Boots", "Hoek Creek",
	"Stimpleton", "Little Rouge", "Krighton", "Cats Corner", "Rimmer", "Lister",
]

# the painter keeps at most this many characters of the neighbor name
const SIGN_NAME_LENGTH := 20

# a marker less than this many tiles from an edge belongs to that edge
const EDGE_REACH := 2

# map edges in the order of the neighbor slots at compass rotation 0
const SIDE_HIGH_X := 0
const SIDE_HIGH_Y := 1
const SIDE_LOW_X := 2
const SIDE_LOW_Y := 3


static func name_of(name_index: int) -> String:
	if name_index == 0:
		return "Ocean"

	if name_index > 0 and name_index <= NAMES.size():
		return NAMES[name_index - 1]

	return "City %d" % name_index


# the signed name index of MISC neighbor `slot`; 0 is the ocean
static func name_index(city: CityState, slot: int) -> int:
	var low := city.document.misc_u32(Sc2MiscLayout.NEIGHBORS + slot * STRIDE) & 0xffff

	return low - 0x10000 if low & 0x8000 else low


# tile index -> sign text of every connection marker
static func connection_sign_texts(city: CityState) -> Dictionary[int, String]:
	var result: Dictionary[int, String] = {}
	var edge := city.map_size
	var names: Array[String] = []

	for slot in COUNT:
		names.append(name_of(name_index(city, slot)).left(SIGN_NAME_LENGTH))

	var index := OverlayData.find(city.text_overlays, Sc2OverlayLayout.CONNECTION_MARKER)

	while index >= 0:
		var x := index / edge
		var y := index % edge
		var side := SIDE_HIGH_X
		var position := 0

		# later edges win at a corner, in the order of the original
		if y < EDGE_REACH:
			side = SIDE_LOW_Y
			position = x

		if x >= edge - EDGE_REACH:
			side = SIDE_HIGH_X
			position = y

		if y >= edge - EDGE_REACH:
			side = SIDE_HIGH_Y
			position = edge - 1 - x

		if x < EDGE_REACH:
			side = SIDE_LOW_X
			position = edge - 1 - y

		var slot := (city.compass_rotation() + side) & 3
		result[index] = "%s %d" % [names[slot], 5 + position % 5]
		index = OverlayData.find(city.text_overlays, Sc2OverlayLayout.CONNECTION_MARKER, index + 1)

	return result
