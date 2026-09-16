class_name CityMapConstants
extends RefCounted
# shared view constants and unchanged palette shader source

const Renderer = preload("res://src/view/city_isometric_renderer.gd")
const DynamicSpriteCanvas = preload("res://src/view/city_dynamic_sprite_canvas.gd")
const ZOOM_LEVELS := [0.1, 0.25, 0.5, 1.0, 2.0, 3.0, 4.0]
const DEFAULT_ZOOM_INDEX := 3
const WHEEL_ZOOM_DEBOUNCE_MSEC := 250
# a continuing wheel gesture can delay the next wheel zoom by at most this much
const WHEEL_ZOOM_MAX_DEBOUNCE_MSEC := 500
# child layer order: network preview artwork, then the price label above it
const NETWORK_PREVIEW_Z_INDEX := 80
const PRICE_LAYER_Z_INDEX := 90
const SIGN_FONT_HEIGHTS := [12, 14, 16]
const SIGN_PANEL_FILL := Color("9f9f9f")
const SIGN_POST_FILL := Color("bbbbbb")
const SIGN_EDGE_LIGHT := Color("e3e3e3")
const SIGN_EDGE_MIDDLE := Color("838383")
const SIGN_EDGE_DARK := Color("575757")
const SIGN_TEXT_COLOR := Color("000030")
const PALETTE_CYCLE_SHADER := preload("res://src/view/map/palette_cycle.gdshader")
