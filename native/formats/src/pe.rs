//! Resources of 32-bit Windows executables: bitmaps, RLE8 bitmap data, icons
//! and cursors. The reader never runs the program.

/// "MZ" at the start of the DOS header.
const MZ_SIGNATURE: u32 = 0x5a4d;
const DOS_HEADER_SIZE: usize = 0x40;
/// The DOS header field that holds the PE header offset.
const PE_OFFSET_FIELD: i64 = 0x3c;
const PE_SIGNATURE: u32 = 0x0000_4550;
/// The data directories of a PE32 optional header start at this offset.
const DATA_DIRECTORIES: i64 = 96;
/// Resource directory entries: a name or target with this bit is a string or a subdirectory.
const HIGH_BIT: u32 = 0x8000_0000;
const OFFSET_MASK: u32 = 0x7fff_ffff;
const ID_MASK: u32 = 0xffff;
/// The BI_RLE8 compression of a DIB.
pub const RLE8: u32 = 1;
const PE32_MAGIC: u32 = 0x010b;
const RESOURCE_DIRECTORY_INDEX: usize = 2;

pub const TYPE_BITMAP: u32 = 2;

fn has(bytes: &[u8], offset: i64, size: i64) -> bool {
    offset >= 0 && size >= 0 && offset <= bytes.len() as i64 - size
}
fn u16_at(bytes: &[u8], offset: i64) -> u32 {
    if !has(bytes, offset, 2) {
        return 0;
    }
    let at = offset as usize;
    u32::from(u16::from_le_bytes([bytes[at], bytes[at + 1]]))
}
fn u32_at(bytes: &[u8], offset: i64) -> u32 {
    if !has(bytes, offset, 4) {
        return 0;
    }
    let at = offset as usize;
    u32::from_le_bytes([bytes[at], bytes[at + 1], bytes[at + 2], bytes[at + 3]])
}

/// The resource directory of one file.
pub struct Directory<'a> {
    pub bytes: &'a [u8],
    root: i64,
    sections: i64,
    section_count: i64,
}

/// A resource name: a number or a UTF-16 string.
pub enum Name<'a> {
    Id(u32),
    Text(&'a str),
}
impl std::fmt::Display for Name<'_> {
    fn fmt(&self, f: &mut std::fmt::Formatter) -> std::fmt::Result {
        match self {
            Self::Id(id) => write!(f, "{id}"),
            Self::Text(text) => write!(f, "{text}"),
        }
    }
}

