class_name CityViewConfiguration
extends RefCounted
# geometry for one native graphics size
# the three standard instances are shared with gpu worker threads
# do not mutate instances after construction. use with_top_margin() to derive a variant

var view_size: int
var divisor: int
var tile_width: int
var tile_height: int
var half_width: int
var half_height: int
var altitude_step: int
var top_margin: int
var side_margin: int
var sprite_base: int


func _init(graphics_size: int, scale_divisor: int, tile_extent: Vector2i,
	half_extent: Vector2i, height_step: int, margins: Vector2i, base_sprite: int) -> void:
	view_size = graphics_size
	divisor = scale_divisor
	tile_width = tile_extent.x
	tile_height = tile_extent.y
	half_width = half_extent.x
	half_height = half_extent.y
	altitude_step = height_step
	top_margin = margins.y
	side_margin = margins.x
	sprite_base = base_sprite


func with_top_margin(value: int) -> CityViewConfiguration:
	return CityViewConfiguration.new(view_size, divisor, Vector2i(tile_width, tile_height),
		Vector2i(half_width, half_height), altitude_step, Vector2i(side_margin, value), sprite_base)
