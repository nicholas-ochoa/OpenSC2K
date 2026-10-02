class_name CitySignatureCache
extends RefCounted
# main-thread cache records for unchanged render inputs. these records
# belong to one citystate and are never serialized into the city document


class MaskedFlags extends RefCounted:
	var revision := -1
	var size := -1
	var value := 0


class TextOverlays extends RefCounted:
	var key: Array[int] = []
	var value := 0
	# sign cells of the cached xtxt revision
	var signs := PackedInt32Array()
