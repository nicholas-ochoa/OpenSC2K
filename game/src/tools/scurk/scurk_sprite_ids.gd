class_name ScurkSpriteIds
extends RefCounted
## Sprite ranges for the SCURK object editor.

enum View { LARGE = 0, MEDIUM = 1, SMALL = 2 }

const OBJECT_COUNT := 500
const VIEW_COUNT := 3
const SMALL_FIRST := 0
const MEDIUM_FIRST := OBJECT_COUNT
const LARGE_FIRST := OBJECT_COUNT * 2
const LARGE_LAST := LARGE_FIRST + OBJECT_COUNT - 1
const SPRITE_COUNT := OBJECT_COUNT * VIEW_COUNT
