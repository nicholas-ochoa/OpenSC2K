//! Original Korean text uses Johab, whose trail bytes include ASCII characters.
//! Newspaper grammar also has opcodes; plain TXT resources do not.

use super::johab_table::ROWS;
use crate::bytes::{latin1, read_u32_be};
use std::sync::OnceLock;

/// The grammar opcodes that take one argument byte.
const ARGUMENT_OPCODES: [u8; 8] = [0x25, 0x26, 0x2a, 0x3c, 0x40, 0x5b, 0x5c, 0x5e];
/// The opcode whose argument is a literal character, which can be a pair.
const LITERAL_OPCODE: u8 = 0x5c;
const MINIMUM_HANGUL_SYLLABLES: usize = 16;
const FIRST_HANGUL_SYLLABLE: u32 = 0xac00;
const LAST_HANGUL_SYLLABLE: u32 = 0xd7a3;
const INVALID_PAIR: char = '\u{fffd}';
const FIRST_LEAD: usize = 0x80;
const TRAILS: usize = 256;

/// The code point of each pair, by lead byte from 0x80 and trail byte. 0 marks an invalid pair.
fn table() -> &'static [[u32; TRAILS]] {
    static TABLE: OnceLock<Vec<[u32; TRAILS]>> = OnceLock::new();

    TABLE.get_or_init(|| {
        let mut table = vec![[0; TRAILS]; TRAILS - FIRST_LEAD];

        for (lead, row) in ROWS {
            let points = &mut table[usize::from(lead) - FIRST_LEAD];

            for (trail, character) in row.chars().enumerate().take(TRAILS) {
                points[trail] = if character == INVALID_PAIR { 0 } else { u32::from(character) };
            }
        }

        table
    })
}

/// The Unicode code point of the Johab pair at `at`, or 0 for an invalid pair.
pub fn code_point(bytes: &[u8], at: usize) -> u32 {
    match (bytes.get(at), bytes.get(at + 1)) {
        (Some(&lead), Some(&trail)) if usize::from(lead) >= FIRST_LEAD => table()[usize::from(lead) - FIRST_LEAD][usize::from(trail)],
        _ => 0,
    }
}

fn is_syllable(point: u32) -> bool {
    (FIRST_HANGUL_SYLLABLE..=LAST_HANGUL_SYLLABLE).contains(&point)
}

/// Detect the whole text resource file, not only the requested short label.
/// Every high byte must form a valid pair. An uncertain or malformed file
/// keeps its existing single-byte decoding instead of discarding source bytes.
pub fn is_text(bytes: &[u8], record_boundaries: &[usize]) -> bool {
    let mut cursor = 0;
    let mut syllables = 0;

    for &end in record_boundaries.iter().chain([bytes.len()].iter()) {
        if end < cursor || end > bytes.len() {
            return false;
        }

        while cursor < end {
            if bytes[cursor] < 0x80 {
                cursor += 1;
                continue;
            }

            // Two malformed records cannot supply half a character each.
            if cursor + 1 >= end {
                return false;
            }

            let point = code_point(bytes, cursor);

            if point == 0 {
                return false;
            }

            syllables += usize::from(is_syllable(point));
            cursor += 2;
        }
    }

    syllables >= MINIMUM_HANGUL_SYLLABLES
}

/// Decode a file that `is_text` identified. Entries can be ASCII or shorter
/// than the detection threshold. An invalid pair keeps the Latin-1 text.
pub fn decode_text(bytes: &[u8]) -> String {
    let mut text = String::new();
    let mut cursor = 0;

    while cursor < bytes.len() {
        let value = bytes[cursor];

        if value < 0x80 {
            text.push(char::from(value));
            cursor += 1;
            continue;
        }

        match char::from_u32(code_point(bytes, cursor)) {
            Some(character) if character != '\0' => text.push(character),
            _ => return latin1(bytes),
        }

        cursor += 2;
    }

    text
}

/// Whether newspaper grammar is Johab text. Opcode arguments can be pair trails.
pub fn is_grammar(grammar: &[u8], offsets: &[u8]) -> bool {
    let mut visited = std::collections::HashSet::new();
    let mut syllables = 0;
    let mut invalid = 0;

    for at in (0..offsets.len().saturating_sub(3)).step_by(4) {
        let mut cursor = read_u32_be(offsets, at) as usize;

        if !visited.insert(cursor) {
            continue;
        }

        while cursor < grammar.len() && grammar[cursor] != 0 {
            let value = grammar[cursor];

            if ARGUMENT_OPCODES.contains(&value) {
                cursor += if value == LITERAL_OPCODE && code_point(grammar, cursor + 1) > 0 {
                    3
                } else {
                    2
                };
                continue;
            }

            if value >= 0x80 {
                let point = code_point(grammar, cursor);

                if point > 0 {
                    syllables += usize::from(is_syllable(point));
                    cursor += 2;
                    continue;
                }

                invalid += 1;
            }

            cursor += 1;
        }
    }

    // Short accidental CP437 or token pairs are not enough to select a
    // language. The supplied Korean grammar has over 80,000 complete Hangul
    // pairs and no unmatched high bytes outside explicit opcode arguments.
    syllables >= MINIMUM_HANGUL_SYLLABLES && invalid == 0
}

#[cfg(test)]
mod tests {
    use super::*;

    const KOREAN: [u8; 4] = [0xd0, 0x65, 0x8b, 0xa1];

    #[test]
    fn pairs_map_to_their_characters() {
        assert_eq!(code_point(&[0xd0, 0x65], 0), u32::from('한'));
        assert_eq!(code_point(&[0xd9, 0x40], 0), u32::from('“'));
        assert_eq!(code_point(&[0x84, 0x5c], 0), u32::from('ㅍ'));
        assert_eq!(code_point(&[0xff, 0xff], 0), 0);
        assert_eq!(code_point(&[0x88], 0), 0);
        assert_eq!(code_point(&[0x41, 0x41], 0), 0);
    }

    #[test]
    fn text_needs_enough_syllables_and_whole_pairs() {
        let long: Vec<u8> = KOREAN.iter().copied().cycle().take(KOREAN.len() * 8).collect();
        assert!(is_text(&long, &[]));
        assert!(!is_text(&KOREAN, &[]), "too few syllables");
        assert!(!is_text(&long, &[1]), "a pair cannot cross a record boundary");
        assert_eq!(decode_text(&[b'A', 0xd0, 0x65]), "A한");
        assert_eq!(
            decode_text(&[b'A', 0xff, 0xff]),
            "A\u{ff}\u{ff}",
            "an invalid pair keeps the Latin-1 text"
        );
    }
}
