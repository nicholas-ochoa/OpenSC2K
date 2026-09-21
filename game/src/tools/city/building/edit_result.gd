class_name BuildingEditResult
extends EditCommandResult


var tile_id := BuildingTileIds.EMPTY
var overlay_id := 0

var lfsr_state_before := 0
var lfsr_state_after := 0
# small cities refresh power and water at once after placement
var immediate_power_refresh := false
var immediate_water_refresh := false

# a new stadium with a microsimulation record waits for a team
var stadium_team_selection_required := false
var stadium_team_index := -1
var stadium_team_label := 0
var stadium_team_name := ""

# rejection details. residents can refuse a nuisance building
var residential_tiles := 0
var resident_objection := false
var lfsr_advanced := false
var notice_bitmap_id := 0
var notice_string_id := 0


static func rejected(message: String, charged := 0) -> BuildingEditResult:
	var result := BuildingEditResult.new()
	result.error = message
	result.cost = charged

	return result
