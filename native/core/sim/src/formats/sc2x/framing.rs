//! TEXT.bin and CUNK.bin: indexed collections of original chunk payloads.
//!
//! Both keep each payload byte for byte. The framing only gives each payload a
//! flat entry name; it is not compression.

use super::wire::{Reader, put_len, put_u32};

pub const SCHEMA_VERSION: u32 = 1;
pub const HEADER_SIZE: usize = 16;
pub const TEXT_INDEX_SIZE: usize = 16;
pub const CHUNK_INDEX_SIZE: usize = 24;

/// CUNK payload status: the bytes are the stored chunk payload of an unknown
/// encoding, not a decoded known structure.
pub const CHUNK_STORED: u32 = 0x1;
/// CUNK payload status: a legacy structure that a version 4 structure replaced,
/// such as a template that does not describe SCEN schema 2.
pub const CHUNK_SUPERSEDED: u32 = 0x2;
pub const CHUNK_DEFINED_FLAGS: u32 = CHUNK_STORED | CHUNK_SUPERSEDED;

/// One scenario TEXT chunk: its position among all source chunks, its position
/// among the TEXT chunks, and its complete payload, including its purpose tag.
#[derive(Clone, Debug, Default, PartialEq, Eq)]
pub struct TextOccurrence {
    pub source_order: u32,
    pub source_occurrence: u32,
    pub payload: Vec<u8>,
}

/// One preserved chunk.
#[derive(Clone, Debug, Default, PartialEq, Eq)]
pub struct PreservedChunk {
    pub chunk_id: [u8; 4],
    pub occurrence: u32,
    pub source_order: u32,
    pub flags: u32,
    pub payload: Vec<u8>,
}

fn read_header(reader: &mut Reader, stride: u32, name: &str) -> Result<(usize, usize), String> {
    let schema = reader.u32()?;
    let count = reader.u32()? as usize;
    let index_stride = reader.u32()?;
    let payload_bytes = reader.u32()? as usize;

    if schema != SCHEMA_VERSION {
        return Err(format!(
            "{} uses layout schema {}; this version reads schema {}",
            name, schema, SCHEMA_VERSION
        ));
    }

    if index_stride != stride {
        return Err(format!("{} index stride is {}; expected {}", name, index_stride, stride));
    }

    match count
        .checked_mul(stride as usize)
        .and_then(|bytes| bytes.checked_add(payload_bytes))
    {
        Some(bytes) if bytes == reader.remaining() => Ok((count, payload_bytes)),
        _ => Err(format!("{} size does not match its occurrence count and payload bytes", name)),
    }
}

/// Check that each payload follows the previous one with no gaps.
fn take_payload<'a>(payloads: &'a [u8], offset: usize, length: usize, packed: &mut usize, name: &str) -> Result<&'a [u8], String> {
    if offset != *packed || offset + length > payloads.len() {
        return Err(format!("{} payloads are not packed in index order", name));
    }

    *packed += length;

    Ok(&payloads[offset..offset + length])
}

pub fn encode_text(occurrences: &[TextOccurrence]) -> Vec<u8> {
    let payload_bytes: usize = occurrences.iter().map(|occurrence| occurrence.payload.len()).sum();
    let mut output = Vec::with_capacity(HEADER_SIZE + occurrences.len() * TEXT_INDEX_SIZE + payload_bytes);
    put_u32(&mut output, SCHEMA_VERSION);
    put_len(&mut output, occurrences.len());
    put_u32(&mut output, TEXT_INDEX_SIZE as u32);
    put_len(&mut output, payload_bytes);
    let mut offset = 0;

    for occurrence in occurrences {
        put_u32(&mut output, occurrence.source_order);
        put_u32(&mut output, occurrence.source_occurrence);
        put_len(&mut output, offset);
        put_len(&mut output, occurrence.payload.len());
        offset += occurrence.payload.len();
    }

    for occurrence in occurrences {
        output.extend_from_slice(&occurrence.payload);
    }

    output
}

pub fn decode_text(bytes: &[u8]) -> Result<Vec<TextOccurrence>, String> {
    let mut reader = Reader::new(bytes);
    let (count, payload_bytes) = read_header(&mut reader, TEXT_INDEX_SIZE as u32, "TEXT")?;
    let index = reader.bytes(count * TEXT_INDEX_SIZE)?;
    let payloads = reader.bytes(payload_bytes)?;
    let mut entries = Reader::new(index);
    let mut result = Vec::with_capacity(count);
    let mut packed = 0;

    for position in 0..count {
        let source_order = entries.u32()?;
        let source_occurrence = entries.u32()?;
        let offset = entries.u32()? as usize;
        let length = entries.u32()? as usize;

        if source_occurrence as usize != position {
            return Err("TEXT occurrences are not in source occurrence order".into());
        }

        if result.last().is_some_and(|last: &TextOccurrence| last.source_order >= source_order) {
            return Err("TEXT source order does not increase".into());
        }

        let payload = take_payload(payloads, offset, length, &mut packed, "TEXT")?.to_vec();
        result.push(TextOccurrence {
            source_order,
            source_occurrence,
            payload,
        });
    }

    if packed != payloads.len() {
        return Err("TEXT has payload bytes that no occurrence uses".into());
    }

    Ok(result)
}

