class_name LoadedAssetState
extends RefCounted
# ApplicationAssets replaces these assets when the source changes.

# asset source and startup status
var asset_source: GameAssetSource
var data_pack := DataPack.new()
# the data pack folder, which supplies the original game data files
var reference_root := ""
var runtime_initialized := false
var assets_ready := false
# loaded graphics
var palette: Sc2Palette
var scenario_palette: Sc2Palette
var scenario_graphics: ScenarioGraphics
var scurk_graphics: ScurkGraphics
var palette_index_encoding: Sc2Palette
var large_sprites: Sc2SpriteArchive
var small_medium_sprites: Sc2SpriteArchive
var base_large_sprites: Sc2SpriteArchive
var base_small_medium_sprites: Sc2SpriteArchive
# active scurk tile set
var active_scurk_tile_set: ScurkMif
var active_scurk_name := ""
var active_scurk_path := ""
