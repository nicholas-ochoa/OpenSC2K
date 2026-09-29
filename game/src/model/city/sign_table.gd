class_name CitySignTable
extends RefCounted
## Signs of an SC2X version 4 working document. XSGN holds each sign with its
## own ID, tile, and text, independent of facilities, objects, and markers.
## Original and SCLG cities keep signs in XTXT and XLAB instead.

const CHUNK_ID := "XSGN"


static func uses_table(city: CityState) -> bool:
	return city != null and city.document != null and city.document.is_sc2x()


# {ok, error, capacity, ids, xs, ys, texts, extension} for every slot
static func decode(city: CityState) -> Dictionary:
	var chunk := city.document.find_chunk(CHUNK_ID)

	if chunk == null:
		return {"ok": false, "error": "XSGN data is missing"}

	return NativeSc2x.decode_signs(chunk.decoded_payload, city.map_size)


# tile index -> sign text, for every active sign
static func texts_by_tile(city: CityState) -> Dictionary[int, String]:
	var result: Dictionary[int, String] = {}

	if not uses_table(city):
		return result

	var table := decode(city)

	if not table.ok:
		return result

	for slot in table.ids.size():
		if int(table.ids[slot]) != 0:
			result[int(table.xs[slot]) * city.map_size + int(table.ys[slot])] = table.texts[slot]

	return result


static func text_at(city: CityState, point: Vector2i) -> String:
	var index := city.index_of(point.x, point.y)

	return texts_by_tile(city).get(index, "") if index >= 0 else ""


# The sign budget of new signs: the map profile. An imported table can hold more.
static func budget(city: CityState) -> int:
	var profile := Sc2xDocument.profile(city.map_size)

	return int(profile.get("signs", 0))


# The XSGN payload after `point` gets `text`. Empty text removes the sign. A new
# sign takes the next persistent ID and the first empty slot.
static func with_text(city: CityState, point: Vector2i, text: String) -> Dictionary:
	var table := decode(city)

	if not table.ok:
		return {"ok": false, "error": table.error}

	var error := str(NativeSc2x.name_error(text))

	if not error.is_empty():
		return {"ok": false, "error": error}

	var ids: PackedInt64Array = table.ids
	var xs: PackedInt32Array = table.xs
	var ys: PackedInt32Array = table.ys
	var texts: PackedStringArray = table.texts
	var found := -1
	var free := -1
	var active := 0

	for slot in ids.size():
		if ids[slot] == 0:
			free = slot if free < 0 else free
			continue

		active += 1

		if xs[slot] == point.x and ys[slot] == point.y:
			found = slot

	var metadata := city.document.sc2x_metadata
	var sign_id := 0

	if text.is_empty():
		if found < 0:
			return {"ok": false, "error": "this tile does not have a sign"}

		ids[found] = 0
		xs[found] = 0
		ys[found] = 0
		texts[found] = ""
	elif found >= 0:
		texts[found] = text
		sign_id = ids[found]
	else:
		if free < 0 or active >= budget(city):
			return {"ok": false, "error": "all sign slots are in use"}

		sign_id = metadata.next_sign_id
		ids[free] = sign_id
		xs[free] = point.x
		ys[free] = point.y
		texts[free] = text

	var encoded: Dictionary = NativeSc2x.encode_signs({
		"ids": ids, "xs": xs, "ys": ys, "texts": texts, "extension": table.extension,
	}, city.map_size)

	if not encoded.ok:
		return {"ok": false, "error": encoded.error}

	return {"ok": true, "error": "", "payload": encoded.data, "sign_id": sign_id}


# The XSGN payload with every sign turned with the map. IDs and text stay.
static func rotated(city: CityState, counter_clockwise: bool) -> Dictionary:
	var table := decode(city)

	if not table.ok:
		return {"ok": false, "error": table.error}

	var xs: PackedInt32Array = table.xs
	var ys: PackedInt32Array = table.ys

	for slot in table.ids.size():
		if int(table.ids[slot]) == 0:
			continue

		var point := Vector2i(xs[slot], ys[slot])
		var last := city.map_size - 1
		xs[slot] = point.y if counter_clockwise else last - point.y
		ys[slot] = last - point.x if counter_clockwise else point.x

	return NativeSc2x.encode_signs({
		"ids": table.ids, "xs": xs, "ys": ys, "texts": table.texts, "extension": table.extension,
	}, city.map_size)
