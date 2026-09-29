//! Bounds-checked big-endian reads and appending writes for SC2X v4 entries.

/// A cursor over one entry. Each read checks the remaining length.
pub struct Reader<'a> {
    data: &'a [u8],
    offset: usize,
}

impl<'a> Reader<'a> {
    pub fn new(data: &'a [u8]) -> Self {
        Self { data, offset: 0 }
    }

    pub fn offset(&self) -> usize {
        self.offset
    }

    pub fn remaining(&self) -> usize {
        self.data.len() - self.offset
    }

    pub fn bytes(&mut self, count: usize) -> Result<&'a [u8], String> {
        if count > self.remaining() {
            return Err(format!("Data ends at byte {}; {} more bytes are required", self.data.len(), count));
        }

        let result = &self.data[self.offset..self.offset + count];
        self.offset += count;

        Ok(result)
    }

    pub fn u8(&mut self) -> Result<u8, String> {
        Ok(self.bytes(1)?[0])
    }

    pub fn u16(&mut self) -> Result<u16, String> {
        let bytes = self.bytes(2)?;

        Ok(u16::from_be_bytes([bytes[0], bytes[1]]))
    }

    pub fn u32(&mut self) -> Result<u32, String> {
        let bytes = self.bytes(4)?;

        Ok(u32::from_be_bytes([bytes[0], bytes[1], bytes[2], bytes[3]]))
    }

    pub fn i32(&mut self) -> Result<i32, String> {
        Ok(self.u32()? as i32)
    }

    /// A length field as `usize`, checked against the bytes that remain.
    pub fn length(&mut self) -> Result<usize, String> {
        let value = self.u32()? as usize;

        if value > self.remaining() {
            return Err(format!("Length {} exceeds the {} remaining bytes", value, self.remaining()));
        }

        Ok(value)
    }
}

pub fn put_u16(output: &mut Vec<u8>, value: u16) {
    output.extend_from_slice(&value.to_be_bytes());
}

pub fn put_u32(output: &mut Vec<u8>, value: u32) {
    output.extend_from_slice(&value.to_be_bytes());
}

pub fn put_i32(output: &mut Vec<u8>, value: i32) {
    output.extend_from_slice(&value.to_be_bytes());
}

/// A `usize` count as a u32 field. Callers check capacities before encoding.
pub fn put_len(output: &mut Vec<u8>, value: usize) {
    put_u32(output, u32::try_from(value).unwrap_or(u32::MAX));
}
