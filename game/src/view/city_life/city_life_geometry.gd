class_name CityLifeGeometry
extends RefCounted
## Read-only geometry changes shared by decorative roads and light receivers.
@warning_ignore_start("integer_division")

var reset := false
var _signature: Array = []
var _layout: Array = []
var _planes: Array[PackedByteArray] = []


func sync(city: CityState) -> Dictionary[Vector2i, bool]:
	var changed: Dictionary[Vector2i, bool] = {}
	reset = false
	var layout := [city.get_instance_id(), city.map_size, city.compass_rotation(), city.visible_altitude_levels]
	var revision := [layout, city.mirror_signature(["ALTM", "XBLD", "XTER", "XZON", "XBIT"])]
	if revision == _signature:
		return changed
	_signature = revision
	# Native setters can mutate borrowed mirrors. Keep owned snapshots.
	var planes: Array[PackedByteArray] = [city.altitude_words.to_byte_array(), city.buildings.duplicate(), city.terrain.duplicate(),
		city.zones.duplicate(), city.tile_flags.duplicate(), city.object_altitude_overrides.to_byte_array()]
	reset = layout != _layout or _planes.size() != planes.size()
	if not reset:
		for plane in planes.size():
			if planes[plane].size() != _planes[plane].size():
				reset = true
				break
			var mask := Sc2ZoneLayout.CORNERS_MASK if plane == 3 else (Sc2TileFlags.FLIPPED | Sc2TileFlags.WATER if plane == 4 else 255)
			var indices := NativeCityChanges.changed_cells(_planes[plane], planes[plane], 4 if plane in [0, 5] else 1, mask)
			if indices.size() > 1024:
				reset = true
				break
			for index in indices:
				var tile := Vector2i(index / city.map_size, index % city.map_size)
				for x in range(-1, 2):
					for y in range(-1, 2):
						changed[tile + Vector2i(x, y)] = true
	_planes = planes
	_layout = layout
	return changed