impl<'a> Directory<'a> {
    pub fn open(bytes: &'a [u8]) -> Result<Self, String> {
        if bytes.len() < DOS_HEADER_SIZE || u16_at(bytes, 0) != MZ_SIGNATURE {
            return Err("file does not have an MZ header".into());
        }
        let pe = i64::from(u32_at(bytes, PE_OFFSET_FIELD));
        if !has(bytes, pe, 24) || u32_at(bytes, pe) != PE_SIGNATURE {
            return Err("file does not have a valid PE header".into());
        }
        let section_count = i64::from(u16_at(bytes, pe + 6));
        let optional_size = i64::from(u16_at(bytes, pe + 20));
        let optional = pe + 24;
        if !has(bytes, optional, optional_size) {
            return Err("PE optional header is truncated".into());
        }
        if u16_at(bytes, optional) != PE32_MAGIC {
            return Err("only PE32 resources are supported".into());
        }
        let entry = optional + DATA_DIRECTORIES + RESOURCE_DIRECTORY_INDEX as i64 * 8;
        if !has(bytes, entry, 8) {
            return Err("PE resource directory entry is missing".into());
        }
        let (rva, size) = (u32_at(bytes, entry), u32_at(bytes, entry + 4));
        if rva == 0 || size == 0 {
            return Err("PE file does not contain resources".into());
        }
        let mut directory = Self {
            bytes,
            root: 0,
            sections: optional + optional_size,
            section_count,
        };
        directory.root = directory
            .offset(i64::from(rva))
            .ok_or("PE resource directory is outside its sections")?;
        Ok(directory)
    }
    /// The file offset of a relative virtual address.
    pub fn offset(&self, rva: i64) -> Option<i64> {
        if self.section_count < 0 || !has(self.bytes, self.sections, self.section_count * 40) {
            return None;
        }
        for index in 0..self.section_count {
            let header = self.sections + index * 40;
            let virtual_size = i64::from(u32_at(self.bytes, header + 8));
            let address = i64::from(u32_at(self.bytes, header + 12));
            let raw_size = i64::from(u32_at(self.bytes, header + 16));
            let raw_offset = i64::from(u32_at(self.bytes, header + 20));
            if rva >= address && rva < address + virtual_size.max(raw_size) {
                let result = raw_offset + rva - address;
                return (result >= 0 && result < self.bytes.len() as i64).then_some(result);
            }
        }
        None
    }
    fn entries(&self, directory: i64) -> Option<(i64, i64)> {
        if !has(self.bytes, directory, 16) {
            return None;
        }
        let count = i64::from(u16_at(self.bytes, directory + 12) + u16_at(self.bytes, directory + 14));
        let first = directory + 16;
        has(self.bytes, first, count * 8).then_some((first, count))
    }
    fn numeric_child(&self, directory: i64, wanted: u32) -> Option<i64> {
        let (first, count) = self.entries(directory)?;
        for index in 0..count {
            let name = u32_at(self.bytes, first + index * 8);
            if name & HIGH_BIT != 0 || name & ID_MASK != wanted {
                continue;
            }
            let target = u32_at(self.bytes, first + index * 8 + 4);
            if target & HIGH_BIT == 0 {
                return None;
            }
            return Some(self.root + i64::from(target & OFFSET_MASK));
        }
        None
    }
    fn named_child(&self, directory: i64, wanted: &str) -> Option<i64> {
        let (first, count) = self.entries(directory)?;
        let wanted: Vec<u8> = wanted.encode_utf16().flat_map(u16::to_le_bytes).collect();
        for index in 0..count {
            let name = u32_at(self.bytes, first + index * 8);
            if name & HIGH_BIT == 0 {
                continue;
            }
            let at = self.root + i64::from(name & OFFSET_MASK);
            if !has(self.bytes, at, 2) {
                return None;
            }
            let length = i64::from(u16_at(self.bytes, at)) * 2;
            if !has(self.bytes, at + 2, length) {
                return None;
            }
            if self.bytes[(at + 2) as usize..(at + 2 + length) as usize] != wanted[..] {
                continue;
            }
            let target = u32_at(self.bytes, first + index * 8 + 4);
            if target & HIGH_BIT == 0 {
                return None;
            }
            let result = self.root + i64::from(target & OFFSET_MASK);
            return has(self.bytes, result, 16).then_some(result);
        }
        None
    }
    fn first_data(&self, directory: i64) -> Option<i64> {
        if !has(self.bytes, directory, 24) {
            return None;
        }
        if u16_at(self.bytes, directory + 12) + u16_at(self.bytes, directory + 14) < 1 {
            return None;
        }
        let target = u32_at(self.bytes, directory + 20);
        (target & HIGH_BIT == 0).then_some(self.root + i64::from(target))
    }
    fn data(&self, entry: i64) -> Option<&'a [u8]> {
        if !has(self.bytes, entry, 16) {
            return None;
        }
        let size = i64::from(u32_at(self.bytes, entry + 4));
        let offset = self.offset(i64::from(u32_at(self.bytes, entry)))?;
        has(self.bytes, offset, size).then(|| &self.bytes[offset as usize..(offset + size) as usize])
    }

    /// Numeric IDs of the bitmap resources, in ascending order.
    pub fn bitmap_ids(&self) -> Result<Vec<i32>, String> {
        let directory = self
            .numeric_child(self.root, TYPE_BITMAP)
            .ok_or("PE file does not contain bitmap resources")?;
        if !has(self.bytes, directory, 16) {
            return Err("PE bitmap resource directory is truncated".into());
        }
        let (first, count) = self.entries(directory).ok_or("PE bitmap resource entries are truncated")?;
        let mut ids: Vec<i32> = (0..count)
            .filter_map(|index| {
                let name = u32_at(self.bytes, first + index * 8);
                let target = u32_at(self.bytes, first + index * 8 + 4);
                (name & HIGH_BIT == 0 && target & HIGH_BIT != 0).then_some((name & ID_MASK) as i32)
            })
            .collect();
        ids.sort_unstable();
        Ok(ids)
    }

    /// The DIB of a bitmap resource.
    pub fn bitmap(&self, name: &Name) -> Result<&'a [u8], String> {
        let directory = self
            .numeric_child(self.root, TYPE_BITMAP)
            .ok_or("PE file does not contain bitmap resources")?;
        let language = match name {
            Name::Id(id) => self.numeric_child(directory, *id),
            Name::Text(text) => self.named_child(directory, text),
        }
        .ok_or_else(|| format!("PE bitmap resource {name} is missing"))?;
        let entry = self
            .first_data(language)
            .filter(|e| has(self.bytes, *e, 16))
            .ok_or_else(|| format!("PE bitmap resource {name} has no language data"))?;
        let dib = self
            .data(entry)
            .ok_or_else(|| format!("PE bitmap resource {name} data is truncated"))?;
        if dib.len() < 40 {
            return Err(format!("PE bitmap resource {name} has a short DIB header"));
        }
        Ok(dib)
    }

    /// The data of an icon, cursor, or icon or cursor group resource.
    pub fn icon_resource(&self, type_id: u32, id: u32) -> Result<&'a [u8], String> {
        if id > 65535 || ![1, 3, 12, 14].contains(&type_id) {
            return Err("Invalid icon/cursor resource ID or type".into());
        }
        let directory = self
            .numeric_child(self.root, type_id)
            .ok_or("Icon/cursor resource type is missing")?;
        let language = self.numeric_child(directory, id).ok_or("Icon/cursor resource is missing")?;
        let entry = self
            .first_data(language)
            .filter(|e| has(self.bytes, *e, 16))
            .ok_or("Icon/cursor language data is truncated")?;
        self.data(entry).ok_or_else(|| "Icon/cursor resource data is truncated".into())
    }
}

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

