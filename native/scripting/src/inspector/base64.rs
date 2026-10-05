//! Base64 encoding (RFC 4648) for the WebSocket handshake.

const ALPHABET: &[u8; 64] = b"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
const PADDING: char = '=';

pub fn encode(data: &[u8]) -> String {
    let mut text = String::with_capacity(data.len().div_ceil(3) * 4);

    for group in data.chunks(3) {
        let bytes = [group[0], *group.get(1).unwrap_or(&0), *group.get(2).unwrap_or(&0)];
        let bits = (bytes[0] as u32) << 16 | (bytes[1] as u32) << 8 | bytes[2] as u32;

        for index in 0..4 {
            if index <= group.len() {
                text.push(ALPHABET[(bits >> (18 - index * 6)) as usize & 0x3f] as char);
            } else {
                text.push(PADDING);
            }
        }
    }

    text
}

#[cfg(test)]
mod tests {
    use super::encode;

    #[test]
    fn encodes_the_standard_test_vectors() {
        let cases = [
            ("", ""),
            ("f", "Zg=="),
            ("fo", "Zm8="),
            ("foo", "Zm9v"),
            ("foob", "Zm9vYg=="),
            ("fooba", "Zm9vYmE="),
            ("foobar", "Zm9vYmFy"),
        ];

        for (input, expected) in cases {
            assert_eq!(encode(input.as_bytes()), expected);
        }
    }
}
