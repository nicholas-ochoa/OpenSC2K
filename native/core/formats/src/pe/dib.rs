//! Bitmap resources: 8-bit, RLE8, and 4-bit indexed DIBs.

use super::{HIGH_BIT, Name, RLE8, has, u16_at, u32_at};

/// The header fields of a DIB.
pub struct DibHeader {
    pub width: u32,
    pub height: u32,
    pub bits_per_pixel: u32,
    pub compression: u32,
    pub color_count: u32,
}

pub fn dib_header(dib: &[u8]) -> DibHeader {
    DibHeader {
        width: u32_at(dib, 4),
        height: u32_at(dib, 8),
        bits_per_pixel: u16_at(dib, 14),
        compression: u32_at(dib, 16),
        color_count: u32_at(dib, 32),
    }
}

/// Top-down palette indices of an image.
pub struct Indexed {
    pub width: usize,
    pub height: usize,
    pub pixels: Vec<i32>,
}

/// An uncompressed or RLE8 8-bit indexed DIB.
pub fn decode_indexed8(dib: &[u8], name: &Name) -> Result<Indexed, String> {
    let header = dib_header(dib);

    if header.bits_per_pixel != 8 || header.compression > RLE8 {
        return Err(format!("PE bitmap resource {name} is not an uncompressed or RLE8 indexed image"));
    }

    let header_size = i64::from(u32_at(dib, 0));

    // a negative height marks a top-down DIB
    let top_down = header.height & HIGH_BIT != 0;
    let height = if top_down {
        i64::from(header.height.wrapping_neg())
    } else {
        i64::from(header.height)
    };

    let width = i64::from(header.width);

    if width <= 0 || height <= 0 || width > 4096 || height > 4096 {
        return Err(format!("PE bitmap resource {name} has invalid dimensions"));
    }

    let color_count = if header.color_count > 0 {
        i64::from(header.color_count)
    } else {
        256
    };

    let pixel_offset = header_size + color_count * 4;

    if header_size < 40 || color_count > 256 || !has(dib, 0, pixel_offset) || u16_at(dib, 12) != 1 {
        return Err(format!("PE bitmap resource {name} has an invalid header or palette"));
    }

    let (w, h) = (width as usize, height as usize);

    if header.compression == RLE8 {
        if top_down {
            return Err("RLE8 bitmap height must be positive".into());
        }

        let data_size = i64::from(u32_at(dib, 20));

        if data_size <= 0 || !has(dib, pixel_offset, data_size) {
            return Err("RLE8 bitmap data size is invalid".into());
        }

        let (pixels, _) = decode_rle8(&dib[pixel_offset as usize..(pixel_offset + data_size) as usize], w, h)?;

        if pixels.iter().any(|p| i64::from(*p) >= color_count) {
            return Err("RLE8 pixel index exceeds its palette".into());
        }

        return Ok(Indexed {
            width: w,
            height: h,
            pixels,
        });
    }

    let stride = w.div_ceil(4) * 4;

    if !has(dib, pixel_offset, (stride * h) as i64) {
        return Err(format!("PE bitmap resource {name} pixel data is truncated"));
    }

    let mut pixels = Vec::with_capacity(w * h);

    for y in 0..h {
        let row = pixel_offset as usize + (if top_down { y } else { h - 1 - y }) * stride;
        pixels.extend(dib[row..row + w].iter().map(|p| i32::from(*p)));
    }

    Ok(Indexed {
        width: w,
        height: h,
        pixels,
    })
}

