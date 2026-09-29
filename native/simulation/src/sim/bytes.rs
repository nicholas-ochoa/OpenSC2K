//! Big-endian fields in caller-validated buffers, as in BinaryData.
//! Values are `i64` because GDScript integers are 64-bit. Writes keep the low bits.

#[inline]
pub fn read_u16_be(data: &[u8], offset: i64) -> i64 {
    let offset = offset as usize;

    ((data[offset] as i64) << 8) | data[offset + 1] as i64
}

#[inline]
pub fn read_u32_be(data: &[u8], offset: i64) -> i64 {
    let offset = offset as usize;

    ((data[offset] as i64) << 24)
        | ((data[offset + 1] as i64) << 16)
        | ((data[offset + 2] as i64) << 8)
        | data[offset + 3] as i64
}

#[inline]
pub fn read_i32_be(data: &[u8], offset: i64) -> i64 {
    let value = read_u32_be(data, offset);

    if value & 0x8000_0000 != 0 { value - 0x1_0000_0000 } else { value }
}

#[inline]
pub fn write_u16_be(data: &mut [u8], offset: i64, value: i64) {
    let offset = offset as usize;
    data[offset] = (value >> 8) as u8;
    data[offset + 1] = value as u8;
}

#[inline]
pub fn write_u32_be(data: &mut [u8], offset: i64, value: i64) {
    let offset = offset as usize;
    data[offset] = (value >> 24) as u8;
    data[offset + 1] = (value >> 16) as u8;
    data[offset + 2] = (value >> 8) as u8;
    data[offset + 3] = value as u8;
}

/// Add a signed value to a big-endian 32-bit field. The stored value wraps.
#[inline]
pub fn add_i32_be(data: &mut [u8], offset: i64, value: i64) {
    let current = read_i32_be(data, offset);
    write_u32_be(data, offset, current + value);
}

/// A GDScript packed-array index. Negative indices count from the end.
#[inline]
pub fn slot(len: usize, index: i64) -> usize {
    if index < 0 { (len as i64 + index) as usize } else { index as usize }
}

/// Read a byte as a GDScript integer. Negative indices count from the end.
#[inline]
pub fn at(data: &[u8], index: i64) -> i64 {
    data[slot(data.len(), index)] as i64
}

/// Store the low byte of `value`, as a PackedByteArray assignment does.
#[inline]
pub fn put(data: &mut [u8], index: i64, value: i64) {
    let position = slot(data.len(), index);
    data[position] = value as u8;
}

/// Little-endian 64-bit word, as PackedByteArray.decode_u64 returns it.
#[inline]
pub fn decode_u64(data: &[u8], offset: usize) -> u64 {
    let mut word = [0u8; 8];
    word.copy_from_slice(&data[offset..offset + 8]);
    u64::from_le_bytes(word)
}
