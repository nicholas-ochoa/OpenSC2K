class_name CityLifeSprites
extends RefCounted
## Shared pixel artwork. Vehicle frames use the approved Set B atlas.

const COLORS := [Color("b34c3c"), Color("d9d5c4"), Color("d1aa45"), Color("477358"), Color("637f9d"), Color("8c8583")]
enum Vehicle { CAR, TRUCK, BUS }
const VEHICLE_ATLAS := preload("res://assets/city_life/vehicles_b.png")
const DIAGONAL_ATLAS := preload("res://assets/city_life/vehicles_diagonal.png")
const DIAGONAL_CELL := Vector2i(20, 14)
const VEHICLE_SIZES := [Vector2i(9, 6), Vector2i(12, 8), Vector2i(14, 9)]
const VARIANTS := 18
const CELL := Vector2i(16, 10)
var images: Dictionary[String, Image] = {}
var _vehicle_atlas := VEHICLE_ATLAS.get_image()
var _diagonal_atlas := DIAGONAL_ATLAS.get_image()


func prepare_frames() -> void:
	for direction in 8:
		for variant in VARIANTS:
			for kind in 3:
				sprite(false, variant, direction, 0, kind)
		for variant in COLORS.size():
			for phase in 2:
				sprite(true, variant, direction, phase)


func sprite(walking: bool, variant: int, direction: int, phase: int, vehicle_kind: int = Vehicle.CAR) -> Image:
	var key := "%d:%d:%d:%d:%d" % [int(walking), variant, direction, phase if walking else 0, vehicle_kind]
	if not images.has(key):
		images[key] = _person(variant, direction, phase) if walking else _vehicle(variant, direction, vehicle_kind)
	return images[key]


static func _person(variant: int, direction: int, phase: int) -> Image:
	var image := Image.create(3, 6, false, Image.FORMAT_RGBA8)
	image.set_pixel(1, 0, Color("574737"))
	image.set_pixel(1, 1, Color("d0a577"))
	var shirt: Color = COLORS[variant % COLORS.size()]
	image.set_pixel(1, 2, shirt.lightened(0.12))
	image.set_pixel(1, 3, shirt)
	image.set_pixel(2 if direction in [0, 1, 4, 5] else 0, 3, Color("d0a577"))
	image.set_pixel(1, 4, Color("333d50"))
	image.set_pixel(phase % 2 * 2, 5, Color("252831"))
	return image


func _vehicle(variant: int, direction: int, kind: int) -> Image:
	if direction >= 4:
		var origin := Vector2i((direction - 4) * DIAGONAL_CELL.x, (kind * VARIANTS + variant) * DIAGONAL_CELL.y)
		var cell := _diagonal_atlas.get_region(Rect2i(origin, DIAGONAL_CELL))
		return cell.get_region(cell.get_used_rect())
	# Each direction is original artwork; never flip the roof or move its light side.
	var origin := Vector2i(direction * CELL.x, (kind * VARIANTS + variant) * CELL.y)
	return _vehicle_atlas.get_region(Rect2i(origin, VEHICLE_SIZES[kind]))
