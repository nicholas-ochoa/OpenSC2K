//! The text and newspaper records of the DOS, Macintosh, and demo versions,
//! converted to the Windows data files, as Sc2DataConvert.

use crate::data_usa::{EXTENDED_TOKEN_BYTES, STORY_PRIORITIES};
use crate::text::johab;

const TEXT_RESOURCE_PREFIX: &str = "TXT";
const NEWSPAPER_RESOURCE_PREFIX: &str = "PPDT";
pub const NEWSPAPER_IDS: [i64; 6] = [1000, 1001, 1002, 1003, 1004, 1005];
/// The game does not read records 1004 and 1005.
const REQUIRED_NEWSPAPER_IDS: [i64; 4] = [1000, 1001, 1002, 1003];
/// Windows releases and demos keep the records in index and data file pairs.
const TEXT_FILE_NAMES: [&str; 2] = ["TEXT_USA", "TEXT"];
const NEWSPAPER_FILE_NAMES: [&str; 2] = ["DATA_USA", "DATA"];
const INDEX_RECORD_SIZE: usize = 8;
pub const BASES_ID: i64 = 1000;
pub const COUNTS_ID: i64 = 1001;
pub const OFFSETS_ID: i64 = 1002;
pub const GRAMMAR_ID: i64 = 1003;
/// DOS and Macintosh tokens 0x80 to 0xb6 select phrases 32 to 86.
const SHIFTED_TOKEN_FIRST: u8 = 0x80;
const SHIFTED_TOKEN_LAST: u8 = 0xb6;
/// Only the shifted encoding uses 0x80 to 0x9d as tokens; only Windows uses 0xee to 0xff.
const SHIFTED_ONLY_TOKEN_END: u8 = 0x9d;
const WINDOWS_ONLY_TOKEN_FIRST: u8 = 0xee;
/// The Macintosh curly quotes of the DOS and Macintosh grammar.
const QUOTE_BYTES: [(u8, u8); 4] = [(0xd2, 0x22), (0xd3, 0x22), (0xd4, 0x27), (0xd5, 0x27)];
const ARGUMENT_OPCODES: [u8; 8] = [0x25, 0x26, 0x2a, 0x3c, 0x40, 0x5b, 0x5c, 0x5e];
const NO_TABLE_BASE: usize = 0xffff;
const HEADLINE_END: u8 = 0x2b;

/// Records by id in insertion order. The first record of an id stays.
#[derive(Clone, Debug, Default, PartialEq, Eq)]
pub struct Records(pub Vec<(i64, Vec<u8>)>);

impl Records {
    pub fn get(&self, id: i64) -> Option<&[u8]> {
        self.0
            .iter()
            .find(|(known, _)| *known == id)
            .map(|(_, bytes)| bytes.as_slice())
    }

    pub fn has(&self, id: i64) -> bool {
        self.get(id).is_some()
    }

    /// Keep the first record of each id.
    pub fn keep(&mut self, id: i64, bytes: &[u8]) {
        if !self.has(id) {
            self.0.push((id, bytes.to_vec()));
        }
    }

    /// Store a record; a known id keeps its position.
    fn set(&mut self, id: i64, bytes: Vec<u8>) {
        match self.0.iter_mut().find(|(known, _)| *known == id) {
            Some(entry) => entry.1 = bytes,
            None => self.0.push((id, bytes)),
        }
    }

    fn bytes(&self, id: i64) -> &[u8] {
        self.get(id).unwrap_or_default()
    }
}

/// One source record of an import.
#[derive(Clone, Debug, Default)]
pub struct SourceRecord {
    pub name: String,
    /// The resource type, or empty for a file.
    pub kind: String,
    pub id: i64,
    /// The container of the record.
    pub source: String,
    pub bytes: Vec<u8>,
}

fn u16_be(data: &[u8], at: usize) -> usize {
    usize::from(u16::from_be_bytes([data[at], data[at + 1]]))
}

