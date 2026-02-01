class_name CityDynamicCommandCache
extends RefCounted
# cache painter commands independently of static-region publication
var signature: Array = []
var commands: Array[Dictionary] = []
var rebuilds := 0
var _phase := -1
var _phase_animated := false

func get_commands(city: CityState, sprites: Sc2SpriteArchive, view: int, phase: int) -> Array[Dictionary]:
	if city == null or city.document == null or not city.is_valid() or sprites == null or not sprites.is_valid():
		return []
	var things := city.document.find_chunk("XTHG")
	var next := [city.get_instance_id(), sprites.get_instance_id(), view,
		city.visible_altitude_levels, city.compass_rotation(), hash(city.altitude_words),
		hash(city.terrain), hash(city.buildings), hash(city.zones), hash(city.text_overlays),
		hash(city.tile_flags), hash(things.decoded_payload) if things != null else 0]
	if next != signature or (_phase_animated and phase != _phase):
		var changed := next != signature
		signature = next
		commands = CityIsometricRenderer.dynamic_draw_commands(city, sprites, view, phase)
		_phase = phase
		if changed:
			_phase_animated = commands.any(func(command: Dictionary) -> bool: return command.has("overlay"))
			if not _phase_animated and things != null:
				# type 6 uses the display clock to mirror its sprite. other moving
				# sprites derive their frames from the saved moving-object state
				for record in city.thing_count():
					var offset := record * CityState.THING_RECORD_SIZE
					if offset < things.decoded_payload.size() and things.decoded_payload[offset] == 6:
						_phase_animated = true
						break
		rebuilds += 1
	return commands
