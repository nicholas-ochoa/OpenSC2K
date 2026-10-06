//! The 256-color palette of the original graphics and its color cycles, as
//! Sc2Palette. Two groups of entries rotate: a fast group every base tick and
//! a slow group every eight.

pub const COLOR_COUNT: usize = 256;
const BMP_HEADER_SIZE: usize = 14;
const MIN_DIB_SIZE: usize = 40;
const BMP_MIN_SIZE: usize = 54;
const INDEXED_BITS: usize = 8;
pub const FAST_CYCLE_START: usize = 0xab;
pub const FAST_CYCLE_COUNT: usize = 49;
/// The groups have their own cycles, so the entries cannot simply rotate.
const FAST_CYCLE_TABLE: [usize; FAST_CYCLE_COUNT] = [
    1, 2, 3, 4, 5, 6, 7, 0, 9, 10, 11, 12, 13, 14, 15, 8, 17, 18, 19, 20, 21, 22, 23, 16, 25, 26,
    27, 24, 28, 36, 29, 30, 31, 32, 33, 34, 35, 40, 37, 38, 39, 48, 41, 42, 43, 44, 45, 46, 47,
];
pub const SLOW_CYCLE_START: usize = 0xe0;
pub const SLOW_CYCLE_COUNT: usize = 16;
const SLOW_CYCLE_TABLE: [usize; SLOW_CYCLE_COUNT] =
    [1, 0, 3, 2, 5, 4, 7, 6, 9, 8, 11, 10, 13, 12, 14, 0];
const FAST_CYCLE_LENGTH: i64 = 8;
const SLOW_CYCLE_LENGTH: i64 = 2;
const BASE_TICKS_PER_SLOW_STEP: i64 = 8;
/// The SCURK palette clock: a startup delay, then a fast step every five
/// timer ticks and a slow step every thirty.
const SCURK_FAST_DELAY: i64 = 6;
const SCURK_FAST_TICKS: i64 = 5;
const SCURK_SLOW_DELAY: i64 = 31;
const SCURK_SLOW_TICKS: i64 = 30;

fn u16_le(data: &[u8], at: usize) -> usize {
    usize::from(u16::from_le_bytes([data[at], data[at + 1]]))
}

fn u32_le(data: &[u8], at: usize) -> usize {
    u32::from_le_bytes([data[at], data[at + 1], data[at + 2], data[at + 3]]) as usize
}

/// The RGB colors of an 8-bit Windows BMP palette.
pub fn bmp_colors(bytes: &[u8]) -> Result<Vec<[u8; 3]>, String> {
    if bytes.len() < BMP_MIN_SIZE || bytes[0] != b'B' || bytes[1] != b'M' {
        return Err("Palette file is not a Windows BMP".into());
    }

    let dib_size = u32_le(bytes, 14);

    if dib_size < MIN_DIB_SIZE || BMP_HEADER_SIZE + dib_size > bytes.len() {
        return Err("BMP information header is invalid".into());
    }

    if u16_le(bytes, 28) != INDEXED_BITS {
        return Err("BMP does not use an 8-bit indexed palette".into());
    }

    let count = match u32_le(bytes, 46) {
        0 => COLOR_COUNT,
        count => count,
    };

    if count > COLOR_COUNT {
        return Err("BMP palette has more than 256 colors".into());
    }

    let start = BMP_HEADER_SIZE + dib_size;

    if start + count * 4 > bytes.len() {
        return Err("BMP palette extends past the file".into());
    }

    Ok((0..count)
        .map(|index| {
            let offset = start + index * 4;
            [bytes[offset + 2], bytes[offset + 1], bytes[offset]]
        })
        .collect())
}

fn apply_cycle(indices: &mut [i32], start: usize, table: &[usize]) {
    let previous = indices.to_vec();

    for (destination, &source) in table.iter().enumerate() {
        indices[start + destination] = previous[start + source];
    }
}

/// The palette entry that each entry shows after the cycle steps.
pub fn index_map_steps(fast_steps: i64, slow_steps: i64) -> Vec<i32> {
    let mut indices: Vec<i32> = (0..COLOR_COUNT as i32).collect();

    for _ in 0..fast_steps.max(0).rem_euclid(FAST_CYCLE_LENGTH) {
        apply_cycle(&mut indices, FAST_CYCLE_START, &FAST_CYCLE_TABLE);
    }

    let slow = if slow_steps <= 0 {
        0
    } else {
        1 + (slow_steps - 1).rem_euclid(SLOW_CYCLE_LENGTH)
    };

    for _ in 0..slow {
        apply_cycle(&mut indices, SLOW_CYCLE_START, &SLOW_CYCLE_TABLE);
    }

    indices
}

/// The index map after `base_ticks` of the game clock.
pub fn index_map(base_ticks: i64) -> Vec<i32> {
    let ticks = base_ticks.max(0);
    let slow_ticks = ticks / BASE_TICKS_PER_SLOW_STEP;
    let slow = if slow_ticks == 0 {
        0
    } else {
        1 + (slow_ticks - 1).rem_euclid(SLOW_CYCLE_LENGTH)
    };

    index_map_steps(ticks.rem_euclid(FAST_CYCLE_LENGTH), slow)
}

/// The index map after `timer_ticks` of the SCURK palette clock.
pub fn scurk_index_map(timer_ticks: i64) -> Vec<i32> {
    let ticks = timer_ticks.max(0);
    let fast = if ticks < SCURK_FAST_DELAY {
        0
    } else {
        1 + (ticks - SCURK_FAST_DELAY) / SCURK_FAST_TICKS
    };
    let slow = if ticks < SCURK_SLOW_DELAY {
        0
    } else {
        1 + (ticks - SCURK_SLOW_DELAY) / SCURK_SLOW_TICKS
    };

    index_map_steps(fast, slow)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn cycles_return_to_the_start() {
        assert_eq!(index_map(0), (0..256).collect::<Vec<i32>>());
        assert_eq!(
            index_map(1)[FAST_CYCLE_START],
            (FAST_CYCLE_START + 1) as i32
        );
        assert_eq!(
            index_map(8)[SLOW_CYCLE_START],
            (SLOW_CYCLE_START + 1) as i32
        );
        assert_eq!(index_map(16), index_map_steps(0, 2), "a second slow step");
        assert_eq!(scurk_index_map(5), index_map(0));
        assert_eq!(scurk_index_map(6), index_map_steps(1, 0));
    }

    #[test]
    fn bmp_palettes_need_eight_bits() {
        let mut bmp = vec![0; 54 + 1024];
        bmp[..2].copy_from_slice(b"BM");
        bmp[14] = 40;
        bmp[28] = 8;
        bmp[54..58].copy_from_slice(&[3, 2, 1, 0]);
        assert_eq!(bmp_colors(&bmp).unwrap()[0], [1, 2, 3]);
        bmp[28] = 24;
        assert_eq!(
            bmp_colors(&bmp).unwrap_err(),
            "BMP does not use an 8-bit indexed palette"
        );
    }
}
