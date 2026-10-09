//! The ZIP reader. Offsets are `i64`, so a field that names a position before
//! the start of the archive fails a bounds check instead of wrapping.

use super::{
    ABSOLUTE_MAX_BYTES, Archive, CENTRAL_SIGNATURE, CENTRAL_SIZE, DEFLATE, DEFLATE_OPTIONS, DESCRIPTOR_FLAG, DESCRIPTOR_SIGNATURE,
    END_SIGNATURE, END_SIZE, Entry, LOCAL_SIGNATURE, LOCAL_SIZE, MAX_VERSION, MEMBER_OVERHEAD, STORED, ZIP16_MAX, ZIP32_MAX,
    ZIP64_END_SIGNATURE, ZIP64_END_SIZE, ZIP64_EXTRA, ZIP64_LOCATOR_SIGNATURE, ZIP64_LOCATOR_SIZE, inflate, valid_path,
};
use crate::crc32;
use std::collections::HashSet;

/// The archive members in central directory order. Every member and the total
/// output size are checked before decompression.
pub fn decode(bytes: &[u8], max_file_bytes: i64, max_data_bytes: i64) -> Result<Archive, String> {
    let size = bytes.len() as i64;

    if size < END_SIZE
        || size > max_file_bytes
        || max_file_bytes > ABSOLUTE_MAX_BYTES
        || !(0..=ABSOLUTE_MAX_BYTES).contains(&max_data_bytes)
    {
        return Err("The ZIP size is invalid.".into());
    }

    let reader = Reader { bytes };
    let end = reader.find_end().ok_or("The ZIP directory is missing.")?;

    let directory = reader
        .directory(end, max_file_bytes)
        .ok_or("The ZIP directory bounds or disk fields are invalid.")?;

    let mut entries: Vec<Entry> = Vec::new();
    let mut paths: HashSet<String> = HashSet::new();
    let mut position = directory.offset;
    let mut total = 0_i64;

    for _ in 0..directory.count {
        if position + CENTRAL_SIZE > directory.end || reader.u32(position) != i64::from(CENTRAL_SIGNATURE) {
            return Err("The ZIP directory entry is invalid.".into());
        }

        let mut entry = Entry {
            flags: reader.u16(position + 8) as u16,
            method: reader.u16(position + 10) as u16,
            crc: reader.u32(position + 16) as u32,
            compressed_size: reader.u32(position + 20),
            size: reader.u32(position + 24),
            local_offset: reader.u32(position + 42),
            ..Entry::default()
        };

        let name_size = reader.u16(position + 28);
        let extra_size = reader.u16(position + 30);
        let comment_size = reader.u16(position + 32);
        let next = position + CENTRAL_SIZE + name_size + extra_size + comment_size;

        if next > directory.end || reader.u16(position + 6) > MAX_VERSION {
            return Err("The ZIP member header is unsupported.".into());
        }

        entry.name = reader.slice(position + CENTRAL_SIZE, position + CENTRAL_SIZE + name_size).to_vec();

        if entry.name.contains(&0) {
            return Err("The ZIP member path contains a null byte.".into());
        }

        // invalid UTF-8 does not survive a round trip through a string
        entry.path = String::from_utf8(entry.name.clone()).unwrap_or_default();

        if entry.path.as_bytes() != entry.name.as_slice() || !valid_path(&entry.path) || paths.contains(&entry.path) {
            return Err("The ZIP member path is invalid or repeated.".into());
        }

        let extra = reader.extra(position + CENTRAL_SIZE + name_size, extra_size);

        let resolved = extra
            .as_ref()
            .is_ok_and(|extra| resolve_zip64(&mut entry, extra, reader.u16(position + 34), max_file_bytes));

        if !resolved {
            return Err("The ZIP member extra data is invalid.".into());
        }

        if !supported(&entry) {
            return Err("The ZIP member encoding is unsupported.".into());
        }

        paths.insert(entry.path.clone());
        total += entry.size;

        if total > max_data_bytes {
            return Err("The decoded ZIP exceeds the size limit.".into());
        }

        if !reader.local(&mut entry, directory.offset, max_file_bytes) {
            return Err("The ZIP local header does not match its directory.".into());
        }

        entries.push(entry);
        position = next;
    }

    if position != directory.end {
        return Err("The ZIP directory has trailing data.".into());
    }

    let mut by_offset: Vec<usize> = (0..entries.len()).collect();
    by_offset.sort_by_key(|index| entries[*index].local_offset);
    position = 0;

    for index in &by_offset {
        if entries[*index].local_offset != position {
            return Err("The ZIP members overlap or have unlisted data.".into());
        }

        position = entries[*index].end_offset;
    }

    if position != directory.offset {
        return Err("The ZIP data bounds are invalid.".into());
    }

    // decompress in data order, then list the members in directory order
    let mut decoded: Vec<Vec<u8>> = vec![Vec::new(); entries.len()];

    for index in by_offset {
        let entry = &entries[index];
        let raw = reader.slice(entry.data_offset, entry.data_offset + entry.compressed_size);

        decoded[index] = if entry.method == STORED {
            if crc32::calculate(raw) != entry.crc {
                return Err("The ZIP member checksum is invalid.".into());
            }

            raw.to_vec()
        } else {
            inflate::member(raw, entry.crc, entry.size)?
        };
    }

    let members = entries.into_iter().map(|entry| entry.path).zip(decoded).collect();

    Ok(Archive { members })
}

