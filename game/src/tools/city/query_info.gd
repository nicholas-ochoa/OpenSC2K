class_name QueryInfo
extends QueryConstants
## What a Query tool click shows. The native simulation library holds the
## rules; see native/core/sim/src/sim/tools/query/mod.rs. The view adds the sprites.


static func inspect(city: CityState, point: Vector2i) -> QueryResult:
	if city == null or not city.is_valid():
		return QueryResult.failure("city is invalid")

	var result: QueryResult = NativeSimulationBridge.run("query.inspect", city, null, null, null, {"point": point}).result

	if not result.ok:
		return result

	result.sprite_id = Presentation.sprite_id(city, result)

	for thing in result.things:
		var visual := Presentation.thing_sprite(city, point, thing, thing.record)
		thing.sprite_id = visual.sprite_id if visual != null else -1
		thing.sprite_flip = visual.flip if visual != null else false

	return result
