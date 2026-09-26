class_name ScreenPixels
extends RefCounted
# Keeps nearest-neighbor artwork on whole screen pixels when the interface uses
# a fractional scale. The application sets the scale. Zero turns alignment off,
# as in headless runs, and the helpers then return their input.

# screen pixels for each interface pixel
static var scale := 0.0
# pixel-art textures that change size with the scale
static var _textures: Array[WeakRef] = []


# sets the scale and tells each watched texture that its size changed
static func set_scale(value: float) -> void:
	if is_equal_approx(scale, value):
		return

	scale = value
	var live: Array[WeakRef] = []

	for texture_ref in _textures:
		var texture := texture_ref.get_ref() as Texture2D

		if texture != null:
			live.append(texture_ref)
			texture.emit_changed()

	_textures = live


static func watch(texture: Texture2D) -> void:
	_textures.append(weakref(texture))


# the whole screen pixels for each artwork pixel that base interface pixels
# for each artwork pixel become, and at least one
static func art_pixels(base := 1.0, pixels_per_unit := scale) -> int:
	return maxi(1, roundi(base * pixels_per_unit))


# the interface length of texels artwork pixels at base interface pixels for
# each artwork pixel, on whole screen pixels
static func art_length(texels: float, base := 1.0, pixels_per_unit := scale) -> float:
	if pixels_per_unit <= 0.0:
		return texels * base

	return texels * art_pixels(base, pixels_per_unit) / pixels_per_unit


# the largest interface scale up to units that gives each artwork pixel whole
# screen pixels. a scale below one screen pixel for each artwork pixel is
# unchanged
static func fit_scale(units: float, pixels_per_unit := scale) -> float:
	if pixels_per_unit <= 0.0 or units * pixels_per_unit < 1.0:
		return units

	return floorf(units * pixels_per_unit + 0.001) / pixels_per_unit


# the interface length nearest to units that covers whole screen pixels, and
# at least one screen pixel
static func length(units: float, pixels_per_unit := scale) -> float:
	if pixels_per_unit <= 0.0:
		return units

	return maxf(1.0, roundf(units * pixels_per_unit)) / pixels_per_unit


# the largest length up to units that divides into count cells of whole screen
# pixels. a length too short for one screen pixel for each cell is unchanged
static func whole_cells(units: float, count: int, pixels_per_unit := scale) -> float:
	if pixels_per_unit <= 0.0 or count <= 0:
		return units

	var cell := floorf(units * pixels_per_unit / count)

	return cell * count / pixels_per_unit if cell >= 1.0 else units


# the smallest size, up to 16 interface pixels larger on each axis, that lets
# the main window copy an embedded window to the screen one pixel for one. the
# window texture has its screen size rounded up to whole pixels, and the copy
# squeezes it into the exact screen size with nearest sampling. the copy is
# one to one while the rounding and the start of the window within its first
# screen pixel stay less than one pixel together
static func window_size(position: Vector2i, size: Vector2i, pixels_per_unit := scale) -> Vector2i:
	if pixels_per_unit <= 0.0:
		return size

	var result := size

	for axis in 2:
		var start := position[axis] * pixels_per_unit
		var sample := fposmod(0.5 - (start - floorf(start)), 1.0)

		for units in range(size[axis], size[axis] + 17):
			var pixels := units * pixels_per_unit

			if sample + ceilf(pixels - 0.0001) - pixels < 0.9:
				result[axis] = units
				break

	return result


# moves a point in the local space of item to the nearest screen pixel corner.
# the main window draws each embedded window from its own texture with nearest
# sampling, so a point aligns in the space of its own window
static func snap(item: CanvasItem, point: Vector2, pixels_per_unit := scale) -> Vector2:
	if pixels_per_unit <= 0.0 or not item.is_inside_tree():
		return point

	var to_screen := Transform2D.IDENTITY.scaled(Vector2.ONE * pixels_per_unit) * item.get_global_transform_with_canvas()

	return to_screen.affine_inverse() * (to_screen * point).round()