fn supported(entry: &Entry) -> bool {
    entry.flags & !super::ALLOWED_FLAGS == 0
        && (entry.method == DEFLATE
            || (entry.method == STORED && entry.flags & DEFLATE_OPTIONS == 0 && entry.size == entry.compressed_size))
}

/// Replaces the fields that hold the ZIP64 marker with the values of the extra
/// field, in the order of the specification.
fn resolve_zip64(entry: &mut Entry, extra: &[u8], disk: i64, max_file_bytes: i64) -> bool {
    let reader = Reader { bytes: extra };
    let mut offset = 0_i64;

    for field in [&mut entry.size, &mut entry.compressed_size, &mut entry.local_offset] {
        if *field != ZIP32_MAX {
            continue;
        }

        if offset + 8 > extra.len() as i64 {
            return false;
        }

        let value = reader.u64(offset);

        if value < 0 || value > max_file_bytes {
            return false;
        }

        *field = value;
        offset += 8;
    }

    if disk == ZIP16_MAX {
        return offset + 4 <= extra.len() as i64 && reader.u32(offset) == 0;
    }

    disk == 0
}

struct Directory {
    count: i64,
    size: i64,
    offset: i64,
    end: i64,
}

struct Reader<'a> {
    bytes: &'a [u8],
}

