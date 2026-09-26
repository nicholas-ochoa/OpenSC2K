class_name WindowPixelFit
extends Node
# The main window draws each embedded window, such as a dialog, menu, or
# tooltip, from a texture of whole screen pixels. At a fractional UI scale the
# copy can repeat or drop a row or column of pixels. After a window stops
# moving, or the scale changes, this enlarges the window by a few interface
# pixels so that the copy is one to one. It never moves a window.

# a position that no window has, for a window that was not seen before
const UNSEEN := Vector2i(-2147483648, -2147483648)


func _process(_delta: float) -> void:
	if ScreenPixels.scale <= 0.0:
		return

	for window in get_tree().root.get_embedded_subwindows():
		if window.visible:
			fit(window)


# fits one window. the fit depends on the position, and a dragged window has
# no signal, so a moving window waits until it stops
static func fit(window: Window) -> void:
	var moving: bool = window.position != window.get_meta(&"pixel_fit_last_position", UNSEEN)
	window.set_meta(&"pixel_fit_last_position", window.position)

	if moving:
		return

	var fitted_size: Vector2i = window.get_meta(&"pixel_fit_size", Vector2i(-1, -1))

	if (window.size == fitted_size and window.position == window.get_meta(&"pixel_fit_position", Vector2i.ZERO)
			and is_equal_approx(float(window.get_meta(&"pixel_fit_scale", 0.0)), ScreenPixels.scale)):
		return

	# a size other than the last fitted size comes from the player or the window
	if window.size != fitted_size:
		window.set_meta(&"pixel_fit_unfitted", window.size)

	var target := ScreenPixels.window_size(window.position, window.get_meta(&"pixel_fit_unfitted", window.size))

	if window.size != target:
		window.size = target

	# keep the size that the window accepts, which its limits can change
	window.set_meta(&"pixel_fit_size", window.size)
	window.set_meta(&"pixel_fit_position", window.position)
	window.set_meta(&"pixel_fit_scale", ScreenPixels.scale)
