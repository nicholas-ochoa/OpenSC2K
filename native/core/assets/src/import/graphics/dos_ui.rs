//! The DOS toolbar. TOOL.RAW is a 72 by 312 indexed image, with its height
//! before its width. Its button interiors go to the places of the Windows
//! toolbar strip. MINE.PAL supplies its colors.

use super::UiImage;

const TOOLBAR_WIDTH: usize = 72;
const TOOLBAR_HEIGHT: usize = 312;
pub const HEADER_SIZE: usize = 4;
const PALETTE_SIZE: usize = 768;
pub const STRIP_WIDTH: usize = 531;
pub const STRIP_HEIGHT: usize = 23;
const BUTTON_BACKGROUND: i32 = 145;

/// A rectangle: x, y, width, height.
type Rect = (usize, usize, usize, usize);

/// The 15 tool group buttons: a 3 by 5 grid of 24 by 24 cells, with a 19 by
/// 19 icon 3 pixels inside each cell.
const GROUP_COLUMNS: usize = 3;
const GROUP_CELL: usize = 24;
const GROUP_ICON: usize = 19;
const GROUP_ICON_OFFSET: usize = 3;
#[rustfmt::skip]
const GROUP_TARGETS: [Rect; 15] = [
    (0, 0, 23, 23), (24, 0, 26, 23), (50, 0, 20, 23),
    (70, 0, 25, 23), (95, 0, 21, 23), (116, 0, 24, 23),
    (140, 0, 23, 23), (163, 0, 23, 23), (186, 0, 23, 23),
    (209, 0, 23, 23), (232, 0, 23, 23), (255, 0, 23, 23),
    (278, 0, 23, 23), (302, 0, 23, 23), (325, 0, 23, 23),
];
/// The source in TOOL.RAW, and the target in the strip.
#[rustfmt::skip]
const SPECIAL_REGIONS: [(Rect, Rect); 7] = [
    ((8, 127, 25, 18), (348, 0, 29, 23)), // Sign
    ((38, 127, 25, 18), (377, 0, 26, 23)), // Query
    ((8, 154, 25, 17), (405, 0, 27, 23)), // Rotate left
    ((38, 154, 25, 17), (433, 0, 27, 23)), // Rotate right
    ((4, 176, 19, 19), (462, 0, 23, 23)), // Zoom out
    ((27, 176, 19, 19), (486, 0, 23, 23)), // Zoom in
    ((50, 176, 19, 19), (510, 0, 21, 23)), // Center
];

/// The toolbar strip of TOOL.RAW, with the colors of MINE.PAL.
pub fn toolbar(raw: &[u8], palette: &[u8]) -> Result<UiImage, String> {
    if raw.len() != HEADER_SIZE + TOOLBAR_WIDTH * TOOLBAR_HEIGHT {
        return Err("DOS TOOL.RAW has an invalid pixel length.".into());
    }

    let height = usize::from(u16::from_le_bytes([raw[0], raw[1]]));
    let width = usize::from(u16::from_le_bytes([raw[2], raw[3]]));

    if height != TOOLBAR_HEIGHT || width != TOOLBAR_WIDTH {
        return Err("DOS TOOL.RAW must contain a 72 by 312 toolbar.".into());
    }

    if palette.len() != PALETTE_SIZE {
        return Err("DOS toolbar needs the 256-color MINE.PAL.".into());
    }

    let mut pixels = vec![BUTTON_BACKGROUND; STRIP_WIDTH * STRIP_HEIGHT];

    for (group, target) in GROUP_TARGETS.iter().enumerate() {
        let x = group % GROUP_COLUMNS * GROUP_CELL + GROUP_ICON_OFFSET;
        let y = group / GROUP_COLUMNS * GROUP_CELL + GROUP_ICON_OFFSET;
        copy_icon(raw, (x, y, GROUP_ICON, GROUP_ICON), *target, &mut pixels);
    }

    for (source, target) in SPECIAL_REGIONS {
        copy_icon(raw, source, target, &mut pixels);
    }

    Ok(UiImage {
        width: STRIP_WIDTH as i64,
        height: STRIP_HEIGHT as i64,
        pixels,
        palette: palette.to_vec(),
    })
}

/// Copy `source` to the center of `target`.
fn copy_icon(raw: &[u8], source: Rect, target: Rect, pixels: &mut [i32]) {
    let left = target.0 + (target.2 - source.2) / 2;
    let top = target.1 + (target.3 - source.3) / 2;

    for y in 0..source.3 {
        for x in 0..source.2 {
            let from = HEADER_SIZE + (source.1 + y) * TOOLBAR_WIDTH + source.0 + x;
            pixels[(top + y) * STRIP_WIDTH + left + x] = i32::from(raw[from]);
        }
    }
}