/// BI_RLE8 data as top-down palette indices, and the bytes it consumed.
pub fn decode_rle8(bytes: &[u8], width: usize, height: usize) -> Result<(Vec<i32>, usize), String> {
    if width == 0 || height == 0 || width > 4096 || height > 4096 {
        return Err("RLE8 dimensions must be 1 through 4096".into());
    }

    let mut pixels = vec![0; width * height];
    let (mut x, mut y, mut offset) = (0, 0, 0); // y counts rows from the bottom
    while offset + 2 <= bytes.len() {
        let mut count = usize::from(bytes[offset]);
        let value = bytes[offset + 1];
        offset += 2;

        if count == 0 {
            match value {
                1 => return Ok((pixels, offset)),
                0 => {
                    x = 0;
                    y += 1;

                    if y > height {
                        return Err("RLE8 line escape exceeds the image".into());
                    }

                    continue;
                }
                2 => {
                    if offset + 2 > bytes.len() {
                        return Err("RLE8 delta is truncated".into());
                    }

                    x += usize::from(bytes[offset]);
                    y += usize::from(bytes[offset + 1]);
                    offset += 2;

                    if x > width || y >= height {
                        return Err("RLE8 delta exceeds the image".into());
                    }

                    continue;
                }
                _ => {}
            }

            count = usize::from(value);
            let padded = (count + 1) & !1;

            if offset + padded > bytes.len() {
                return Err("RLE8 absolute run or padding is truncated".into());
            }

            if x + count > width || y >= height {
                return Err("RLE8 absolute run exceeds its row".into());
            }

            let at = (height - 1 - y) * width + x;

            for (target, source) in pixels[at..at + count].iter_mut().zip(&bytes[offset..offset + count]) {
                *target = i32::from(*source);
            }

            offset += padded;
        } else {
            if x + count > width || y >= height {
                return Err("RLE8 encoded run exceeds its row".into());
            }

            let at = (height - 1 - y) * width + x;
            pixels[at..at + count].fill(i32::from(value));
        }

        x += count;
    }

    Err("RLE8 end-of-bitmap escape is missing".into())
}

/// A DIB in which RLE8 rows are expanded to uncompressed bottom-up rows. The
/// DIB palette stays. Godot cannot read RLE-compressed BMP files.
pub fn expand_rle8_dib(dib: &[u8], image: &Indexed) -> Vec<u8> {
    let header = dib_header(dib);
    let colors = if header.color_count > 0 { header.color_count } else { 256 };
    let pixel_offset = (u32_at(dib, 0) + colors * 4) as usize;
    let stride = (image.width + 3) & !3;
    let mut out = dib[..pixel_offset.min(dib.len())].to_vec();
    out.resize(pixel_offset + stride * image.height, 0);
    out[16..20].copy_from_slice(&0_u32.to_le_bytes());
    out[20..24].copy_from_slice(&((stride * image.height) as u32).to_le_bytes());

    for (y, row) in image.pixels.chunks_exact(image.width).enumerate() {
        let at = pixel_offset + (image.height - 1 - y) * stride;

        for (target, pixel) in out[at..at + image.width].iter_mut().zip(row) {
            *target = *pixel as u8;
        }
    }

    out
}

/// A BMP file around a DIB of any bit depth.
pub fn wrap_dib(dib: &[u8]) -> Result<Vec<u8>, String> {
    if dib.len() < 40 {
        return Err("PE bitmap has an unsupported DIB header".into());
    }

    let header_size = u32_at(dib, 0) as usize;

    if header_size < 40 || header_size > dib.len() {
        return Err("PE bitmap DIB header is invalid".into());
    }

    let header = dib_header(dib);
    let mut color_count = header.color_count as usize;

    if color_count == 0 && header.bits_per_pixel <= 8 {
        color_count = 1 << header.bits_per_pixel;
    }

    let mask_size = if header.compression == 3 && header_size == 40 { 12 } else { 0 };
    let pixel_offset = 14 + header_size + color_count * 4 + mask_size;

    if pixel_offset > dib.len() + 14 {
        return Err("PE bitmap palette is truncated".into());
    }

    let mut out = vec![0; 14];
    out[0..2].copy_from_slice(b"BM");
    out[2..6].copy_from_slice(&((dib.len() + 14) as u32).to_le_bytes());
    out[10..14].copy_from_slice(&(pixel_offset as u32).to_le_bytes());
    out.extend_from_slice(dib);
    Ok(out)
}

/// A 4-bit uncompressed DIB as top-down palette indices.
pub fn decode_indexed4(dib: &[u8]) -> Result<Indexed, String> {
    let header = dib_header(dib);

    if header.bits_per_pixel != 4 || header.compression != 0 {
        return Err("Unsupported original bitmap".into());
    }

    let colors = if header.color_count > 0 { header.color_count as usize } else { 16 };
    let (w, h) = (header.width as usize, header.height as usize);
    let stride = (w * 4).div_ceil(32) * 4;
    let start = u32_at(dib, 0) as usize + colors * 4;

    if w == 0 || h == 0 || start + stride * h > dib.len() {
        return Err("Unsupported original bitmap".into());
    }

    let mut pixels = Vec::with_capacity(w * h);

    for y in 0..h {
        let row = start + (h - 1 - y) * stride;
        pixels.extend((0..w).map(|x| {
            let value = dib[row + x / 2];
            i32::from(if x % 2 == 0 { value >> 4 } else { value & 15 })
        }));
    }

    Ok(Indexed {
        width: w,
        height: h,
        pixels,
    })
}
