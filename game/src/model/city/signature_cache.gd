class_name CitySignatureCache
extends RefCounted
# main-thread cache records for unchanged render-input pages. these records
# belong to one citystate and are never serialized into the city document


class MaskedFlags extends RefCounted:
	var pages: Array[PackedByteArray] = []
	var masked_pages: Array[PackedByteArray] = []
	var revision := -1
	var source := 0
	var size := -1
	var value := 0


class TextOverlays extends RefCounted:
	var key: Array[int] = []
	var value := 0
	var pages: Array[PackedByteArray] = []
	var high_pages: Array[PackedByteArray] = []
	var indices: Array[PackedInt32Array] = []
