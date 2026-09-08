class_name ScurkPlaceResult
extends EditCommandResult
# scurk place & print object placement, or an artwork stamp for a tile
# above 255. scurk history always owns these edits

var tile_id := 0
var area := 1
var zone_id := 0
var overlay_id := 0
# artwork stamps before and after a "scurk_artwork" edit
var old_stamps: Array[ScurkArtworkStamp] = []
var new_stamps: Array[ScurkArtworkStamp] = []


func copy() -> EditCommandResult:
	var result := super.copy() as ScurkPlaceResult
	result.old_stamps = ScurkArtworkStamp.copy_all(old_stamps)
	result.new_stamps = ScurkArtworkStamp.copy_all(new_stamps)

	return result
