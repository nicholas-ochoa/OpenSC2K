class_name CityDynamicCommandCache
extends RefCounted
# cache painter commands independently of static-region publication
var signature: Array = []
var commands: Array[Dictionary] = []
var rebuilds := 0

func get_commands(city: CityState, sprites: Sc2SpriteArchive, view: int, phase: int) -> Array[Dictionary]:
	if city == null or sprites == null:
		return []
	var things := city.document.find_chunk("XTHG")
	var next := [city.get_instance_id(), sprites.get_instance_id(), view, phase,
		city.visible_altitude_levels, city.compass_rotation(), hash(city.altitude_words),
		hash(city.terrain), hash(city.buildings), hash(city.zones), hash(city.text_overlays),
		hash(city.tile_flags), hash(things.decoded_payload) if things != null else 0]
	if next != signature:
		signature = next
		commands = CityIsometricRenderer.dynamic_draw_commands(city, sprites, view, phase)
		rebuilds += 1
	return commands
