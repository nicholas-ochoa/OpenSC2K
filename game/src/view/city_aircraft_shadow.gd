class_name CityAircraftShadow
extends RefCounted
## Black alpha silhouettes blend with the current ground, including moving water.

const OPACITY := 0.35


static func create(source: Image, occluder: Image, origin: Vector2i, limit: Vector2i) -> Image:
	return NativeSpriteCompositor.aircraft_shadow(source, occluder, origin, limit)
