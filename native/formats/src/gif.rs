//! GIF89a export and indexed GIF import. The cycle export has full frames with
//! local palettes and a repeating SCURK palette cycle.

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

fn u16_le(out: &mut Vec<u8>, value: usize) {
    out.extend_from_slice(&[(value & 255) as u8, ((value >> 8) & 255) as u8]);
}

/// Pixels with -1 replaced by the first unused index, which pixels in use, and
/// whether a pixel was transparent.
struct Raster {
    bytes: Vec<u8>,
    used: [bool; 256],
    clear_index: u8,
    transparent: bool,
}
fn raster(pixels: &[i32]) -> Result<Raster, String> {
    let mut used = [false; 256];
    let mut transparent = false;
    for &pixel in pixels {
        if !(-1..=255).contains(&pixel) {
            return Err("GIF pixel is outside the indexed palette.".into());
        }
        if pixel < 0 {
            transparent = true;
        } else {
            used[pixel as usize] = true;
        }
    }
    let clear_index = if transparent {
        match used.iter().position(|u| !u) {
            Some(index) => index as u8,
            None => return Err("GIF transparency requires an unused palette index.".into()),
        }
    } else {
        0
    };
    let bytes = pixels.iter().map(|p| if *p < 0 { clear_index } else { *p as u8 }).collect();
    Ok(Raster {
        bytes,
        used,
        clear_index,
        transparent,
    })
}

// A clear code every 254 pixels keeps the codes at nine bits.
fn literal_lzw(pixels: &[u8]) -> Vec<u8> {
    let mut output = Vec::new();
    let (mut buffer, mut bits) = (0_u32, 0);
    let mut emit = |code: u32, output: &mut Vec<u8>| {
        buffer |= code << bits;
        bits += 9;
        while bits >= 8 {
            output.push((buffer & 255) as u8);
            buffer >>= 8;
            bits -= 8;
        }
    };
    for run in pixels.chunks(254) {
        emit(CLEAR, &mut output);
        for pixel in run {
            emit(u32::from(*pixel), &mut output);
        }
    }
    emit(END, &mut output);
    if bits > 0 {
        output.push((buffer & 255) as u8);
    }
    output
}

// `palette` holds 256 RGB colors; `mapping` selects the color of each index.
fn write_palette(out: &mut Vec<u8>, palette: &[u8], mapping: &[i32]) {
    for index in mapping {
        let at = usize::try_from(*index).ok().filter(|i| *i < 256).map(|i| i * 3);
        // An index outside the palette is magenta, as Sc2Palette.color.
        out.extend_from_slice(at.map_or(&[255, 0, 255][..], |at| &palette[at..at + 3]));
    }
}
fn write_blocks(out: &mut Vec<u8>, compressed: &[u8]) {
    for block in compressed.chunks(255) {
        out.push(block.len() as u8);
        out.extend_from_slice(block);
    }
    out.push(0);
}

/// One frame with the palette in its original index order.
pub fn encode(width: i64, height: i64, pixels: &[i32], palette: &[u8]) -> Result<Vec<u8>, String> {
    if !(1..=MAX_DIMENSION).contains(&width) || !(1..=MAX_DIMENSION).contains(&height) || pixels.len() as i64 != width * height {
        return Err("Invalid GIF dimensions, pixels, or palette.".into());
    }
    let raster = raster(pixels)?;
    let identity: Vec<i32> = (0..256).collect();
    let mut out = b"GIF89a".to_vec();
    u16_le(&mut out, width as usize);
    u16_le(&mut out, height as usize);
    out.extend_from_slice(&[GLOBAL_TABLE_256, raster.clear_index, 0]);
    write_palette(&mut out, palette, &identity);
    if raster.transparent {
        out.extend_from_slice(&[EXTENSION, GRAPHIC_CONTROL, 4, HAS_TRANSPARENT, 0, 0, raster.clear_index, 0]);
    }
    out.push(IMAGE);
    u16_le(&mut out, 0);
    u16_le(&mut out, 0);
    u16_le(&mut out, width as usize);
    u16_le(&mut out, height as usize);
    out.push(0);
    out.push(CODE_SIZE);
    write_blocks(&mut out, &literal_lzw(&raster.bytes));
    out.push(TRAILER);
    Ok(out)
}

