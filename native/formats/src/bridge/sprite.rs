//! SimCity 2000 sprite records.

use super::{failure, ints, rgba_image, success};
use godot::{classes::Image, prelude::*};
use sc2k_formats::sprite;

/// SimCity 2000 sprite records. See `sprite.rs`.
#[derive(GodotClass)]
#[class(base=Object, no_init)]
pub struct NativeSpriteCodec {}
#[godot_api]
impl NativeSpriteCodec {
    /// `{ok, error, pixels, rows}`. Transparent pixels are -1.
    #[func]
    fn decode(data: PackedByteArray, width: i64, height: i64, allow_unpadded_odd_runs: bool) -> VarDictionary {
        match sprite::decode(data.as_slice(), width as i32, height as i32, allow_unpadded_odd_runs) {
            Ok(decoded) => {
                let mut result = success();
                result.set("pixels", &ints(&decoded.pixels));
                result.set("rows", decoded.rows);
                result
            }
            Err(error) => failure(&error),
        }
    }

    /// `{ok, error, pixels, rows}` of a DOS sprite record between `start` and `end`.
    #[func]
    fn decode_dos(data: PackedByteArray, start: i64, end: i64, width: i64, height: i64) -> VarDictionary {
        if start < 0 || end < start || !(1..=4096).contains(&width) || !(1..=4096).contains(&height) {
            return failure("Invalid row marker or row count.");
        }

        match sprite::decode_dos(data.as_slice(), start as usize, end as usize, width as usize, height as usize) {
            Ok(decoded) => {
                let mut result = success();
                result.set("pixels", &ints(&decoded.pixels));
                result.set("rows", decoded.rows);
                result
            }
            Err(error) => failure(&error),
        }
    }

    /// True when every pixel is a palette index or -1.
    #[func]
    fn valid_indices(pixels: PackedInt32Array) -> bool {
        pixels.as_slice().iter().all(|p| (-1..=255).contains(p))
    }

    /// An RGBA8 image of palette indices. `palette` holds 256 RGBA colors.
    #[func]
    fn color_image(pixels: PackedInt32Array, width: i64, height: i64, palette: PackedByteArray) -> Option<Gd<Image>> {
        (pixels.len() as i64 == width * height).then(|| {
            rgba_image(
                width as usize,
                height as usize,
                &sprite::colorize(pixels.as_slice(), palette.as_slice()),
            )
        })?
    }

    /// An RGBA8 image whose opaque pixels store their index in each color byte.
    #[func]
    fn index_image(pixels: PackedInt32Array, width: i64, height: i64) -> Option<Gd<Image>> {
        (pixels.len() as i64 == width * height)
            .then(|| rgba_image(width as usize, height as usize, &sprite::index_image(pixels.as_slice())))?
    }
}
