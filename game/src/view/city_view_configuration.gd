class_name CityViewConfiguration
extends RefCounted
# immutable geometry for one native graphics size, safe to share with workers
# setters reject changes after construction; hot-path reads use typed fields

var _sealed := false

var view_size: int:
	set(value):
		if _sealed:
			push_error("CityViewConfiguration is immutable")
		else:
			view_size = value
var divisor: int:
	set(value):
		if _sealed:
			push_error("CityViewConfiguration is immutable")
		else:
			divisor = value
var tile_width: int:
	set(value):
		if _sealed:
			push_error("CityViewConfiguration is immutable")
		else:
			tile_width = value
var tile_height: int:
	set(value):
		if _sealed:
			push_error("CityViewConfiguration is immutable")
		else:
			tile_height = value
var half_width: int:
	set(value):
		if _sealed:
			push_error("CityViewConfiguration is immutable")
		else:
			half_width = value
var half_height: int:
	set(value):
		if _sealed:
			push_error("CityViewConfiguration is immutable")
		else:
			half_height = value
var altitude_step: int:
	set(value):
		if _sealed:
			push_error("CityViewConfiguration is immutable")
		else:
			altitude_step = value
var top_margin: int:
	set(value):
		if _sealed:
			push_error("CityViewConfiguration is immutable")
		else:
			top_margin = value
var side_margin: int:
	set(value):
		if _sealed:
			push_error("CityViewConfiguration is immutable")
		else:
			side_margin = value
var sprite_base: int:
	set(value):
		if _sealed:
			push_error("CityViewConfiguration is immutable")
		else:
			sprite_base = value


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
	_sealed = true


func with_top_margin(value: int) -> CityViewConfiguration:
	return CityViewConfiguration.new(view_size, divisor, Vector2i(tile_width, tile_height),
		Vector2i(half_width, half_height), altitude_step, Vector2i(side_margin, value), sprite_base)
