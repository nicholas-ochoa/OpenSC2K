class_name DisasterFocus
extends DisasterStartConstants

@warning_ignore_start("integer_division")

const MARKER_OVERLAYS := {
	DisasterMapConstants.FIRE_OVERLAY: true,
	DisasterMapConstants.TOXIC_OVERLAY: true,
	DisasterMapConstants.FLOOD_OVERLAY: true,
	RIOT_OVERLAY_FORWARD: true,
	RIOT_OVERLAY_REVERSE: true,
}


# returns the disaster tile, or a negative point when nothing is located
static func find_point(city: CityState) -> Vector2i:
	if city == null or not city.is_valid():
		return Vector2i(-1, -1)

	var thing_point := _thing_point(city)

	return thing_point if thing_point.x >= 0 else _marker_point(city)


static func _thing_point(city: CityState) -> Vector2i:
	var chunk := city.document.find_chunk("XTHG")

	if chunk == null or chunk.decoded_payload.size() != city.document.decoded_size("XTHG"):
		return Vector2i(-1, -1)

	var things: PackedByteArray = chunk.decoded_payload

	for record in range(1, ThingData.count(things)):
		var offset := record * CityState.THING_RECORD_SIZE
		var type := int(ThingData.read(things, offset))

		if (
			type == TYPE_MONSTER
			or type == TYPE_TORNADO
			or type == TYPE_EXPLOSION
			or (type == TYPE_AIRPLANE and ThingData.read(things, offset + 2) == 7)
		):
			return Vector2i(
				ThingData.read(things, offset + 3), ThingData.read(things, offset + 4)
			)

	return Vector2i(-1, -1)


static func _marker_point(city: CityState) -> Vector2i:
	var map_edge: int = city.map_size
	var markers := PackedInt32Array()

	# a search of the overlay bytes costs much less than a check of each tile
	for overlay: int in MARKER_OVERLAYS:
		var found := OverlayData.find(city.text_overlays, overlay)

		while found >= 0:
			markers.append(found)
			found = OverlayData.find(city.text_overlays, overlay, found + 1)

	if markers.is_empty():
		return Vector2i(-1, -1)

	# tile order, x first, so equal distances choose the first tile
	markers.sort()
	var total := Vector2i.ZERO

	for index in markers:
		total += Vector2i(index / map_edge, index % map_edge)

	# scattered markers average to a quiet tile, so snap back to the nearest marker
	var average := Vector2i(total.x / markers.size(), total.y / markers.size())
	var nearest := Vector2i(-1, -1)
	var nearest_distance := map_edge * 2

	for index in markers:
		var point := Vector2i(index / map_edge, index % map_edge)
		var distance := absi(point.x - average.x) + absi(point.y - average.y)

		if distance < nearest_distance:
			nearest = point
			nearest_distance = distance

	return nearest
