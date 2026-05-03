extends "res://src/main.gd"
## Inclusive CPU timings for the native frame benchmark only.
var frame_profile := {}


func _record(name: String, started: int) -> void:
	var elapsed := Time.get_ticks_usec() - started
	var entry: Dictionary = frame_profile.get(name, {"calls": 0, "usec": 0, "max_usec": 0})
	entry.calls += 1
	entry.usec += elapsed
	entry.max_usec = maxi(entry.max_usec, elapsed)
	frame_profile[name] = entry


func _process(delta: float) -> void:
	var started := Time.get_ticks_usec()
	super._process(delta)
	_record("process", started)


func _init() -> void:
	moving_sprites = ProfileMovingSprites.new(self)
	interface = ProfileInterface.new(self)
	map_render = ProfileMapRender.new(self)
	static_render = ProfileStaticRender.new(self)


class ProfileMovingSprites extends ApplicationMovingSprites:

	func _refresh_moving_things(view_size := -1) -> void:
		var started := Time.get_ticks_usec()
		super._refresh_moving_things(view_size)
		app._record("moving", started)

	func _static_occlusion_candidates(bounds: Rect2i) -> Array[Dictionary]:
		var started := Time.get_ticks_usec()
		var result := super._static_occlusion_candidates(bounds)
		app._record("foreground_candidates", started)

		return result


class ProfileInterface extends ApplicationInterface:

	func _refresh_details() -> void:
		var started := Time.get_ticks_usec()
		super._refresh_details()
		app._record("details", started)


class ProfileMapRender extends ApplicationMapRender:

	func _refresh_map(force := true) -> void:
		var started := Time.get_ticks_usec()
		super._refresh_map(force)
		app._record("refresh_map", started)

	func _poll_region_cache() -> void:
		var started := Time.get_ticks_usec()
		super._poll_region_cache()
		app._record("poll_regions", started)

	func _refresh_sign_occlusion(view_size: int) -> void:
		var started := Time.get_ticks_usec()
		super._refresh_sign_occlusion(view_size)
		app._record("signs", started)

	func _sign_palette_image(indexed: Image, mapping: PackedInt32Array) -> Image:
		var started := Time.get_ticks_usec()
		var result := super._sign_palette_image(indexed, mapping)
		app._record("sign_palette_pixels", started)

		return result


class ProfileStaticRender extends ApplicationStaticRender:

	func _update_palette_cycle_texture() -> void:
		var started := Time.get_ticks_usec()
		super._update_palette_cycle_texture()
		app._record("palette", started)

	func _static_signature_for_mode(mode: String, view_size: int) -> Array:
		var started := Time.get_ticks_usec()
		var result := super._static_signature_for_mode(mode, view_size)
		app._record("signature", started)

		return result
