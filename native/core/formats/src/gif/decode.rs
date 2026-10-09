//! Indexed GIF import: the first image on its logical screen.

use super::*;

/// The first image on its logical screen. Pixels outside the image and pixels
/// of the transparent index are -1.
pub struct Decoded {
    pub width: usize,
    pub height: usize,
    pub pixels: Vec<i32>,
    /// 256 RGB colors. Entries past the color table are black.
    pub palette: Vec<u8>,
}

fn u16_at(bytes: &[u8], at: usize) -> usize {
    usize::from(bytes[at]) | usize::from(bytes[at + 1]) << 8
}

fn colors(bytes: &[u8], start: usize, count: usize) -> Option<&[u8]> {
    bytes.get(start..start + count * 3)
}

// The position after the terminating zero-length block.
fn skip_blocks(bytes: &[u8], start: usize) -> Option<usize> {
    let mut position = start;

    while position < bytes.len() {
        let length = usize::from(bytes[position]);
        position += 1 + length;

        if length == 0 {
            return Some(position);
        }
    }

    None
}

pub fn decode(bytes: &[u8]) -> Result<Decoded, String> {
    if bytes.len() < 13 || !(bytes.starts_with(b"GIF87a") || bytes.starts_with(b"GIF89a")) {
        return Err("File does not have a GIF signature.".into());
    }

    let (screen_width, screen_height) = (u16_at(bytes, 6), u16_at(bytes, 8));

    if screen_width < 1 || screen_height < 1 || screen_width > 4096 || screen_height > 4096 {
        return Err("GIF dimensions must be 1 through 4096".into());
    }

    let mut position = 13;
    let mut global: &[u8] = &[];

    if bytes[10] & COLOR_TABLE != 0 {
        global = colors(bytes, position, 2 << (bytes[10] & 7)).ok_or("GIF color table extends past the file.")?;
        position += global.len();
    }

    let mut transparent: i32 = -1;

    while position < bytes.len() {
        let kind = bytes[position];
        position += 1;

        if kind == TRAILER {
            break;
        }

        if kind == EXTENSION {
            if position >= bytes.len() {
                break;
            }

            let label = bytes[position];
            position += 1;

            if label == GRAPHIC_CONTROL && position + 5 < bytes.len() && bytes[position] == 4 {
                transparent = if bytes[position + 1] & HAS_TRANSPARENT != 0 {
                    i32::from(bytes[position + 4])
                } else {
                    -1
                };
            }

            position = skip_blocks(bytes, position).ok_or("GIF extension extends past the file.")?;
            continue;
        }

        if kind != IMAGE {
            return Err("GIF contains an unknown block.".into());
        }

        return decode_image(bytes, position, screen_width, screen_height, global, transparent);
    }

    Err("GIF contains no image.".into())
}

