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
const NEEDS: Array[String] = [
	"Power Plant Needed", "Citizens Demand Road & Rail", "Citizens Demand Police",
	"Fire Protection Demanded", "Water Shortage Reported", "Hospitals Demanded",
	"Citizens Demand Schools", "Industry Demands Seaport", "Commerce Demands Airport",
	"Residents Demand Zoo", "Residents Demand Stadium", "Residents Demand Marina",
	"Residents Demand Park", "Industry Needs Connections", "Commerce Needs Connections",
]
const WARNINGS: Array[String] = ["Blizzard Warning", "Hurricane Warning", "Tornado Warning"]
const DISASTERS: Array[String] = [
	"None", "Fire", "Flood", "Riots", "Pollution", "Crash", "Earthquake", "Tornado",
	"Monster", "Meltdown", "Microwave", "Volcano", "Fire Storm", "Mass Riots", "Major Flood",
	"Chemical Spill", "Hurricane",
]
const BROWNOUTS := "Brownouts Reported"
const PAUSED_TEXT := "*PAUSED*"


static func monthly_resource(status_index: int, weather_trend: int) -> int:
	if status_index >= 0 and status_index < NEED_COUNT:
		return NEED_FIRST + status_index

	if status_index == WeatherDisasterPhase.STATUS_WEATHER and weather_trend >= 9 and weather_trend < WEATHER_COUNT:
		return WARNING_FIRST + weather_trend - 9

	return 0


static func text(resource_id: int) -> String:
	if resource_id >= NEED_FIRST and resource_id < NEED_FIRST + NEED_COUNT:
		return NEEDS[resource_id - NEED_FIRST]

	if resource_id == BROWNOUT:
		return BROWNOUTS

	if resource_id >= WARNING_FIRST and resource_id < WARNING_FIRST + WARNINGS.size():
		return WARNINGS[resource_id - WARNING_FIRST]

	if resource_id >= WEATHER_FIRST and resource_id < WEATHER_FIRST + WEATHER_COUNT:
		return RciAftermathPhase.WEATHER_NAMES[resource_id - WEATHER_FIRST]

	if resource_id == PAUSED:
		return PAUSED_TEXT

	var disaster := DISASTER_IDS.find(resource_id)

	if disaster >= 0:
		return DISASTERS[disaster]

	return ""
