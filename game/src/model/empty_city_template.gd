class_name EmptyCityTemplate
extends RefCounted
## The empty city that New City starts from. The native simulation library
## makes it; see native/core/sim/src/sim/new_city/template.rs.

const NEUTRAL_GROWTH := 0x7f


static func create(map_edge: int = 128) -> Sc2File:
	var document := Sc2File.new()
	document.apply_native(NativeCityDocument.empty_city(map_edge))

	return document


# FUN_0040e250 fills the rate of growth map with the neutral value
static func fill_neutral_growth(document: Sc2File) -> void:
	var growth := document.find_chunk("XROG")
	var neutral_growth := PackedByteArray()
	neutral_growth.resize(growth.expected_decoded_size)
	neutral_growth.fill(NEUTRAL_GROWTH)
	growth.set_decoded_payload(neutral_growth, true)
