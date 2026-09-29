//! The parts that XMIC, XTHG, and XSGN share: the 24-byte collection header,
//! the per-slot text index and UTF-8 text section, and the extension section.

use super::wire::{Reader, put_len, put_u16, put_u32};

/// The first binary layout schema of the named collections.
pub const SCHEMA_VERSION: u32 = 1;
pub const HEADER_SIZE: usize = 24;
pub const TEXT_INDEX_SIZE: usize = 8;
pub const MAX_NAME_CODE_POINTS: usize = 64;
pub const MAX_NAME_BYTES: usize = 256;
pub const EXTENSION_BLOCK_HEADER: usize = 8;

/// The six u32 fields at the start of XMIC.bin, XTHG.bin, and XSGN.bin.
#[derive(Clone, Copy, Debug, Default, PartialEq, Eq)]
pub struct Header {
    pub schema_version: u32,
    pub capacity: u32,
    pub active_records: u32,
    pub record_stride: u32,
    pub text_bytes: u32,
    pub extension_bytes: u32,
}

impl Header {
    pub fn read(reader: &mut Reader, stride: u32, name: &str) -> Result<Self, String> {
        let header = Self {
            schema_version: reader.u32()?,
            capacity: reader.u32()?,
            active_records: reader.u32()?,
            record_stride: reader.u32()?,
            text_bytes: reader.u32()?,
            extension_bytes: reader.u32()?,
        };

        if header.schema_version != SCHEMA_VERSION {
            return Err(format!(
                "{} uses layout schema {}; this version reads schema {}",
                name, header.schema_version, SCHEMA_VERSION
            ));
        }

        if header.record_stride != stride {
            return Err(format!("{} record stride is {}; expected {}", name, header.record_stride, stride));
        }

        if header.active_records > header.capacity {
            return Err(format!("{} has more active records than slots", name));
        }

        Ok(header)
    }

    pub fn write(&self, output: &mut Vec<u8>) {
        put_u32(output, self.schema_version);
        put_u32(output, self.capacity);
        put_u32(output, self.active_records);
        put_u32(output, self.record_stride);
        put_u32(output, self.text_bytes);
        put_u32(output, self.extension_bytes);
    }
}

/// Check one record-owned name. Empty text is valid here; callers that need
/// text, such as signs, check that separately.
pub fn check_name(text: &str) -> Result<(), String> {
    if text.len() > MAX_NAME_BYTES {
        return Err(format!("Name has {} UTF-8 bytes; the limit is {}", text.len(), MAX_NAME_BYTES));
    }

    let code_points = text.chars().count();

    if code_points > MAX_NAME_CODE_POINTS {
        return Err(format!(
            "Name has {} code points; the limit is {}",
            code_points, MAX_NAME_CODE_POINTS
        ));
    }

    if text.contains('\0') {
        return Err("Name contains a NUL character".into());
    }

    Ok(())
}

/// Encode one text index entry per name and the packed text. Text is packed by
/// slot. An empty name has offset, length, and count zero.
pub fn encode_texts(names: &[String]) -> Result<(Vec<u8>, Vec<u8>), String> {
    let mut index = Vec::with_capacity(names.len() * TEXT_INDEX_SIZE);
    let mut text = Vec::new();

    for (slot, name) in names.iter().enumerate() {
        check_name(name).map_err(|error| format!("Slot {}: {}", slot, error))?;

        if name.is_empty() {
            put_u32(&mut index, 0);
            put_u16(&mut index, 0);
            put_u16(&mut index, 0);
            continue;
        }

        put_len(&mut index, text.len());
        put_u16(&mut index, name.len() as u16);
        put_u16(&mut index, name.chars().count() as u16);
        text.extend_from_slice(name.as_bytes());
    }

    Ok((index, text))
}

/// Decode the text of `count` slots. Nonempty text must be packed by slot with
/// no gaps or unused bytes, as `encode_texts` writes it.
pub fn decode_texts(index: &[u8], text: &[u8], count: usize, name: &str) -> Result<Vec<String>, String> {
    let mut reader = Reader::new(index);
    let mut result = Vec::with_capacity(count);
    let mut position = 0usize;

    for slot in 0..count {
        let offset = reader.u32()? as usize;
        let length = reader.u16()? as usize;
        let code_points = reader.u16()? as usize;

        if length == 0 {
            if offset != 0 || code_points != 0 {
                return Err(format!("{} slot {} has an empty name with a nonzero offset or count", name, slot));
            }

            result.push(String::new());
            continue;
        }

        if offset != position || offset + length > text.len() {
            return Err(format!("{} slot {} text is outside the packed text section", name, slot));
        }

        let value =
            std::str::from_utf8(&text[offset..offset + length]).map_err(|_| format!("{} slot {} text is not valid UTF-8", name, slot))?;

        if value.chars().count() != code_points {
            return Err(format!("{} slot {} code-point count does not match its text", name, slot));
        }

        check_name(value).map_err(|error| format!("{} slot {}: {}", name, slot, error))?;
        result.push(value.to_string());
        position += length;
    }

    if position != text.len() {
        return Err(format!("{} text section has {} unused bytes", name, text.len() - position));
    }

    Ok(result)
}

