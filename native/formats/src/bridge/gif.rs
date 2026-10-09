//! Indexed GIF files.

use super::{bytes, failure, ints, success};
use godot::prelude::*;
use sc2k_formats::gif;

/// Indexed GIF files. See `gif.rs`.
#[derive(GodotClass)]
#[class(base=Object, no_init)]
pub struct NativeIndexedGif {}
#[godot_api]
impl NativeIndexedGif {
    /// `{ok, error, bytes}`: one frame. `palette` holds 256 RGB colors.
    #[func]
    fn encode(width: i64, height: i64, pixels: PackedInt32Array, palette: PackedByteArray) -> VarDictionary {
        if palette.len() != 768 {
            return failure("Invalid GIF dimensions, pixels, or palette.");
        }

        match gif::encode(width, height, pixels.as_slice(), palette.as_slice()) {
            Ok(file) => {
                let mut result = success();
                result.set("bytes", &bytes(&file));
                result
            }
            Err(error) => failure(&error),
        }
    }

    /// `{ok, error, bytes, frame_count}`. `mappings` holds the palette index map
    /// of the first tick and of each of the 120 cycle ticks.
    #[func]
    fn encode_cycle(width: i64, height: i64, pixels: PackedInt32Array, palette: PackedByteArray, mappings: VarArray) -> VarDictionary {
        let maps: Vec<Vec<i32>> = mappings
            .iter_shared()
            .map(|m| m.try_to::<PackedInt32Array>().map(|a| a.to_vec()).unwrap_or_default())
            .collect();
        if palette.len() != 768 || maps.iter().any(|m| m.len() != 256) {
            return failure("Invalid SCURK GIF dimensions, pixels, or palette.");
        }

        match gif::encode_cycle(width, height, pixels.as_slice(), palette.as_slice(), &maps) {
            Ok((file, frames)) => {
                let mut result = success();
                result.set("bytes", &bytes(&file));
                result.set("frame_count", frames as i64);
                result
            }
            Err(error) => failure(&error),
        }
    }

    /// `{ok, error, width, height, pixels, palette}`. `palette` holds 256 RGB colors.
    #[func]
    fn decode(data: PackedByteArray) -> VarDictionary {
        match gif::decode(data.as_slice()) {
            Ok(decoded) => {
                let mut result = success();
                result.set("width", decoded.width as i64);
                result.set("height", decoded.height as i64);
                result.set("pixels", &ints(&decoded.pixels));
                result.set("palette", &bytes(&decoded.palette));
                result
            }
            Err(error) => failure(&error),
        }
    }

    #[constant]
    const CYCLE_TICKS: i32 = gif::CYCLE_TICKS as i32;
}
