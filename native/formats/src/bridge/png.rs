//! Indexed PNG files.

use super::super::png;
use super::{bytes, failure, ints, success};
use godot::{
    classes::{Image, file_access::CompressionMode, image::Format},
    prelude::*,
};

/// Indexed PNG files. See `png.rs`.
#[derive(GodotClass)]
#[class(base=Object, no_init)]
pub struct NativeIndexedPng {}
#[godot_api]
impl NativeIndexedPng {
    /// `{ok, error, bytes}`. `palette` holds 256 RGB colors; -1 pixels are transparent.
    #[func]
    fn encode(width: i64, height: i64, pixels: PackedInt32Array, palette: PackedByteArray) -> VarDictionary {
        let lines = match png::scanlines(width, height, pixels.as_slice()) {
            Ok(lines) => lines,
            Err(error) => return failure(&error),
        };

        if palette.len() != 768 {
            return failure("Invalid PNG pixels or palette");
        }

        let Ok(idat) = bytes(&lines.raw).compress(CompressionMode::DEFLATE) else {
            return failure("Cannot compress PNG pixel data");
        };

        let mut result = success();
        let file = png::assemble(width as u32, height as u32, palette.as_slice(), lines.transparent, idat.as_slice());
        result.set("bytes", &bytes(&file));
        result
    }

    /// `{ok, error, width, height, pixels, palette}`. `palette` holds 256 RGB colors.
    #[func]
    fn decode(data: PackedByteArray, strict_palette: bool) -> VarDictionary {
        let rewritten = match png::rewrite(data.as_slice(), strict_palette) {
            Ok(rewritten) => rewritten,
            Err(error) => return failure(&error),
        };

        let mut image = Image::new_gd();

        if image.load_png_from_buffer(&bytes(&rewritten.bytes)) != godot::global::Error::OK {
            return failure("Cannot decode PNG pixel data");
        }

        image.convert(Format::RGBA8);

        // Each RGBA8 pixel of the index palette reads as its little-endian index.
        let pixels: Vec<i32> = image
            .get_data()
            .as_slice()
            .chunks_exact(4)
            .map(|p| i32::from_le_bytes([p[0], p[1], p[2], p[3]]))
            .collect();
        let mut result = success();
        result.set("width", rewritten.width);
        result.set("height", rewritten.height);
        result.set("pixels", &ints(&pixels));
        result.set("palette", &bytes(&rewritten.palette));
        result
    }
}
