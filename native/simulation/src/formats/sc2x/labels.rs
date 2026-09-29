//! Runtime label tables. Original and SCLG cities use 25-byte XLAB records.
//! A version 4 working document uses wide records instead: a big-endian u16
//! byte length and up to 256 UTF-8 bytes. The wide table is runtime state only;
//! names are saved in their owning structures and in metadata.

pub const LEGACY_RECORD_SIZE: usize = 25;
pub const LEGACY_MAX_TEXT: usize = 23;
pub const WIDE_RECORD_SIZE: usize = 258;
pub const WIDE_TEXT_OFFSET: usize = 2;
pub const WIDE_MAX_TEXT: usize = 256;
/// The mayor name and the five shared stadium team names.
pub const MAYOR_LABEL: usize = 0;
pub const TEAM_LABEL_FIRST: usize = 0xfb;
pub const TEAM_COUNT: usize = 5;

pub fn record_size(wide: bool) -> usize {
    if wide { WIDE_RECORD_SIZE } else { LEGACY_RECORD_SIZE }
}

/// The text of one label, or `None` outside the table. Legacy bytes are read
/// as Latin-1, so every byte keeps a distinct character.
pub fn read(labels: &[u8], id: usize, wide: bool) -> Option<String> {
    let size = record_size(wide);
    let offset = id.checked_mul(size)?;

    if offset + size > labels.len() {
        return None;
    }

    if wide {
        let length = (((labels[offset] as usize) << 8) | labels[offset + 1] as usize).min(WIDE_MAX_TEXT);
        let start = offset + WIDE_TEXT_OFFSET;

        return Some(String::from_utf8_lossy(&labels[start..start + length]).into_owned());
    }

    let declared = (labels[offset] as usize).min(LEGACY_MAX_TEXT);
    let start = offset + 1;
    let text = &labels[start..start + declared];
    let end = text.iter().position(|&byte| byte == 0).unwrap_or(text.len());

    Some(text[..end].iter().map(|&byte| byte as char).collect())
}

/// Store `text` in a wide table. Text longer than the record limit is cut at a
/// character boundary. Returns false outside the table.
pub fn write_wide(labels: &mut [u8], id: usize, text: &str) -> bool {
    let offset = id * WIDE_RECORD_SIZE;

    if offset + WIDE_RECORD_SIZE > labels.len() {
        return false;
    }

    let mut end = text.len().min(WIDE_MAX_TEXT);

    while !text.is_char_boundary(end) {
        end -= 1;
    }

    let record = &mut labels[offset..offset + WIDE_RECORD_SIZE];
    record.fill(0);
    record[0] = (end >> 8) as u8;
    record[1] = end as u8;
    record[WIDE_TEXT_OFFSET..WIDE_TEXT_OFFSET + end].copy_from_slice(&text.as_bytes()[..end]);

    true
}

/// Clear one record, as the original clears the length byte of a label.
pub fn clear(labels: &mut [u8], id: usize, wide: bool) {
    let size = record_size(wide);
    let offset = id * size;

    if offset + size <= labels.len() {
        labels[offset] = 0;

        if wide {
            labels[offset + 1] = 0;
        }
    }
}

/// Zero a whole record, for names that moved to their owning structure.
pub fn erase(labels: &mut [u8], id: usize, wide: bool) {
    let size = record_size(wide);
    let offset = id * size;

    if offset + size <= labels.len() {
        labels[offset..offset + size].fill(0);
    }
}

/// A wide table that holds every label ID through `last_id`.
pub fn wide_table(last_id: usize) -> Vec<u8> {
    vec![0; (last_id.max(TEAM_LABEL_FIRST + TEAM_COUNT - 1) + 1) * WIDE_RECORD_SIZE]
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn legacy_labels_read_latin_1_up_to_the_declared_length() {
        let mut labels = vec![0u8; LEGACY_RECORD_SIZE * 3];
        labels[25] = 5;
        labels[26..31].copy_from_slice(b"Caf\xe9s");
        assert_eq!(read(&labels, 1, false).unwrap(), "Caf\u{e9}s");
        labels[50] = 40;
        labels[51..54].copy_from_slice(b"Abc");
        assert_eq!(read(&labels, 2, false).unwrap(), "Abc");
        assert!(read(&labels, 3, false).is_none());
    }

    #[test]
    fn wide_labels_hold_256_bytes_and_cut_at_characters() {
        let mut labels = wide_table(260);
        assert_eq!(labels.len(), 261 * WIDE_RECORD_SIZE);
        let long = "\u{1F999}".repeat(64);
        assert!(write_wide(&mut labels, 260, &long));
        assert_eq!(read(&labels, 260, true).unwrap(), long);
        assert!(write_wide(&mut labels, 1, &format!("a{}", long)));
        assert_eq!(read(&labels, 1, true).unwrap(), "a".to_string() + &"\u{1F999}".repeat(63));
        clear(&mut labels, 1, true);
        assert_eq!(read(&labels, 1, true).unwrap(), "");
        assert!(!write_wide(&mut labels, 261, "x"));
    }
}
