class_name HdSprite
extends RefCounted
## The full-color art of one indexed city sprite. It changes only the look of
## the sprite. The indexed pixels still give the geometry, masks, and saves.

# RGBA pixels at any density. They cover the width of the sprite and `height`
# logical rows that end at the bottom of the sprite.
var image: Image
var height := 0
# Optional: equal frames from top to bottom, each the size of `image`.
var animation: Image
var frames := 1
var fps := 8
