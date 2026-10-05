class_name DemolishConstants
extends RefCounted
## The bulldozer tool. The demolition rules run in the native simulation
## library; see native/core/sim/src/sim/tools/commands/demolish.rs.

const GROUP_BULLDOZER := CityToolIds.Group.BULLDOZER
const SUBTOOL_DEMOLISH := CityToolIds.Bulldozer.DEMOLISH
# the chunks that a demolition checks, in commit order
const PAYLOAD_IDS: PackedStringArray = ["ALTM", "XBLD", "XTER", "XZON", "XUND", "XBIT", "XTXT", "XLAB", "XMIC", "MISC"]
