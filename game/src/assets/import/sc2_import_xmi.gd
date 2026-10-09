class_name Sc2ImportXmi
extends RefCounted
## Convert a single XMIDI sequence to SMF with explicit note-off events. The
## native formats library converts it; see native/core/assets/src/import/xmi.rs.


static func convert(data: PackedByteArray) -> AssetBytesResult:
	return AssetBytesResult.from_native(NativeAudioImport.xmi_to_midi(data))