/// One entry of an icon or cursor group.
pub struct GroupEntry {
    pub id: u32,
    pub width: u32,
    pub height: u32,
    pub planes: u32,
    pub bits: u32,
    pub length: u32,
}
pub fn decode_group(bytes: &[u8], cursor: bool) -> Result<Vec<GroupEntry>, String> {
    if bytes.len() < 6 || u16_at(bytes, 0) != 0 || u16_at(bytes, 2) != if cursor { 2 } else { 1 } {
        return Err("Invalid icon/cursor group header".into());
    }
    let count = u16_at(bytes, 4) as usize;
    if count == 0 || bytes.len() != 6 + count * 14 {
        return Err("Invalid icon/cursor group length".into());
    }
    let mut entries: Vec<GroupEntry> = Vec::new();
    for i in 0..count {
        let at = (6 + i * 14) as i64;
        let size = |offset: i64| {
            if cursor {
                u16_at(bytes, at + offset)
            } else {
                match bytes[(at + offset / 2) as usize] {
                    0 => 256,
                    value => u32::from(value),
                }
            }
        };
        let (width, height) = (size(0), size(2));
        let id = u16_at(bytes, at + 12);
        let length = u32_at(bytes, at + 8);
        if width == 0 || width > 256 || height == 0 || height > 512 || id == 0 || entries.iter().any(|e| e.id == id) || length == 0 {
            return Err("Invalid icon/cursor group entry".into());
        }
        entries.push(GroupEntry {
            id,
            width,
            height,
            planes: u16_at(bytes, at + 4),
            bits: u16_at(bytes, at + 6),
            length,
        });
    }
    Ok(entries)
}

