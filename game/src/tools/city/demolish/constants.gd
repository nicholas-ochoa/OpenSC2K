class_name DemolishConstants
extends RefCounted

const NewsQueue = preload("res://src/simulation/reports/news_queue.gd")

const GROUP_BULLDOZER := 0
const SUBTOOL_DEMOLISH := 0
const RADIOACTIVITY := 0x05
const MILITARY_ZONE := 0x07
const DYNAMIC_LABEL_FIRST := 61
const DYNAMIC_LABEL_LAST := 200
const MICROSIM_LABEL_BASE := 51
const PROTECTED_CONNECTION_LABEL := 0xff
const FLAG_CLEAR_AFTER_STRUCTURE := 0x3d
const FLAG_FLIPPED := 0x02
const FLAG_WATER := 0x04
const HIGHWAY_STRAIGHT_FIRST := 0x49
const HIGHWAY_STRAIGHT_LAST := 0x50
const BRIDGE_FIRST := 0x51
const BRIDGE_LAST := 0x5c
const HIGHWAY_SHAPED_FIRST := 0x61
const HIGHWAY_SHAPED_LAST := 0x69
const REINFORCED_BRIDGE_FIRST := 0x6a
const REINFORCED_BRIDGE_LAST := 0x6b
const TUNNEL_FIRST := 0x3f
const TUNNEL_LAST := 0x42
const RUNWAY_FIRST := 0xdd
const RUNWAY_LAST := 0xde
const PIER_FIRST := 0xdf
const PIER_LAST := 0xe0
const SUBWAY_STATION := 0xe9
const TUNNEL_MASK := 0x7c00
const BRIDGE_DEBRIS_SPRITE := 1392
const SOUND_EXPLODE := 504
const SOUND_FOREST_PROTEST := 512
const NEWS_FOREST_PROTEST := 0x28
const MAX_PARALLEL_EFFECT_OFFSET_FRAMES := 2
const MISC_GRANTED_REWARDS := 0x0078
const REWARD_BIT_BY_TILE := {
	0xf3: 0,
	0xd0: 1,
	0xdb: 2,
	0xff: 3,
}

const CORNER_BOTTOM_LEFT := [0x10, 0x20, 0x40, 0x80]
const CORNER_BOTTOM_RIGHT := [0x20, 0x40, 0x80, 0x10]
const CORNER_TOP_LEFT := [0x40, 0x80, 0x10, 0x20]
const CORNER_TOP_RIGHT := [0x80, 0x10, 0x20, 0x40]
const DIRECTIONS := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
