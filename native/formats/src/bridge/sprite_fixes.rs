//! The sprite corrections of sc2kfix for GDScript.

use godot::prelude::*;
use sc2k_assets::sprite_fixes::{self, Fix};

/// The sprite corrections of sc2kfix.
#[derive(GodotClass)]
#[class(base=Object, no_init)]
pub struct NativeSpriteFixes {}

#[godot_api]
impl NativeSpriteFixes {
    /// The corrected pixels, or an empty array when the pixels are not the original sprite.
    #[func]
    fn corrected(pixels: PackedInt32Array, width: i64, height: i64, crc32: i64, shift_x: i64, edits: PackedInt64Array) -> PackedInt32Array {
        let fix = Fix {
            width: width.max(0) as usize,
            height: height.max(0) as usize,
            crc32: crc32 as u32,
            shift_x,
            edits: edits.as_slice(),
        };

        sprite_fixes::corrected(pixels.as_slice(), fix.width, fix.height, &fix)
            .map_or(PackedInt32Array::new(), |result| PackedInt32Array::from(result.as_slice()))
    }
}
