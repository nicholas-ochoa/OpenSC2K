//! The city view without engine types. `art` makes the indexed sprite images
//! of a graphics pack, `snapshot` copies the city maps for the painter,
//! `camera` maps screen points to source pixels, `regions` caches painted
//! regions as palette indices, and `present` draws them through the cycling
//! palette into a frame of 32-bit pixels. `picking` finds the tile under a point.

pub mod art;
pub mod camera;
pub mod geometry;
pub mod picking;
pub mod present;
pub mod regions;
pub mod snapshot;

/// A frame of 0x00RRGGBB pixels, as a window surface takes them.
pub struct Frame<'a> {
    pub width: usize,
    pub height: usize,
    pub pixels: &'a mut [u32],
}

/// An RGB color as a frame pixel.
pub fn pixel(rgb: [u8; 3]) -> u32 {
    (u32::from(rgb[0]) << 16) | (u32::from(rgb[1]) << 8) | u32::from(rgb[2])
}
