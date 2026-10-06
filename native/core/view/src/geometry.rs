//! The geometry of the three graphics sizes. Source pixels are pixels of the
//! large view; the small and medium views divide them by 4 and 2.

pub const VIEW_SMALL: usize = 0;
pub const VIEW_MEDIUM: usize = 1;
pub const VIEW_LARGE: usize = 2;
pub const TILE_WIDTH: i32 = 32;
pub const TILE_HEIGHT: i32 = 17;
pub const HALF_WIDTH: i32 = 16;
pub const HALF_HEIGHT: i32 = 8;
pub const ALTITUDE_STEP: i32 = 12;
pub const TOP_MARGIN: i32 = 512;
pub const SIDE_MARGIN: i32 = 32;
const LARGE_WIDTH: i32 = 4160;
const LARGE_HEIGHT: i32 = 2944;
const ORIGINAL_EDGE: i32 = 128;

/// The pixels of a view for each source pixel: 4, 2, or 1.
pub fn divisor(view: usize) -> i32 {
    4 >> view
}

/// The size of the whole map in pixels of `view`.
pub fn view_size(view: usize, edge: i32) -> (i32, i32) {
    let d = divisor(view);

    (
        (LARGE_WIDTH + (edge - ORIGINAL_EDGE) * 32) / d,
        (LARGE_HEIGHT + (edge - ORIGINAL_EDGE) * 16) / d,
    )
}

/// The left corner of the flat diamond of tile (x, y) at `altitude`, in source pixels.
pub fn tile_left(edge: i32, x: i32, y: i32, altitude: i32) -> (i32, i32) {
    (
        SIDE_MARGIN + edge * HALF_WIDTH + (x - y) * HALF_WIDTH,
        TOP_MARGIN + (x + y) * HALF_HEIGHT - altitude * ALTITUDE_STEP,
    )
}

/// The source point at the center of tile (x, y) on flat ground at `altitude`.
pub fn tile_center(edge: i32, x: i32, y: i32, altitude: i32) -> (f64, f64) {
    let (left, top) = tile_left(edge, x, y, altitude);

    (
        f64::from(left + HALF_WIDTH),
        f64::from(top) + f64::from(TILE_HEIGHT - 1) / 2.0,
    )
}