/// An icon or cursor image: XOR indices, the AND mask, and its palette.
pub struct IconImage {
    pub width: usize,
    pub height: usize,
    pub bits: u32,
    pub hotspot: (u32, u32),
    /// RGB colors.
    pub palette: Vec<u8>,
    pub pixels: Vec<i32>,
    pub and_mask: Vec<u8>,
    pub inverting_pixels: usize,
    pub trailing_bytes: usize,
}
pub fn decode_icon(bytes: &[u8], cursor: bool) -> Result<IconImage, String> {
    let start = if cursor { 4 } else { 0 };
    if bytes.len() < start + 40 {
        return Err("Icon/cursor DIB header is truncated".into());
    }
    let hotspot = if cursor { (u16_at(bytes, 0), u16_at(bytes, 2)) } else { (0, 0) };
    let s = start as i64;
    let header = u32_at(bytes, s) as usize;
    let width = u32_at(bytes, s + 4) as i32;
    let stored_height = u32_at(bytes, s + 8) as i32;
    let bits = u16_at(bytes, s + 14);
    if header != 40 || !(1..=256).contains(&width) || !(2..=512).contains(&stored_height) || stored_height % 2 != 0 {
        return Err("Unsupported icon/cursor DIB dimensions or header".into());
    }
    // the DIB height counts the pixels and the mask
    let (width, height) = (width as usize, (stored_height / 2) as usize);
    if hotspot.0 as usize >= width || hotspot.1 as usize >= height {
        return Err("Cursor hotspot is outside its image".into());
    }
    if u16_at(bytes, s + 12) != 1 || ![1, 4, 8].contains(&bits) || u32_at(bytes, s + 16) != 0 {
        return Err("Icon/cursor DIB must be uncompressed indexed data".into());
    }
    let mut count = u32_at(bytes, s + 32) as usize;
    if count == 0 {
        count = 1 << bits;
    }
    if count > 1 << bits {
        return Err("Invalid icon/cursor palette length".into());
    }
    let pixels_start = start + header + count * 4;
    let xor_stride = (width * bits as usize).div_ceil(32) * 4;
    let and_stride = width.div_ceil(32) * 4;
    let mask_start = pixels_start + xor_stride * height;
    let end = mask_start + and_stride * height;
    if bytes.len() < end {
        return Err("Icon/cursor palette or mask data is truncated".into());
    }
    let palette: Vec<u8> = (0..count)
        .flat_map(|i| {
            let at = start + header + i * 4;
            [bytes[at + 2], bytes[at + 1], bytes[at]]
        })
        .collect();
    let bits_usize = bits as usize;
    let mut pixels = Vec::with_capacity(width * height);
    let mut and_mask = Vec::with_capacity(width * height);
    let mut inverting = 0;
    for y in 0..height {
        let row = height - 1 - y;
        for x in 0..width {
            let bit = x * bits_usize;
            let byte = bytes[pixels_start + row * xor_stride + bit / 8];
            let index = usize::from((byte >> (8 - bits_usize - bit % 8)) & ((1_u16 << bits) - 1) as u8);
            if index >= count {
                return Err("Icon/cursor index is outside its palette".into());
            }
            let mask = (bytes[mask_start + row * and_stride + x / 8] >> (7 - x % 8)) & 1;
            pixels.push(index as i32);
            and_mask.push(mask);
            if mask == 1 && palette[index * 3..index * 3 + 3] != [0, 0, 0] {
                inverting += 1;
            }
        }
    }
    Ok(IconImage {
        width,
        height,
        bits,
        hotspot,
        palette,
        pixels,
        and_mask,
        inverting_pixels: inverting,
        trailing_bytes: bytes.len() - end,
    })
}

/// RGBA8 pixels: the AND mask makes a pixel transparent.
pub fn icon_transparent(pixels: &[i32], and_mask: &[u8], palette: &[u8]) -> Vec<u8> {
    let mut out = Vec::with_capacity(pixels.len() * 4);
    for (pixel, mask) in pixels.iter().zip(and_mask) {
        if *mask != 0 {
            out.extend_from_slice(&[0, 0, 0, 0]);
        } else {
            let at = *pixel as usize * 3;
            out.extend_from_slice(&[palette[at], palette[at + 1], palette[at + 2], 255]);
        }
    }
    out
}

