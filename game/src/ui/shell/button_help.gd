class_name ButtonHelp
extends RefCounted
## The help for the toolbar buttons and the status bar. The DOS and Macintosh
## versions show it on a Shift-click. The text comes from the help file of the
## Windows 95 version (SC2USA.HLP), without the sentences that do not apply.
## A paragraph can name a bound key as {query}, {center}, {bulldoze}, or
## {help}. The paragraph is left out when its action has no key.

const STATUS_BAR := "Status Bar"
const DEMAND_INDICATOR := "Demand Indicator"
# the topic of each toolbar group, in CityToolIds.Group order
const GROUP_TOPICS: Array[String] = [
	"Bulldozer", "Landscape Tool", "Emergency", "Power", "Water System", "Rewards",
	"Roads", "Rails", "Ports", "Residential Zones", "Commercial Zones", "Industrial Zones",
	"Education", "City Services", "Recreation", "Signs", "Query", "Center",
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
# the action of each key name in the text
const KEY_ACTIONS: Dictionary[String, String] = {
	"query": "tool_query_modifier", "center": "tool_center_modifier",
	"bulldoze": "tool_bulldoze_modifier", "help": "button_help_modifier",
}
const TOPICS: Dictionary[String, Array] = {
	"Bulldozer": [
		"The bulldozer is a multi-function multi-level tool, with a default setting and a submenu to choose "
			+ "between four additional actions. Click and hold on the Bulldozer button to open the submenu. When "
			+ "the bulldozer is active, the cursor will appear as a bulldozer.",
		"To operate the bulldozer, choose the function you want, then click or click and drag where you want "
			+ "to do your 'dozin'.",
		"Demolish/Clear (the default) destroys and removes trees, rubble, and man-made (Sim-made?) objects "
			+ "without affecting the terrain or zoning status. Just click on anything to destroy it.",
		"Cost: $1 per tile.",
		"Level Terrain lets you choose an altitude level and slice off hills and mountains at your chosen "
			+ "height. Level also clears, removing all trees, roads, power lines and buildings.",
		"Cost: $25 per tile per altitude change.",
		"Raise Terrain lets you make mountains out of molehills.",
		"Cost: $25 per tile per altitude change.",
		"Lower Terrain lets you lower mountains and dig canyons. (If you lower the terrain below sea level, "
			+ "it will fill with water.)",
		"Cost: $25 per tile per altitude change.",
		"De-zone lets you change residential, commercial or industrial zones to unzoned land.",
		"Cost: $1 per tile.",
		"Raising, lowering and leveling terrain can be very expensive, so do it sparingly. If you want to "
			+ "make a lot of changes to the landscape, do it in terrain-editing mode before you start your city, or "
			+ "save up a lot of cash.",
		"Hold down the {bulldoze} key to use Demolish/Clear with any tool.",
	],
	"Landscape Tool": [
		"The Landscape Tool lets you add trees and water to your city. When active the cursor will appear as "
			+ "a tree. Clicking and holding on it opens a submenu that allows you to choose between trees and "
			+ "water.",
		"The Tree tool lets you place trees onto the landscape. Each click will place either one or two "
			+ "trees. You can click repeatedly on a single tile to create dense thickets, and click and drag across "
			+ "many tiles to create forests.",
		"Cost: $3 per click.",
		"The Water tool lets you create lakes and streams by clicking where you want your water to appear.",
		"Cost: $100 per tile.",
	],
	"Emergency": [
		"The Emergency Tool lets you dispatch police and/or fire departments to the scene of a disaster. This "
			+ "tool will be ghosted and unavailable unless a disaster is occurring. When active the cursor will "
			+ "appear as an emergency beacon. Clicking and holding on it opens a submenu that allows you to choose "
			+ "between dispatching police and fire.",
		"Once you activate the tool and choose the department you want to dispatch, click on the area of the "
			+ "city where you want your city's finest to go. An icon representing either your dispatched fire or "
			+ "police troops will be placed where you click. You can place one icon for each station you have. "
			+ "After you have placed them all, clicking again will move the first one you placed to the last place "
			+ "you clicked, enabling you to block, surround and contain a fire or riot. There is no cost for "
			+ "dispatching police or firesims.",
	],
	"Power": [
		"Power is a multi-use tool. Clicking and holding on it opens a submenu that allows you to choose "
			+ "between two functions: laying power lines and placing power plants. When this tool is active, the "
			+ "cursor appears as a lightning bolt.",
		"Power Lines (the default setting) lets you \"paint\" your power lines onto the land by clicking in the "
			+ "place where you want the line to start, dragging the cursor to the place where you want the line to "
			+ "stop, and releasing the mouse button.",
		"Power lines blink warning lights to let you know if they're not hooked to a power source. Power "
			+ "lines can only be run in straight lines and 90 degree angles. They can cross roads or rails, but not "
			+ "on curved sections or straight sections that run at 45 degrees. Laying power lines across water is a "
			+ "little more expensive. If you lay power lines across water, a dialog box will open and let you know "
			+ "how much it will cost.",
		"Cost: $2 per tile across land, $10 per tile across water.",
		"Power Plant... lets you choose power sources for your city. Depending on the year and the technology "
			+ "level of you city, there may be from three to nine types of power plants available. Click on the "
			+ "power source you want, then click on the terrain where you want it to go. There is an info button "
			+ "for each power plant that tells you the advantages, disadvantages and costs for each type of power "
			+ "plant, as well as the approximate year it becomes available.",
	],
	"Water System": [
		"The Water System tool is a multi-use tool. Clicking and holding on it opens a submenu that allows "
			+ "you to choose between five different water-related functions: laying water pipes, installing water "
			+ "pumps, buying storage tanks, and building treatment and desalinization plants. When this tool is "
			+ "active, the cursor appears as a water faucet.",
		"Depending on the year and technology level in your city, you may only have access to pumps and water "
			+ "towers. As time passes and inventions are invented, the other options become available. A city can "
			+ "exist without a water system, but population density will be limited. When the Sims build, they "
			+ "install the underground water pipes for their buildings. Your only responsibility is to hook the "
			+ "buildings up to the water system.",
		"Pipes (the default setting) lets you \"paint\" your water pipes onto the landscape by clicking in the "
			+ "place where you want the pipe to start, dragging the cursor to the place you want the pipe to stop, "
			+ "and releasing the mouse button. Water pipes are always laid underground. Activating Pipes "
			+ "automatically turns on the underground view so you can see your pipes.",
		"Cost: $3 per tile.",
		"Water Pumps, when placed on land act as wells, a good source of water. Water pumps need to be hooked "
			+ "to the power grid to function. When pumps are placed right next to a lake or river, they supply "
			+ "twice as much water as a well. A pump placed next to a coastline (salt water) only produces as much "
			+ "water as a well.",
		"Cost: $100 per pump.",
		"Water Towers lets you store precious water so you won't have summer shortages in arid climates.",
		"Cost: $250 per tower.",
		"Treatment plants clean and recycle your city's water, lessening seasonal shortages.",
		"Cost: $500 per treatment plant.",
		"Desalinization plants remove the salt from sea water. They are expensive, but sometimes necessary in "
			+ "beach communities with little or no other source of water. Desalinization plants, which need power "
			+ "to function, have internal pumps, and don't require extra water pumps. They produce approximately "
			+ "twice as much water as two water pumps next to a river.",
		"Cost: $1,000 per desalinization plant.",
	],
	"Rewards": [
		"This button is like a surprise package. It will be ghosted and unavailable until you deserve a "
			+ "reward. Rewards are based on your city's population, and consist of special buildings and monuments "
			+ "to your mayoral prowess. When this tool is active, the cursor appears as a mayor tipping his hat.",
		"The rewards you can strive to gain are... No, I won't tell you. You'll just have to wait and see for "
			+ "yourself.",
	],
	"Roads": [
		"Roads is a multi-use tool. Clicking and holding on it opens a submenu that allows you to choose "
			+ "between five different road-related functions: placing roads and highways, and building tunnels, "
			+ "onramps and bus depots. When this tool is active, the cursor appears as a piece of paved road.",
		"Depending on the year and technology level of your city, you may only have access to roads and "
			+ "tunnels. As time passes, the other options become available.",
		"Road (the default setting) lets you \"paint\" your roads onto the land by clicking in the place where "
			+ "you want the road to start, dragging the cursor to the place you want the road to stop, and "
			+ "releasing the mouse button.",
		"Roads can run in straight lines, 90 degree angles and 45 degree angles. When roads cross, they form "
			+ "an intersection. If you lay a road across water and it is possible to build a bridge, you will be "
			+ "told how much it will cost. If a bridge can't be built, you will be notified.",
		"Cost: $10 per road tile.",
		"Highways are high-capacity roads that are raised above the ground on pylons. They can handle four "
			+ "times as many cars as regular roads. They are placed the same way as roads. You will need to place "
			+ "onramps to allow cars to get on and off highways. When highways cross, they form cloverleaves. If "
			+ "you lay a highway across water and it is possible to build a bridge, you will be told how much it "
			+ "will cost. If a bridge can't be built, you will be notified.",
		"Cost: $100 per highway section (4 tiles).",
		"Tunnel lets you road pathways through hills and mountains. Tunnels cannot curve, and you cannot "
			+ "cross tunnels, even at different altitudes. To place a tunnel, click on the tile that you want as "
			+ "your entrance point. The entrance point must be a sloped tile. Your highway engineers won't try to "
			+ "build a tunnel where it's impossible to build, or where it is unsafe, due to unstable terrain. If "
			+ "you pick a good spot, an engineer's report will tell you how much the tunnel will cost and ask if "
			+ "you want to go ahead or not.",
		"Cost: $150 per tile of tunnel.",
		"Onramps allow cars and buses to travel back and forth between roads and highways. Onramps are a "
			+ "little tricky to place. You can only put them at intersections between roads and highways.",
		"Cost: $25 per tile.",
		"Bus Depots allow commuters to take the bus to work and help alleviate traffic. They must be placed "
			+ "on level ground. You will need at least two bus depots since buses travel between them. Passengers "
			+ "can get on and off between depots.",
		"Cost: $250 per depot.",
	],
	"Rails": [
		"Rails is a multi-use tool. Clicking and holding on it opens a submenu that allows you to choose "
			+ "between four different rail-related functions: placing rails, placing subways (underground rails), "
			+ "building rail depots and building subway stations. When this tool is active, the cursor appears as "
			+ "length of track.",
		"Depending on the year and technology level of your city, you may only have access to rails and rail "
			+ "depots. As time passes, the other options become available.",
		"Rail (the default setting) lets you \"paint\" your tracks onto the land by clicking in the place where "
			+ "you want the rail to start, dragging the cursor to the place where you want it to stop, and "
			+ "releasing the mouse button. Rails are useless without rail depots.",
		"Cost: $25 per tile.",
		"Subway is an underground rail system. Subways are placed in the same way as rails, but while looking "
			+ "at the underground view. Subways are useless without subway stations.",
		"Cost: $100 per tile.",
		"Rail Depots allow commuters to get on and off trains. Without depots, rails are useless. They must "
			+ "be placed on level ground, and adjacent to tracks.",
		"Cost: $500 per depot.",
		"Subway Stations allow passengers access to subway trains. Subway trains only stop at stations. They "
			+ "must be placed on level ground, adjacent to a subway line. It's usually easiest to place subway "
			+ "stations while looking at the underground level.",
		"Cost: $250 per depot.",
		"Subway to Rail junction allows you to hook up your subways and above-ground rails for a continuous "
			+ "transit system. They must be placed adjacent to a rail tile.",
		"Cost $250 per tile.",
	],
	"Ports": [
		"Ports is a dual-purpose tool that allows you to place both airports and seaports. Click and hold on "
			+ "the Ports button to open a menu and choose the type of port you want to place. When this tool is "
			+ "active, the cursor will appear as an airplane.",
		"Ports are placed by clicking and dragging to form a square or rectangle, then release the mouse "
			+ "button. Ports must be powered before they will develop. Seaports must be on a shoreline to be of any "
			+ "use.",
		"Cost: $150 per seaport tile, $250 per airport tile.",
	],
	"Residential Zones": [
		"The Residential Zone tool lets you, as mayor, designate areas of your city as places where people "
			+ "live. Clicking and holding on Residential Zones opens a submenu that lets you choose whether the "
			+ "zones will be low density (light) or high density (dense). When this tool is active, the cursor will "
			+ "appear as a little house.",
		"To zone an area as residential, click and hold on the terrain, then drag the mouse, creating a "
			+ "rectangle, then release the mouse button. If you zone residential over an area that includes some "
			+ "tiles that are already the same density residential, you will not be charged for rezoning those "
			+ "tiles. If you zone residential over an undeveloped area that is already commercial industrial or a "
			+ "different density residential, it will be rezoned and you will be charged. You cannot rezone an area "
			+ "that is already developed.",
		"Cost: Light Residential $5 per tile, Dense Residential $10 per tile.",
	],
	"Commercial Zones": [
		"The Commercial Zone tool lets you, as mayor, designate areas of your city as places where people "
			+ "build stores, offices and other places of commerce. Clicking and holding on Commercial Zones opens a "
			+ "submenu that lets you choose whether the zones will be low density (light) or high density (dense). "
			+ "When this tool is active, the cursor will appear as a little office building.",
		"To zone an area as commercial, click and hold on the terrain, then drag the mouse, creating a "
			+ "rectangle, then release the mouse button. If you zone commercial over an area that includes some "
			+ "tiles that are already the same density commercial, you will not be charged for rezoning those "
			+ "tiles. If you zone commercial over an undeveloped area that is already residential, industrial or a "
			+ "different density commercial, it will be rezoned and you will be charged. You cannot rezone an area "
			+ "that is already developed.",
		"Cost: Light Commercial $5 per tile, Dense Commercial $10 per tile.",
	],
	"Industrial Zones": [
		"The Industrial Zone tool lets you, as mayor, designate areas of your city as places where people "
			+ "build factories. Clicking and holding on Industrial Zones opens a submenu that lets you choose "
			+ "whether the zones will be low density (light) or high density (dense). When this tool is active, the "
			+ "cursor will appear as a little factory.",
		"To zone an area as industrial, click and hold on the terrain, then drag the mouse, creating a "
			+ "rectangle, then release the mouse button. If you zone industrial over an area that includes some "
			+ "tiles that are already the same density industrial, you will not be charged for rezoning those "
			+ "tiles. If you zone industrial over an undeveloped area that is already commercial, residential or a "
			+ "different density industrial, it will be rezoned and you will be charged. You cannot rezone an area "
			+ "that is already developed.",
		"Cost: Light Industrial $5 per tile, Dense Industrial $10 per tile.",
	],
	"Education": [
		"Education is a multi-function tool that lets you provide your citizens with everything they need to "
			+ "improve their minds. Click and hold on the Education button to open a submenu with the following "
			+ "smart choices: school, college, library and museum. When this tool is active, the cursor will appear "
			+ "as a mortarboard.",
		"Cost: $250 per school, $1,000 per college, $500 per library, $500 per museum.",
	],
	"City Services": [
		"City Services is a multi-function tool that lets you provide your city with those necessities of "
			+ "life that we all wish weren't necessary. Click and hold on the City Services button to open a "
			+ "submenu with the following unpleasant choices: police, fire station, hospital and prison. When this "
			+ "tool is active, the cursor will appear as a badge.",
		"Cost: $500 per police station, $500 per fire station, $500 per hospital, $1000 per prison.",
	],
	"Recreation": [
		"Recreation is a multi-function tool that lets you provide your citizens with places to have a little "
			+ "rest, relaxation and plain old fun. Click and hold on the Recreation button to open a submenu with "
			+ "the following exciting choices: park, zoo, stadium, marina. When this tool is active, the cursor "
			+ "will appear as a bunch of balloons!",
		"Cost: $5 per small park, $25 per large park, $500 per zoo, $1,000 per stadium, $500 per marina.",
	],
	"Signs": [
		"The Sign tool lets you label streets, buildings and points of interest in your city. When this tool "
			+ "is active, the cursor will appear as a little sign. To make a sign, activate the Sign tool and click "
			+ "on the place where you want it to appear. When the dialog box opens, type in the words you want the "
			+ "sign to say, then click DONE.",
		"There is no cost for placing signs.",
		"The display of your signs can be turned on and off with the Display Signs button.",
	],
	"Query": [
		"Query is a tool for closely inspecting different parts of your city. When this tool is active, the "
			+ "cursor appears as a magnifying glass. To get information, activate the tool, then click somewhere or "
			+ "on something on the terrain. A dialog box will open, and display fascinating facts about the spot "
			+ "where you clicked.",
		"Once you have viewed the dialog box, you can usually just click anywhere to make it go away. "
			+ "Sometimes the Query dialog box allows you to rename buildings (like stadiums). In these cases, you "
			+ "will have to click on the DONE button to close the box. Click on RENAME if you want to change the "
			+ "name of the queried building. There is no cost to use the Query tool.",
		"There is a keyboard shortcut for the Query tool--just hold down the {query} key and click anywhere "
			+ "in the terrain.",
	],
	"Center": [
		"The Center tool lets you pick a place in your city to be centered in the City window. Just activate "
			+ "the tool and click anywhere in the city. When Center is active, the cursor will appear as a target "
			+ "sight. There is no cost for centering.",
		"There is a keyboard shortcut for activating the center tool--hold down the {center} key.",
	],
	"Rotate Counter-Clockwise": [
		"Click on this button to rotate the entire city limits 90 degrees counter-clockwise. There is no cost "
			+ "for rotating.",
	],
	"Rotate Clockwise": [
		"Click on this button to rotate the entire city limits 90 degrees clockwise. There is no cost for "
			+ "rotating.",
	],
	"Zoom In": [
		"Click here to zoom in for an enlarged, closer view in the City window. If you are currently zoomed "
			+ "all the way in, this button will be ghosted and unavailable. There is no cost for zooming.",
	],
	"Zoom Out": [
		"Click here to zoom out for a smaller, farther-out view in the City window. If you are currently "
			+ "zoomed all the way out, this button will be ghosted and unavailable. There is no cost for zooming.",
	],
	"Show Buildings": [
		"Click here to toggle on and off the display of all buildings in the City window. The buildings won't "
			+ "really go away, they'll just be invisible until you turn them back on.",
	],
	"Show Signs": [
		"Click here to toggle on and off the display of all signs in the City window. The signs will be "
			+ "invisible until you turn them back on.",
	],
	"Show Infrastructure": [
		"Click here to toggle on and off the display of all miscellaneous city infrastructure items in the "
			+ "City window (roads, rails, subway lines, power lines, water pumps and subway stations).",
	],
	"Show Underground": [
		"Click here to toggle between the surface and the underground displays.",
	],
	"Demand Indicator": [
		"The Demand Indicator gives you a constant readout of what types of zones the Sims in your city need. "
			+ "Depending on the size of your city, the indicator can take up to a few minutes to respond to your "
			+ "changes, so be patient.",
	],
	"Make": [
		"Click here to generate a new landscape based on the Coast button, the River button and the three "
			+ "sliders.",
	],
	"Raise Terrain": [
		"Click on the Raise Terrain button, then click or click and drag on the terrain to raise the land. "
			+ "Clicking on water will eventually raise the waterbed above sea level and turn it into dry land. When "
			+ "Raise Terrain is active, the cursor will appear as three upward-pointing arrows.",
	],
	"Lower Terrain": [
		"Click on the Lower Terrain button, then click or click and drag on the terrain to lower the land. "
			+ "Clicking on dry land will eventually lower it below sea level and turn it into a lake or stream. "
			+ "When Lower Terrain is active, the cursor will appear as three downward-pointing arrows.",
	],
	"Stretch Terrain": [
		"The Stretch Terrain button lets you grab the land and stretch it up or down. Just click and hold on "
			+ "the terrain, then drag it either up or down. When Stretch Terrain is active, the cursor will appear "
			+ "as an up-and-down-pointing arrow.",
	],
	"Level Terrain": [
		"The Level Terrain button lets you pick an altitude and quickly bring the land around it either up or "
			+ "down to match your chosen level. Just click and hold at the altitude you want, then drag the cursor "
			+ "around the area you want leveled. When Level Terrain is active, the cursor will appear as a flat, "
			+ "four-way arrow.",
	],
	"Raise Sea Level": [
		"Click here to raise the sea level in the terrain by one tile.",
	],
	"Lower Sea Level": [
		"Click here to lower the sea level in the terrain by one tile.",
	],
	"Place Water": [
		"The Place Water tool lets you create lakes and streams by clicking where you want your water to "
			+ "appear. When this tool is active, the cursor appears as a water droplet.",
	],
	"Place Stream": [
		"The Place Stream tool lets you send streams flowing down slopes into the valleys below. Click where "
			+ "you want the stream to begin. When this tool is active, the cursor appears as a tiny babbling brook.",
	],
	"Place Tree": [
		"The Place Tree tool lets you add trees to the landscape. When active, the cursor will appear as a "
			+ "tree. Each click will place either one or two trees. You can click repeatedly on a single tile to "
			+ "create dense thickets, and click and drag across many tiles to create forests.",
	],
	"Place Forest": [
		"The Place Forest tool works like Place Tree, except it places trees on a number of tiles with each "
			+ "click. When active, the cursor will appear as a tiny little forest.",
	],
	"Done": [
		"Click here when you are done editing the terrain and are ready to switch over to city-building mode.",
	],
	"Status Bar": [
		"The status bar is at the bottom of the City window. From left to right, it shows these items:",
		"The active tool. Point at the tool name to read more about the tool.",
		"The weather in your city.",
		"The Demand Indicator. It shows the demand for residential, commercial and industrial zones.",
		"The newest city reports. During a disaster, click the button next to the reports to see the "
			+ "disaster.",
		"The simulation speed.",
		"The compass. It shows the direction of north.",
		"The zoom level of the City window.",
		"Hold down the {help} key and click a part of the status bar or a toolbar button to get help about "
			+ "it.",
	],
}


static func group_topic(group: int) -> String:
	return GROUP_TOPICS[group] if group >= 0 and group < GROUP_TOPICS.size() else ""


# the topic of a tool button. the landscape editor has its own terrain tools
static func tool_topic(group: int, subtool: int, landscape_editor: bool) -> String:
	if landscape_editor:
		return EDITOR_TOPICS.get(Vector2i(group, subtool), group_topic(group))

	return group_topic(group)


# The text of a topic, with the bound keys named, or "" for an unknown topic.
static func text(topic: String, bindings: ControlBindings) -> String:
	var paragraphs := PackedStringArray()

	for paragraph: String in TOPICS.get(topic, []):
		var named := _name_keys(paragraph, bindings)

		if not named.is_empty():
			paragraphs.append(named)

	return "\n\n".join(paragraphs)


# "" when the paragraph names a key that has no binding
static func _name_keys(paragraph: String, bindings: ControlBindings) -> String:
	var result := paragraph

	for key_name: String in KEY_ACTIONS:
		var placeholder := "{%s}" % key_name

		if not result.contains(placeholder):
			continue

		var binding := bindings.first_key(KEY_ACTIONS[key_name]) if bindings != null else null

		if binding == null:
			return ""

		result = result.replace(placeholder, binding.full_text())

	return result