/// One tagged block of the extension section. Unknown tags are kept in order.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct ExtensionBlock {
    pub tag: [u8; 4],
    pub data: Vec<u8>,
}

pub fn encode_extension(blocks: &[ExtensionBlock]) -> Vec<u8> {
    let mut output = Vec::new();

    for block in blocks {
        output.extend_from_slice(&block.tag);
        put_len(&mut output, block.data.len());
        output.extend_from_slice(&block.data);
    }

    output
}

pub fn decode_extension(bytes: &[u8], name: &str) -> Result<Vec<ExtensionBlock>, String> {
    let mut reader = Reader::new(bytes);
    let mut blocks = Vec::new();

    while reader.remaining() > 0 {
        if reader.remaining() < EXTENSION_BLOCK_HEADER {
            return Err(format!("{} extension section ends inside a block header", name));
        }

        let tag_bytes = reader.bytes(4)?;
        let length = reader
            .length()
            .map_err(|_| format!("{} extension block exceeds its section", name))?;
        let tag = [tag_bytes[0], tag_bytes[1], tag_bytes[2], tag_bytes[3]];

        if !tag.iter().all(|byte| (0x20..=0x7e).contains(byte)) {
            return Err(format!("{} extension block tag is not printable ASCII", name));
        }

        blocks.push(ExtensionBlock {
            tag,
            data: reader.bytes(length)?.to_vec(),
        });
    }

    Ok(blocks)
}

/// Read the text index, text, and extension sections that follow the fixed
/// records, and check that they end the entry.
pub fn read_tail(reader: &mut Reader, header: &Header, name: &str) -> Result<(Vec<String>, Vec<ExtensionBlock>), String> {
    let count = header.capacity as usize;
    let index = reader.bytes(count * TEXT_INDEX_SIZE)?;
    let text = reader.bytes(header.text_bytes as usize)?;
    let names = decode_texts(index, text, count, name)?;
    let extension = decode_extension(reader.bytes(header.extension_bytes as usize)?, name)?;

    if reader.remaining() != 0 {
        return Err(format!("{} has {} bytes after its extension section", name, reader.remaining()));
    }

    Ok((names, extension))
}

/// Check that a fixed-size entry section fits before reading it, so that a
/// corrupt capacity cannot request a huge allocation.
pub fn require(reader: &Reader, count: usize, stride: usize, name: &str) -> Result<(), String> {
    match count.checked_mul(stride) {
        Some(bytes) if bytes <= reader.remaining() => Ok(()),
        _ => Err(format!("{} capacity {} does not fit in the entry", name, count)),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn names_follow_code_point_and_byte_limits() {
        assert!(check_name("").is_ok());
        assert!(check_name("a").is_ok());
        assert!(check_name(&"a".repeat(64)).is_ok());
        assert!(check_name(&"a".repeat(65)).is_err());
        // four-byte characters: 64 of them are exactly 256 bytes
        assert!(check_name(&"\u{1F600}".repeat(64)).is_ok());
        assert!(check_name(&"\u{1F600}".repeat(65)).is_err());
        assert!(check_name("a\0b").is_err());
    }

    #[test]
    fn text_section_round_trips_and_packs_by_slot() {
        let names = vec![
            String::new(),
            "Main Street".to_string(),
            String::new(),
            "Llama \u{1F999}".to_string(),
        ];
        let (index, text) = encode_texts(&names).unwrap();
        assert_eq!(index.len(), 4 * TEXT_INDEX_SIZE);
        assert_eq!(text.len(), "Main Street".len() + "Llama \u{1F999}".len());
        assert_eq!(decode_texts(&index, &text, 4, "T").unwrap(), names);
        // the empty first slot stores zero offset, length, and count
        assert_eq!(&index[0..8], &[0; 8]);
    }

    #[test]
    fn text_section_rejects_bad_index_values() {
        let names = vec!["abc".to_string(), "de".to_string()];
        let (index, text) = encode_texts(&names).unwrap();

        let mut wrong_count = index.clone();
        wrong_count[7] = 9;
        assert!(decode_texts(&wrong_count, &text, 2, "T").is_err());

        let mut gap = index.clone();
        gap[11] = 4;
        assert!(decode_texts(&gap, &text, 2, "T").is_err());

        let mut invalid = text.clone();
        invalid[0] = 0xff;
        assert!(decode_texts(&index, &invalid, 2, "T").is_err());

        let mut unused = text.clone();
        unused.push(b'x');
        assert!(decode_texts(&index, &unused, 2, "T").is_err());
    }

    #[test]
    fn extension_blocks_round_trip_and_reject_truncation() {
        let blocks = vec![
            ExtensionBlock {
                tag: *b"LREC",
                data: vec![1, 2, 3],
            },
            ExtensionBlock {
                tag: *b"ZZZZ",
                data: vec![],
            },
        ];
        let bytes = encode_extension(&blocks);
        assert_eq!(decode_extension(&bytes, "T").unwrap(), blocks);
        assert!(decode_extension(&bytes[..bytes.len() - 1], "T").is_err());
        assert!(decode_extension(&bytes[..5], "T").is_err());
    }
}
