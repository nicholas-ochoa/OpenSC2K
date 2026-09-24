class_name AppPreferences
extends RefCounted
# ApplicationSettings loads and saves these preferences. Keys match
# AppSettingsStore; settings_path selects the file.

const SettingsStore = preload("res://src/ui/settings/app_settings_store.gd")

var soundtrack_folder := ""
var toolbar_sounds := true
var sound_pack_folder := ""
var music_pack_folder := ""
var city_renderer := "gpu"
var ui_theme := "light"
var translucent_menus := true
var dark_underground := false
var default_mayor_name := "Mayor"
var overview_graphics := 0
var zoom_graphics: Array[int] = SettingsStore.normalize_zoom_graphics(SettingsStore.DEFAULT_ZOOM_GRAPHICS)
var background_audio := false
var shuffle_music := false
var original_compatibility := false
var warn_sc2x_conversion := true
var settings_path := SettingsStore.SETTINGS_PATH
var music_volume := 0.8
var effects_volume := 0.8
var fullscreen := false
var graphics_source := "auto"
var graphics_folder := ""
