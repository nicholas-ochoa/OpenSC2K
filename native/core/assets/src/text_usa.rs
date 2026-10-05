//! The text resources of TEXT_USA.DAT and its index, as TextUsaResource.

use crate::bytes::{latin1, read_u32_le};
use crate::text::johab;

const INDEX_RECORD_SIZE: usize = 8;

/// The text of each of `ids` in the data file and its index, by id.
pub fn load_ids(data: &[u8], index: &[u8], ids: &[i64]) -> Result<Vec<(i64, String)>, String> {
    if ids.iter().any(|&id| id < 0) {
        return Err("text resource ID is negative".into());
    }

    if !index.len().is_multiple_of(INDEX_RECORD_SIZE) {
        return Err("text index has a partial record".into());
    }

    let mut records: Vec<(i64, usize)> = Vec::new();

    for offset in (0..index.len()).step_by(INDEX_RECORD_SIZE) {
        let id = i64::from(read_u32_le(index, offset));
        let start = read_u32_le(index, offset + 4) as usize;

        if start > data.len() {
            return Err(format!("text resource {id} has an invalid offset"));
        }

        if records
            .last()
            .is_some_and(|&(_, previous)| start < previous)
        {
            return Err("text resource offsets are not ordered".into());
        }

        records.push((id, start));
    }

    let boundaries: Vec<usize> = records.iter().map(|&(_, start)| start).collect();
    let is_johab = johab::is_text(data, &boundaries);
    let mut wanted: Vec<i64> = Vec::new();

    for &id in ids {
        if !wanted.contains(&id) {
            wanted.push(id);
        }
    }

    let mut result: Vec<(i64, String)> = Vec::new();

    for (position, &(id, start)) in records.iter().enumerate() {
        if !wanted.contains(&id) {
            continue;
        }

        let end = records
            .get(position + 1)
            .map_or(data.len(), |&(_, next)| next);
        let bytes = &data[start..end];
        let text = if is_johab {
            johab::decode_text(bytes)
        } else {
            latin1(bytes)
        };

        match result.iter_mut().find(|(known, _)| *known == id) {
            Some(entry) => entry.1 = text,
            None => result.push((id, text)),
        }
    }

    if result.len() != wanted.len() {
        return Err("one or more requested text resources are missing".into());
    }

    Ok(result)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn requested_texts_load() {
        let data = b"HelloWorld";
        let mut index = Vec::new();

        for (id, start) in [(3000u32, 0u32), (3001, 5)] {
            index.extend_from_slice(&id.to_le_bytes());
            index.extend_from_slice(&start.to_le_bytes());
        }

        assert_eq!(
            load_ids(data, &index, &[3001]),
            Ok(vec![(3001, "World".to_string())])
        );
        assert!(
            load_ids(data, &index, &[9])
                .unwrap_err()
                .contains("missing")
        );
        assert!(
            load_ids(data, &index[..7], &[3000])
                .unwrap_err()
                .contains("partial")
        );
    }
}
