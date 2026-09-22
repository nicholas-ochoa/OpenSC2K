class_name OrderedChunkCommit
extends RefCounted
## Apply caller-selected chunks in order and refresh their city mirrors.
## Rollback requires valid snapshots. It writes in apply order, so revisions
## advance and dirty flags remain set even when the original bytes are restored.


static func apply(
	city: CityState, chunk_ids: PackedStringArray, payloads: Dictionary, rollback: Dictionary
) -> bool:
	var applied := PackedStringArray()

	for chunk_id in chunk_ids:
		var chunk := city.document.find_chunk(chunk_id)

		if chunk == null or not payloads.has(chunk_id) or not chunk.set_decoded_payload(payloads[chunk_id]):
			for rollback_id in applied:
				city.document.find_chunk(rollback_id).set_decoded_payload(rollback[rollback_id])

			city.resync_mirrors(applied)

			return false

		applied.append(chunk_id)

	city.resync_mirrors(chunk_ids)

	return true
