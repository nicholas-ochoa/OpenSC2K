class_name CityTrainArtwork
extends RefCounted
## Remove detached corner dots only from recognized original train artwork.

const SOURCES := {
	1374: {"size": Vector2i(32, 20), "sha256": "7dd358d609c83e4c15eb396087e143a7e9c92366d0a18a06e32aae0f9bb3b179", "dots": [Vector2i(0, 11), Vector2i(31, 11), Vector2i(15, 19)]},
	1375: {"size": Vector2i(32, 21), "sha256": "88b8107bcecc3cf198706440c58ed2c9d079b8bcde8541cc58722e70b5ddc261", "dots": [Vector2i(0, 12), Vector2i(31, 12), Vector2i(15, 20)]},
	1376: {"size": Vector2i(32, 19), "sha256": "8b2ad0360959e72e80b702cf83d3bf10770ea888f81cda90553d2e51be55cdbb", "dots": [Vector2i(0, 10), Vector2i(31, 10), Vector2i(15, 18)]},
	1377: {"size": Vector2i(32, 33), "sha256": "2bf4fd52dfcab91735f73ac4b9af677ddb19daba454cbde210c1af82dede61b6", "dots": [Vector2i(0, 16), Vector2i(31, 16), Vector2i(15, 32)]},
	1378: {"size": Vector2i(32, 28), "sha256": "98c548b38f3cea247c5a7406287f662638fb6a6c12a2f85f2438631f455dc205", "dots": [Vector2i(0, 19), Vector2i(31, 13), Vector2i(16, 27)]},
}


static func clean(entry: Sc2SpriteArchive.SpriteEntry, image: Image) -> Image:
	var source: Dictionary = SOURCES.get(entry.sprite_id, {})
	if source.is_empty() or image.get_size() != source.size or CityBrightmaps.fingerprint(entry) != source.sha256:
		return image
	# Keep the imported archive and its shared decoded image intact. This copy
	# is retained by the dynamic sprite cache, before mirroring and scaling.
	var result := image.duplicate()
	for point: Vector2i in source.dots:
		result.set_pixelv(point, Color.TRANSPARENT)
	return result
