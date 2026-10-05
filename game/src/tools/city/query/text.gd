class_name QueryText
extends QueryConstants
## The text of the query dialog. The native simulation library holds the
## rules; see native/core/sim/src/sim/tools/query/text.rs.


static func format_text(info: QueryResult) -> String:
	return NativeCityTools.query_text(info)


static func specific_sound_events(tile_id: int, statistic_0: int) -> Array[int]:
	var result: Array[int] = []
	result.assign(Array(NativeCityTools.query_sound_events(tile_id, statistic_0)))

	return result


static func expand_specific_template(
	city: CityState, microsim: CityRecords.Microsim, template: String
) -> String:
	var args := {
		"tile_id": microsim.tile_id, "stat_0": microsim.stat_0, "stat_1": microsim.stat_1,
		"stat_2": microsim.stat_2, "stat_3": microsim.stat_3, "template": template,
	}

	return NativeSimulationBridge.run("query.template", city, null, null, null, args).result


static func tile_name(city: CityState, point: Vector2i, building := -1) -> String:
	if city == null or city.index_of(point.x, point.y) < 0:
		return ""

	return NativeSimulationBridge.run("query.tile_name", city, null, null, null, {"point": point, "building": building}).result
