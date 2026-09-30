//! CRC-32 of PNG and ZIP records (reflected polynomial 0xedb88320).

const fn table() -> [u32; 256] {
    let mut table = [0_u32; 256];
    let mut byte = 0;
    while byte < 256 {
        let mut value = byte as u32;
        let mut bit = 0;
        while bit < 8 {
            value = (value >> 1) ^ if value & 1 != 0 { 0xedb8_8320 } else { 0 };
            bit += 1;
        }
        table[byte] = value;
        byte += 1;
    }
    table
}
static TABLE: [u32; 256] = table();

pub fn calculate(bytes: &[u8]) -> u32 {
    !bytes.iter().fold(u32::MAX, |value, byte| {
        (value >> 8) ^ TABLE[((value ^ u32::from(*byte)) & 0xff) as usize]
    })
}

#[cfg(test)]
mod tests {
    #[test]
    fn known_values() {
        assert_eq!(super::calculate(b""), 0);
        assert_eq!(super::calculate(b"123456789"), 0xcbf4_3926);
        assert_eq!(super::calculate(b"IEND"), 0xae42_6082);
    }
}
