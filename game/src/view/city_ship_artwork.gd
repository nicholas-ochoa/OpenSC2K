class_name CityShipArtwork
extends RefCounted
## Remove baked water from recognized original ships on the enhanced water surface.

const SOURCES := {
	369: {"size": Vector2i(24, 13), "sha256": "3497bd1d842a408d358c77bbef6cdcb31bf8d8d17880f8b0b884376e90e20bd2"},
	370: {"size": Vector2i(24, 11), "sha256": "5fda19d608ef8d8f8e1be71aa9c97c5e18d2f7160bad794b9bfeafae4911b1a0"},
	371: {"size": Vector2i(24, 10), "sha256": "225519e11aae196c7112a757028fc80a0bdc5fa7e198c2bd936ad3d3d6d34a2b"},
	372: {"size": Vector2i(24, 12), "sha256": "1b6485b69a3e19092fa0e3d71b8b2bb32f1fea7e029c1b4ed38cd8e2cb43c153"},
	373: {"size": Vector2i(24, 14), "sha256": "ba8f648fd9be284b28b2252148a9b1add6d2c60432e94391aa76a20f989fbdc4"},
	869: {"size": Vector2i(48, 25), "sha256": "a86ac5bc83ed5e0984f1e506d25e2b4fe84ff16524445d510bfd34627e77cf7d"},
	870: {"size": Vector2i(48, 23), "sha256": "be9ec9d5d6ac5ffabfe955122700f804b592270f1dd8632cfbb572fbb3df5661"},
	871: {"size": Vector2i(48, 20), "sha256": "6a48b8f3ab1d4db29ce6b0bf78e4dc5aa6bcc70948d3aedf71e27a6f0072b248"},
	872: {"size": Vector2i(48, 23), "sha256": "a8926e6b15b6f2a517644fd8958fc2859227fb5d84280433ff0c7f23b1ccbc8c"},
	873: {"size": Vector2i(48, 27), "sha256": "295256c05ad1d10c9b959f5c1821d26d19a7d701e441f1b871b0c9668c739a7b"},
	1369: {"size": Vector2i(64, 49), "sha256": "282554ec7c99d187dff6326f5f17e06d69ed906047de6da1401b62d9343a6ebe"},
	1370: {"size": Vector2i(64, 41), "sha256": "75c8adc50746290dd3e1a6867315a10c4dbbf2f9fc16ad8926835a1dd1c026fe"},
	1371: {"size": Vector2i(64, 35), "sha256": "9004d068e789bc809c5e76af843408693b40cadbb45cf0940ec4c0140c4faeac"},
	1372: {"size": Vector2i(64, 42), "sha256": "aa290324819d9d20967631f246bfb3b01dffcf590701d9d010af1f652f784cfa"},
	1373: {"size": Vector2i(64, 54), "sha256": "2dbfbfcd0a8be7c6dfa300b80ce43618676125fcdf64efb0c2db88158341f6d7"},
	1380: {"size": Vector2i(32, 22), "sha256": "88baecefda7bfc697b29d5d9127ea09fd3b11f93abed3339fed9090b7190b2aa"},
	1381: {"size": Vector2i(32, 22), "sha256": "6477cfc5236131ab059d858f3472b9030371085ed2b94d1465daaa5e328e6925"},
}


static func clean(entry: Sc2SpriteArchive.SpriteEntry, image: Image, palette: Sc2Palette, enhanced_water: bool) -> Image:
	var source: Dictionary = SOURCES.get(entry.sprite_id, {})
	if not enhanced_water or source.is_empty() or image.get_size() != source.size:
		return image
	if palette == null or not palette.is_valid() or palette.is_index_encoding or CityBrightmaps.fingerprint(entry) != source.sha256:
		return image
	# The connected hull retains its blue containers and deck details. Outside
	# its column spans, the original art contains baked water, foam and markers.
	# Work once on a cached display copy; never rewrite imported/custom artwork.
	var columns := WaterReflectionSprite.hull_columns(image, palette)
	var result := image.duplicate()
	for y in image.get_height():
		for x in image.get_width():
			var pixel := image.get_pixel(x, y)
			if pixel.a == 0.0 or (y >= columns[x].x and y < columns[x].y):
				continue
			var color := palette.color(roundi(pixel.r * 255.0))
			# Preserve the pale wake as translucent neutral foam. Opaque blue
			# water and detached dark/colored specks must expose the live water.
			if color.r > 0.25 and color.g > 0.65 and color.g > color.b * 0.8:
				result.set_pixel(x, y, Color(154.0 / 255.0, 0.0, 0.0, 0.4))
			else:
				result.set_pixel(x, y, Color.TRANSPARENT)
	return result
