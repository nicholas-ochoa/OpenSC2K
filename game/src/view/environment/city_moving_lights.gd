class_name CityMovingLights
extends RefCounted
## Small authored light sources for matching original moving artwork only.

const SOURCES := CityMovingLightSources.DATA
var masks: Dictionary[String, Image] = {}


func mask(archive: Sc2SpriteArchive, sprite_id: int) -> Image:
	# A graphics set's own authored brightmap always takes precedence.
	if archive.visual_emission.has(sprite_id):
		return archive.visual_emission[sprite_id]
	var record: Dictionary = SOURCES.get(str(sprite_id), {})
	if record.is_empty():
		record = CityMonsterLightSources.DATA.get(str(sprite_id), {})
	if record.is_empty():
		return null
	var key := "%d:%d:%d" % [archive.get_instance_id(), archive.visual_revision, sprite_id]
	if masks.has(key):
		return masks[key]
	var entry := archive.find_sprite(sprite_id)
	if entry == null or entry.width != int(record.width) or entry.height != int(record.height) \
			or CityBrightmaps.fingerprint(entry) != record.indices_sha256:
		return null
	var image := Image.create(entry.width, entry.height, false, Image.FORMAT_RGBA8)
	for light: Array in record.lights:
		image.set_pixel(int(light[0]), int(light[1]), Color(light[2]))
	masks[key] = image
	return image