/// An animated cycle. `mappings` holds the palette index map of the first tick
/// and of each of the 120 cycle ticks. Returns the file and its frame count.
pub fn encode_cycle(width: i64, height: i64, pixels: &[i32], palette: &[u8], mappings: &[Vec<i32>]) -> Result<(Vec<u8>, usize), String> {
    if !(1..=128).contains(&width)
        || !(1..=256).contains(&height)
        || pixels.len() as i64 != width * height
        || mappings.len() != CYCLE_TICKS + 1
    {
        return Err("Invalid SCURK GIF dimensions, pixels, or palette.".into());
    }
    let raster = raster(pixels)?;
    let compressed = literal_lzw(&raster.bytes);
    // A new frame starts where the colors of the used indices change.
    let mut frames: Vec<(usize, &[i32])> = Vec::new();
    let mut previous: Vec<i32> = Vec::new();
    for (tick, mapping) in mappings[1..].iter().enumerate() {
        let signature: Vec<i32> = (0..256).filter(|i| raster.used[*i]).map(|i| mapping[i]).collect();
        if frames.is_empty() || signature != previous {
            frames.push((tick, mapping));
            previous = signature;
        }
    }
    let mut out = b"GIF89a".to_vec();
    u16_le(&mut out, width as usize);
    u16_le(&mut out, height as usize);
    out.extend_from_slice(&[GLOBAL_TABLE_256, raster.clear_index, 0]);
    write_palette(&mut out, palette, &mappings[0]);
    out.extend_from_slice(&[EXTENSION, APPLICATION, 11]);
    out.extend_from_slice(b"NETSCAPE2.0");
    out.extend_from_slice(&[3, 1, 0, 0, 0]); // repeat forever
    for (index, (start, mapping)) in frames.iter().enumerate() {
        let end = frames.get(index + 1).map_or(CYCLE_TICKS, |f| f.0);
        let delay = (end as f64 * 5.5).round() as i64 - (*start as f64 * 5.5).round() as i64;
        let control = if raster.transparent {
            DISPOSE_KEEP | HAS_TRANSPARENT
        } else {
            DISPOSE_KEEP
        };
        out.extend_from_slice(&[EXTENSION, GRAPHIC_CONTROL, 4, control]);
        u16_le(&mut out, delay as usize);
        out.extend_from_slice(&[raster.clear_index, 0, IMAGE]);
        u16_le(&mut out, 0);
        u16_le(&mut out, 0);
        u16_le(&mut out, width as usize);
        u16_le(&mut out, height as usize);
        out.push(LOCAL_TABLE_256);
        write_palette(&mut out, palette, mapping);
        out.push(CODE_SIZE);
        write_blocks(&mut out, &compressed);
    }
    out.push(TRAILER);
    Ok((out, frames.len()))
}

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

#[cfg(test)]
mod tests {
    use super::*;

    fn palette() -> Vec<u8> {
        (0..256).flat_map(|i| [i as u8, (255 - i) as u8, 7]).collect()
    }

    #[test]
    fn round_trip_with_transparency() {
        let pixels: Vec<i32> = (0..600).map(|i| if i % 7 == 0 { -1 } else { i % 200 }).collect();
        let bytes = encode(30, 20, &pixels, &palette()).unwrap();
        let decoded = decode(&bytes).unwrap();
        assert_eq!((decoded.width, decoded.height), (30, 20));
        assert_eq!(decoded.pixels, pixels);
        assert_eq!(&decoded.palette[3..6], &[1, 254, 7]);
    }

    #[test]
    fn cycle_frames_follow_color_changes() {
        let pixels = vec![1, 2, 3, 4];
        let mut mappings: Vec<Vec<i32>> = vec![(0..256).collect(); CYCLE_TICKS + 1];
        mappings[61][2] = 9;
        let (bytes, frames) = encode_cycle(2, 2, &pixels, &palette(), &mappings).unwrap();
        // tick 60 changes a used color and tick 61 restores it
        assert_eq!(frames, 3);
        assert_eq!(decode(&bytes).unwrap().pixels, pixels);
    }

    #[test]
    fn errors() {
        assert_eq!(decode(b"nope").err().unwrap(), "File does not have a GIF signature.");
        let all: Vec<i32> = (-1..256).collect();
        assert_eq!(
            encode(all.len() as i64, 1, &all, &palette()).err().unwrap(),
            "GIF transparency requires an unused palette index."
        );
        assert_eq!(
            encode(1, 1, &[300], &palette()).err().unwrap(),
            "GIF pixel is outside the indexed palette."
        );
    }
}