/// RGBA8 pixels of the icon drawn over `background`: the AND mask keeps the
/// background, and the XOR colors invert it.
pub fn icon_composite(pixels: &[i32], and_mask: &[u8], palette: &[u8], background: &[u8]) -> Vec<u8> {
    let mut out = Vec::with_capacity(pixels.len() * 4);
    for (i, (pixel, mask)) in pixels.iter().zip(and_mask).enumerate() {
        let at = *pixel as usize * 3;
        let backdrop = if *mask != 0 {
            &background[i * 4..i * 4 + 3]
        } else {
            &[0, 0, 0][..]
        };
        out.extend_from_slice(&[
            backdrop[0] ^ palette[at],
            backdrop[1] ^ palette[at + 1],
            backdrop[2] ^ palette[at + 2],
            255,
        ]);
    }
    out
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn rle8_runs_escapes_and_errors() {
        let (pixels, consumed) = decode_rle8(&[3, 7, 0, 0, 0, 3, 1, 2, 3, 0, 0, 1], 4, 2).unwrap();
        assert_eq!(pixels, vec![1, 2, 3, 0, 7, 7, 7, 0]);
        assert_eq!(consumed, 12);
        assert_eq!(decode_rle8(&[5, 1, 0, 1], 4, 1).err().unwrap(), "RLE8 encoded run exceeds its row");
        assert_eq!(decode_rle8(&[1, 1], 4, 1).err().unwrap(), "RLE8 end-of-bitmap escape is missing");
    }

    fn icon(bits: u32) -> Vec<u8> {
        // 8 by 1 pixels: header, two colors, xor row, and row
        let mut bytes = vec![0; 40];
        bytes[0] = 40;
        bytes[4] = 8;
        bytes[8] = 2;
        bytes[12] = 1;
        bytes[14] = bits as u8;
        bytes[32] = 2;
        bytes.extend_from_slice(&[0, 0, 0, 0, 30, 20, 10, 0]);
        bytes.extend_from_slice(&[0b1010_0000, 0, 0, 0]);
        bytes.extend_from_slice(&[0b0100_0000, 0, 0, 0]);
        bytes
    }

    #[test]
    fn icons() {
        let decoded = decode_icon(&icon(1), false).unwrap();
        assert_eq!(decoded.pixels, vec![1, 0, 1, 0, 0, 0, 0, 0]);
        assert_eq!(decoded.and_mask, vec![0, 1, 0, 0, 0, 0, 0, 0]);
        assert_eq!(&decoded.palette[3..6], &[10, 20, 30]);
        assert_eq!(decoded.inverting_pixels, 0);
        let rgba = icon_transparent(&decoded.pixels, &decoded.and_mask, &decoded.palette);
        assert_eq!(&rgba[..8], &[10, 20, 30, 255, 0, 0, 0, 0]);
        let over = icon_composite(&decoded.pixels, &decoded.and_mask, &decoded.palette, &[1; 32]);
        assert_eq!(&over[..8], &[10, 20, 30, 255, 1, 1, 1, 255]);
        assert!(decode_icon(&icon(2), false).is_err());
    }

    // Root 64 and a directory at 96 with one named and one numeric entry.
    fn named_directory(name: &str) -> Vec<u8> {
        let mut bytes = vec![0; 384];
        bytes[108] = 1;
        bytes[110] = 1;
        bytes[112..116].copy_from_slice(&0x8000_0080_u32.to_le_bytes());
        bytes[116..120].copy_from_slice(&0x8000_00c0_u32.to_le_bytes());
        bytes[120..124].copy_from_slice(&7_u32.to_le_bytes());
        bytes[124..128].copy_from_slice(&0x8000_00d0_u32.to_le_bytes());
        let encoded: Vec<u8> = name.encode_utf16().flat_map(u16::to_le_bytes).collect();
        bytes[192..194].copy_from_slice(&((encoded.len() / 2) as u16).to_le_bytes());
        bytes[194..194 + encoded.len()].copy_from_slice(&encoded);
        // names are length-prefixed, not terminated
        bytes[194 + encoded.len()] = 0xff;
        bytes
    }
    fn directory(bytes: &[u8]) -> Directory<'_> {
        Directory {
            bytes,
            root: 64,
            sections: 0,
            section_count: 0,
        }
    }

    #[test]
    fn named_and_numeric_children() {
        for name in ["ADVICEU", "城🏙"] {
            let bytes = named_directory(name);
            let d = directory(&bytes);
            assert_eq!(d.named_child(96, name), Some(256));
            assert_eq!(d.named_child(96, "missing"), None);
            assert_eq!(d.named_child(96, "7"), None);
            assert_eq!(d.numeric_child(96, 7), Some(272));
            for length in 0..272 {
                assert_eq!(directory(&bytes[..length]).named_child(96, name), None);
            }
        }
        let bytes = named_directory("城🏙");
        for (at, value) in [(108, 0xffff_u32), (112, 0xffff_ffff), (192, 0xffff), (116, 192), (116, 0xffff_ffff)] {
            let mut bad = bytes.clone();
            let width = if at == 108 || at == 192 { 2 } else { 4 };
            bad[at..at + width].copy_from_slice(&value.to_le_bytes()[..width]);
            assert_eq!(directory(&bad).named_child(96, "城🏙"), None, "change at {at}");
        }
    }

    #[test]
    fn bounded_reads() {
        let bytes = [0xa5, 0x12, 0x34, 0x56, 0x78, 0x5a];
        for size in 0..=bytes.len() {
            let prefix = &bytes[..size];
            for offset in -1..size as i64 + 2 {
                let fits = |n: i64| offset >= 0 && offset + n <= size as i64;
                let at = offset.max(0) as usize;
                let short = if fits(2) {
                    u32::from(u16::from_le_bytes([prefix[at], prefix[at + 1]]))
                } else {
                    0
                };
                let word = if fits(4) {
                    u32::from_le_bytes(prefix[at..at + 4].try_into().unwrap())
                } else {
                    0
                };
                assert_eq!(u16_at(prefix, offset), short);
                assert_eq!(u32_at(prefix, offset), word);
            }
        }
    }

    #[test]
    fn groups() {
        let mut bytes = vec![0, 0, 1, 0, 1, 0];
        bytes.extend_from_slice(&[32, 32, 0, 0, 1, 0, 4, 0, 100, 0, 0, 0, 5, 0]);
        let entries = decode_group(&bytes, false).unwrap();
        assert_eq!(
            (entries[0].id, entries[0].width, entries[0].bits, entries[0].length),
            (5, 32, 4, 100)
        );
        assert!(decode_group(&bytes, true).is_err());
    }
}
