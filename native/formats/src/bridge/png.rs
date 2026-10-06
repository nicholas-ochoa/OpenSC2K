//! Indexed PNG files.

use super::{bytes, failure, ints, success};
use godot::prelude::*;
use sc2k_formats::png;

/// Indexed PNG files. See `png.rs`.
#[derive(GodotClass)]
#[class(base=Object, no_init)]
pub struct NativeIndexedPng {}
#[godot_api]
impl NativeIndexedPng {
    /// `{ok, error, bytes}`. `palette` holds 256 RGB colors; -1 pixels are transparent.
    #[func]
    fn encode(width: i64, height: i64, pixels: PackedInt32Array, palette: PackedByteArray) -> VarDictionary {
        match png::encode_indexed(width, height, pixels.as_slice(), palette.as_slice()) {
            Ok(file) => {
                let mut result = success();
                result.set("bytes", &bytes(&file));
                result
            }
            Err(error) => failure(&error),
        }
    }

    /// `{ok, error, width, height, pixels, palette}`. `palette` holds 256 RGB colors.
    #[func]
    fn decode(data: PackedByteArray, strict_palette: bool) -> VarDictionary {
        match png::decode_indexed(data.as_slice(), strict_palette) {
            Ok(decoded) => {
                let mut result = success();
                result.set("width", decoded.width);
                result.set("height", decoded.height);
                result.set("pixels", &ints(&decoded.pixels));
                result.set("palette", &bytes(&decoded.palette));
                result
            }
            Err(error) => failure(&error),
        }
    }
}
