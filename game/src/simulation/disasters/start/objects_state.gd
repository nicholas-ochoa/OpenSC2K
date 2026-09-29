class_name DisasterStartObjectsState
extends DisasterStartConstants


static func has_active_object(city: CityState, _disaster_type: int) -> bool:
	if city == null or not city.is_valid():
		return false

	var chunk := city.document.find_chunk("XTHG")

	if chunk == null or chunk.decoded_payload.size() != city.document.decoded_size("XTHG"):
		return false

	var things: PackedByteArray = chunk.decoded_payload

	for record in range(1, ThingData.count(things)):
		if city.simulation_slice != null:
			city.simulation_slice.checkpoint()

		var offset := record * CityState.THING_RECORD_SIZE
		var type := int(ThingData.read(things, offset))

		if type == TYPE_MONSTER or type == TYPE_TORNADO or type == TYPE_EXPLOSION:
			return true

		if type == TYPE_AIRPLANE and ThingData.read(things, offset + 2) == 7:
			return true

	return false
