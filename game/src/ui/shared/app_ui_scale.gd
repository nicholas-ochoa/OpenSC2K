class_name AppUiScale
extends RefCounted
# The project stretch mode fits the base layout size to the window. The UI
# scale is relative to that fit: 2.0 is the fitted size, and smaller values
# show more of the layout. The interface never uses fewer than one screen pixel
# for each interface pixel, and the layout never becomes smaller than the base
# size. The city map uses its own whole-pixel scale, which follows the fit and
# not the UI scale.

const OPTIONS: Array[float] = [1.0, 1.5, 2.0]
const DEFAULT := 2.0


static func normalize(value: Variant) -> float:
	if not (value is float or value is int):
		return DEFAULT

	var result := DEFAULT

	for option in OPTIONS:
		if absf(float(value) - option) < absf(float(value) - result):
			result = option

	return result


static func option_index(value: float) -> int:
	return OPTIONS.find(normalize(value))


# the scale that the project stretch mode uses to fit the base size
static func fit_scale(window_size: Vector2i, base_size: Vector2i) -> float:
	if base_size.x <= 0 or base_size.y <= 0 or window_size.x <= 0 or window_size.y <= 0:
		return 1.0

	return minf(float(window_size.x) / base_size.x, float(window_size.y) / base_size.y)


static func screen_scale(ui_scale: float, window_size: Vector2i, base_size: Vector2i) -> float:
	var fit := fit_scale(window_size, base_size)

	return maxf(fit * normalize(ui_scale) / DEFAULT, minf(fit, 1.0))


static func content_scale_factor(ui_scale: float, window_size: Vector2i, base_size: Vector2i) -> float:
	return screen_scale(ui_scale, window_size, base_size) / fit_scale(window_size, base_size)


# the whole number of screen pixels for each city source pixel at 100% zoom,
# near the fitted scale
static func map_pixels(fit: float) -> int:
	return maxi(1, roundi(fit))


# sets the window content scale and returns the screen pixels for each
# interface pixel on each axis
static func apply(window: Window, ui_scale: float) -> Vector2:
	var window_size := window.size
	var base_size := window.content_scale_size
	var factor := content_scale_factor(ui_scale, window_size, base_size)

	if not is_equal_approx(window.content_scale_factor, factor):
		window.content_scale_factor = factor

	# Godot rounds the layout to whole interface pixels, so use the scales that
	# it applies
	var applied := window.get_final_transform().get_scale()

	return applied if applied.x > 0.0 and applied.y > 0.0 else Vector2.ONE * screen_scale(ui_scale, window_size, base_size)
