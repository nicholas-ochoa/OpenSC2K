class_name PaletteAnimationClock
extends RefCounted
# ApplicationFrame advances the clock; ApplicationStaticRender builds the palette texture.

var cycle_ticks := 0
# display time not yet counted as a whole base tick
var elapsed_msec := 0.0
var cycle_texture: ImageTexture
var underground_cycle_texture: ImageTexture
# the active palette with the current animation cycle applied, for toolbar icons
var toolbar_palette: Sc2Palette
