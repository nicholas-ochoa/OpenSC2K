class_name ButtonHelp
extends RefCounted
## The help that a Shift-click on a toolbar button or the status bar shows.
## The text comes from the Macintosh version 1.2, which shows it on a
## Shift-click: TEXT resources 1100-1133, 1200-1222, and 1686.

const STATUS_BAR := "Status Window"
const DEMAND_INDICATOR := "Zone Demand"
# the topic of each toolbar group, in CityToolIds.Group order
const GROUP_TOPICS: Array[String] = [
	"Bulldozer", "Landscape", "Dispatch", "Power", "Water", "City Bonus",
	"Roads", "Rail", "Ports", "Residential Zoning", "Commercial Zoning", "Industrial Zoning",
	"Education Zones", "Health and Safety Zones", "Recreation Zones", "Place Sign", "Query Tool", "Center Display",
]
# the landscape editor uses the Terrain toolbar topics
const EDITOR_TOPICS: Dictionary[Vector2i, String] = {
	Vector2i(CityToolIds.Group.BULLDOZER, CityToolIds.Bulldozer.RAISE): "Raise Terrain",
	Vector2i(CityToolIds.Group.BULLDOZER, CityToolIds.Bulldozer.LOWER): "Lower Terrain",
	Vector2i(CityToolIds.Group.BULLDOZER, CityToolIds.Bulldozer.STRETCH): "Stretch Terrain",
	Vector2i(CityToolIds.Group.BULLDOZER, CityToolIds.Bulldozer.LEVEL): "Level Terrain",
	Vector2i(CityToolIds.Group.BULLDOZER, CityToolIds.Bulldozer.RAISE_SEA): "Raise Sea Level",
	Vector2i(CityToolIds.Group.BULLDOZER, CityToolIds.Bulldozer.LOWER_SEA): "Lower Sea Level",
	Vector2i(CityToolIds.Group.LANDSCAPE, CityToolIds.Landscape.WATER): "Place Water",
	Vector2i(CityToolIds.Group.LANDSCAPE, CityToolIds.Landscape.STREAM): "Place Stream",
	Vector2i(CityToolIds.Group.LANDSCAPE, CityToolIds.Landscape.TREES): "Place Tree",
	Vector2i(CityToolIds.Group.LANDSCAPE, CityToolIds.Landscape.FOREST): "Place Forest",
}
const TOPICS: Dictionary[String, Array] = {
	"Bulldozer": [
		"Demolish/Clear - This will destroy buildings, roads, trees, and decorative water, and will remove "
			+ "rubble.",
		"Level Terrain - This tool will level terrain to the same altitude as the first location you click "
			+ "on. It will also clear terrain by removing trees, roads, powerlines, and buildings.",
		"Raise Terrain - This raises the terrain.",
		"Lower Terrain- This lowers the terrain.",
		"De-zone - This will remove the zone from an area.",
	],
	"Landscape": [
		"Trees - This tool adds trees to the terrain.",
		"Water - This will put down small streams and decorative ponds.  It can be used to create waterfalls "
			+ "for the Hydro electric power plant.",
	],
	"Dispatch": [
		"This tool is only available during emergencies.  It allows you to direct your police and "
			+ "firefighters to suppress problems.",
		"Dispatch Police - Police are useful for suppressing riots and resisting floods.",
		"Dispatch Firefighters- Firefighters suppress fire and resist floods and toxic clouds.",
		"Dispatch Military - Military units may be available to your city after the military has constructed "
			+ "a base. Military units are highly trained and are effective against a variety of disasters.",
	],
	"Power": [
		"Power Lines - Build these from your power plants to your zoned areas so they can start to build. "
			+ "These can cross roads and rails only at right angles. There is a slight transmission loss of power "
			+ "through these lines, so try to minimize the distance they have to traverse.",
		"Power Plants - This will bring up a list of the currently available power plants that you may build. "
			+ "This list will grow as time passes and technology progresses.",
	],
	"Water": [
		"Pipes - These transmit water and carry away sewage.  You need powered water pumps to generate water.",
		"Water Pump - Powered pumps will generate water for your city.  The amount they produce is increased "
			+ "by placing them next to standing water.  It also has a seasonal variance depending on rainfall.",
		"Water Tower - Water towers store water to combat seasonal variation.",
		"Treatment - Adding a treatment plant reduces your city-wide pollution levels.",
		"Desalinization - Water pumps will not pump sea water.  A desalinization plant will take sea water "
			+ "and produce pure water for your city.",
	],
	"City Bonus": [
		"As your city grows in size, the city council will vote to reward you.",
		"Mayor's House - You will be given a residence at 2000 population.",
		"City Hall - The council will vote to build a City Hall at 10000 population.",
		"Statue - This will occur after the City Hall, but before Arcologies or the other rewards.",
	],
	"Roads": [
		"Road - This is your primary method of transport.  Roads connect zones, allowing them to grow.",
		"Highway - Highways are faster and more efficient than roads.  Commuters will move from road to "
			+ "onramps, then to highways, back to onramps, then on to roads again.  Without the roads and on-ramps, "
			+ "highway are useless.",
		"Tunnel - Tunnels dig through a mountain rather than going over it.  One advantage to tunnels is that "
			+ "zones can be built over tunneled areas, improving land usage.",
		"Onramp - These are necessary for highways to function.  They can only be placed at a highway/road "
			+ "juncture.",
		"Bus Depot - Depots provide rapid, low traffic transport.  Up to half of your city's commuters will "
			+ "use these depots if they are well placed.",
	],
	"Rail": [
		"Rail - This transport method is efficient and traffic free.  You must carefully place your rail "
			+ "depots, or else the rail will go unused.",
		"Subway - These are underground railways.  They operate like rail, except that subways need subway "
			+ "stations to operate.",
		"Rail Depot - This is where commuters enter and exit the rail system.",
		"Sub Station - This is where commuters enter and exit the subway system.",
		"Sub<-->Rail - This allows you to connect your above-ground rail with your below-ground subway.  You "
			+ "must place this next to an existing rail line.",
	],
	"Ports": [
		"Seaport - This provides vital external transport for your city's industries.  It will not be "
			+ "necessary until your city hits 10,000 people or so.",
		"Airport - This provides inter-city transport for your city's commerce.  It will not be needed until "
			+ "your city hits 15,000 people or so.",
	],
	"Residential Zoning": [
		"Residential zones are where the people live.  Low density zoning will only allow single family homes "
			+ "in an area.  High density zoning will allow homes as well as high-rise apartments and condominiums.",
	],
	"Commercial Zoning": [
		"Commercial areas provide services to your local population.  This includes grocery stores, motels, "
			+ "entertainment, maintenance and more.  High density zoning includes banking, real estate, and "
			+ "financial services.",
	],
	"Industrial Zoning": [
		"Industry is the backbone of your city.  Initially, new residents are moving in to work with your "
			+ "industry.  Meanwhile, industry is growing to meet external demands.",
	],
	"Education Zones": [
		"These special zones increase the \"EQ\" or education quotient of your residents over time. The EQ of "
			+ "your city will influence many factors including crime, productivity, and which industries prosper. "
			+ "Each type of zone affects different age groups and has a maintenance cost associated with it.",
		"School - This represents primary and secondary education (from kindergarden to 12th grade). This "
			+ "will increase the EQ of the 5- to 20-year olds in your city. Of all education zones, these should be "
			+ "the most numerous in your city.",
		"College - This represents higher education- universities, junior colleges and vocational schools. "
			+ "This zone increases the EQ of the 15- to 25-year-olds primarily, and the older residents as well, "
			+ "though to a lesser degree.",
		"Library - This increases the EQ for all ages but to a lesser degree than the schools and colleges.",
		"Museum - Like the library this zone increases the EQ for all ages. But the effect is more and so is "
			+ "the cost.",
	],
	"Health and Safety Zones": [
		"These zones include essential city services to protect your residents.",
		"Police - Police stations help manage the crime in your city.",
		"Fire Station - Fire stations attempt to prevent and extinguish any fires in your city. They also "
			+ "help during any sort of emergency.",
		"Hospital - This will have an beneficial effect on the health of your citizens.",
		"Prison - This will improve police performance if there is a lot of crime in your city.",
	],
	"Recreation Zones": [
		"These special zones have a positive effect on residential growth and generally make your city a "
			+ "nicer place to live.",
		"Parks - Small and big parks both have a positive effect on local land values.",
		"Zoo - Zoos improve your city's desirability for residents, and improves its tourist value.",
		"Stadium - Your citizens are more enthusiastic and loyal if they have a local team to rally behind.",
		"Marina - These can only be placed down by the water.",
	],
	"Place Sign": [
		"This tool is used to place signs (labels) in your city. To use it just click on the city location "
			+ "where you want it placed and then enter the text for it. These can be used to name streets, "
			+ "subdivisions, lakes, etc. Or you may use this for jotting down notes to yourself about future plans "
			+ "for each area. \nThese signs can be toggled on and off with the layer control button near the bottom "
			+ "of the City toolbar. To erase a sign, click on the base with the sign tool to open the record, then "
			+ "hit the delete key.",
	],
	"Query Tool": [
		"This tool will give you detailed information on anything in your city.  Most areas only tell you "
			+ "about land value, local traffic, power and water supply.  Special buildings such as fire "
			+ "departments, zoos, museums, et al., will have a specific micro-simulation you can examine.",
	],
	"Center Display": [
		"This is the centering tool. It is used to scroll around your city. When you click in the window the "
			+ "scene will re-center on the place you clicked. If you click near the center of the window and hold "
			+ "the mouse button down, you can then smoothly scroll around by moving the mouse to adjust direction "
			+ "and speed.",
	],
	"Zoom Out": [
		"There are three scales your city can be viewed at.  This button allows you to increase the scale of "
			+ "your display.  The tiles grow smaller and the area displayed grows.",
	],
	"Zoom In": [
		"There are three scales your city can be viewed at.  This button allows you to decrease the scale of "
			+ "your display.  The tiles grow larger and the area displayed shrinks.",
	],
	"Zone Demand": [
		"These colored bars show you the current demand for each type of zone in your city. If the bar is up "
			+ "in the \"+\" area then your city needs more of that type of zone. The letters represent \"R\"esidential, "
			+ "\"C\"ommercial and \"I\"ndustrial.",
	],
	"Rotate Counter-Clockwise": [
		"Each time you click this button the scene in the window will rotate 90 degrees counter-clockwise.",
	],
	"Rotate Clockwise": [
		"Each time you click this button the scene in the window will rotate 90 degrees clockwise.",
	],
	"Building Layer": [
		"This button will flatten your buildings, allowing you to examine your roads, wires and other "
			+ "infrastructure.  You will recognize the building types by their color:  green - residential, blue - "
			+ "commercial, yellow - industrial, orange - city structures, grey - port structures. In under-view, "
			+ "the zone colors will be shown as outlines instead of colored-in squares.",
	],
	"Sign Layer": [
		"This will hide your city's names and labels.  See the 'PLACE SIGN' tool above.",
	],
	"Road/Tree Layer": [
		"This will turn off the display of your roads, rail, wires, trees and other non-building structures.",
	],
	"Under-View Layer": [
		"This will transform your city display to a stick-figure outline of the terrain. Pipes and subways "
			+ "will become more visible, while all surface items will be hidden. The other layer buttons are still "
			+ "available and allow you to further customize the view.",
	],
	"Status Window": [
		"The Status Window shows the currently selected tool and its cost.  It also has an iconic display for "
			+ "the weather.  The second line of the window shows messages, warnings, and recommendations.\nIn the "
			+ "Emergency Mode, the weather icon changes into a big red arrow.  By clicking here, you can cycle "
			+ "through the disasters afflicting your city.",
	],
	"Make New Map": [
		"This button will generate a new map. The new map will be based on the settings of the two buttons "
			+ "and three sliders above.",
	],
	"Raise Terrain": [
		"This tool will raise the altitude when you click on the terrain, thereby creating hills.",
	],
	"Lower Terrain": [
		"This tool will lower the altitude when you click on the terrain, thereby creating valleys.",
	],
	"Stretch Terrain": [
		"This tool will allow you to stretch the terrain up or down. Click on the tile you wish to change and "
			+ "slowly move the mouse up or down while holding the button.",
	],
	"Level Terrain": [
		"This tool will level terrain and remove trees. Click on the tile level you wish to extend and move "
			+ "the mouse in the direction you want while holding down the mouse button.",
	],
	"Raise Sea Level": [
		"Each time you press this button the sea level across the entire map will be raised one level.",
	],
	"Lower Sea Level": [
		"Each time you press this button the sea level across the entire map will be lowered one level.",
	],
	"Place Water": [
		"This tool places tiles of water, thereby allowing you to create larger bodies of water like lakes and "
			+ "streams.",
	],
	"Place Stream": [
		"This tool creates streams. Click where you want the stream to start and it will flow downhill from "
			+ "that point.",
	],
	"Place Tree": [
		"This tool adds trees to the terrain. Holding down the SHIFT key while using this tool will remove "
			+ "trees.",
	],
	"Place Forest": [
		"This tool will add a forested area to the terrain. Holding down the SHIFT key while using this tool "
			+ "will remove trees.",
	],
	"Done": [
		"When you are finished editing the terrain this button will bring you into the game. Make sure you "
			+ "are finished because you cannot return to the map-editing mode once the game has started.",
	],
}


static func group_topic(group: int) -> String:
	return GROUP_TOPICS[group] if group >= 0 and group < GROUP_TOPICS.size() else ""


# the topic of a tool button. the landscape editor has its own terrain tools
static func tool_topic(group: int, subtool: int, landscape_editor: bool) -> String:
	if landscape_editor:
		return EDITOR_TOPICS.get(Vector2i(group, subtool), group_topic(group))

	return group_topic(group)


# the text of a topic, or "" for an unknown topic
static func text(topic: String) -> String:
	return "\n\n".join(PackedStringArray(TOPICS.get(topic, [])))
