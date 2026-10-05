//! Dotted version numbers such as "0.10.2".

use crate::text::strip_edges;

/// The number of one part: its leading digits, or 0.
fn part(parts: &[&str], index: usize) -> i64 {
    let Some(text) = parts.get(index) else {
        return 0;
    };
    let text = strip_edges(text);
    let digits = text.bytes().take_while(u8::is_ascii_digit).count();

    text[..digits]
        .parse()
        .unwrap_or(if digits > 0 { i64::MAX } else { 0 })
}

/// Compare dotted versions such as "0.10.2" and "0.9": -1, 0, or 1. A missing
/// part counts 0; a part that is not a number counts its leading digits.
pub fn compare(first: &str, second: &str) -> i64 {
    let first_parts: Vec<&str> = first.split('.').collect();
    let second_parts: Vec<&str> = second.split('.').collect();

    for index in 0..first_parts.len().max(second_parts.len()) {
        let (a, b) = (part(&first_parts, index), part(&second_parts, index));

        if a != b {
            return if a < b { -1 } else { 1 };
        }
    }

    0
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parts_compare_as_numbers() {
        assert_eq!(compare("0.10.2", "0.9"), 1);
        assert_eq!(compare("1.0", "1.0.0"), 0);
        assert_eq!(compare("1.2rc", "1.3"), -1);
        assert_eq!(compare("", "0"), 0);
    }
}
