//! Bounded readers of the original asset containers: the DAT archive of named
//! records, Macintosh resource forks, and the resources of Windows NE and PE
//! executables. They never run the source programs.

use super::has_range;
use crate::bytes::latin1;

const DIRECTORY_ENTRY_SIZE: usize = 16;
const DIRECTORY_NAME_SIZE: usize = 12;
const MAX_DIRECTORY_ENTRIES: usize = 65536;
const APPLE_SINGLE: usize = 0x0005_1600;
const APPLE_DOUBLE: usize = 0x0005_1607;
const APPLE_RESOURCE_FORK: usize = 2;
const APPLE_ENTRY_SIZE: usize = 12;
const MAC_BINARY_HEADER: usize = 128;
const MAC_MAP_HEADER_SIZE: usize = 28;
const MAC_MAX_TYPES: usize = 4096;
const MAC_TYPE_SIZE: usize = 8;
const MAC_REFERENCE_SIZE: usize = 12;
const PE_SIGNATURE: usize = 0x4550;
const PE32_MAGIC: usize = 0x10b;
const PE_MIN_OPTIONAL_SIZE: usize = 120;
const PE_SECTION_SIZE: usize = 40;
const PE_RESOURCE_DIRECTORY: usize = 112;
const PE_MAX_DEPTH: usize = 2;
const PE_HIGH_BIT: usize = 0x8000_0000;
const NE_RECORD_SIZE: usize = 12;
const NE_MAX_SHIFT: usize = 20;

/// One source record with its container identity.
#[derive(Clone, Debug, Default, PartialEq, Eq)]
pub struct Resource {
    pub name: String,
    /// The resource type of a Macintosh or Windows record, else empty.
    pub kind: String,
    /// The numeric ID, or -1.
    pub id: i64,
    pub bytes: Vec<u8>,
}

/// The records of a container, or an error and no records.
#[derive(Clone, Debug, Default, PartialEq, Eq)]
pub struct Container {
    pub resources: Vec<Resource>,
    pub error: String,
}

fn u16_le(data: &[u8], at: usize) -> usize {
    usize::from(u16::from_le_bytes([data[at], data[at + 1]]))
}

fn u32_le(data: &[u8], at: usize) -> usize {
    u32::from_le_bytes([data[at], data[at + 1], data[at + 2], data[at + 3]]) as usize
}

fn u16_be(data: &[u8], at: usize) -> usize {
    usize::from(u16::from_be_bytes([data[at], data[at + 1]]))
}

fn u32_be(data: &[u8], at: usize) -> usize {
    u32::from_be_bytes([data[at], data[at + 1], data[at + 2], data[at + 3]]) as usize
}

/// Text without leading and trailing whitespace and control characters.
fn strip_edges(text: &str) -> String {
    text.trim_matches(|character: char| character <= ' ')
        .to_string()
}

/// UTF-16LE text up to its first zero unit.
fn utf16(data: &[u8]) -> String {
    let units: Vec<u16> = data
        .chunks_exact(2)
        .map(|pair| u16::from_le_bytes([pair[0], pair[1]]))
        .take_while(|&unit| unit != 0)
        .collect();

    String::from_utf16_lossy(&units)
}

/// True for an optional sign and digits.
fn is_valid_int(text: &str) -> bool {
    let digits = text.strip_prefix(['+', '-']).unwrap_or(text);

    !digits.is_empty() && digits.bytes().all(|byte| byte.is_ascii_digit())
}

impl Container {
    fn fail(&mut self, message: &str) {
        self.error = message.to_string();
        self.resources.clear();
    }

    fn failed(message: &str) -> Self {
        Self {
            resources: Vec::new(),
            error: message.to_string(),
        }
    }

    fn push(&mut self, name: String, bytes: &[u8], kind: String, id: i64) {
        self.resources.push(Resource {
            name,
            kind,
            id,
            bytes: bytes.to_vec(),
        });
    }

