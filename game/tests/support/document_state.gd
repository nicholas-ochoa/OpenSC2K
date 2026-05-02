extends RefCounted
## Compare saved state without repeating RLE encoding after each small operation.


static func capture(document: Sc2File) -> Array:
	var values: Array = [document.map_size, document.large_version]
	for chunk in document.chunks:
		values.append([chunk.chunk_id, chunk.decoded_payload.duplicate()])
	return values