fn u32_be(data: &[u8], at: usize) -> usize {
    u32::from_be_bytes([data[at], data[at + 1], data[at + 2], data[at + 3]]) as usize
}

fn u32_le(data: &[u8], at: usize) -> usize {
    u32::from_le_bytes([data[at], data[at + 1], data[at + 2], data[at + 3]]) as usize
}

fn is_valid_int(text: &str) -> bool {
    let digits = text.strip_prefix(['+', '-']).unwrap_or(text);

    !digits.is_empty() && digits.bytes().all(|byte| byte.is_ascii_digit())
}

/// The file name without its last extension, as Godot's `get_basename`.
fn basename(name: &str) -> &str {
    match name.rfind('.') {
        Some(dot) if name.rfind(['/', '\\']).is_none_or(|slash| dot > slash) => &name[..dot],
        _ => name,
    }
}

/// The text and newspaper records of a source. DOS keeps TXT and PPDT
/// records in SC2000.DAT; Windows demos keep .DAT and .IDX pairs; a
/// Macintosh application keeps TEXT and DATA resources. The Macintosh text
/// comes from the file with the newspaper, because each scenario has its own TEXT 128.
pub fn find_records(source: &[SourceRecord]) -> (Records, Records) {
    let mut text = Records::default();
    let mut newspaper = Records::default();
    let mut container: Option<&str> = None;
    let mut files: Vec<(String, &[u8])> = Vec::new();

    for record in source {
        if record.kind == "DATA" && record.id == GRAMMAR_ID && container.is_none() {
            container = Some(&record.source);
        } else if record.kind.is_empty()
            && !files
                .iter()
                .any(|(name, _)| *name == record.name.to_uppercase())
        {
            files.push((record.name.to_uppercase(), &record.bytes));
        }
    }

    let file = |name: String| {
        files
            .iter()
            .find(|(known, _)| *known == name)
            .map(|(_, bytes)| *bytes)
    };

    for (names, target) in [
        (&TEXT_FILE_NAMES, &mut text),
        (&NEWSPAPER_FILE_NAMES, &mut newspaper),
    ] {
        for name in names {
            if let (Some(data), Some(index)) =
                (file(format!("{name}.DAT")), file(format!("{name}.IDX")))
            {
                for (id, bytes) in indexed_records(data, index).0 {
                    target.keep(id, &bytes);
                }
            }
        }
    }

    for record in source {
        let in_container = container == Some(record.source.as_str());

        if record.kind.is_empty() {
            let name = basename(&record.name).to_uppercase();

            if let Some(number) = name
                .strip_prefix(TEXT_RESOURCE_PREFIX)
                .filter(|number| is_valid_int(number))
            {
                text.keep(number.parse().unwrap_or(0), &record.bytes);
            } else if let Some(number) = name
                .strip_prefix(NEWSPAPER_RESOURCE_PREFIX)
                .filter(|number| is_valid_int(number))
            {
                let id = number.parse().unwrap_or(-1);

                if NEWSPAPER_IDS.contains(&id) {
                    newspaper.keep(id, &record.bytes);
                }
            }
        } else if in_container && record.kind == "TEXT" && record.id >= 0 {
            text.keep(record.id, &record.bytes);
        } else if in_container && record.kind == "DATA" && NEWSPAPER_IDS.contains(&record.id) {
            newspaper.keep(record.id, &record.bytes);
        }
    }

    (text, newspaper)
}

/// The records of a Windows .IDX file: a little-endian id and data offset for
/// each record, in data order. A bad index gives no records.
pub fn indexed_records(data: &[u8], index: &[u8]) -> Records {
    let mut records = Records::default();

    if index.is_empty() || !index.len().is_multiple_of(INDEX_RECORD_SIZE) {
        return records;
    }

    for offset in (0..index.len()).step_by(INDEX_RECORD_SIZE) {
        let start = u32_le(index, offset + 4);
        let end = if offset + INDEX_RECORD_SIZE >= index.len() {
            data.len()
        } else {
            u32_le(index, offset + INDEX_RECORD_SIZE + 4)
        };

        if start > end || end > data.len() {
            return Records::default();
        }

        records.set(u32_le(index, offset) as i64, data[start..end].to_vec());
    }

    records
}

