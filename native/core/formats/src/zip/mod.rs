//! Byte-only ZIP container. No files are extracted to disk. Callers set the size
//! limits. The encoder writes members in the given order with fixed timestamps.
//!
//! The reader accepts STORED and DEFLATE members, data descriptors and ZIP64
//! records. It checks every member against its CRC-32 and size, and refuses
//! overlapping members, unlisted data and unsafe paths.

mod inflate;
mod read;

#[cfg(test)]
mod tests;

use crate::crc32;

pub use read::decode;

/// ZIP64 fields can name larger sizes; these bound what one archive may use.
pub const ABSOLUTE_MAX_BYTES: i64 = 1024 * 1024 * 1024;

const LOCAL_SIGNATURE: u32 = 0x0403_4b50;
const CENTRAL_SIGNATURE: u32 = 0x0201_4b50;
const END_SIGNATURE: u32 = 0x0605_4b50;
const DESCRIPTOR_SIGNATURE: u32 = 0x0807_4b50;
const ZIP64_END_SIGNATURE: u32 = 0x0606_4b50;
const ZIP64_LOCATOR_SIGNATURE: u32 = 0x0706_4b50;

const LOCAL_SIZE: i64 = 30;
const CENTRAL_SIZE: i64 = 46;
const END_SIZE: i64 = 22;
const ZIP64_END_SIZE: i64 = 56;
const ZIP64_LOCATOR_SIZE: i64 = 20;
const ZIP16_MAX: i64 = 0xffff;
const ZIP32_MAX: i64 = 0xffff_ffff;

/// The smallest archive bytes that one member needs.
const MEMBER_OVERHEAD: i64 = LOCAL_SIZE + CENTRAL_SIZE + 2;

const STORED: u16 = 0;
const DEFLATE: u16 = 8;
const UTF8_FLAG: u16 = 0x0800;
const DESCRIPTOR_FLAG: u16 = 0x0008;
const DEFLATE_OPTIONS: u16 = 0x0006;
const ALLOWED_FLAGS: u16 = UTF8_FLAG | DESCRIPTOR_FLAG | DEFLATE_OPTIONS;
const ZIP64_EXTRA: u16 = 0x0001;

/// The newest ZIP version that the reader accepts (4.5, ZIP64).
const MAX_VERSION: i64 = 45;

/// The version that the writer stores (2.0, DEFLATE).
const WRITE_VERSION: u16 = 20;

/// 1980-01-01 in MS-DOS date format, fixed for deterministic output.
const FIXED_DATE: u16 = 33;

/// A final fixed-Huffman block with only the end-of-block code.
const EMPTY_DEFLATE: [u8; 2] = [0x03, 0x00];

/// The DEFLATE level of the writer: the best compression.
const DEFLATE_LEVEL: u8 = 9;

/// The members of a decoded archive in central directory order.
#[derive(Debug, Default, Clone, PartialEq, Eq)]
pub struct Archive {
    pub members: Vec<(String, Vec<u8>)>,
}

impl Archive {
    pub fn get(&self, path: &str) -> Option<&[u8]> {
        self.members.iter().find(|(name, _)| name == path).map(|(_, data)| data.as_slice())
    }
}

/// Writes `members` in their order. With `always_deflate`, every member uses
/// DEFLATE, even when stored bytes would be smaller.
pub fn encode(members: &[(String, &[u8])], max_file_bytes: i64, max_data_bytes: i64, always_deflate: bool) -> Result<Vec<u8>, String> {
    if !(0..=ABSOLUTE_MAX_BYTES).contains(&max_file_bytes) || !(0..=ABSOLUTE_MAX_BYTES).contains(&max_data_bytes) {
        return Err("The ZIP size limit is invalid.".into());
    }

    if members.len() as i64 > max_file_bytes / MEMBER_OVERHEAD {
        return Err("The ZIP member list is invalid or too long.".into());
    }

    let count = members.len() as i64;
    let mut total = 0_i64;
    let mut header_size = END_SIZE
        + if count >= ZIP16_MAX {
            ZIP64_END_SIZE + ZIP64_LOCATOR_SIZE
        } else {
            0
        };

    for (path, data) in members {
        if !valid_path(path) || path.len() > 65535 {
            return Err("The ZIP member path is invalid.".into());
        }

        total += data.len() as i64;
        header_size += LOCAL_SIZE + CENTRAL_SIZE + path.len() as i64 * 2;

        if total > max_data_bytes || header_size > max_file_bytes {
            return Err("The ZIP exceeds the size limit.".into());
        }
    }

    let mut bytes = Vec::new();
    let mut directory = Vec::new();
    let mut payload_size = 0_i64;

    for (path, data) in members {
        let mut entry = Entry {
            name: path.as_bytes().to_vec(),
            flags: UTF8_FLAG,
            size: data.len() as i64,
            local_offset: bytes.len() as i64,
            ..Entry::default()
        };

        let deflated;

        let payload: &[u8] = if data.is_empty() && always_deflate {
            entry.method = DEFLATE;

            &EMPTY_DEFLATE
        } else if data.is_empty() {
            data
        } else {
            entry.crc = crc32::calculate(data);
            deflated = miniz_oxide::deflate::compress_to_vec(data, DEFLATE_LEVEL);

            if always_deflate || deflated.len() < data.len() {
                entry.method = DEFLATE;

                &deflated
            } else {
                data
            }
        };

        entry.compressed_size = payload.len() as i64;
        payload_size += payload.len() as i64;

        if header_size + payload_size > max_file_bytes {
            return Err("The encoded ZIP exceeds the file size limit.".into());
        }

        bytes.extend_from_slice(&local_header(&entry));
        bytes.extend_from_slice(&entry.name);
        bytes.extend_from_slice(payload);
        directory.extend_from_slice(&central_header(&entry));
        directory.extend_from_slice(&entry.name);
    }

    let directory_offset = bytes.len();
    let mut end = vec![0_u8; END_SIZE as usize];
    put_u32(&mut end, 0, END_SIGNATURE);
    put_u16(&mut end, 8, count.min(ZIP16_MAX) as u16);
    put_u16(&mut end, 10, count.min(ZIP16_MAX) as u16);
    put_u32(&mut end, 12, directory.len() as u32);
    put_u32(&mut end, 16, directory_offset as u32);
    bytes.extend_from_slice(&directory);

    if count >= ZIP16_MAX {
        let position = bytes.len();
        bytes.extend_from_slice(&zip64_end(count, directory.len() as i64, directory_offset as i64, position as i64));
    }

    bytes.extend_from_slice(&end);

    Ok(bytes)
}

