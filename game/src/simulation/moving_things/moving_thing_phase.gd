class_name MovingThingPhase
extends RefCounted
## One moving-thing tick. The native library updates each record with its type's rule.

# things and text change on nearly every tick; the map chunks follow
const COMMIT_ORDER := [
	"XTHG", "XTXT", "ALTM", "XBLD", "XTER", "XZON", "XUND", "XBIT", "XTRF", "XLAB", "XMIC", "MISC",
]


static func run(
	city: CityState,
	random: SimRandom,
	lfsr_random: SimLfsrRandom,
	game_random: GameLcgRandom = null,
	ship_home := Vector2i(-1, -1),
	allow_disaster_damage := true,
	traffic_news_time_msec := -1,
	traffic_news_deadline_msec := 0,
	suppress_vehicle_crashes := false
) -> MovingThingResult:
	if city == null or not city.is_valid():
		return MovingThingResult.failure("city is invalid")

	if random == null:
		return MovingThingResult.failure("a compatible random generator is required")

	if lfsr_random == null:
		return MovingThingResult.failure("a compatible LFSR generator is required")

	if game_random == null:
		game_random = GameLcgRandom.new(1)

	if traffic_news_time_msec < 0:
		traffic_news_time_msec = Time.get_ticks_msec()

	var response := NativeSimulationBridge.run("moving", city, random, lfsr_random, game_random, {
		"ship_home": ship_home,
		"allow_disaster_damage": allow_disaster_damage,
		"traffic_news_time_msec": traffic_news_time_msec,
		"traffic_news_deadline_msec": traffic_news_deadline_msec,
		"suppress_vehicle_crashes": suppress_vehicle_crashes,
	}, PackedStringArray(COMMIT_ORDER))

	if not response.failed_chunk.is_empty():
		return MovingThingResult.failure("cannot store %s after the moving-thing tick" % response.failed_chunk)

	return response.result
