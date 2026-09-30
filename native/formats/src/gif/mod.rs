//! GIF89a export and indexed GIF import. The cycle export has full frames with
//! local palettes and a repeating SCURK palette cycle.

mod decode;
mod encode;

#[cfg(test)]
mod tests;

pub use decode::*;
pub use encode::*;

pub const MAX_DIMENSION: i64 = 4096;
const MAX_CODES: usize = 4096;

/// Ticks of one SCURK cycle: the least common multiple of the 40-tick fast and
/// 60-tick slow cycles.
pub const CYCLE_TICKS: usize = 120;
// Block introducers and extension labels.
const EXTENSION: u8 = 0x21;
const IMAGE: u8 = 0x2c;
const TRAILER: u8 = 0x3b;
const GRAPHIC_CONTROL: u8 = 0xf9;
const APPLICATION: u8 = 0xff;

/// Screen and image flags: a 256-color table follows.
const COLOR_TABLE: u8 = 0x80;

/// The size field of a 256-color table.
const TABLE_SIZE_256: u8 = 7;

/// Screen flags: a global 256-color table of 8-bit colors.
const GLOBAL_TABLE_256: u8 = COLOR_TABLE | 0x70 | TABLE_SIZE_256;

/// Image flags: a local 256-color table.
const LOCAL_TABLE_256: u8 = COLOR_TABLE | TABLE_SIZE_256;
const INTERLACED: u8 = 0x40;

/// Graphic control flags: keep the frame, and use the transparent index.
const DISPOSE_KEEP: u8 = 8;
const HAS_TRANSPARENT: u8 = 1;

/// The initial LZW code size of 8-bit pixels.
const CODE_SIZE: u8 = 8;
const CLEAR: u32 = 256;
const END: u32 = 257;
// First rows and row steps of the four interlace passes.
const INTERLACE_PASSES: [(usize, usize); 4] = [(0, 8), (4, 8), (2, 4), (1, 2)];
