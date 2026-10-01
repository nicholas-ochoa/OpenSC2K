class_name DebugTileLayers
extends RefCounted
## The debug tile layers. Each layer gives one byte for each tile, and a table
## of 256 colors tints the tile. Value zero is clear in most layers, so the city
## shows through. DebugLayerColors makes the tables and DebugLayerValues makes
## the bytes.

enum Layer {
	NONE, ZONE_TYPE, BUILDING_ID, TERRAIN_ID, UNDERGROUND_ID, OVERLAY_KIND, LAND_ALTITUDE, WATER_ALTITUDE,
	TUNNEL_LEVELS, SALT_WATER, FLIPPED, WATER, MARK, WATERED, PIPED, POWERED, POWERABLE, TRAFFIC, POLLUTION,
	LAND_VALUE, CRIME, POLICE, FIRE, POPULATION, GROWTH, POWER_GRIDS, WATER_NETWORKS, UNUSUAL_VALUES,
	CHANGED_TILES, DISASTER_PREVIEW, MISSING_ARTWORK,
}
enum Kind {
	IDS,
	CATEGORIES,
	FLAG,
	GRADIENT,
	NETWORKS,
	BITS,
	MARK,
}

# menu groups, in menu order
const GROUPS: Array = [
	["Tile bytes", [Layer.ZONE_TYPE, Layer.BUILDING_ID, Layer.TERRAIN_ID, Layer.UNDERGROUND_ID, Layer.OVERLAY_KIND,
		Layer.LAND_ALTITUDE, Layer.WATER_ALTITUDE, Layer.TUNNEL_LEVELS]],
	["Tile flags (XBIT)", [Layer.SALT_WATER, Layer.FLIPPED, Layer.WATER, Layer.MARK, Layer.WATERED, Layer.PIPED,
		Layer.POWERED, Layer.POWERABLE]],
	["Data maps (raw bytes)", [Layer.TRAFFIC, Layer.POLLUTION, Layer.LAND_VALUE, Layer.CRIME, Layer.POLICE, Layer.FIRE,
		Layer.POPULATION, Layer.GROWTH]],
	["Analysis", [Layer.POWER_GRIDS, Layer.WATER_NETWORKS, Layer.UNUSUAL_VALUES, Layer.CHANGED_TILES]],
	["Check results", [Layer.DISASTER_PREVIEW, Layer.MISSING_ARTWORK]],
]
const TITLES: Dictionary[Layer, String] = {
	Layer.NONE: "None",
	Layer.ZONE_TYPE: "Zone Type (XZON)",
	Layer.BUILDING_ID: "Building ID (XBLD)",
	Layer.TERRAIN_ID: "Terrain ID (XTER)",
	Layer.UNDERGROUND_ID: "Underground ID (XUND)",
	Layer.OVERLAY_KIND: "Overlay Kind (XTXT)",
	Layer.LAND_ALTITUDE: "Land Altitude (ALTM)",
	Layer.WATER_ALTITUDE: "Water Altitude (ALTM)",
	Layer.TUNNEL_LEVELS: "Tunnel Levels (ALTM)",
	Layer.SALT_WATER: "Salt Water",
	Layer.FLIPPED: "Flipped",
	Layer.WATER: "Water",
	Layer.MARK: "Mark",
	Layer.WATERED: "Watered",
	Layer.PIPED: "Piped",
	Layer.POWERED: "Powered",
	Layer.POWERABLE: "Powerable",
	Layer.TRAFFIC: "Traffic (XTRF)",
	Layer.POLLUTION: "Pollution (XPLT)",
	Layer.LAND_VALUE: "Land Value (XVAL)",
	Layer.CRIME: "Crime (XCRM)",
	Layer.POLICE: "Police Power (XPLC)",
	Layer.FIRE: "Fire Power (XFIR)",
	Layer.POPULATION: "Population Density (XPOP)",
	Layer.GROWTH: "Rate of Growth (XROG)",
	Layer.POWER_GRIDS: "Power Grids",
	Layer.WATER_NETWORKS: "Water Networks",
	Layer.UNUSUAL_VALUES: "Unusual Values",
	Layer.CHANGED_TILES: "Changed Tiles",
	Layer.DISASTER_PREVIEW: "Disaster Preview",
	Layer.MISSING_ARTWORK: "Missing Artwork",
}
# layers whose values come from a check, not from the city arrays
const EXTERNAL: Array[Layer] = [Layer.DISASTER_PREVIEW, Layer.MISSING_ARTWORK]
const FLAG_BITS: Dictionary[Layer, int] = {
	Layer.SALT_WATER: Sc2TileFlags.SALT_WATER, Layer.FLIPPED: Sc2TileFlags.FLIPPED, Layer.WATER: Sc2TileFlags.WATER,
	Layer.MARK: Sc2TileFlags.MARK, Layer.WATERED: Sc2TileFlags.WATERED, Layer.PIPED: Sc2TileFlags.PIPED,
	Layer.POWERED: Sc2TileFlags.POWERED, Layer.POWERABLE: Sc2TileFlags.POWERABLE,
}
const DATA_CHUNKS: Dictionary[Layer, String] = {
	Layer.TRAFFIC: "XTRF", Layer.POLLUTION: "XPLT", Layer.LAND_VALUE: "XVAL", Layer.CRIME: "XCRM",
	Layer.POLICE: "XPLC", Layer.FIRE: "XFIR", Layer.POPULATION: "XPOP", Layer.GROWTH: "XROG",
}
# the chunks that each layer reads. a new revision of one of them refreshes the layer
const SOURCE_CHUNKS: Dictionary[Layer, Array] = {
	Layer.ZONE_TYPE: ["XZON"], Layer.BUILDING_ID: ["XBLD"], Layer.TERRAIN_ID: ["XTER"], Layer.UNDERGROUND_ID: ["XUND"],
	Layer.OVERLAY_KIND: ["XTXT"], Layer.LAND_ALTITUDE: ["ALTM"], Layer.WATER_ALTITUDE: ["ALTM"],
	Layer.TUNNEL_LEVELS: ["ALTM"], Layer.POWER_GRIDS: ["XBIT"], Layer.WATER_NETWORKS: ["XBIT"],
	Layer.UNUSUAL_VALUES: ["XZON", "XTER", "XUND", "XBIT"],
	Layer.CHANGED_TILES: ["XBLD", "XZON", "XTER", "ALTM", "XUND", "XTXT", "XBIT"],
}
const ZONE_NAMES := ["No zone", "Light residential", "Dense residential", "Light commercial", "Dense commercial",
	"Light industrial", "Dense industrial", "Military", "Airport", "Seaport"]
