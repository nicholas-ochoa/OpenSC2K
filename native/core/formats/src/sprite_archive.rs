//! Sprite archives: a big-endian record count, then a 10-byte record for each
//! sprite (ID, data offset, height, width), then the encoded pixels.

const COUNT_SIZE: usize = 2;
const RECORD_SIZE: usize = 10;

/// One archive record, with the encoded pixels up to the next record.
#[derive(Clone, Debug, Default, PartialEq, Eq)]
pub struct Entry {
    pub sprite_id: i64,
    pub offset: usize,
    pub width: i64,
    pub height: i64,
    /// The number of earlier records with this sprite ID.
    pub duplicate_index: i64,
    pub encoded: Vec<u8>,
}

fn u16_be(bytes: &[u8], at: usize) -> i64 {
    i64::from(u16::from_be_bytes([bytes[at], bytes[at + 1]]))
}

/// The records of an archive, or the first fault.
pub fn parse(bytes: &[u8]) -> Result<Vec<Entry>, String> {
    if bytes.len() < COUNT_SIZE {
        return Err("archive is shorter than its count field".into());
    }

    let count = u16_be(bytes, 0) as usize;
    let header_end = COUNT_SIZE + count * RECORD_SIZE;

    if header_end > bytes.len() {
        return Err("metadata table extends past the file".into());
    }

    let mut entries: Vec<Entry> = Vec::with_capacity(count);
    let mut duplicates = std::collections::HashMap::new();

    for index in 0..count {
        let at = COUNT_SIZE + index * RECORD_SIZE;
        let sprite_id = u16_be(bytes, at);
        let offset = u32::from_be_bytes([bytes[at + 2], bytes[at + 3], bytes[at + 4], bytes[at + 5]]) as usize;
        let duplicate = duplicates.entry(sprite_id).or_insert(0);
        let entry = Entry {
            sprite_id,
            offset,
            height: u16_be(bytes, at + 6),
            width: u16_be(bytes, at + 8),
            duplicate_index: *duplicate,
            encoded: Vec::new(),
        };
        *duplicate += 1;

        if entry.width <= 0 || entry.height <= 0 {
            return Err(format!("sprite {sprite_id} has an empty dimension"));
        }

        if offset < header_end || offset > bytes.len() {
            return Err(format!("sprite {sprite_id} has an invalid data offset"));
        }

        entries.push(entry);
    }

    for index in 0..entries.len() {
        let end = entries.get(index + 1).map_or(bytes.len(), |next| next.offset);
        let start = entries[index].offset;

        if end < start {
            return Err("sprite offsets are not in ascending order".into());
        }

        entries[index].encoded = bytes[start..end].to_vec();
    }

    Ok(entries)
}

#[cfg(test)]
mod tests {
    use super::parse;

    #[test]
    fn records_take_the_bytes_up_to_the_next_record() {
        let mut bytes = vec![0, 2];
        bytes.extend([0, 7, 0, 0, 0, 22, 0, 1, 0, 2]);
        bytes.extend([0, 7, 0, 0, 0, 24, 0, 3, 0, 4]);
        bytes.extend([1, 2, 3]);
        let entries = parse(&bytes).unwrap();
        assert_eq!(entries[0].encoded, [1, 2]);
        assert_eq!((entries[1].width, entries[1].height, entries[1].duplicate_index), (4, 3, 1));
        assert_eq!(entries[1].encoded, [3]);

        bytes[7] = 30;
        assert_eq!(parse(&bytes).unwrap_err(), "sprite 7 has an invalid data offset");
        assert_eq!(parse(&[0, 9]).unwrap_err(), "metadata table extends past the file");
        assert_eq!(parse(&[0]).unwrap_err(), "archive is shorter than its count field");
    }
}
