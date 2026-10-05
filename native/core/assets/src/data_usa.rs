//! The newspaper grammar of DATA_USA.DAT and its index DATA_USA.IDX: the
//! phrase tables of each story type and the grammar text of each phrase.

use crate::bytes::{read_u16_be, read_u32_be, read_u32_le};
use crate::text::johab;

const INDEX_RECORD_SIZE: usize = 8;
pub const BASE_RESOURCE_ID: u32 = 1000;
pub const COUNT_RESOURCE_ID: u32 = 1001;
pub const OFFSET_RESOURCE_ID: u32 = 1002;
pub const GRAMMAR_RESOURCE_ID: u32 = 1003;
/// The phrase tables. A story type is the number of its table.
pub const TABLE_ENTRY_COUNT: usize = 250;
pub const PHRASE_COUNT: usize = 2500;

#[derive(Clone, Debug, Default, PartialEq, Eq)]
pub struct DataUsa {
    /// The first phrase of each table.
    pub bases: Vec<i32>,
    /// The phrase count of each table.
    pub counts: Vec<i32>,
    /// The grammar offset of each phrase.
    pub offsets: Vec<i64>,
    pub grammar: Vec<u8>,
    /// True for the Korean grammar, whose text is Johab pairs.
    pub is_johab: bool,
}

impl DataUsa {
    /// The grammar bytes of `phrase_id`, without the zero that ends them.
    pub fn phrase_bytes(&self, phrase_id: usize) -> &[u8] {
        let Some(&start) = self.offsets.get(phrase_id) else {
            return &[];
        };
        let start = (start.max(0) as usize).min(self.grammar.len());
        let length = self.grammar[start..]
            .iter()
            .position(|&byte| byte == 0)
            .unwrap_or(self.grammar.len() - start);

        &self.grammar[start..start + length]
    }
}

/// The resources of the data file by id, from the index records.
fn resources(data: &[u8], index: &[u8]) -> Result<Vec<(u32, Vec<u8>)>, String> {
    if !index.len().is_multiple_of(INDEX_RECORD_SIZE) {
        return Err("DATA_USA index has a partial record".into());
    }

    let mut records: Vec<(u32, usize)> = Vec::new();

    for at in (0..index.len()).step_by(INDEX_RECORD_SIZE) {
        let resource_id = read_u32_le(index, at);
        let data_offset = read_u32_le(index, at + 4) as usize;

        if data_offset > data.len() {
            return Err(format!(
                "DATA_USA resource {resource_id} has an invalid offset"
            ));
        }

        if records
            .last()
            .is_some_and(|&(_, previous)| data_offset < previous)
        {
            return Err("DATA_USA resource offsets are not ordered".into());
        }

        records.push((resource_id, data_offset));
    }

    Ok(records
        .iter()
        .enumerate()
        .map(|(position, &(resource_id, start))| {
            let end = records
                .get(position + 1)
                .map_or(data.len(), |&(_, next)| next);
            (resource_id, data[start..end].to_vec())
        })
        .collect())
}

