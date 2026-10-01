class_name HelicopterShotCommand
extends RefCounted
## The Center tool easter egg. SIMCITY.EXE 0x00454650 runs before each Center
## click. A helicopter draws above its tile, so the click reads the tile four
## rows down the screen. A helicopter there starts its emergency descent. The
## helicopter tick then plays the air disaster sound and explodes.

# both coordinates plus 4 is four rows down the screen in every rotation,
# because a rotation rewrites the stored coordinates
const SCREEN_ROWS_BELOW := 4
const STATE_EMERGENCY_DESCENT := 5
const SOUND_HIT := 0x204
const RECORD_SIZE := Sc2ThingLayout.RECORD_SIZE


# the record of the helicopter that a Center click at `point` hits, or -1
static func apply(city: CityState, point: Vector2i) -> int:
	if city == null or not city.is_valid():
		return -1

	var index := city.index_of(point.x + SCREEN_ROWS_BELOW, point.y + SCREEN_ROWS_BELOW)

	if index < 0:
		return -1

	var thing_chunk := city.document.find_chunk("XTHG")
	var text_chunk := city.document.find_chunk("XTXT")

	if thing_chunk == null or text_chunk == null:
		return -1

	var overlay_id := OverlayData.read(text_chunk.decoded_payload, index)

	if not OverlayData.is_thing(overlay_id):
		return -1

	var things: PackedByteArray = thing_chunk.decoded_payload.duplicate()
	var record := OverlayData.thing_record(overlay_id)

	if record < 0 or record >= ThingData.count(things):
		return -1

	var offset := record * RECORD_SIZE

	if ThingData.read(things, offset + Sc2ThingLayout.Field.TYPE) != Sc2ThingLayout.Type.HELICOPTER:
		return -1

	ThingData.write(things, offset + Sc2ThingLayout.Field.STATE, STATE_EMERGENCY_DESCENT)

	if not thing_chunk.set_decoded_payload(things):
		return -1

	return record
