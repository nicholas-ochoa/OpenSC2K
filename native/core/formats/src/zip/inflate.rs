//! Raw DEFLATE decoding of one ZIP member.

use crate::crc32;
use miniz_oxide::inflate::TINFLStatus;
use miniz_oxide::inflate::core::{DecompressorOxide, decompress, inflate_flags};

/// The member bytes. The stream must end at the end of `raw`, make exactly
/// `expected` bytes, and match `crc`.
pub fn member(raw: &[u8], crc: u32, expected: i64) -> Result<Vec<u8>, String> {
    let expected = usize::try_from(expected).map_err(|_| "The ZIP member size or stream boundary is invalid.")?;

    // One spare byte shows a stream that makes more than its declared size.
    let mut output = vec![0_u8; expected + 1];
    let mut decompressor = DecompressorOxide::new();
    let flags = inflate_flags::TINFL_FLAG_USING_NON_WRAPPING_OUTPUT_BUF;
    let (status, consumed, written) = decompress(&mut decompressor, raw, &mut output, 0, flags);

    match status {
        TINFLStatus::Done => {}
        TINFLStatus::HasMoreOutput => return Err("The ZIP member exceeds its declared size.".into()),
        _ => return Err("The compressed ZIP member is invalid.".into()),
    }

    if written > expected {
        return Err("The ZIP member exceeds its declared size.".into());
    }

    if consumed != raw.len() || written != expected {
        return Err("The ZIP member size or stream boundary is invalid.".into());
    }

    output.truncate(expected);

    if crc32::calculate(&output) != crc {
        return Err("The compressed ZIP member is invalid.".into());
    }

    Ok(output)
}
