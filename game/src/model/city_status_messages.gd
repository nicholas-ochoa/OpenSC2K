class_name CityStatusMessages
extends RefCounted


const NEED_FIRST := 265
const NEED_COUNT := 15
const BROWNOUT := 280
const WARNING_FIRST := 281
const PAUSED := 528
const WEATHER_FIRST := 33200
const WEATHER_COUNT := 12
const DISASTER_IDS := [
	33212, 33213, 33214, 33215, 33216, 33217, 33218, 33219,
	33232, 33233, 33234, 33235, 33236, 33237, 33238, 33239, 33252,
]
const DISASTER_FALLBACKS := [
	"None", "Fire", "Flood", "Riots", "Pollution", "Crash", "Earthquake", "Tornado",
	"Monster", "Meltdown", "Microwave", "Volcano", "Firestorm", "Mass riots", "Mass floods",
	"Chemical spill", "Hurricane",
]
const NEED_FALLBACKS := [
	"Power plant needed", "More transport needed", "Police needed", "Fire protection needed",
	"Water Shortage Reported", "Hospital needed", "School needed", "Seaport needed",
	"Airport needed", "Zoo needed", "Stadium needed", "Marina needed", "Park needed",
	"Industrial connections needed", "Commercial connections needed",
]


static func resource_ids() -> PackedInt32Array:
	var ids := PackedInt32Array([PAUSED])

	for resource_id in range(NEED_FIRST, WARNING_FIRST + 3):
		ids.append(resource_id)

	for resource_id in range(WEATHER_FIRST, WEATHER_FIRST + WEATHER_COUNT):
		ids.append(resource_id)

	ids.append_array(PackedInt32Array(DISASTER_IDS))

	return ids


static func monthly_resource(status_index: int, weather_trend: int) -> int:
	if status_index >= 0 and status_index < NEED_COUNT:
		return NEED_FIRST + status_index

	if status_index == WeatherDisasterPhase.STATUS_WEATHER and weather_trend >= 9 and weather_trend < WEATHER_COUNT:
		return WARNING_FIRST + weather_trend - 9

	return 0


static func text(resource_id: int, strings: Dictionary = {}) -> String:
	if resource_id == 0:
		return ""

	var original := str(strings.get(resource_id, "")).strip_edges()

	if not original.is_empty():
		return original

	if resource_id >= NEED_FIRST and resource_id < NEED_FIRST + NEED_COUNT:
		return NEED_FALLBACKS[resource_id - NEED_FIRST]

	if resource_id >= WEATHER_FIRST and resource_id < WEATHER_FIRST + WEATHER_COUNT:
		return RciAftermathPhase.WEATHER_NAMES[resource_id - WEATHER_FIRST]

	if resource_id >= WARNING_FIRST and resource_id < WARNING_FIRST + 3:
		return "%s warning" % RciAftermathPhase.WEATHER_NAMES[resource_id - WARNING_FIRST + 9]

	if resource_id == PAUSED:
		return "Paused"

	if resource_id == BROWNOUT:
		return "Brownouts reported"

	var disaster := DISASTER_IDS.find(resource_id)

	if disaster >= 0:
		return DISASTER_FALLBACKS[disaster]

	return ""
