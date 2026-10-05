class_name Sc2ImportAudio
extends RefCounted
## Convert source sound payloads into portable PCM WAV without playback. The
## native formats library converts them; see native/core/assets/src/import/wave.rs.


static func mac_sound(data: PackedByteArray) -> AssetBytesResult:
	return AssetBytesResult.from_native(NativeAudioImport.mac_sound(data))


# Keep only the format and sample chunks of a RIFF WAVE file. Some Special Edition CD-ROM sounds
# have a sampler chunk after an odd-sized sample chunk without the RIFF pad byte.
static func riff_wave(data: PackedByteArray) -> AssetBytesResult:
	return AssetBytesResult.from_native(NativeAudioImport.riff_wave(data))


static func pcm_wave(samples: PackedByteArray, rate: int, channels: int, bits: int) -> AssetBytesResult:
	return AssetBytesResult.from_native(NativeAudioImport.pcm_wave(samples, rate, channels, bits))
