//! SimCity 2000 sprite records: row blocks of skip and pixel runs.

// Outer block modes and row commands of SimCity 2000 sprites.
const BLOCK_SKIP: u8 = 0;
const BLOCK_ROW: u8 = 1;
const BLOCK_END: u8 = 2;
const ROW_NOTHING: u8 = 0;
const ROW_END: u8 = 2;
const ROW_SKIP: u8 = 3;
const ROW_PIXELS: u8 = 4;

/// Decoded palette indices, -1 where a pixel is transparent, and the row count.
#[derive(Debug, PartialEq, Eq)]
pub struct Decoded {
    pub pixels: Vec<i32>,
    pub rows: i32,
}

/// Decodes one sprite of `width` by `height` pixels. Errors name the fault
/// without the sprite ID; the caller adds it.
pub fn decode(data: &[u8], width: i32, height: i32, allow_unpadded_odd_runs: bool) -> Result<Decoded, String> {
    let (w, h) = (width.max(0) as usize, height.max(0) as usize);
    let mut pixels = vec![-1; w * h];
    let mut position = 0;
    let mut row = 0;
    let mut found_end = false;
    while position < data.len() {
        if position + 2 > data.len() {
            return Err("truncated block header".into());
        }
        let block_length = usize::from(data[position]);
        // two layers of commands: outer blocks and then row runs
        let block_mode = data[position + 1];
        position += 2;
        if block_mode == BLOCK_END {
            found_end = true;
            break;
        }
        if position + block_length > data.len() {
            return Err("block extends past sprite data".into());
        }
        if block_mode == BLOCK_SKIP {
            position += block_length;
            continue;
        }
        if block_mode != BLOCK_ROW {
            return Err(format!("unsupported outer block mode {block_mode}"));
        }
        if row >= h {
            return Err("sprite has more rows than its header".into());
        }
        let row_end = position + block_length;
        let mut x = 0;
        while position < row_end {
            if position + 2 > row_end {
                return Err("truncated row command".into());
            }
            let count = usize::from(data[position]);
            let mode = data[position + 1];
            position += 2;
            match mode {
                ROW_NOTHING | ROW_END => {}
                ROW_SKIP => {
                    x += count;
                    if x > w {
                        return Err("row skip extends past sprite width".into());
                    }
                }
                ROW_PIXELS => {
                    if position + count > row_end {
                        return Err("pixel run extends past row block".into());
                    }
                    if x + count > w {
                        return Err("pixel run extends past sprite width".into());
                    }
                    for (target, source) in pixels[row * w + x..row * w + x + count]
                        .iter_mut()
                        .zip(&data[position..position + count])
                    {
                        *target = i32::from(*source);
                    }
                    x += count;
                    position += count;
                    if count % 2 == 1 {
                        if position < row_end {
                            position += 1;
                        } else if !allow_unpadded_odd_runs {
                            return Err("odd pixel run has no padding byte".into());
                        }
                    }
                }
                _ => return Err(format!("unsupported row mode {mode}")),
            }
        }
        row += 1;
    }
    if !found_end {
        return Err("sprite has no end block".into());
    }
    Ok(Decoded { pixels, rows: row as i32 })
}

// DOS sprite row markers and commands.
const DOS_ROW: u8 = 0x10;
const DOS_SKIP: u8 = 0x04;
const DOS_PIXELS: u8 = 0x0c;

/// A DOS sprite record between `start` and `end`: rows that start with 0x10
/// and a length, then skip (0x04) and pixel (0x0c) commands, and a 0 end marker.
pub fn decode_dos(data: &[u8], start: usize, end: usize, width: usize, height: usize) -> Result<Decoded, String> {
    let mut pixels = vec![-1; width * height];
    let (mut cursor, mut row) = (start, 0);
    let mut terminated = false;
    let end = end.min(data.len());
    while cursor < end {
        let marker = data[cursor];
        cursor += 1;
        if marker == 0 {
            terminated = true;
            break;
        }
        if marker != DOS_ROW || cursor >= end || row >= height {
            return Err("Invalid row marker or row count.".into());
        }
        let length = usize::from(data[cursor]);
        let row_end = cursor + length;
        cursor += 1;
        if length == 0 || row_end > end {
            return Err("Row exceeds the sprite data.".into());
        }
        let mut column = 0;
        while cursor < row_end {
            if row_end - cursor < 2 {
                return Err("Truncated row command.".into());
            }
            let (operation, count) = (data[cursor], usize::from(data[cursor + 1]));
            cursor += 2;
            if column + count > width {
                return Err("Row command exceeds the sprite width.".into());
            }
            if operation == DOS_PIXELS {
                if count > row_end - cursor {
                    return Err("Pixel run exceeds the row data.".into());
                }
                let at = row * width + column;
                for (target, source) in pixels[at..at + count].iter_mut().zip(&data[cursor..cursor + count]) {
                    *target = i32::from(*source);
                }
                cursor += count;
            } else if operation != DOS_SKIP {
                return Err(format!("Unsupported row command 0x{operation:02x}."));
            }
            column += count;
        }
        row += 1;
    }
    if !terminated {
        return Err("Sprite has no end marker.".into());
    }
    Ok(Decoded { pixels, rows: row as i32 })
}

