class_name DebugLayerValues
extends RefCounted
## The tile bytes of a debug layer, as an R8 image that the layer shader reads.
## A worker thread builds the bytes from shared copies of the city arrays.
## Raw layers upload the city array as it is; the color table masks the bits.
## The native library makes the derived layers. Coarse data maps keep their own
## size, and the shader samples them by tile.

@warning_ignore_start("integer_division")

const Layer = DebugTileLayers.Layer


# the arrays that a layer reads. packed arrays share their data until the city
# writes them, so a worker thread can build from this copy while the game runs
static func source(city: CityState, layer: Layer) -> Dictionary:
	var result := {"edge": city.map_size, "flags": city.tile_flags}

	match layer:
		Layer.ZONE_TYPE, Layer.UNUSUAL_VALUES:
			result.zones = city.zones
			result.terrain = city.terrain
			result.underground = city.underground
		Layer.BUILDING_ID:
			result.buildings = city.buildings
		Layer.TERRAIN_ID:
			result.terrain = city.terrain
		Layer.UNDERGROUND_ID:
			result.underground = city.underground
		Layer.OVERLAY_KIND:
			result.overlays = city.text_overlays
		Layer.LAND_ALTITUDE, Layer.WATER_ALTITUDE, Layer.TUNNEL_LEVELS:
			result.altitude = city.altitude_words
		_:
			if DebugTileLayers.DATA_CHUNKS.has(layer):
				var chunk := city.document.find_chunk(DebugTileLayers.DATA_CHUNKS[layer])
				result.data = chunk.decoded_payload if chunk != null else PackedByteArray()

	return result


# build the layer bytes from `source`. Safe on a worker thread
static func build(tiles: Dictionary, layer: Layer, changes: PackedByteArray = PackedByteArray()) -> Result:
	var result := Result.new()
	var map_edge: int = tiles.edge
	var edge := map_edge
	var data := PackedByteArray()

	match layer:
		Layer.ZONE_TYPE:
			data = tiles.zones
		Layer.BUILDING_ID:
			data = tiles.buildings
		Layer.TERRAIN_ID:
			data = tiles.terrain
		Layer.UNDERGROUND_ID:
			data = tiles.underground
		Layer.OVERLAY_KIND:
			data = NativeDebugTiles.overlay_kinds(tiles.overlays, edge * edge)
		Layer.LAND_ALTITUDE:
			data = NativeDebugTiles.altitude_field(tiles.altitude, 0, Sc2AltitudeLayout.LEVEL_MASK)
		Layer.WATER_ALTITUDE:
			data = NativeDebugTiles.altitude_field(tiles.altitude, Sc2AltitudeLayout.WATER_SHIFT, Sc2AltitudeLayout.LEVEL_MASK)
		Layer.TUNNEL_LEVELS:
			data = NativeDebugTiles.altitude_field(tiles.altitude, Sc2AltitudeLayout.TUNNEL_SHIFT,
				Sc2AltitudeLayout.TUNNEL_FIELD_VALUE_MASK)
		Layer.POWER_GRIDS, Layer.WATER_NETWORKS:
			var power := layer == Layer.POWER_GRIDS
			var networks := NativeDebugTiles.networks(tiles.flags, edge,
				Sc2TileFlags.POWERABLE if power else Sc2TileFlags.PIPED, Sc2TileFlags.POWERED if power else Sc2TileFlags.WATERED)
			data = networks.values
			result.summary = "%d networks, %d supplied, largest %d tiles" % [networks.count, networks.supplied, networks.largest]
		Layer.UNUSUAL_VALUES:
			data = NativeDebugTiles.unusual_values(tiles.zones, tiles.terrain, tiles.underground, tiles.flags)
		Layer.CHANGED_TILES:
			data = changes
		_:
			if DebugTileLayers.FLAG_BITS.has(layer):
				data = tiles.flags
			elif DebugTileLayers.DATA_CHUNKS.has(layer):
				data = tiles.get("data", PackedByteArray())
				edge = CityDataGrid.edge(data, map_edge)

	if edge <= 0 or data.size() != edge * edge:
		data = PackedByteArray()
		data.resize(map_edge * map_edge)
		edge = map_edge

	result.image = Image.create_from_data(edge, edge, false, Image.FORMAT_R8, data)
	result.values = data
	result.edge = edge

	return result


# the layer value of one tile, or -1 outside the map
static func value_at(result: Result, map_edge: int, point: Vector2i) -> int:
	if result == null or point.x < 0 or point.y < 0 or point.x >= map_edge or point.y >= map_edge:
		return -1

	var scale := maxi(1, map_edge / maxi(1, result.edge))
	var index := (point.x / scale) * result.edge + point.y / scale

	return result.values[index] if index < result.values.size() else -1


class Result extends RefCounted:
	var image: Image
	var values := PackedByteArray()
	var edge := 0
	# a one-line summary for the legend, such as the network counts
	var summary := ""