const OVERLAY_NAMES := ["None", "Sign", "Facility", "Moving object", "Connection marker", "Other marker"]
const UNUSUAL_NAMES := ["Zone type above 9", "Unused terrain ID", "Unused underground ID", "MARK flag left set"]
const CHANGE_NAMES := ["Building", "Zone", "Terrain", "Altitude", "Underground", "Overlay", "Flags"]


static func title(layer: Layer) -> String:
	return TITLES.get(layer, "")


static func kind(layer: Layer) -> Kind:
	match layer:
		Layer.BUILDING_ID, Layer.TERRAIN_ID, Layer.UNDERGROUND_ID:
			return Kind.IDS
		Layer.ZONE_TYPE, Layer.OVERLAY_KIND:
			return Kind.CATEGORIES
		Layer.POWER_GRIDS, Layer.WATER_NETWORKS:
			return Kind.NETWORKS
		Layer.UNUSUAL_VALUES, Layer.CHANGED_TILES, Layer.DISASTER_PREVIEW:
			return Kind.BITS
		Layer.MISSING_ARTWORK:
			return Kind.MARK

	return Kind.FLAG if FLAG_BITS.has(layer) else Kind.GRADIENT


static func source_chunks(layer: Layer) -> PackedStringArray:
	if FLAG_BITS.has(layer):
		return PackedStringArray(["XBIT"])

	if DATA_CHUNKS.has(layer):
		return PackedStringArray([DATA_CHUNKS[layer]])

	return PackedStringArray(SOURCE_CHUNKS.get(layer, []))


# the largest value of a gradient layer
static func maximum(layer: Layer) -> int:
	match layer:
		Layer.LAND_ALTITUDE, Layer.WATER_ALTITUDE:
			return Sc2AltitudeLayout.LEVEL_MASK
		Layer.TUNNEL_LEVELS:
			return Sc2AltitudeLayout.TUNNEL_FIELD_VALUE_MASK

	return 255


# names of the categories or bits of a layer, in value or bit order
static func category_names(layer: Layer) -> Array:
	match layer:
		Layer.ZONE_TYPE:
			return ZONE_NAMES
		Layer.OVERLAY_KIND:
			return OVERLAY_NAMES
		Layer.UNUSUAL_VALUES:
			return UNUSUAL_NAMES
		Layer.CHANGED_TILES, Layer.DISASTER_PREVIEW:
			return CHANGE_NAMES

	return []


# the inspector text of one layer value
static func describe(layer: Layer, value: int) -> String:
	if value < 0:
		return "No value"

	match kind(layer):
		Kind.IDS:
			return "%d (0x%02X)" % [value, value]
		Kind.FLAG:
			return "Set" if value & FLAG_BITS[layer] else "Clear"
		Kind.NETWORKS:
			if value == 0:
				return "Not in a network"

			var supplied := value >= NativeDebugTiles.SUPPLIED_BASE
			return "Network color %d, %s" % [value, "supplied" if supplied else "not supplied"]
		Kind.BITS:
			return _bit_names(layer, value)
		Kind.MARK:
			return "Needs missing artwork" if value != 0 else "Artwork found"

	if layer == Layer.ZONE_TYPE:
		var zone := value & Sc2ZoneLayout.TYPE_MASK
		var zone_name: String = ZONE_NAMES[zone] if zone < ZONE_NAMES.size() else "Unknown zone"
		return "%s (%d), corners 0x%X" % [zone_name, zone, (value & Sc2ZoneLayout.CORNERS_MASK) >> 4]

	if layer == Layer.OVERLAY_KIND:
		return OVERLAY_NAMES[value] if value < OVERLAY_NAMES.size() else str(value)

	return "%d of %d" % [value, maximum(layer)]


static func _bit_names(layer: Layer, value: int) -> String:
	if value == 0:
		return "None"

	var names := PackedStringArray()
	var all := category_names(layer)

	for bit in all.size():
		if value & (1 << bit):
			names.append(all[bit])

	return ", ".join(names)
