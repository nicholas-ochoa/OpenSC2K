//! Resources of 32-bit Windows executables: bitmaps, RLE8 bitmap data, icons
//! and cursors. The reader never runs the program.

mod dib;
mod icon;

#[cfg(test)]
mod tests;

pub use dib::*;
pub use icon::*;

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
