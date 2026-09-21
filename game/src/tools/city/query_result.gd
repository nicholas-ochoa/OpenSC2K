class_name QueryResult
extends RefCounted


var ok := false
var shows_traffic := false
var altitude_is_depth := false
var shows_land_value := false
var shows_utilities := false
var powered := false
var watered := false

var error := ""
var kind := ""
var title := ""
var zone_name := ""
var zone_density := ""
var crime_level := ""
var pollution_level := ""
var water_detail := ""
var action := ""
var corner_name := ""
var underground_name := ""
var microsim_label := ""

var overlay_id := 0
var zone_id := 0
var sprite_id := 0
var building_id := BuildingTileIds.EMPTY
var terrain_id := TerrainTileIds.FLAT
var traffic := 0
var altitude_feet := 0
var land_value := 0
var crime := 0
var pollution := 0
var microsim_type := 0
var tile_id := BuildingTileIds.EMPTY
var altitude_raw := 0
var land_value_raw := 0
var crime_raw := 0
var pollution_raw := 0
var zone_raw := 0
var flags_raw := 0
var underground_id := UndergroundTileIds.EMPTY
var microsim_id := -1
var action_resource_id := -1
var point := Vector2i(-1, -1)
var microsim: CityRecords.Microsim
var lines := PackedStringArray()
var flag_names := PackedStringArray()
var sound_events: Array[int] = []
var things: Array[QueryThing] = []


static func failure(message: String) -> QueryResult:
	var result := QueryResult.new()
	result.error = message

	return result
