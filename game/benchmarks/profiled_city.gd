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

func _refresh_moving_things(view_size := -1) -> void:
	var started := Time.get_ticks_usec()
	super._refresh_moving_things(view_size)
	_record("moving", started)

func _refresh_details() -> void:
	var started := Time.get_ticks_usec()
	super._refresh_details()
	_record("details", started)

func _refresh_map(force := true) -> void:
	var started := Time.get_ticks_usec()
	super._refresh_map(force)
	_record("refresh_map", started)

func _poll_region_cache() -> void:
	var started := Time.get_ticks_usec()
	super._poll_region_cache()
	_record("poll_regions", started)

func _update_palette_cycle_texture() -> void:
	var started := Time.get_ticks_usec()
	super._update_palette_cycle_texture()
	_record("palette", started)

func _refresh_sign_occlusion(view_size: int) -> void:
	var started := Time.get_ticks_usec()
	super._refresh_sign_occlusion(view_size)
	_record("signs", started)

func _static_signature_for_mode(mode: String, view_size: int) -> Array:
	var started := Time.get_ticks_usec()
	var result := super._static_signature_for_mode(mode, view_size)
	_record("signature", started)
	return result

func _sign_palette_image(indexed: Image, mapping: PackedInt32Array) -> Image:
	var started := Time.get_ticks_usec()
	var result := super._sign_palette_image(indexed, mapping)
	_record("sign_palette_pixels", started)
	return result

func _static_occlusion_candidates(bounds: Rect2i) -> Array[Dictionary]:
	var started := Time.get_ticks_usec()
	var result := super._static_occlusion_candidates(bounds)
	_record("foreground_candidates", started)
	return result
