class_name RenderCaches
extends RefCounted


# region workers and the whole-city static image
var region_cache: CityRegionCache
var static_city_image: Image
var static_occlusion_commands: Array[Dictionary] = []
var static_occlusion_grid: Dictionary = {}
var static_visual_signature: Array = []
var static_render_mode := CityViewMode.Mode.NONE
var static_display_city: CityState
var static_view_cache: Dictionary[CityViewMode.Mode, Dictionary] = {}
# moving sprite and sign composition
var dynamic_sprite_cache: Dictionary = {}
var dynamic_foreground_cache: Dictionary = {}
var dynamic_occluder_cache: Dictionary = {}
var dynamic_visual_cache: Dictionary = {}
var dynamic_command_cache := CityDynamicCommandCache.new()
var foreground_view_rect := Rect2()
var foreground_complete := false
var sign_foreground_cache: Dictionary = {}
var dynamic_special_batch_cache: Dictionary = {}
var dynamic_sign_occluders: Array[Dictionary] = []
var dynamic_sign_occlusion_grid: Dictionary = {}