fn decode_image(
    bytes: &[u8],
    start: usize,
    screen_width: usize,
    screen_height: usize,
    global: &[u8],
    transparent: i32,
) -> Result<Decoded, String> {
    if start + 9 > bytes.len() {
        return Err("GIF image header extends past the file.".into());
    }

    let (left, top) = (u16_at(bytes, start), u16_at(bytes, start + 2));
    let (width, height) = (u16_at(bytes, start + 4), u16_at(bytes, start + 6));
    let flags = bytes[start + 8];
    let mut position = start + 9;

    if width < 1 || height < 1 || left + width > screen_width || top + height > screen_height {
        return Err("GIF image is outside its logical screen.".into());
    }

    let mut table = global;

    if flags & COLOR_TABLE != 0 {
        table = colors(bytes, position, 2 << (flags & 7)).ok_or("GIF color table extends past the file.")?;
        position += table.len();
    }

    if table.is_empty() {
        return Err("GIF has no color table.".into());
    }

    if position >= bytes.len() || !(2..=8).contains(&bytes[position]) {
        return Err("GIF LZW code size is invalid.".into());
    }

    let code_size = bytes[position];
    let mut data = Vec::new();
    position += 1;

    loop {
        if position >= bytes.len() {
            return Err("GIF image data extends past the file.".into());
        }

        let length = usize::from(bytes[position]);

        if position + 1 + length > bytes.len() {
            return Err("GIF image data extends past the file.".into());
        }

        if length == 0 {
            break;
        }

        data.extend_from_slice(&bytes[position + 1..position + 1 + length]);
        position += 1 + length;
    }

    let indices = lzw_decode(&data, u32::from(code_size), width * height);

    if indices.len() < width * height {
        return Err("GIF image data is invalid or incomplete.".into());
    }

    let rows: Vec<usize> = if flags & INTERLACED != 0 {
        INTERLACE_PASSES
            .iter()
            .flat_map(|(first, step)| (*first..height).step_by(*step))
            .collect()
    } else {
        (0..height).collect()
    };

    let color_count = table.len() / 3;
    let mut pixels = vec![-1; screen_width * screen_height];

    for (source_row, row) in rows.iter().enumerate() {
        let y = top + row;

        for x in 0..width {
            let index = indices[source_row * width + x];

            if usize::from(index) >= color_count {
                return Err("GIF pixel is outside its color table.".into());
            }

            pixels[y * screen_width + left + x] = if i32::from(index) == transparent { -1 } else { i32::from(index) };
        }
    }

    let mut palette = table.to_vec();
    palette.resize(768, 0);
    palette.truncate(768);
    Ok(Decoded {
        width: screen_width,
        height: screen_height,
        pixels,
        palette,
    })
}

/// Variable-length codes of up to 12 bits. Returns fewer indices on an error.
fn lzw_decode(data: &[u8], minimum_code_size: u32, count: usize) -> Vec<u8> {
    let clear_code = 1_usize << minimum_code_size;
    let end_code = clear_code + 1;
    let mut prefixes = vec![-1_i32; MAX_CODES];
    let mut suffixes = vec![0_u8; MAX_CODES];
    let mut firsts = vec![0_u8; MAX_CODES];

    for code in 0..clear_code {
        suffixes[code] = code as u8;
        firsts[code] = code as u8;
    }

    let mut output = Vec::with_capacity(count);
    let mut stack = vec![0_u8; MAX_CODES];
    let mut code_size = minimum_code_size + 1;
    let mut next_code = end_code + 1;
    let mut previous: i64 = -1;
    let (mut buffer, mut bits, mut position) = (0_u64, 0, 0);

    while output.len() < count {
        while bits < code_size {
            if position >= data.len() {
                return output;
            }

            buffer |= u64::from(data[position]) << bits;
            position += 1;
            bits += 8;
        }

        let code = (buffer & ((1 << code_size) - 1)) as usize;
        buffer >>= code_size;
        bits -= code_size;

        if code == clear_code {
            code_size = minimum_code_size + 1;
            next_code = end_code + 1;
            previous = -1;
            continue;
        }

        if code == end_code {
            return output;
        }

        if previous < 0 {
            if code >= clear_code {
                return output;
            }

            output.push(code as u8);
            previous = code as i64;
            continue;
        }

        let entry = if code == next_code {
            previous as usize
        } else if code > next_code || (clear_code..=end_code).contains(&code) {
            return output;
        } else {
            code
        };

        let mut depth = 0;
        let mut walk = entry as i32;

        while walk >= 0 {
            stack[depth] = suffixes[walk as usize];
            depth += 1;
            walk = prefixes[walk as usize];
        }

        output.extend(stack[..depth].iter().rev());

        if code == next_code {
            output.push(firsts[previous as usize]);
        }

        if next_code < MAX_CODES {
            prefixes[next_code] = previous as i32;
            suffixes[next_code] = firsts[entry];
            firsts[next_code] = firsts[previous as usize];
            next_code += 1;

            if next_code == 1 << code_size && code_size < 12 {
                code_size += 1;
            }
        }

        previous = code as i64;
    }

    output
}
