class_name ScurkPlaceResult
extends EditCommandResult
# scurk place & print object placement, or an artwork stamp for a tile
# above 255. scurk history always owns these edits

var tile_id := 0
var area := 1
var zone_id := 0
var overlay_id := 0
# artwork stamps before and after a "scurk_artwork" edit
var old_stamps: Array = []
var new_stamps: Array = []
