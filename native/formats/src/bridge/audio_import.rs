//! The sound and music converters of the game importer.

use godot::prelude::*;
use sc2k_assets::import::{voc, wave, xmi};

/// `{ok, error, bytes}` of a conversion.
fn converted(result: Result<Vec<u8>, String>) -> VarDictionary {
    match result {
        Ok(bytes) => {
            let mut value = super::success();
            value.set("bytes", &PackedByteArray::from(bytes.as_slice()));
            value
        }
        Err(error) => super::failure(&error),
    }
}

/// The sound and music converters of the game importer.
#[derive(GodotClass)]
#[class(base=Object, no_init)]
pub struct NativeAudioImport {}

#[godot_api]
impl NativeAudioImport {
    /// One XMIDI sequence as a Standard MIDI File.
    #[func]
    fn xmi_to_midi(data: PackedByteArray) -> VarDictionary {
        converted(xmi::convert(data.as_slice()))
    }

    /// A Creative Voice file as a WAVE file.
    #[func]
    fn voc_to_wave(data: PackedByteArray) -> VarDictionary {
        converted(voc::convert(data.as_slice()))
    }

    /// The sample buffer of a Macintosh sound resource as a WAVE file.
    #[func]
    fn mac_sound(data: PackedByteArray) -> VarDictionary {
        converted(wave::mac_sound(data.as_slice()))
    }

    /// The format and sample chunks of a RIFF WAVE file.
    #[func]
    fn riff_wave(data: PackedByteArray) -> VarDictionary {
        converted(wave::riff_wave(data.as_slice()))
    }

    /// A PCM WAVE file of `samples`.
    #[func]
    fn pcm_wave(samples: PackedByteArray, rate: i64, channels: i64, bits: i64) -> VarDictionary {
        converted(wave::pcm_wave(samples.as_slice(), rate, channels, bits))
    }
}
