class_name NewTerrainValues
extends NewTerrainConstants


static func _index(x: int, y: int, map_edge: int = 128) -> int:
	return x * map_edge + y
