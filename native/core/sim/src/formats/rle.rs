//! The Maxis run-length code of compressed city chunks.
//!
//! A control byte below 0x80 starts a literal of that many bytes. A control byte
//! above 0x80 repeats the next byte `control - 127` times. 0x80 is reserved.

/// The largest run that one control byte can hold.
const MAX_RUN: usize = 128;

/// The largest literal that the encoder writes.
const MAX_LITERAL: usize = 127;

/// Decode `encoded`. With `expected_size`, reject output that is not that size.
pub fn decode(encoded: &[u8], expected_size: Option<usize>) -> Result<Vec<u8>, String> {
    let mut decoded = Vec::with_capacity(expected_size.unwrap_or(encoded.len() * 2));
    let mut read_offset = 0;

    while read_offset < encoded.len() {
        let control = encoded[read_offset] as usize;
        read_offset += 1;

        if control < 0x80 {
            if read_offset + control > encoded.len() {
                return Err("Literal data extends past the encoded input".into());
            }

            if expected_size.is_some_and(|size| decoded.len() + control > size) {
                return Err("Literal data extends past the expected output size".into());
            }

            decoded.extend_from_slice(&encoded[read_offset..read_offset + control]);
            read_offset += control;
        } else if control == 0x80 {
            return Err("Control byte 0x80 is reserved".into());
        } else {
            if read_offset >= encoded.len() {
                return Err("Run control byte has no value byte".into());
            }

            let count = control - 127;

            if expected_size.is_some_and(|size| decoded.len() + count > size) {
                return Err("Run extends past the expected output size".into());
            }

            let value = encoded[read_offset];
            read_offset += 1;
            decoded.resize(decoded.len() + count, value);
        }
    }

    if let Some(size) = expected_size
        && decoded.len() != size
    {
        return Err(format!("Decoded {} bytes; expected {} bytes", decoded.len(), size));
    }

    Ok(decoded)
}

/// Encode `decoded` as the original game does. Runs of two or more bytes become
/// runs. Other bytes become literals of at most 127 bytes.
pub fn encode(decoded: &[u8]) -> Vec<u8> {
    let mut encoded = Vec::with_capacity(decoded.len() / 2 + 16);
    let mut read_offset = 0;

    while read_offset < decoded.len() {
        let run_size = measure_run(decoded, read_offset);

        if run_size >= 2 {
            encoded.push((127 + run_size) as u8);
            encoded.push(decoded[read_offset]);
            read_offset += run_size;
            continue;
        }

        let literal_start = read_offset;
        read_offset += 1;

        while read_offset < decoded.len() && read_offset - literal_start < MAX_LITERAL {
            if measure_run(decoded, read_offset) >= 2 {
                break;
            }

            read_offset += 1;
        }

        encoded.push((read_offset - literal_start) as u8);
        encoded.extend_from_slice(&decoded[literal_start..read_offset]);
    }

    encoded
}

fn measure_run(data: &[u8], start: usize) -> usize {
    let first = data[start];
    let limit = (data.len() - start).min(MAX_RUN);
    let mut run_size = 1;

    while run_size < limit && data[start + run_size] == first {
        run_size += 1;
    }

    run_size
}

#[cfg(test)]
mod tests {
    use super::*;

    fn check_round_trip(original: &[u8]) {
        let encoded = encode(original);

        assert_eq!(decode(&encoded, Some(original.len())).unwrap(), original);
        assert_eq!(decode(&encoded, None).unwrap(), original);
    }

    #[test]
    fn round_trips_runs_literals_and_limits() {
        check_round_trip(&[]);
        check_round_trip(&[7]);
        check_round_trip(&[1, 2, 3, 3, 3, 4]);
        check_round_trip(&[9; 128]);
        check_round_trip(&[9; 129]);
        check_round_trip(&[9; 300]);
        check_round_trip(&(0..=255).cycle().take(1000).collect::<Vec<u8>>());
    }

    #[test]
    fn encodes_the_original_control_bytes() {
        assert_eq!(encode(&[5, 5]), [0x81, 5]);
        assert_eq!(encode(&[5; 128]), [0xff, 5]);
        assert_eq!(encode(&[5; 129]), [0xff, 5, 1, 5]);
        assert_eq!(encode(&[1, 2, 2]), [1, 1, 0x81, 2]);

        let literal = (0..200).map(|value| value as u8).collect::<Vec<u8>>();
        let encoded = encode(&literal);

        assert_eq!(encoded[0], 127);
        assert_eq!(encoded[128], 73);
    }

    #[test]
    fn rejects_invalid_input() {
        assert_eq!(decode(&[0x80], None).unwrap_err(), "Control byte 0x80 is reserved");
        assert_eq!(decode(&[2, 1], None).unwrap_err(), "Literal data extends past the encoded input");
        assert_eq!(decode(&[0x81], None).unwrap_err(), "Run control byte has no value byte");
        assert_eq!(
            decode(&[0x82, 4], Some(2)).unwrap_err(),
            "Run extends past the expected output size"
        );
        assert_eq!(
            decode(&[2, 1, 2], Some(1)).unwrap_err(),
            "Literal data extends past the expected output size"
        );
        assert_eq!(decode(&[1, 1], Some(2)).unwrap_err(), "Decoded 1 bytes; expected 2 bytes");
    }

    #[test]
    fn decodes_empty_literals() {
        assert_eq!(decode(&[0, 1, 7], Some(1)).unwrap(), [7]);
    }
}