impl Reader<'_> {
    fn field<const N: usize>(&self, offset: i64) -> Option<[u8; N]> {
        let start = usize::try_from(offset).ok()?;

        self.bytes
            .get(start..start.checked_add(N)?)
            .map(|slice| slice.try_into().expect("N bytes"))
    }

    // out-of-bounds reads give 0, as the reads of Godot byte arrays do
    fn u16(&self, offset: i64) -> i64 {
        self.field::<2>(offset).map_or(0, |bytes| i64::from(u16::from_le_bytes(bytes)))
    }

    fn u32(&self, offset: i64) -> i64 {
        self.field::<4>(offset).map_or(0, |bytes| i64::from(u32::from_le_bytes(bytes)))
    }

    // a value above the signed range reads as negative and fails the range checks
    fn u64(&self, offset: i64) -> i64 {
        self.field::<8>(offset).map_or(0, i64::from_le_bytes)
    }

    fn slice(&self, start: i64, end: i64) -> &[u8] {
        let length = self.bytes.len() as i64;
        let start = start.clamp(0, length) as usize;
        let end = end.clamp(0, length) as usize;

        &self.bytes[start..end.max(start)]
    }

    fn find_end(&self) -> Option<i64> {
        let size = self.bytes.len() as i64;
        let last = size - END_SIZE;
        let first = (size - END_SIZE - 65535 - 1).max(-1);
        let mut offset = last;

        while offset > first {
            if self.u32(offset) == i64::from(END_SIGNATURE) && offset + END_SIZE + self.u16(offset + 20) == size {
                return Some(offset);
            }

            offset -= 1;
        }

        None
    }

    /// The ZIP64 extra field of a header, or empty bytes.
    fn extra(&self, offset: i64, size: i64) -> Result<&[u8], ()> {
        let mut found: Option<&[u8]> = None;
        let end = offset + size;
        let mut position = offset;

        while position < end {
            if position + 4 > end {
                return Err(());
            }

            let tag = self.u16(position);
            let length = self.u16(position + 2);

            if position + 4 + length > end {
                return Err(());
            }

            if tag == i64::from(ZIP64_EXTRA) {
                if found.is_some() {
                    return Err(());
                }

                found = Some(self.slice(position + 4, position + 4 + length));
            }

            position += 4 + length;
        }

        Ok(found.unwrap_or(&[]))
    }

    fn directory(&self, end: i64, max_file_bytes: i64) -> Option<Directory> {
        let mut result = Directory {
            count: self.u16(end + 10),
            size: self.u32(end + 12),
            offset: self.u32(end + 16),
            end,
        };

        if self.u16(end + 4) != 0 || self.u16(end + 6) != 0 || self.u16(end + 8) != result.count {
            return None;
        }

        let locator = end - ZIP64_LOCATOR_SIZE;
        let has_zip64 = locator >= 0 && self.u32(locator) == i64::from(ZIP64_LOCATOR_SIGNATURE);

        if result.count == ZIP16_MAX || result.size == ZIP32_MAX || result.offset == ZIP32_MAX || has_zip64 {
            if !has_zip64 || self.u32(locator + 4) != 0 || self.u32(locator + 16) != 1 {
                return None;
            }

            let position = self.u64(locator + 8);

            if position < 0 || position > locator - ZIP64_END_SIZE || self.u32(position) != i64::from(ZIP64_END_SIGNATURE) {
                return None;
            }

            let record_size = self.u64(position + 4);

            if record_size < 44 || record_size > max_file_bytes || position + 12 + record_size != locator {
                return None;
            }

            if self.u16(position + 14) > MAX_VERSION || self.u32(position + 16) != 0 || self.u32(position + 20) != 0 {
                return None;
            }

            let count = self.u64(position + 32);
            let size = self.u64(position + 40);
            let offset = self.u64(position + 48);

            if count < 0
                || count > max_file_bytes / MEMBER_OVERHEAD
                || count != self.u64(position + 24)
                || size < 0
                || size > max_file_bytes
                || offset < 0
                || offset > max_file_bytes
            {
                return None;
            }

            if (result.count != ZIP16_MAX && result.count != count)
                || (result.size != ZIP32_MAX && result.size != size)
                || (result.offset != ZIP32_MAX && result.offset != offset)
            {
                return None;
            }

            result.count = count;
            result.size = size;
            result.offset = offset;
            result.end = position;
        }

        if result.offset + result.size != result.end
            || result.count * CENTRAL_SIZE > result.size
            || result.count > max_file_bytes / MEMBER_OVERHEAD
        {
            return None;
        }

        Some(result)
    }

    /// Checks the local header of `entry` against its directory entry and finds
    /// the member data and its end, after an optional data descriptor.
    fn local(&self, entry: &mut Entry, directory_offset: i64, max_file_bytes: i64) -> bool {
        let offset = entry.local_offset;

        if offset + LOCAL_SIZE > directory_offset || self.u32(offset) != i64::from(LOCAL_SIGNATURE) {
            return false;
        }

        if self.u16(offset + 4) > MAX_VERSION
            || self.u16(offset + 6) != i64::from(entry.flags)
            || self.u16(offset + 8) != i64::from(entry.method)
        {
            return false;
        }

        let name_size = self.u16(offset + 26);
        let extra_size = self.u16(offset + 28);
        entry.data_offset = offset + LOCAL_SIZE + name_size + extra_size;
        entry.end_offset = entry.data_offset + entry.compressed_size;

        if entry.end_offset > directory_offset || name_size != entry.name.len() as i64 {
            return false;
        }

        if self.slice(offset + LOCAL_SIZE, offset + LOCAL_SIZE + name_size) != entry.name.as_slice() {
            return false;
        }

        let Ok(extra) = self.extra(offset + LOCAL_SIZE + name_size, extra_size) else {
            return false;
        };

        let mut local = Entry {
            crc: self.u32(offset + 14) as u32,
            compressed_size: self.u32(offset + 18),
            size: self.u32(offset + 22),
            ..Entry::default()
        };

        let zip64 = local.size == ZIP32_MAX || local.compressed_size == ZIP32_MAX;

        if !resolve_zip64(&mut local, extra, 0, max_file_bytes) {
            return false;
        }

        if entry.flags & DESCRIPTOR_FLAG == 0 {
            return local.crc == entry.crc && local.compressed_size == entry.compressed_size && local.size == entry.size;
        }

        if (local.crc != 0 && local.crc != entry.crc)
            || (local.compressed_size != 0 && local.compressed_size != entry.compressed_size)
            || (local.size != 0 && local.size != entry.size)
        {
            return false;
        }

        let descriptor = entry.end_offset;
        let fields_size = if zip64 { 20 } else { 12 };

        // The optional signature can also be a valid CRC. Check both interpretations.
        if descriptor + 4 <= directory_offset
            && self.u32(descriptor) == i64::from(DESCRIPTOR_SIGNATURE)
            && self.descriptor_matches(descriptor + 4, entry, zip64, directory_offset)
        {
            entry.end_offset = descriptor + 4 + fields_size;

            return true;
        }

        if self.descriptor_matches(descriptor, entry, zip64, directory_offset) {
            entry.end_offset = descriptor + fields_size;

            return true;
        }

        false
    }

    fn descriptor_matches(&self, offset: i64, entry: &Entry, zip64: bool, limit: i64) -> bool {
        if offset + if zip64 { 20 } else { 12 } > limit || self.u32(offset) != i64::from(entry.crc) {
            return false;
        }

        if zip64 {
            return self.u64(offset + 4) == entry.compressed_size && self.u64(offset + 12) == entry.size;
        }

        self.u32(offset + 4) == entry.compressed_size && self.u32(offset + 8) == entry.size
    }
}
