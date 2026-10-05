class_name CityLifeSprites
extends RefCounted
## Original small pixel artwork, generated once and shared by all figures.

@warning_ignore_start("integer_division")

const COLORS := [Color("b34c3c"), Color("d9d5c4"), Color("d1aa45"), Color("477358"), Color("637f9d"), Color("8c8583")]
enum Vehicle { CAR, TRUCK, BUS }
var images: Dictionary[String, Image] = {}


func sprite(walking: bool, variant: int, direction: int, phase: int, vehicle_kind: int = Vehicle.CAR) -> Image:
	var key := "%d:%d:%d:%d:%d" % [int(walking), variant, direction, phase if walking else 0, vehicle_kind]
	if not images.has(key):
		images[key] = _person(variant, direction, phase) if walking else (
			_car(variant, direction) if vehicle_kind == Vehicle.CAR else _large_vehicle(variant, direction, vehicle_kind))
	return images[key]


static func _person(variant: int, direction: int, phase: int) -> Image:
	var image := Image.create(3, 6, false, Image.FORMAT_RGBA8)
	image.set_pixel(1, 0, Color("574737"))
	image.set_pixel(1, 1, Color("d0a577"))
	var shirt: Color = COLORS[variant % COLORS.size()]
	image.set_pixel(1, 2, shirt.lightened(0.12))
	image.set_pixel(1, 3, shirt)
	image.set_pixel(0 if direction > 1 else 2, 3, Color("d0a577"))
	image.set_pixel(1, 4, Color("333d50"))
	image.set_pixel(phase % 2 * 2, 5, Color("252831"))
	return image


static func _large_vehicle(variant: int, direction: int, kind: int) -> Image:
	var rows := ["..cccc......", ".ccccccc....", "..ccccccc...", "...ccccbb...",
		"....cccwbbh.", ".....tbbbbh.", "........tt.."]
	if kind == Vehicle.BUS:
		rows = ["..bbbb........", ".bbbbbbb......", "..bwbbwbbbb...", "...bbwwwwwbb..",
			"....bbbbbbbwh.", ".....tbbbbbbh.", ".........tbt.."]
	if direction == 0 or direction == 2:
		rows = ["......bb....", "...cccbbwh..", ".ccccccbbh..", "..ccccccbb..",
			"...ccccctb..", "....tccct...", "............"] if kind == Vehicle.TRUCK else [
			".........bb...", "......bbbbwh..", "...bbbbbbbbh..", ".bbwwwwwbbbb..",
			"..bbbbbbbbtb..", "...tbbbbbt....", ".............."]
	var image := Image.create(rows[0].length(), rows.size(), false, Image.FORMAT_RGBA8)
	var body: Color = COLORS[variant % COLORS.size()]
	var cargo := Color("c5bca9") if variant % 2 == 0 else Color("9aabb0")
	for y in rows.size():
		for x in rows[y].length():
			var color := Color.TRANSPARENT
			match rows[y][x]:
				"b": color = body if y < 3 else body.darkened(0.28)
				"c": color = cargo if y < 3 else cargo.darkened(0.22)
				"w": color = Color("859da5")
				"t": color = Color("24272b")
				"h": color = Color("ded9b7")
			if color.a > 0.0:
				image.set_pixel(x, y, color)
	if direction >= 2:
		image.flip_x()
	return image


static func _car(variant: int, direction: int) -> Image:
	var image := Image.create(9, 6, false, Image.FORMAT_RGBA8)
	var style := variant / COLORS.size()
	var rows := [".........", "..bbb....", ".btwbbb..", "..bbwbbh.", "...tbbhh.", ".....tt.."]
	if style == 1:
		rows = ["..bb.....", ".btwbb...", "..bbwwbb.", "...bbbbb.", "....tbhh.", "......t.."]
	elif style == 2:
		rows = ["..bbb....", ".btbbbb..", "..bbwwwb.", "...bbbbb.", "....tbhh.", "......t.."]
	var body: Color = COLORS[variant % COLORS.size()]
	for y in rows.size():
		for x in rows[y].length():
			var color := Color.TRANSPARENT
			match rows[y][x]:
				"b": color = body if y < 3 else body.darkened(0.28)
				"w": color = Color("859da5")
				"t": color = Color("24272b")
				"h": color = Color("ded9b7")
			if color.a > 0.0:
				image.set_pixel(x, y, color)
	if direction >= 2:
		image.flip_x()
	if direction == 0 or direction == 3:
		image.flip_y()
	return image
