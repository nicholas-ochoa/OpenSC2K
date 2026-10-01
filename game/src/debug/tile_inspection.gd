class_name TileInspection
extends RefCounted
## The stored values of one tile for the Tile Inspector: the tile bytes, the
## decoded XBIT flags and ALTM fields, the overlay layers, the data maps and
## the moving things on the tile. Inspection reads the city only.

const FLAG_NAMES := ["SALT", "FLIP", "WATER", "MARK", "WATERED", "PIPED", "POWERED", "POWERABLE"]
const DATA_CHUNKS := ["XTRF", "XPLT", "XVAL", "XCRM", "XPLC", "XFIR", "XPOP", "XROG"]


# rows of [caption, text]. an empty list means the point is outside the map
static func rows(city: CityState, point: Vector2i) -> Array:
	var index := city.index_of(point.x, point.y) if city != null else -1

	if index < 0:
		return []

	var result := []
	var building := int(city.buildings[index])
	var zone := int(city.zones[index])
	var word := int(city.altitude_words[index])
	var flags := int(city.tile_flags[index])

	result.append(["Tile", "%d, %d  (cell %d)" % [point.x, point.y, index]])
	result.append(["Building", _byte(building)])
	result.append(["Zone", DebugTileLayers.describe(DebugTileLayers.Layer.ZONE_TYPE, zone) + "  " + _byte(zone)])
	result.append(["Terrain", _byte(int(city.terrain[index]))])
	result.append(["Underground", _byte(int(city.underground[index]))])
	result.append(["Altitude", "land %d, water %d, tunnel %d  (0x%04X)" % [
		word & Sc2AltitudeLayout.LAND_MASK, (word >> Sc2AltitudeLayout.WATER_SHIFT) & Sc2AltitudeLayout.LEVEL_MASK,
		(word >> Sc2AltitudeLayout.TUNNEL_SHIFT) & Sc2AltitudeLayout.TUNNEL_FIELD_VALUE_MASK, word & 0xffff]])
	result.append(["XBIT", "%s  %s" % [_byte(flags), flag_names(flags)]])
	result.append(["Overlay", overlay_text(city.text_overlays, index)])
	result.append(["Data maps", data_map_text(city, point)])
	var things := thing_text(city, point)

	if not things.is_empty():
		result.append(["Things", things])

	return result


static func text(city: CityState, point: Vector2i, extra: Array = []) -> String:
	var lines := PackedStringArray()

	for row in rows(city, point) + extra:
		lines.append("%-12s %s" % [row[0], row[1]])

	return "\n".join(lines)


static func flag_names(flags: int) -> String:
	var names := PackedStringArray()

	for bit in FLAG_NAMES.size():
		if flags & (1 << bit):
			names.append(FLAG_NAMES[bit])

	return " ".join(names) if not names.is_empty() else "none"


# the top value and, in a layered index, each layer
static func overlay_text(overlays: PackedByteArray, index: int) -> String:
	if index >= OverlayData.count(overlays):
		return "none"

	var top := OverlayData.read(overlays, index)
	var result := "%d (%s)" % [top, _overlay_kind(top)]

	if OverlayData.is_layered(overlays):
		result += "  marker %d, facility %d, object %d" % [
			OverlayData.marker(overlays, index), OverlayData.facility(overlays, index), OverlayData.object(overlays, index)]

	return result


static func _overlay_kind(id: int) -> String:
	if id == 0:
		return "none"

	if OverlayData.is_sign(id):
		return "sign"

	if OverlayData.is_facility(id):
		return "facility"

	if OverlayData.is_thing(id):
		return "moving object"

	return "connection marker" if id == Sc2OverlayLayout.CONNECTION_MARKER else "marker"


# each data map value at the tile; coarse maps read their cell
static func data_map_text(city: CityState, point: Vector2i) -> String:
	var parts := PackedStringArray()

	for chunk_id in DATA_CHUNKS:
		var chunk := city.document.find_chunk(chunk_id) if city.document != null else null

		if chunk == null:
			continue

		var at := CityDataGrid.index(chunk.decoded_payload, city.map_size, point.x, point.y)

		if at >= 0:
			parts.append("%s %d" % [chunk_id, chunk.decoded_payload[at]])

	return "  ".join(parts) if not parts.is_empty() else "none"


# the top moving object of the tile, which the overlay index names
static func thing_text(city: CityState, point: Vector2i) -> String:
	var index := city.index_of(point.x, point.y)
	var overlays := city.text_overlays
	var id := OverlayData.object(overlays, index) if OverlayData.is_layered(overlays) else OverlayData.read(overlays, index)

	if not OverlayData.is_thing(id):
		return ""

	var record_index := OverlayData.thing_record(id)
	var record := city.thing(record_index)

	if record == null:
		return "object %d (no record)" % id

	return "#%d %s, state %d, target %d, %d" % [record_index, DebugObjectFields.type_name(record.type), record.state,
		record.dx, record.dy]


static func _byte(value: int) -> String:
	return "0x%02X (%d)" % [value, value]
