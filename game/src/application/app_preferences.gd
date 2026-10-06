class_name AppPreferences
extends RefCounted
# ApplicationSettings loads and saves these preferences. Keys match
# AppSettingsStore; settings_path selects the file.

const SettingsStore = preload("res://src/ui/settings/app_settings_store.gd")

var soundtrack_folder := ""
var toolbar_sounds := true
var city_sounds: int = WaveSoundGate.CitySounds.DEFAULT
var sound_pack_folder := ""
var music_pack_folder := ""
var data_pack_folder := ""
var city_renderer := "gpu"
var ui_theme := "light"
var ui_language := AppLocalization.DEFAULT
var ui_scale := AppUiScale.DEFAULT
var translucent_menus := true
var dark_underground := false
# the sc2kfix corrections of the original sprites (Sc2kfixSpriteFixes)
var sprite_corrections := false
# autosaves of the last ten minutes in the temporary folder (ApplicationAutosave)
var recent_autosaves := true
var default_mayor_name := "Mayor"
var overview_graphics := 0
var zoom_graphics: Array[int] = SettingsStore.normalize_zoom_graphics(SettingsStore.DEFAULT_ZOOM_GRAPHICS)
var background_audio := false
var shuffle_music := false
# a SoundFontCatalog choice, and the file of the custom choice
var music_soundfont := SoundFontCatalog.DEFAULT
var music_soundfont_path := ""
var settings_path := SettingsStore.default_path()
var music_volume := 0.8
var effects_volume := 0.8
var fullscreen := false
var graphics_source := "auto"
var graphics_folder := ""
# the pack.json of an HD sprite pack, or empty for the original sprites
var hd_pack_folder := ""
var check_for_updates := false
var control_bindings := ControlBindings.defaults()
var update_last_check := 0
var update_skipped_version := ""
var update_checked_at := 0
var update_error := ""
var debug_mode := false


func save_options(include_ui_scale := true) -> SettingsStore.SaveOptions:
	var options := SettingsStore.SaveOptions.new()
	options.graphics_source = graphics_source
	options.graphics_folder = graphics_folder
	options.soundtrack_folder = soundtrack_folder
	options.city_renderer = city_renderer
	options.background_audio = background_audio
	options.zoom_graphics = zoom_graphics
	options.toolbar_sounds = toolbar_sounds
	options.city_sounds = city_sounds
	options.sound_pack_folder = sound_pack_folder
	options.music_pack_folder = music_pack_folder
	options.shuffle_music = shuffle_music
	options.music_soundfont = music_soundfont
	options.music_soundfont_path = music_soundfont_path
	options.default_mayor_name = default_mayor_name
	options.overview_graphics = overview_graphics
	options.ui_theme = ui_theme
	options.ui_language = ui_language
	options.dark_underground = dark_underground
	options.sprite_corrections = sprite_corrections
	options.recent_autosaves = recent_autosaves
	options.translucent_menus = translucent_menus
	options.check_for_updates = check_for_updates
	options.data_pack_folder = data_pack_folder
	options.hd_pack_folder = hd_pack_folder
	options.control_bindings = control_bindings

	if include_ui_scale:
		options.ui_scale = ui_scale

	return options
