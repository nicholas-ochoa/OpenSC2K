//! Content signatures of city byte arrays for view caches. Equal content gives
//! an equal signature. A signature is not saved, and it has no meaning outside
//! one build.

/// Independent lanes, so that the multiplications of one pass can overlap.
const LANES: usize = 4;
const WORD_BYTES: usize = 8;
const BLOCK_BYTES: usize = LANES * WORD_BYTES;
const SEEDS: [u64; LANES] = [
    0x9e37_79b9_7f4a_7c15,
    0xc2b2_ae3d_27d4_eb4f,
    0x1656_67b1_9e37_79f9,
    0x27d4_eb2f_1656_67c5,
];
const MULTIPLIER: u64 = 0xff51_afd7_ed55_8ccd;
const FINAL_MULTIPLIER: u64 = 0xc4ce_b9fe_1a85_ec53;
const ROTATION: u32 = 29;

#[inline]
fn mix(state: u64, value: u64) -> u64 {
    (state ^ value).wrapping_mul(MULTIPLIER).rotate_left(ROTATION)
}

/// The signature of `data` with only the bits of `mask` in each byte.
pub fn masked_bytes(data: &[u8], mask: u8) -> i64 {
    let word_mask = u64::from_ne_bytes([mask; WORD_BYTES]);
    let mut lanes = SEEDS;
    let mut blocks = data.chunks_exact(BLOCK_BYTES);

    for block in &mut blocks {
        for (lane, word) in lanes.iter_mut().zip(block.chunks_exact(WORD_BYTES)) {
            let value = u64::from_le_bytes(word.try_into().unwrap_or_default());
            *lane = mix(*lane, value & word_mask);
        }
    }

    let mut state = data.len() as u64;

    for lane in lanes {
        state = mix(state, lane);
    }

    for &byte in blocks.remainder() {
        state = mix(state, u64::from(byte & mask));
    }

    state ^= state >> 33;
    state = state.wrapping_mul(FINAL_MULTIPLIER);
    state ^= state >> 33;

    state as i64
}

#[cfg(test)]
mod tests {
    use super::*;

    fn pattern(size: usize) -> Vec<u8> {
        (0..size).map(|index| ((index * 37 + (index >> 3)) & 255) as u8).collect()
    }

    #[test]
    fn masked_content_gives_the_signature_of_the_masked_bytes() {
        for size in [0, 1, 7, 8, 9, 31, 32, 33, 16384, 262_144] {
            let data = pattern(size);

            for mask in [0u8, 1, 4, 0x3f, 0x80, 0xc6, 0xff] {
                let masked: Vec<u8> = data.iter().map(|byte| byte & mask).collect();
                assert_eq!(
                    masked_bytes(&data, mask),
                    masked_bytes(&masked, 0xff),
                    "size {} mask {:#x}",
                    size,
                    mask
                );
            }
        }
    }

    #[test]
    fn a_visible_change_changes_the_signature() {
        let size = 16384 + 5;
        let data = pattern(size);
        let original = masked_bytes(&data, 0xc6);

        for index in [0, 31, 4095, 4096, size - 1] {
            let mut changed = data.clone();
            changed[index] ^= 0x40;
            assert_ne!(masked_bytes(&changed, 0xc6), original, "visible bit at {}", index);

            changed[index] ^= 0x40 | 0x01;
            assert_eq!(masked_bytes(&changed, 0xc6), original, "masked bit at {}", index);
        }
    }

    #[test]
    fn the_length_is_part_of_the_signature() {
        assert_ne!(masked_bytes(&[0; 8], 0xff), masked_bytes(&[0; 16], 0xff));
        assert_ne!(masked_bytes(&[], 0xff), masked_bytes(&[0], 0xff));
    }
}
