//! SHA-1 for the WebSocket handshake (RFC 6455 section 4.2.2). The handshake
//! only proves that the server read the key; it is not a security measure.

const INITIAL_STATE: [u32; 5] = [0x6745_2301, 0xefcd_ab89, 0x98ba_dcfe, 0x1032_5476, 0xc3d2_e1f0];
const BLOCK_SIZE: usize = 64;

pub fn digest(data: &[u8]) -> [u8; 20] {
    let mut state = INITIAL_STATE;
    let mut message = data.to_vec();
    let bit_length = (data.len() as u64).wrapping_mul(8);

    // padding: one bit, zeros, then the length in bits
    message.push(0x80);

    while message.len() % BLOCK_SIZE != BLOCK_SIZE - 8 {
        message.push(0);
    }

    message.extend_from_slice(&bit_length.to_be_bytes());

    for block in message.chunks(BLOCK_SIZE) {
        compress(&mut state, block);
    }

    let mut result = [0u8; 20];

    for (index, word) in state.iter().enumerate() {
        result[index * 4..index * 4 + 4].copy_from_slice(&word.to_be_bytes());
    }

    result
}

fn compress(state: &mut [u32; 5], block: &[u8]) {
    let mut words = [0u32; 80];

    for index in 0..16 {
        words[index] = u32::from_be_bytes([block[index * 4], block[index * 4 + 1], block[index * 4 + 2], block[index * 4 + 3]]);
    }

    for index in 16..80 {
        words[index] = (words[index - 3] ^ words[index - 8] ^ words[index - 14] ^ words[index - 16]).rotate_left(1);
    }

    let [mut a, mut b, mut c, mut d, mut e] = *state;

    for (index, word) in words.iter().enumerate() {
        let (mix, constant) = match index {
            0..=19 => ((b & c) | (!b & d), 0x5a82_7999),
            20..=39 => (b ^ c ^ d, 0x6ed9_eba1),
            40..=59 => ((b & c) | (b & d) | (c & d), 0x8f1b_bcdc),
            _ => (b ^ c ^ d, 0xca62_c1d6),
        };

        let next = a
            .rotate_left(5)
            .wrapping_add(mix)
            .wrapping_add(e)
            .wrapping_add(constant)
            .wrapping_add(*word);
        e = d;
        d = c;
        c = b.rotate_left(30);
        b = a;
        a = next;
    }

    for (value, added) in state.iter_mut().zip([a, b, c, d, e]) {
        *value = value.wrapping_add(added);
    }
}

#[cfg(test)]
mod tests {
    use super::digest;

    fn hex(bytes: &[u8]) -> String {
        bytes.iter().map(|byte| format!("{byte:02x}")).collect()
    }

    #[test]
    fn digests_match_the_standard_test_vectors() {
        assert_eq!(hex(&digest(b"")), "da39a3ee5e6b4b0d3255bfef95601890afd80709");
        assert_eq!(hex(&digest(b"abc")), "a9993e364706816aba3e25717850c26c9cd0d89d");
        assert_eq!(
            hex(&digest(b"abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq")),
            "84983e441c3bd26ebaae4aa1f95129e5e54670f1"
        );
        assert_eq!(hex(&digest(&vec![b'a'; 1_000_000])), "34aa973cd4c4daa4f61eeb2bdbad27316534016f");
    }
}
