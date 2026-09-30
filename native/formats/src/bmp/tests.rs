//! Tests of the BMP codec.

use super::*;

fn palette() -> Vec<u8> {
    (0..256).flat_map(|i| [i as u8, 3, 9]).collect()
}

#[test]
fn round_trip_and_dib() {
    let pixels = vec![1, -1, 7, 255, 0, 3];
    let bytes = encode(3, 2, &pixels, &palette(), 5).unwrap();
    let decoded = decode(&bytes).unwrap();
    assert_eq!(decoded.pixels, vec![1, 5, 7, 255, 0, 3]);
    assert_eq!(&decoded.palette[6..9], &[2, 3, 9]);
    assert!(!decoded.top_down);
    let dib = to_dib(&bytes).unwrap();
    assert_eq!(from_dib(&dib).unwrap(), bytes);
}

#[test]
fn palette_mapping() {
    let mut source = palette();
    source[6..9].copy_from_slice(&[3, 3, 9]);
    let (mapped, remapped) = map_to_palette(&[0, 1, 2], &source, &palette(), 0);
    assert_eq!(mapped, vec![-1, 1, 3]);
    assert_eq!(remapped, 1);
}

#[test]
fn used_color_mapping() {
    let mut source = palette();
    source[6..9].copy_from_slice(&[3, 3, 9]);
    let (mapped, remapped) = map_used_colors(&[-1, 2, 2, 1], &source, &palette());
    assert_eq!(mapped, vec![-1, 3, 3, 1]);
    assert_eq!(remapped, 1);
}

#[test]
fn indexed_depths() {
    // a 4-bit, 3 by 1 DIB with two colors
    let mut dib = vec![0; 40];
    dib[0] = 40;
    dib[4] = 3;
    dib[8] = 1;
    dib[12] = 1;
    dib[14] = 4;
    dib[32] = 2;
    dib.extend_from_slice(&[1, 2, 3, 0, 4, 5, 6, 0]);
    dib.extend_from_slice(&[0x10, 0x10, 0, 0]);
    let decoded = decode_indexed(&dib, false).unwrap();
    assert_eq!(decoded.pixels, vec![1, 0, 1]);
    assert_eq!(&decoded.palette[..6], &[3, 2, 1, 6, 5, 4]);
    dib[40 + 8] = 0x20;
    assert_eq!(decode_indexed(&dib, false).err().unwrap(), "Bitmap pixel exceeds the color table.");
}

#[test]
fn errors() {
    assert_eq!(decode(&[0; 4]).err().unwrap(), "BMP file is shorter than an 8-bit indexed header.");
    assert_eq!(
        encode(0, 1, &[], &palette(), 0).err().unwrap(),
        "BMP dimensions are invalid or too large."
    );
    assert_eq!(from_dib(&[0; 4]).err().unwrap(), "DIB data is shorter than its information header.");
}
