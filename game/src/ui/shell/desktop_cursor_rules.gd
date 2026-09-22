class_name DesktopCursorRules
extends RefCounted


# simcity.exe 004ea7f8, consumed by 0047f7ac
const CITY_TOOLS := [2, 3, 28, 8, 19, 24, 21, 22, 25, 4, 5, 6, 7, 20, 26, 27, 23, 11]


static func city_family(display_width: int) -> int:
	# 00425360 reads horzres; 004255a0 selects these boundaries
	return 1000 if display_width >= 1024 else (2000 if display_width >= 800 else 3000)


static func city_tool(group: int, subtool: int) -> int:
	if group < 0 or group >= CITY_TOOLS.size():
		return 0

	return 16 if group == CityToolIds.Group.LANDSCAPE and subtool == CityToolIds.Landscape.WATER else CITY_TOOLS[group]


static func paint_tool(tool: int) -> int:
	# winscurk drawing commands 20000..20013 select 30000..30003
	match tool:
		ScurkPixelCanvas.TOOL_PENCIL:
			return 30000
		ScurkPixelCanvas.TOOL_ERASER:
			return 30001

	return 30002
