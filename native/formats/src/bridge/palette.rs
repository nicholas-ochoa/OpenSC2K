//! The palette of the original graphics and its color cycles.

use godot::prelude::*;
use sc2k_assets::palette;

/// The palette of the original graphics and its color cycles.
#[derive(GodotClass)]
#[class(base=Object, no_init)]
pub struct NativePalette {}

#[godot_api]
impl NativePalette {
    /// `{ok, error, rgb}`: the colors of an 8-bit Windows BMP palette.
    #[func]
    fn bmp_colors(bytes: PackedByteArray) -> VarDictionary {
        match palette::bmp_colors(bytes.as_slice()) {
            Ok(colors) => {
                let mut result = super::success();
                result.set("rgb", &PackedByteArray::from(colors.concat().as_slice()));
                result
            }
            Err(error) => super::failure(&error),
        }
    }

    /// The entry that each palette entry shows after `base_ticks` of the game clock.
    #[func]
    fn index_map(base_ticks: i64) -> PackedInt32Array {
        PackedInt32Array::from(palette::index_map(base_ticks).as_slice())
    }

    /// The index map after `timer_ticks` of the SCURK palette clock.
    #[func]
    fn scurk_index_map(timer_ticks: i64) -> PackedInt32Array {
        PackedInt32Array::from(palette::scurk_index_map(timer_ticks).as_slice())
    }

    #[func]
    fn index_map_steps(fast_steps: i64, slow_steps: i64) -> PackedInt32Array {
        PackedInt32Array::from(palette::index_map_steps(fast_steps, slow_steps).as_slice())
    }
}
