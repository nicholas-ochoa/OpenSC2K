class_name DisasterFocus
extends DisasterStartConstants


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
	var total := Vector2i.ZERO
	var count := 0

	for x in map_edge:
		for y in map_edge:
			if MARKER_OVERLAYS.has(city.text_overlay_id(x, y)):
				total += Vector2i(x, y)
				count += 1

	if count == 0:
		return Vector2i(-1, -1)

	# scattered markers average to a quiet tile, so snap back to the nearest marker
	var average := Vector2i(total.x / count, total.y / count)
	var nearest := Vector2i(-1, -1)
	var nearest_distance := map_edge * 2

	for x in map_edge:
		for y in map_edge:
			if not MARKER_OVERLAYS.has(city.text_overlay_id(x, y)):
				continue

			var distance := absi(x - average.x) + absi(y - average.y)

			if distance < nearest_distance:
				nearest = Vector2i(x, y)
				nearest_distance = distance

	return nearest
