class_name RenderCaches
extends RefCounted

# region workers and the whole-city static image
var region_cache: CityRegionCache
var static_city_image: Image
var static_occlusion_commands: Array[CityStaticCommand] = []
var static_occlusion_grid: NativeRectIndex
var static_visual_signature: Array = []
var static_render_mode := CityViewMode.Mode.NONE
var static_display_city: CityState
var static_view_cache: Dictionary[CityViewMode.Mode, StaticView] = {}
# moving sprite composition
var dynamic_sprite_cache: Dictionary[String, CitySpriteResource] = {}
var dynamic_foreground_cache: Dictionary[String, Image] = {}
var dynamic_occluder_cache: Dictionary[String, OccluderMask] = {}
var dynamic_visual_cache: Dictionary[String, CityDynamicVisual] = {}
var dynamic_active_keys: Dictionary[String, bool] = {}
var dynamic_command_cache := CityDynamicCommandCache.new()
var foreground_view_rect := Rect2()
var foreground_complete := false
var dynamic_special_batch_cache: Dictionary[String, CityDynamicVisual] = {}


class StaticView extends RefCounted:
	var image: Image
	var occlusion_commands: Array[CityStaticCommand]
	var signature: Array
	var display_city: CityState
	var view_size: int

	func _init(rendered_image: Image, commands: Array[CityStaticCommand], stamp: Array,
		source: CityState, graphics_size: int) -> void:
		image = rendered_image
		occlusion_commands = commands
		signature = stamp
		display_city = source
		view_size = graphics_size


class OccluderMask extends RefCounted:
	var bounds: Rect2i
	var image: Image

	func _init(area: Rect2i, mask: Image) -> void:
		bounds = area
		image = mask
