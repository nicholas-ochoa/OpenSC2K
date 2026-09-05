class_name CityStaticCommand
extends CitySpriteVisual
# foreground silhouette in painter order, with optional train crossing masks
# zero means no reference sprite or deck. a negative foreground reference
# uses the full surface. region order is absent from whole-city commands

var position := Vector2i.ZERO
var size := Vector2i.ZERO
var depth_order := -1
var region_order := -1
var train_ignore := false
var train_foreground_reference_sprite_id := 0
var train_deck_thickness := 0
var train_deck_reference_sprite_id := 0
var train_foreground_requires_depth := false