/// The phrase offsets in first-seen order.
fn phrase_starts(offsets: &[u8]) -> Vec<usize> {
    let mut starts: Vec<usize> = Vec::new();

    for offset in (0..offsets.len().saturating_sub(3)).step_by(4) {
        let start = u32_be(offsets, offset);

        if !starts.contains(&start) {
            starts.push(start);
        }
    }

    starts
}

/// DOS, Macintosh, and the Windows 3.x demo use tokens 0x80 to 0x9d often.
/// In Windows grammar those bytes are rare CP437 letters, and tokens 0xee to
/// 0xff are common.
pub fn uses_shifted_tokens(records: &Records) -> bool {
    let grammar = records.bytes(GRAMMAR_ID);
    let offsets = records.bytes(OFFSETS_ID);

    if johab::is_grammar(grammar, offsets) {
        return false;
    }

    let (mut shifted, mut windows) = (0, 0);

    for start in phrase_starts(offsets) {
        let mut cursor = start;

        while cursor < grammar.len() && grammar[cursor] != 0 {
            let value = grammar[cursor];

            if ARGUMENT_OPCODES.contains(&value) {
                cursor += 2;
                continue;
            }

            if (SHIFTED_TOKEN_FIRST..=SHIFTED_ONLY_TOKEN_END).contains(&value) {
                shifted += 1;
            } else if value >= WINDOWS_ONLY_TOKEN_FIRST {
                windows += 1;
            }

            cursor += 1;
        }
    }

    shifted > windows
}

/// The first top-level `wanted` byte of a phrase, skipping opcode arguments
/// and Johab pairs.
fn top_level_byte(grammar: &[u8], start: usize, wanted: u8, is_johab: bool) -> Option<usize> {
    let mut cursor = start;

    while cursor < grammar.len() && grammar[cursor] != 0 {
        if is_johab && johab::code_point(grammar, cursor) > 0 {
            cursor += 2;
            continue;
        }

        if grammar[cursor] == wanted {
            return Some(cursor);
        }

        cursor += if ARGUMENT_OPCODES.contains(&grammar[cursor]) {
            2
        } else {
            1
        };
    }

    None
}

/// The 1993 Macintosh demo grammar has no headline ends and numbers its
/// stories in another order, so the game cannot use it.
pub fn has_headline_ends(records: &Records) -> bool {
    let (bases, counts, offsets, grammar) = (
        records.bytes(BASES_ID),
        records.bytes(COUNTS_ID),
        records.bytes(OFFSETS_ID),
        records.bytes(GRAMMAR_ID),
    );
    let is_johab = johab::is_grammar(grammar, offsets);
    let (mut stories, mut marked) = (0, 0);

    for (table, &priority) in STORY_PRIORITIES.iter().enumerate().take(counts.len() / 2) {
        if priority <= 0 {
            continue;
        }

        for phrase in 0..u16_be(counts, table * 2) {
            let phrase_id = u16_be(bases, table * 2) + phrase;

            if phrase_id * 4 + 4 <= offsets.len() {
                stories += 1;

                if top_level_byte(
                    grammar,
                    u32_be(offsets, phrase_id * 4),
                    HEADLINE_END,
                    is_johab,
                )
                .is_some()
                {
                    marked += 1;
                }
            }
        }
    }

    marked * 2 >= stories
}

