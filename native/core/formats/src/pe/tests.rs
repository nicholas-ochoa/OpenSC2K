//! Tests of the executable resource readers.

use super::*;

#[test]
fn rle8_runs_escapes_and_errors() {
    let (pixels, consumed) = decode_rle8(&[3, 7, 0, 0, 0, 3, 1, 2, 3, 0, 0, 1], 4, 2).unwrap();
    assert_eq!(pixels, vec![1, 2, 3, 0, 7, 7, 7, 0]);
    assert_eq!(consumed, 12);
    assert_eq!(decode_rle8(&[5, 1, 0, 1], 4, 1).err().unwrap(), "RLE8 encoded run exceeds its row");
    assert_eq!(decode_rle8(&[1, 1], 4, 1).err().unwrap(), "RLE8 end-of-bitmap escape is missing");
}

fn icon(bits: u32) -> Vec<u8> {
    // 8 by 1 pixels: header, two colors, xor row, and row
    let mut bytes = vec![0; 40];
    bytes[0] = 40;
    bytes[4] = 8;
    bytes[8] = 2;
    bytes[12] = 1;
    bytes[14] = bits as u8;
    bytes[32] = 2;
    bytes.extend_from_slice(&[0, 0, 0, 0, 30, 20, 10, 0]);
    bytes.extend_from_slice(&[0b1010_0000, 0, 0, 0]);
    bytes.extend_from_slice(&[0b0100_0000, 0, 0, 0]);
    bytes
}

#[test]
fn icons() {
    let decoded = decode_icon(&icon(1), false).unwrap();
    assert_eq!(decoded.pixels, vec![1, 0, 1, 0, 0, 0, 0, 0]);
    assert_eq!(decoded.and_mask, vec![0, 1, 0, 0, 0, 0, 0, 0]);
    assert_eq!(&decoded.palette[3..6], &[10, 20, 30]);
    assert_eq!(decoded.inverting_pixels, 0);
    let rgba = icon_transparent(&decoded.pixels, &decoded.and_mask, &decoded.palette);
    assert_eq!(&rgba[..8], &[10, 20, 30, 255, 0, 0, 0, 0]);
    let over = icon_composite(&decoded.pixels, &decoded.and_mask, &decoded.palette, &[1; 32]);
    assert_eq!(&over[..8], &[10, 20, 30, 255, 1, 1, 1, 255]);
    assert!(decode_icon(&icon(2), false).is_err());
}

// Root 64 and a directory at 96 with one named and one numeric entry.
fn named_directory(name: &str) -> Vec<u8> {
    let mut bytes = vec![0; 384];
    bytes[108] = 1;
    bytes[110] = 1;
    bytes[112..116].copy_from_slice(&0x8000_0080_u32.to_le_bytes());
    bytes[116..120].copy_from_slice(&0x8000_00c0_u32.to_le_bytes());
    bytes[120..124].copy_from_slice(&7_u32.to_le_bytes());
    bytes[124..128].copy_from_slice(&0x8000_00d0_u32.to_le_bytes());
    let encoded: Vec<u8> = name.encode_utf16().flat_map(u16::to_le_bytes).collect();
    bytes[192..194].copy_from_slice(&((encoded.len() / 2) as u16).to_le_bytes());
    bytes[194..194 + encoded.len()].copy_from_slice(&encoded);

    // names are length-prefixed, not terminated
    bytes[194 + encoded.len()] = 0xff;
    bytes
}

fn directory(bytes: &[u8]) -> Directory<'_> {
    Directory {
        bytes,
        root: 64,
        sections: 0,
        section_count: 0,
    }
}

#[test]
fn named_and_numeric_children() {
    for name in ["ADVICEU", "城🏙"] {
        let bytes = named_directory(name);
        let d = directory(&bytes);
        assert_eq!(d.named_child(96, name), Some(256));
        assert_eq!(d.named_child(96, "missing"), None);
        assert_eq!(d.named_child(96, "7"), None);
        assert_eq!(d.numeric_child(96, 7), Some(272));

        for length in 0..272 {
            assert_eq!(directory(&bytes[..length]).named_child(96, name), None);
        }
    }

    let bytes = named_directory("城🏙");

    for (at, value) in [(108, 0xffff_u32), (112, 0xffff_ffff), (192, 0xffff), (116, 192), (116, 0xffff_ffff)] {
        let mut bad = bytes.clone();
        let width = if at == 108 || at == 192 { 2 } else { 4 };
        bad[at..at + width].copy_from_slice(&value.to_le_bytes()[..width]);
        assert_eq!(directory(&bad).named_child(96, "城🏙"), None, "change at {at}");
    }
}

#[test]
fn bounded_reads() {
    let bytes = [0xa5, 0x12, 0x34, 0x56, 0x78, 0x5a];

    for size in 0..=bytes.len() {
        let prefix = &bytes[..size];

        for offset in -1..size as i64 + 2 {
            let fits = |n: i64| offset >= 0 && offset + n <= size as i64;
            let at = offset.max(0) as usize;
            let short = if fits(2) {
                u32::from(u16::from_le_bytes([prefix[at], prefix[at + 1]]))
            } else {
                0
            };

            let word = if fits(4) {
                u32::from_le_bytes(prefix[at..at + 4].try_into().unwrap())
            } else {
                0
            };

            assert_eq!(u16_at(prefix, offset), short);
            assert_eq!(u32_at(prefix, offset), word);
        }
    }
}

#[test]
fn groups() {
    let mut bytes = vec![0, 0, 1, 0, 1, 0];
    bytes.extend_from_slice(&[32, 32, 0, 0, 1, 0, 4, 0, 100, 0, 0, 0, 5, 0]);
    let entries = decode_group(&bytes, false).unwrap();
    assert_eq!(
        (entries[0].id, entries[0].width, entries[0].bits, entries[0].length),
        (5, 32, 4, 100)
    );
    assert!(decode_group(&bytes, true).is_err());
}
