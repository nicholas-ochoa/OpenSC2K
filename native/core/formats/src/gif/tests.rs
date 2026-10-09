//! Tests of the GIF codec.

use super::*;

fn palette() -> Vec<u8> {
    (0..256).flat_map(|i| [i as u8, (255 - i) as u8, 7]).collect()
}

#[test]
fn round_trip_with_transparency() {
    let pixels: Vec<i32> = (0..600).map(|i| if i % 7 == 0 { -1 } else { i % 200 }).collect();
    let bytes = encode(30, 20, &pixels, &palette()).unwrap();
    let decoded = decode(&bytes).unwrap();
    assert_eq!((decoded.width, decoded.height), (30, 20));
    assert_eq!(decoded.pixels, pixels);
    assert_eq!(&decoded.palette[3..6], &[1, 254, 7]);
}

#[test]
fn cycle_frames_follow_color_changes() {
    let pixels = vec![1, 2, 3, 4];
    let mut mappings: Vec<Vec<i32>> = vec![(0..256).collect(); CYCLE_TICKS + 1];
    mappings[61][2] = 9;
    let (bytes, frames) = encode_cycle(2, 2, &pixels, &palette(), &mappings).unwrap();

    // tick 60 changes a used color and tick 61 restores it
    assert_eq!(frames, 3);
    assert_eq!(decode(&bytes).unwrap().pixels, pixels);
}

#[test]
fn errors() {
    assert_eq!(decode(b"nope").err().unwrap(), "File does not have a GIF signature.");
    let all: Vec<i32> = (-1..256).collect();
    assert_eq!(
        encode(all.len() as i64, 1, &all, &palette()).err().unwrap(),
        "GIF transparency requires an unused palette index."
    );
    assert_eq!(
        encode(1, 1, &[300], &palette()).err().unwrap(),
        "GIF pixel is outside the indexed palette."
    );
}