/// Godot's transparent color: white with zero alpha.
const TRANSPARENT: [u8; 4] = [255, 255, 255, 0];

/// RGBA8 pixels of palette indices. `palette` holds 256 RGBA colors; -1 and
/// indices without a color are transparent.
pub fn colorize(pixels: &[i32], palette: &[u8]) -> Vec<u8> {
    let mut out = Vec::with_capacity(pixels.len() * 4);
    for &index in pixels {
        let at = usize::try_from(index).map(|i| i * 4).ok();
        match at.and_then(|at| palette.get(at..at + 4)) {
            Some(color) => out.extend_from_slice(color),
            None => out.extend_from_slice(&TRANSPARENT),
        }
    }
    out
}

/// RGBA8 pixels where each opaque pixel stores its index in the red, green and
/// blue bytes. The renderers read indices back from these images.
pub fn index_image(pixels: &[i32]) -> Vec<u8> {
    let mut out = Vec::with_capacity(pixels.len() * 4);
    for &index in pixels {
        if (0..=255).contains(&index) {
            let value = index as u8;
            out.extend_from_slice(&[value, value, value, 255]);
        } else {
            out.extend_from_slice(&TRANSPARENT);
        }
    }
    out
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn rows_skip_and_runs() {
        // row 0: skip 1, run of 1 (padded); row 1: run of 2; end
        let data = [6, 1, 1, 3, 1, 4, 9, 0, 4, 1, 2, 4, 5, 6, 0, 2];
        let decoded = decode(&data, 3, 2, false).unwrap();
        assert_eq!(decoded.pixels, vec![-1, 9, -1, 5, 6, -1]);
        assert_eq!(decoded.rows, 2);
    }

    #[test]
    fn errors() {
        assert_eq!(decode(&[], 1, 1, false).unwrap_err(), "sprite has no end block");
        assert_eq!(
            decode(&[2, 1, 2, 3, 0, 2], 1, 1, false).unwrap_err(),
            "row skip extends past sprite width"
        );
        assert_eq!(
            decode(&[3, 1, 1, 4, 7, 0, 2], 1, 1, false).unwrap_err(),
            "odd pixel run has no padding byte"
        );
        assert!(decode(&[3, 1, 1, 4, 7, 0, 2], 1, 1, true).is_ok());
        assert_eq!(decode(&[0, 7], 1, 1, false).unwrap_err(), "unsupported outer block mode 7");
    }

    #[test]
    fn dos_rows() {
        // one row (its length counts the length byte): skip 1, two pixels; end marker
        let data = [DOS_ROW, 7, DOS_SKIP, 1, DOS_PIXELS, 2, 7, 8, 0];
        let decoded = decode_dos(&data, 0, data.len(), 3, 1).unwrap();
        assert_eq!(decoded.pixels, vec![-1, 7, 8]);
        assert_eq!(decode_dos(&data[..8], 0, 8, 3, 1).err().unwrap(), "Sprite has no end marker.");
        assert_eq!(
            decode_dos(&[0x10, 3, 9, 1, 0], 0, 5, 3, 1).err().unwrap(),
            "Unsupported row command 0x09."
        );
    }

    #[test]
    fn images() {
        let palette: Vec<u8> = (0..256).flat_map(|i| [i as u8, 1, 2, 255]).collect();
        assert_eq!(colorize(&[-1, 3], &palette), vec![255, 255, 255, 0, 3, 1, 2, 255]);
        assert_eq!(index_image(&[-1, 3]), vec![255, 255, 255, 0, 3, 3, 3, 255]);
    }
}