/// The records in the Windows layout. The record layout and phrase offsets
/// stay; only the shifted token bytes, the Macintosh quotes, and the base of
/// each empty table change. A grammar that the game cannot use gives no records.
pub fn windows_newspaper(records: &Records) -> Records {
    if REQUIRED_NEWSPAPER_IDS.iter().any(|&id| !records.has(id)) {
        return Records::default();
    }

    let mut bases = records.bytes(BASES_ID).to_vec();
    let counts = records.bytes(COUNTS_ID);
    let offsets = records.bytes(OFFSETS_ID);
    let mut grammar = records.bytes(GRAMMAR_ID).to_vec();
    let is_johab = johab::is_grammar(&grammar, offsets);

    if bases.len() != counts.len()
        || !bases.len().is_multiple_of(2)
        || !offsets.len().is_multiple_of(4)
        || !has_headline_ends(records)
    {
        return Records::default();
    }

    for offset in (0..bases.len()).step_by(2) {
        if u16_be(counts, offset) == 0 && u16_be(&bases, offset) == NO_TABLE_BASE {
            bases[offset] = 0;
            bases[offset + 1] = 0;
        }
    }

    let shifted = uses_shifted_tokens(records);

    if !is_johab {
        for start in phrase_starts(offsets) {
            let mut cursor = start;

            while cursor < grammar.len() && grammar[cursor] != 0 {
                let value = grammar[cursor];

                if ARGUMENT_OPCODES.contains(&value) {
                    cursor += 2;
                    continue;
                }

                if shifted && (SHIFTED_TOKEN_FIRST..=SHIFTED_TOKEN_LAST).contains(&value) {
                    grammar[cursor] =
                        EXTENDED_TOKEN_BYTES[usize::from(value - SHIFTED_TOKEN_FIRST)];
                } else if let Some(&(_, quote)) =
                    QUOTE_BYTES.iter().find(|(curly, _)| *curly == value)
                {
                    grammar[cursor] = quote;
                }

                cursor += 1;
            }
        }
    }

    let mut converted = Records::default();

    for id in NEWSPAPER_IDS {
        if let Some(bytes) = records.get(id) {
            converted.set(id, bytes.to_vec());
        }
    }

    converted.set(BASES_ID, bases);
    converted.set(GRAMMAR_ID, grammar);
    converted
}

/// The Windows .DAT file with the records in id order, and its .IDX file of
/// little-endian ids and data offsets.
pub fn resource_files(records: &Records) -> (Vec<u8>, Vec<u8>) {
    let mut sorted: Vec<&(i64, Vec<u8>)> = records.0.iter().collect();
    sorted.sort_by_key(|(id, _)| *id);
    let mut data = Vec::new();
    let mut index = Vec::new();

    for (id, bytes) in sorted {
        index.extend_from_slice(&(*id as u32).to_le_bytes());
        index.extend_from_slice(&(data.len() as u32).to_le_bytes());
        data.extend_from_slice(bytes);
    }

    (data, index)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn index_files_round_trip() {
        let mut records = Records::default();
        records.keep(7, b"seven");
        records.keep(3, b"three");
        records.keep(3, b"later");
        let (data, index) = resource_files(&records);
        assert_eq!(data, b"threeseven");
        let read = indexed_records(&data, &index);
        assert_eq!(read.0, vec![(3, b"three".to_vec()), (7, b"seven".to_vec())]);
        assert!(indexed_records(&data, &index[..7]).0.is_empty());
    }

    #[test]
    fn records_come_from_files_and_containers() {
        let file = |name: &str, bytes: &[u8]| SourceRecord {
            name: name.into(),
            bytes: bytes.to_vec(),
            ..SourceRecord::default()
        };
        let (text, newspaper) = find_records(&[
            file("txt3000.raw", b"a"),
            file("PPDT1002", b"b"),
            file("PPDT1009", b"c"),
            file("TXT3000", b"d"),
        ]);
        assert_eq!(text.0, vec![(3000, b"a".to_vec())]);
        assert_eq!(newspaper.0, vec![(1002, b"b".to_vec())]);
    }
}