pub fn encode_chunks(chunks: &[PreservedChunk]) -> Vec<u8> {
    let payload_bytes: usize = chunks.iter().map(|chunk| chunk.payload.len()).sum();
    let mut output = Vec::with_capacity(HEADER_SIZE + chunks.len() * CHUNK_INDEX_SIZE + payload_bytes);
    put_u32(&mut output, SCHEMA_VERSION);
    put_len(&mut output, chunks.len());
    put_u32(&mut output, CHUNK_INDEX_SIZE as u32);
    put_len(&mut output, payload_bytes);
    let mut offset = 0;

    for chunk in chunks {
        output.extend_from_slice(&chunk.chunk_id);
        put_u32(&mut output, chunk.occurrence);
        put_u32(&mut output, chunk.source_order);
        put_u32(&mut output, chunk.flags);
        put_len(&mut output, offset);
        put_len(&mut output, chunk.payload.len());
        offset += chunk.payload.len();
    }

    for chunk in chunks {
        output.extend_from_slice(&chunk.payload);
    }

    output
}

pub fn decode_chunks(bytes: &[u8]) -> Result<Vec<PreservedChunk>, String> {
    let mut reader = Reader::new(bytes);
    let (count, payload_bytes) = read_header(&mut reader, CHUNK_INDEX_SIZE as u32, "CUNK")?;
    let index = reader.bytes(count * CHUNK_INDEX_SIZE)?;
    let payloads = reader.bytes(payload_bytes)?;
    let mut entries = Reader::new(index);
    let mut result = Vec::with_capacity(count);
    let mut packed = 0;
    let mut seen = std::collections::HashSet::new();

    for _ in 0..count {
        let id = entries.bytes(4)?;
        let chunk_id = [id[0], id[1], id[2], id[3]];
        let occurrence = entries.u32()?;
        let source_order = entries.u32()?;
        let flags = entries.u32()?;
        let offset = entries.u32()? as usize;
        let length = entries.u32()? as usize;

        if !chunk_id.iter().all(|byte| (0x20..=0x7e).contains(byte)) {
            return Err("CUNK chunk ID is not printable ASCII".into());
        }

        if flags & !CHUNK_DEFINED_FLAGS != 0 {
            return Err("CUNK record uses undefined payload flags".into());
        }

        if !seen.insert((chunk_id, occurrence)) {
            return Err("CUNK repeats a chunk ID and occurrence".into());
        }

        if result.last().is_some_and(|last: &PreservedChunk| last.source_order >= source_order) {
            return Err("CUNK source order does not increase".into());
        }

        let payload = take_payload(payloads, offset, length, &mut packed, "CUNK")?.to_vec();
        result.push(PreservedChunk {
            chunk_id,
            occurrence,
            source_order,
            flags,
            payload,
        });
    }

    if packed != payloads.len() {
        return Err("CUNK has payload bytes that no record uses".into());
    }

    Ok(result)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn text_occurrences_keep_every_payload_byte() {
        let occurrences = vec![
            TextOccurrence {
                source_order: 21,
                source_occurrence: 0,
                payload: b"\x80\x00\x00\x00Select\0junk".to_vec(),
            },
            TextOccurrence {
                source_order: 22,
                source_occurrence: 1,
                payload: b"\x81\x00\x00\x00Open".to_vec(),
            },
        ];
        let bytes = encode_text(&occurrences);
        assert_eq!(bytes.len(), 16 + 16 * 2 + 15 + 8);
        assert_eq!(decode_text(&bytes).unwrap(), occurrences);
        assert!(decode_text(&bytes[..bytes.len() - 1]).is_err());

        let mut reordered = bytes.clone();
        reordered[16 + 7] = 5;
        assert!(decode_text(&reordered).is_err());
    }

    #[test]
    fn preserved_chunks_keep_ids_occurrences_and_flags() {
        let chunks = vec![
            PreservedChunk {
                chunk_id: *b"ABCD",
                occurrence: 0,
                source_order: 3,
                flags: CHUNK_STORED,
                payload: vec![1, 2, 3],
            },
            PreservedChunk {
                chunk_id: *b"MISC",
                occurrence: 1,
                source_order: 9,
                flags: 0,
                payload: vec![],
            },
            PreservedChunk {
                chunk_id: *b"TMPL",
                occurrence: 0,
                source_order: 12,
                flags: CHUNK_SUPERSEDED,
                payload: vec![9],
            },
        ];
        let bytes = encode_chunks(&chunks);
        assert_eq!(bytes.len(), 16 + 24 * 3 + 4);
        assert_eq!(decode_chunks(&bytes).unwrap(), chunks);

        let mut flags = bytes.clone();
        flags[16 + 15] = 0x10;
        assert!(decode_chunks(&flags).is_err());

        let mut repeated = chunks.clone();
        repeated[1].chunk_id = *b"ABCD";
        repeated[1].occurrence = 0;
        assert!(decode_chunks(&encode_chunks(&repeated)).is_err());
    }
}
