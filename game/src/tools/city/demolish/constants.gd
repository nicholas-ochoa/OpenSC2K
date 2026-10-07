class_name DemolishConstants
extends RefCounted
## The bulldozer tool. The demolition rules run in the native simulation
## library; see native/core/sim/src/sim/tools/commands/demolish.rs.

const GROUP_BULLDOZER := CityToolIds.Group.BULLDOZER
const SUBTOOL_DEMOLISH := CityToolIds.Bulldozer.DEMOLISH
# the chunks that a demolition checks, in commit order
const PAYLOAD_IDS: PackedStringArray = ["ALTM", "XBLD", "XTER", "XZON", "XUND", "XBIT", "XTXT", "XLAB", "XMIC", "MISC"]
# SIMCITY.EXE string 236, which 0x00443270 shows with picture 403
const FOREST_PROTEST := "Citizens are protesting your\r\ndestruction of the forest."
