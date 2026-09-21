class_name OriginalTextResources
extends RefCounted
# Text resources from the active graphics source.

var original_query_strings: Dictionary[int, String] = OriginalUiStrings.VALUES.duplicate()
var building_objection_text := "Residents objected to this facility site."
var library_texts: Dictionary[int, String] = {}
var newspaper_data: DataUsaResource