    /// The DAT archive: a directory of 12-byte names and data offsets.
    pub fn named_archive(data: &[u8]) -> Self {
        if data.len() < DIRECTORY_ENTRY_SIZE {
            return Self::failed("The asset directory is truncated.");
        }

        let first = u32_le(data, 12);

        if first < DIRECTORY_ENTRY_SIZE
            || !first.is_multiple_of(DIRECTORY_ENTRY_SIZE)
            || first > data.len()
            || first / DIRECTORY_ENTRY_SIZE > MAX_DIRECTORY_ENTRIES
        {
            return Self::failed("The asset directory has an invalid data offset.");
        }

        let mut result = Self::default();

        for index in 0..first / DIRECTORY_ENTRY_SIZE {
            let entry = index * DIRECTORY_ENTRY_SIZE;
            let raw = &data[entry..entry + DIRECTORY_NAME_SIZE];
            let name = strip_edges(&latin1(raw));
            let start = u32_le(data, entry + 12);
            let end = if entry + DIRECTORY_ENTRY_SIZE < first {
                u32_le(data, entry + 28)
            } else {
                data.len()
            };

            if name.is_empty()
                || start < first
                || end < start
                || !has_range(data, start, end - start)
            {
                return Self::failed(&format!("Invalid asset directory entry {index}."));
            }

            result.push(name, &data[start..end], String::new(), -1);
        }

        result
    }

    /// A Macintosh resource fork, alone or in AppleSingle, AppleDouble, or MacBinary.
    pub fn macintosh(data: &[u8]) -> Self {
        let mut fork = data;

        // AppleDouble and AppleSingle both identify the resource fork with entry 2
        if has_range(data, 0, 26) && [APPLE_DOUBLE, APPLE_SINGLE].contains(&u32_be(data, 0)) {
            let count = u16_be(data, 24);

            if !has_range(data, 26, count * APPLE_ENTRY_SIZE) {
                return Self::failed("The AppleDouble entry table is truncated.");
            }

            fork = &[];

            for index in 0..count {
                let entry = 26 + index * APPLE_ENTRY_SIZE;

                if u32_be(data, entry) != APPLE_RESOURCE_FORK {
                    continue;
                }

                let (offset, length) = (u32_be(data, entry + 4), u32_be(data, entry + 8));

                if !has_range(data, offset, length) {
                    return Self::failed("The Macintosh resource fork is truncated.");
                }

                fork = &data[offset..offset + length];
                break;
            }
        } else if has_range(data, 0, MAC_BINARY_HEADER)
            && data[0] == 0
            && (1..=63).contains(&data[1])
            && data[74] == 0
            && data[82] == 0
        {
            // MacBinary stores a padded data fork before its resource fork
            let offset = MAC_BINARY_HEADER
                + u32_be(data, 83).div_ceil(MAC_BINARY_HEADER) * MAC_BINARY_HEADER;
            let length = u32_be(data, 87);

            if length > 0 && has_range(data, offset, length) {
                fork = &data[offset..offset + length];
            }
        }

        Self::resource_fork(fork)
    }

    fn resource_fork(fork: &[u8]) -> Self {
        if !has_range(fork, 0, 16) {
            return Self::failed("No readable Macintosh resource fork was found.");
        }

        let (data_start, map_start) = (u32_be(fork, 0), u32_be(fork, 4));
        let (data_length, map_length) = (u32_be(fork, 8), u32_be(fork, 12));

        if !has_range(fork, data_start, data_length)
            || map_length < MAC_MAP_HEADER_SIZE
            || !has_range(fork, map_start, map_length)
        {
            return Self::failed("Invalid Macintosh resource map.");
        }

        let map_end = map_start + map_length;
        let type_start = map_start + u16_be(fork, map_start + 24);

        if type_start + 2 > map_end {
            return Self::failed("Invalid Macintosh type table.");
        }

        let types = u16_be(fork, type_start) + 1;

        if types > MAC_MAX_TYPES || type_start + 2 + types * MAC_TYPE_SIZE > map_end {
            return Self::failed("The Macintosh type table is truncated.");
        }

        let mut result = Self::default();

        for index in 0..types {
            let entry = type_start + 2 + index * MAC_TYPE_SIZE;
            let kind = latin1(&fork[entry..entry + 4]);
            let count = u16_be(fork, entry + 4) + 1;
            let references = type_start + u16_be(fork, entry + 6);

            if references + count * MAC_REFERENCE_SIZE > map_end {
                return Self::failed("The Macintosh reference list is truncated.");
            }

            for resource in 0..count {
                let reference = references + resource * MAC_REFERENCE_SIZE;
                let id = u16_be(fork, reference) as i64;
                let id = if id >= 32768 { id - 65536 } else { id };
                let relative = u32_be(fork, reference + 4) & 0x00ff_ffff;

                if relative + 4 > data_length {
                    return Self::failed("Invalid Macintosh resource offset.");
                }

                let start = data_start + relative;
                let length = u32_be(fork, start);

                if relative + 4 + length > data_length {
                    return Self::failed("The Macintosh resource data is truncated.");
                }

                result.push(
                    format!("{kind}/{id}"),
                    &fork[start + 4..start + 4 + length],
                    kind.clone(),
                    id,
                );
            }
        }

        result
    }