/// A member path: relative, with `/` separators, and no empty, `.` or `..` part.
pub fn valid_path(path: &str) -> bool {
    if path.is_empty() || path.contains('\\') || path.contains(':') || path.contains('\0') {
        return false;
    }

    path.split('/').all(|part| !part.is_empty() && part != "." && part != "..")
}

#[derive(Debug, Default, Clone)]
struct Entry {
    path: String,
    name: Vec<u8>,
    flags: u16,
    method: u16,
    crc: u32,
    compressed_size: i64,
    size: i64,
    local_offset: i64,
    data_offset: i64,
    end_offset: i64,
}

fn local_header(entry: &Entry) -> Vec<u8> {
    let mut bytes = vec![0_u8; LOCAL_SIZE as usize];
    put_u32(&mut bytes, 0, LOCAL_SIGNATURE);
    put_u16(&mut bytes, 4, WRITE_VERSION);
    put_u16(&mut bytes, 6, entry.flags);
    put_u16(&mut bytes, 8, entry.method);
    put_u16(&mut bytes, 12, FIXED_DATE);
    put_u32(&mut bytes, 14, entry.crc);
    put_u32(&mut bytes, 18, entry.compressed_size as u32);
    put_u32(&mut bytes, 22, entry.size as u32);
    put_u16(&mut bytes, 26, entry.name.len() as u16);

    bytes
}

fn central_header(entry: &Entry) -> Vec<u8> {
    let mut bytes = vec![0_u8; CENTRAL_SIZE as usize];
    put_u32(&mut bytes, 0, CENTRAL_SIGNATURE);
    put_u16(&mut bytes, 4, WRITE_VERSION);
    put_u16(&mut bytes, 6, WRITE_VERSION);
    put_u16(&mut bytes, 8, entry.flags);
    put_u16(&mut bytes, 10, entry.method);
    put_u16(&mut bytes, 14, FIXED_DATE);
    put_u32(&mut bytes, 16, entry.crc);
    put_u32(&mut bytes, 20, entry.compressed_size as u32);
    put_u32(&mut bytes, 24, entry.size as u32);
    put_u16(&mut bytes, 28, entry.name.len() as u16);
    put_u32(&mut bytes, 42, entry.local_offset as u32);

    bytes
}

fn zip64_end(count: i64, size: i64, offset: i64, position: i64) -> Vec<u8> {
    let mut bytes = vec![0_u8; (ZIP64_END_SIZE + ZIP64_LOCATOR_SIZE) as usize];
    put_u32(&mut bytes, 0, ZIP64_END_SIGNATURE);
    put_u64(&mut bytes, 4, 44);
    put_u16(&mut bytes, 12, MAX_VERSION as u16);
    put_u16(&mut bytes, 14, MAX_VERSION as u16);
    put_u64(&mut bytes, 24, count as u64);
    put_u64(&mut bytes, 32, count as u64);
    put_u64(&mut bytes, 40, size as u64);
    put_u64(&mut bytes, 48, offset as u64);

    let locator = ZIP64_END_SIZE as usize;
    put_u32(&mut bytes, locator, ZIP64_LOCATOR_SIGNATURE);
    put_u64(&mut bytes, locator + 8, position as u64);
    put_u32(&mut bytes, locator + 16, 1);

    bytes
}

fn put_u16(bytes: &mut [u8], offset: usize, value: u16) {
    bytes[offset..offset + 2].copy_from_slice(&value.to_le_bytes());
}

fn put_u32(bytes: &mut [u8], offset: usize, value: u32) {
    bytes[offset..offset + 4].copy_from_slice(&value.to_le_bytes());
}

fn put_u64(bytes: &mut [u8], offset: usize, value: u64) {
    bytes[offset..offset + 8].copy_from_slice(&value.to_le_bytes());
}
