//! GIF89a export: one image, or a palette cycle of full frames.

use super::*;

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