    /// The resources of a Windows NE or PE executable.
    pub fn windows(data: &[u8]) -> Self {
        if !has_range(data, 0, 64) || &data[..2] != b"MZ" {
            return Self::failed("No Windows executable header was found.");
        }

        let header = u32_le(data, 60);

        if !has_range(data, header, 64) {
            return Self::failed("The Windows executable header is truncated.");
        }

        let mut result = Self::default();

        if &data[header..header + 2] == b"NE" {
            result.read_ne(data, header);

            return result;
        }

        if u32_le(data, header) != PE_SIGNATURE || u16_le(data, header + 24) != PE32_MAGIC {
            return Self::failed("No supported Windows resource table was found.");
        }

        let section_count = u16_le(data, header + 6);
        let optional_size = u16_le(data, header + 20);
        let sections = header + 24 + optional_size;

        if optional_size < PE_MIN_OPTIONAL_SIZE
            || !has_range(data, header + 24, optional_size)
            || !has_range(data, sections, section_count * PE_SECTION_SIZE)
        {
            return Self::failed("The PE section table is truncated.");
        }

        let rva = u32_le(data, header + 24 + PE_RESOURCE_DIRECTORY);
        let root = pe_offset(data, sections, section_count, rva);

        match root {
            Some(root) if rva != 0 => {
                result.pe_directory(data, root, root, sections, section_count, &[], 0)
            }
            _ => return Self::failed("The executable contains no resource directory."),
        }

        result
    }

    fn read_ne(&mut self, data: &[u8], header: usize) {
        let table = header + u16_le(data, header + 36);
        let end = header + u16_le(data, header + 38);

        if !has_range(data, table, 2) || end < table + 2 || end > data.len() {
            return self.fail("The NE resource table is truncated.");
        }

        let shift = u16_le(data, table);

        if shift > NE_MAX_SHIFT {
            return self.fail("Invalid NE resource alignment.");
        }

        let mut cursor = table + 2;

        while cursor + 2 <= end {
            let type_id = u16_le(data, cursor);

            if type_id == 0 {
                return;
            }

            if cursor + 8 > end {
                return self.fail("The NE type record is truncated.");
            }

            let count = u16_le(data, cursor + 2);
            let kind = ne_name(data, table, end, type_id);
            cursor += 8;

            if cursor + count * NE_RECORD_SIZE > end {
                return self.fail("The NE resource list is truncated.");
            }

            for index in 0..count {
                let reference = cursor + index * NE_RECORD_SIZE;
                let start = u16_le(data, reference) << shift;
                let size = u16_le(data, reference + 2) << shift;
                let id = u16_le(data, reference + 6);

                if !has_range(data, start, size) {
                    return self.fail("The NE resource data is truncated.");
                }

                let number = if id & 0x8000 != 0 {
                    (id & 0x7fff) as i64
                } else {
                    -1
                };
                self.push(
                    ne_name(data, table, end, id),
                    &data[start..start + size],
                    kind.clone(),
                    number,
                );
            }

            cursor += count * NE_RECORD_SIZE;
        }

        self.fail("The NE resource table has no terminator.");
    }

