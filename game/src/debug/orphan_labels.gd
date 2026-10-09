class_name OrphanLabels
extends RefCounted
## Sign labels that no tile shows, as the sc2kfix orphaned label check finds
## them. The original game removes the XTXT entry of a cancelled sign but not
## its XLAB text. An SC2X version 4 city keeps signs in XSGN and has none.


# The IDs of the non-empty sign labels that no XTXT tile uses, or null for a
# city whose overlay layout holds signs elsewhere.
static func find(city: CityState) -> Variant:
	var overlays := city.document.find_chunk("XTXT")
	var labels := city.document.find_chunk("XLAB")

	if overlays == null or labels == null or OverlayData.is_layered(overlays.decoded_payload):
		return null

	var result := PackedInt32Array()

	for id in OverlayData.sign_ids(labels.decoded_payload.size()):
		if Sc2LabelLayout.read(labels.decoded_payload, id).is_empty():
			continue

		if OverlayData.find(overlays.decoded_payload, id) < 0:
			result.append(id)

	return result


static func describe(city: CityState, ids: PackedInt32Array) -> String:
	if ids.is_empty():
		return "No orphaned labels found."

	var labels := city.document.find_chunk("XLAB").decoded_payload
	var names := PackedStringArray()

	for id in ids:
		names.append("%d '%s'" % [id, Sc2LabelLayout.read(labels, id)])

	return "%d orphaned labels: %s." % [ids.size(), ", ".join(names)]
