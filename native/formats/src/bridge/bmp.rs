//! 8-bit indexed BMP files and DIBs.

use super::{bytes, failure, ints, success};
use godot::prelude::*;
use sc2k_formats::bmp;

/// 8-bit indexed BMP files and DIBs. See `bmp.rs`.
#[derive(GodotClass)]
#[class(base=Object, no_init)]
pub struct NativeIndexedBmp {}
#[godot_api]
impl NativeIndexedBmp {
    /// `{ok, error, width, height, pixels, palette, top_down}`. `palette` holds 256 RGB colors.
    #[func]
    fn decode(data: PackedByteArray) -> VarDictionary {
        match bmp::decode(data.as_slice()) {
            Ok(decoded) => Self::decoded_result(&decoded),
            Err(error) => failure(&error),
        }
    }

    /// `{ok, error, width, height, pixels, palette, top_down}` of any 1-, 4- or
    /// 8-bit indexed DIB, uncompressed or RLE8, with or without its file header.
    #[func]
    fn decode_indexed(data: PackedByteArray, file_header: bool) -> VarDictionary {
        match bmp::decode_indexed(data.as_slice(), file_header) {
            Ok(decoded) => Self::decoded_result(&decoded),
            Err(error) => failure(&error),
        }
    }

    /// `{ok, error, bytes}`. `palette` holds 256 RGB colors.
    #[func]
    fn encode(width: i64, height: i64, pixels: PackedInt32Array, palette: PackedByteArray, transparent_index: i64) -> VarDictionary {
        Self::bytes_result(bmp::encode(width, height, pixels.as_slice(), palette.as_slice(), transparent_index))
    }

    /// `{pixels, remapped_color_count}`. Both palettes hold 256 RGB colors.
    #[func]
    fn map_to_palette(pixels: PackedInt32Array, source: PackedByteArray, target: PackedByteArray, transparent_index: i64) -> VarDictionary {
        let mut result = success();

        if source.len() != 768 || target.len() != 768 {
            return failure("BMP palette does not contain 256 colors.");
        }

        let (mapped, remapped) = bmp::map_to_palette(pixels.as_slice(), source.as_slice(), target.as_slice(), transparent_index as usize);
        result.set("pixels", &ints(&mapped));
        result.set("remapped_color_count", remapped as i64);
        result
    }

    /// `{pixels, remapped_color_count}` for imported images: -1 pixels stay and
    /// only the colors in use count.
    #[func]
    fn map_used_colors(pixels: PackedInt32Array, source: PackedByteArray, target: PackedByteArray) -> VarDictionary {
        if source.len() != 768 || target.len() != 768 {
            return failure("The city palette is not available.");
        }

        let (mapped, remapped) = bmp::map_used_colors(pixels.as_slice(), source.as_slice(), target.as_slice());
        let mut result = success();
        result.set("pixels", &ints(&mapped));
        result.set("remapped_color_count", remapped as i64);
        result
    }

    /// `{ok, error, bytes}`: the file without its file header.
    #[func]
    fn to_dib(data: PackedByteArray) -> VarDictionary {
        Self::bytes_result(bmp::to_dib(data.as_slice()))
    }

    /// `{ok, error, bytes}`: a file around the DIB.
    #[func]
    fn from_dib(data: PackedByteArray) -> VarDictionary {
        Self::bytes_result(bmp::from_dib(data.as_slice()))
    }
}

impl NativeIndexedBmp {
    fn decoded_result(decoded: &bmp::Decoded) -> VarDictionary {
        let mut result = success();
        result.set("width", decoded.width as i64);
        result.set("height", decoded.height as i64);
        result.set("pixels", &ints(&decoded.pixels));
        result.set("palette", &bytes(&decoded.palette));
        result.set("top_down", decoded.top_down);
        result
    }

    fn bytes_result(value: Result<Vec<u8>, String>) -> VarDictionary {
        match value {
            Ok(data) => {
                let mut result = success();
                result.set("bytes", &bytes(&data));
                result
            }
            Err(error) => failure(&error),
        }
    }
}