    #[allow(clippy::too_many_arguments)]
    fn pe_directory(
        &mut self,
        data: &[u8],
        root: usize,
        directory: usize,
        sections: usize,
        section_count: usize,
        names: &[String],
        depth: usize,
    ) {
        if !self.error.is_empty() {
            return;
        }

        if depth > PE_MAX_DEPTH || !has_range(data, directory, 16) {
            return self.fail("Invalid PE resource directory.");
        }

        let count = u16_le(data, directory + 12) + u16_le(data, directory + 14);

        if !has_range(data, directory + 16, count * 8) {
            return self.fail("The PE resource table is truncated.");
        }

        for index in 0..count {
            let entry = directory + 16 + index * 8;
            let identifier = u32_le(data, entry);
            let target = u32_le(data, entry + 4);
            let mut name = identifier.to_string();

            if identifier & PE_HIGH_BIT != 0 {
                let text_start = root + (identifier & !PE_HIGH_BIT);

                if !has_range(data, text_start, 2)
                    || !has_range(data, text_start + 2, u16_le(data, text_start) * 2)
                {
                    return self.fail("The PE resource name is truncated.");
                }

                name = utf16(&data[text_start + 2..text_start + 2 + u16_le(data, text_start) * 2]);
            }

            let mut path = names.to_vec();
            path.push(name);

            // a failed subdirectory leaves its error; the next entries still run, as in the scripts
            if target & PE_HIGH_BIT != 0 {
                self.pe_directory(
                    data,
                    root,
                    root + (target & !PE_HIGH_BIT),
                    sections,
                    section_count,
                    &path,
                    depth + 1,
                );
                continue;
            }

            let record = root + target;

            if path.len() != 3 || !has_range(data, record, 16) {
                return self.fail("Invalid PE resource data record.");
            }

            let start = pe_offset(data, sections, section_count, u32_le(data, record));
            let size = u32_le(data, record + 4);

            let Some(start) = start.filter(|&start| has_range(data, start, size)) else {
                return self.fail("The PE resource data is truncated.");
            };

            let id = if is_valid_int(&path[1]) {
                path[1].parse::<i64>().unwrap_or(0)
            } else {
                -1
            };
            self.push(
                path[1].clone(),
                &data[start..start + size],
                path[0].clone(),
                id,
            );
        }
    }
}

fn ne_name(data: &[u8], table: usize, end: usize, value: usize) -> String {
    if value & 0x8000 != 0 {
        return (value & 0x7fff).to_string();
    }

    let start = table + value;

    if start >= end || start + 1 + usize::from(data[start]) > end {
        return String::new();
    }

    latin1(&data[start + 1..start + 1 + usize::from(data[start])])
}

fn pe_offset(data: &[u8], sections: usize, count: usize, rva: usize) -> Option<usize> {
    (0..count).find_map(|index| {
        let entry = sections + index * PE_SECTION_SIZE;
        let (address, length, start) = (
            u32_le(data, entry + 12),
            u32_le(data, entry + 16),
            u32_le(data, entry + 20),
        );

        (rva >= address && rva - address < length && has_range(data, start, length))
            .then(|| start + rva - address)
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn a_named_archive_lists_its_records() {
        let mut data = vec![0; 32];
        data[..4].copy_from_slice(b"A.X\0");
        data[12..16].copy_from_slice(&32u32.to_le_bytes());
        data[16..20].copy_from_slice(b" B  ");
        data[28..32].copy_from_slice(&34u32.to_le_bytes());
        data.extend_from_slice(b"aabb");
        let archive = Container::named_archive(&data);
        let names: Vec<(&str, &[u8])> = archive
            .resources
            .iter()
            .map(|resource| (resource.name.as_str(), resource.bytes.as_slice()))
            .collect();
        assert_eq!(
            names,
            vec![("A.X", b"aa".as_slice()), ("B", b"bb".as_slice())]
        );
        assert_eq!(
            Container::named_archive(&data[..10]).error,
            "The asset directory is truncated."
        );
    }

    #[test]
    fn executables_need_a_resource_table() {
        assert_eq!(
            Container::windows(b"ZM").error,
            "No Windows executable header was found."
        );
        assert_eq!(
            Container::macintosh(&[0; 8]).error,
            "No readable Macintosh resource fork was found."
        );
    }
}
