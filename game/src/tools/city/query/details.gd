class_name QueryDetails
extends QueryConstants
## Query values. The native simulation library holds the rules; see
## native/core/sim/src/sim/tools/query/mod.rs.


static func traffic(
	city: CityState, values: PackedByteArray, point: Vector2i, building: int
) -> int:
	return NativeCityTools.query_traffic(values, city.map_size if city != null else 128, point, building)


# the executable selects the first level whose threshold is above the value
static func level_name(value: int) -> String:
	return NativeCityTools.query_level_name(value)
