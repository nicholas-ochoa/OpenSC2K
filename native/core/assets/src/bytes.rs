//! Byte readers of the resource formats. A short read gives 0.

pub fn read_u16_be(data: &[u8], at: usize) -> u16 {
    match data.get(at..at + 2) {
        Some(bytes) => u16::from_be_bytes([bytes[0], bytes[1]]),
        None => 0,
    }
}

pub fn read_u32_be(data: &[u8], at: usize) -> u32 {
    match data.get(at..at + 4) {
        Some(bytes) => u32::from_be_bytes([bytes[0], bytes[1], bytes[2], bytes[3]]),
        None => 0,
    }
}

pub fn read_u32_le(data: &[u8], at: usize) -> u32 {
    match data.get(at..at + 4) {
        Some(bytes) => u32::from_le_bytes([bytes[0], bytes[1], bytes[2], bytes[3]]),
        None => 0,
    }
}

/// Bytes as Latin-1 text, as Godot's `get_string_from_ascii`. The text ends at
/// the first zero byte.
pub fn latin1(data: &[u8]) -> String {
    data.iter()
        .take_while(|&&byte| byte != 0)
        .map(|&byte| char::from(byte))
        .collect()
}
