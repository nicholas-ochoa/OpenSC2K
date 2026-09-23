class_name ScurkDrawingBackground
extends RefCounted
## Aligns underground wireframe terrain with the sprite's top edge.

@warning_ignore_start("integer_division")

const Workspace = preload("res://src/tools/scurk/scurk_drawing_workspace.gd")


static func underground(sprites: Sc2SpriteArchive, view: int, shape_height: int) -> PackedInt32Array:
	var result := PackedInt32Array()
	if sprites == null:
		return result
	var city_view: int = [CityIsometricRenderer.VIEW_LARGE, CityIsometricRenderer.VIEW_MEDIUM, CityIsometricRenderer.VIEW_SMALL][view]
	var config := CityIsometricRenderer.view_configuration(city_view)
	var ground := sprites.find_sprite(config.sprite_base + CityUndergroundView.TERRAIN_WIREFRAME_FIRST)
	if ground == null:
		return result
	var decoded := ground.decode_indices()
	if not decoded.ok:
		return result
	result.resize(Workspace.WIDTH * Workspace.HEIGHT)
	result.fill(-1)
	var divisor := Workspace.view_divisor(view)
	var origin := Vector2i((Workspace.WIDTH - ground.width * divisor) / 2, Workspace.HEIGHT - shape_height * divisor)
	# The selected tile is at the front of the four-by-four drawing base.
	for x in 4:
		for y in 4:
			var point := origin + Vector2i((x - y) * config.half_width, (x + y - 6) * config.half_height) * divisor
			for sy in ground.height * divisor:
				for sx in ground.width * divisor:
					var index := decoded.pixels[(sy / divisor) * ground.width + sx / divisor]
					var target := point + Vector2i(sx, sy)
					if index >= 0 and target.x >= 0 and target.x < Workspace.WIDTH and target.y >= 0 and target.y < Workspace.HEIGHT:
						result[target.y * Workspace.WIDTH + target.x] = index
	return result
