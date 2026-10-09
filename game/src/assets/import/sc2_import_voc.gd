class_name Sc2ImportVoc
extends RefCounted
## Decode Creative Voice PCM blocks. Retain sample loops in the WAV smpl chunk.
## The native formats library converts it; see native/core/assets/src/import/voc.rs.


static func convert(data: PackedByteArray) -> AssetBytesResult:
	return AssetBytesResult.from_native(NativeAudioImport.voc_to_wave(data))