/// Read the grammar from the data file and its index. A later record with the
/// same id replaces an earlier one.
pub fn parse(data: &[u8], index: &[u8]) -> Result<DataUsa, String> {
    let resources = resources(data, index)?;
    let resource = |resource_id: u32| {
        resources
            .iter()
            .rev()
            .find(|(id, _)| *id == resource_id)
            .map(|(_, bytes)| bytes.as_slice())
            .ok_or_else(|| format!("DATA_USA resource {resource_id} is missing"))
    };

    let base_bytes = resource(BASE_RESOURCE_ID)?;
    let count_bytes = resource(COUNT_RESOURCE_ID)?;
    let offset_bytes = resource(OFFSET_RESOURCE_ID)?;
    let grammar = resource(GRAMMAR_RESOURCE_ID)?;

    if base_bytes.len() != TABLE_ENTRY_COUNT * 2 {
        return Err("DATA_USA headline-base table has the wrong size".into());
    }

    if count_bytes.len() != TABLE_ENTRY_COUNT * 2 {
        return Err("DATA_USA headline-count table has the wrong size".into());
    }

    if offset_bytes.len() != PHRASE_COUNT * 4 {
        return Err("DATA_USA phrase-offset table has the wrong size".into());
    }

    if grammar.is_empty() {
        return Err("DATA_USA grammar text is empty".into());
    }

    let table = |bytes: &[u8]| {
        (0..TABLE_ENTRY_COUNT)
            .map(|entry| i32::from(read_u16_be(bytes, entry * 2)))
            .collect::<Vec<_>>()
    };
    let bases = table(base_bytes);
    let counts = table(count_bytes);
    let offsets: Vec<i64> = (0..PHRASE_COUNT)
        .map(|phrase| i64::from(read_u32_be(offset_bytes, phrase * 4)))
        .collect();

    for table_id in 0..TABLE_ENTRY_COUNT {
        if (bases[table_id] + counts[table_id]) as usize > PHRASE_COUNT {
            return Err(format!(
                "DATA_USA phrase table {table_id} is outside the offset table"
            ));
        }
    }

    for (phrase_id, &offset) in offsets.iter().enumerate() {
        let start = offset as usize;

        if start >= grammar.len() {
            return Err(format!(
                "DATA_USA phrase {phrase_id} has an invalid text offset"
            ));
        }

        if !grammar[start..].contains(&0) {
            return Err(format!("DATA_USA phrase {phrase_id} is not terminated"));
        }
    }

    Ok(DataUsa {
        bases,
        counts,
        offsets,
        grammar: grammar.to_vec(),
        is_johab: johab::is_grammar(grammar, offset_bytes),
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    /// A data file and its index with each resource in id order.
    fn files(resources: &[(u32, Vec<u8>)]) -> (Vec<u8>, Vec<u8>) {
        let mut data = Vec::new();
        let mut index = Vec::new();

        for (resource_id, bytes) in resources {
            index.extend_from_slice(&resource_id.to_le_bytes());
            index.extend_from_slice(&(data.len() as u32).to_le_bytes());
            data.extend_from_slice(bytes);
        }

        (data, index)
    }

    fn grammar_resources() -> Vec<(u32, Vec<u8>)> {
        let mut bases = vec![0; TABLE_ENTRY_COUNT * 2];
        let mut counts = vec![0; TABLE_ENTRY_COUNT * 2];
        bases[5] = 3;
        counts[5] = 2;
        let mut offsets = vec![0; PHRASE_COUNT * 4];
        offsets[4 * 4 + 3] = 3;

        vec![
            (BASE_RESOURCE_ID, bases),
            (COUNT_RESOURCE_ID, counts),
            (OFFSET_RESOURCE_ID, offsets),
            (GRAMMAR_RESOURCE_ID, b"ab\0cd\0".to_vec()),
        ]
    }

    #[test]
    fn the_grammar_reads_its_tables_and_phrases() {
        let (data, index) = files(&grammar_resources());
        let grammar = parse(&data, &index).expect("a valid grammar");
        assert_eq!((grammar.bases[2], grammar.counts[2]), (3, 2));
        assert_eq!(grammar.phrase_bytes(0), b"ab");
        assert_eq!(grammar.phrase_bytes(4), b"cd");
        assert_eq!(grammar.phrase_bytes(PHRASE_COUNT), b"");
        assert!(!grammar.is_johab);
    }

    #[test]
    fn malformed_files_are_rejected() {
        let (data, index) = files(&grammar_resources());
        assert!(
            parse(&data, &index[..index.len() - 1])
                .unwrap_err()
                .contains("partial record")
        );

        let mut unordered = index.clone();
        unordered[12..16].copy_from_slice(&0u32.to_le_bytes());
        unordered[4..8].copy_from_slice(&8u32.to_le_bytes());
        assert!(
            parse(&data, &unordered)
                .unwrap_err()
                .contains("not ordered")
        );

        let mut missing = grammar_resources();
        missing.pop();
        let (data, index) = files(&missing);
        assert_eq!(
            parse(&data, &index).unwrap_err(),
            "DATA_USA resource 1003 is missing"
        );

        let mut high = grammar_resources();
        high[2].1[0] = 0x80;
        let (data, index) = files(&high);
        assert!(
            parse(&data, &index)
                .unwrap_err()
                .contains("invalid text offset")
        );

        let mut open = grammar_resources();
        open[3].1 = b"ab\0cd".to_vec();
        let (data, index) = files(&open);
        assert!(parse(&data, &index).unwrap_err().contains("not terminated"));
    }
}
