class_name ScreenPixels
extends RefCounted
# Keeps nearest-neighbor artwork on whole screen pixels when the interface uses
# a fractional scale. The application sets the scale. Zero turns alignment off,
# as in headless runs, and the helpers then return their input.

# screen pixels for each interface pixel
static var scale := 0.0


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
