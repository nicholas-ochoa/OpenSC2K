//! Portable PCM WAVE files from the sound payloads of the supplied games.

use super::has_range;

const MIN_RATE: i64 = 1000;
const MAX_RATE: i64 = 192_000;
const WAVE_HEADER_SIZE: usize = 44;
const MAC_SAMPLE_HEADER_SIZE: usize = 22;
const MAC_COMMAND_SIZE: usize = 8;
const MAC_FORMAT_1_ENTRY_SIZE: usize = 6;
/// The buffer and sound commands whose offset flag points into the resource.
const MAC_BUFFER_COMMANDS: [u16; 2] = [0x8050, 0x8051];

fn u16_be(data: &[u8], at: usize) -> usize {
    usize::from(u16::from_be_bytes([data[at], data[at + 1]]))
}

fn u32_be(data: &[u8], at: usize) -> usize {
    u32::from_be_bytes([data[at], data[at + 1], data[at + 2], data[at + 3]]) as usize
}

fn u32_le(data: &[u8], at: usize) -> usize {
    u32::from_le_bytes([data[at], data[at + 1], data[at + 2], data[at + 3]]) as usize
}

fn put_u16(data: &mut [u8], at: usize, value: usize) {
    data[at..at + 2].copy_from_slice(&(value as u16).to_le_bytes());
}

pub fn put_u32(data: &mut [u8], at: usize, value: usize) {
    data[at..at + 4].copy_from_slice(&(value as u32).to_le_bytes());
}

/// A PCM WAVE file of `samples`. An odd sample chunk gets its pad byte.
pub fn pcm_wave(samples: &[u8], rate: i64, channels: i64, bits: i64) -> Result<Vec<u8>, String> {
    if !(MIN_RATE..=MAX_RATE).contains(&rate)
        || !(1..=2).contains(&channels)
        || ![8, 16].contains(&bits)
        || samples.is_empty()
    {
        return Err("Invalid PCM sample format.".into());
    }

    let block = (channels * (bits / 8)) as usize;

    if !samples.len().is_multiple_of(block) {
        return Err("PCM samples end in an incomplete frame.".into());
    }

    let mut data = vec![0; WAVE_HEADER_SIZE];
    data[..4].copy_from_slice(b"RIFF");
    put_u32(&mut data, 4, 36 + samples.len() + samples.len() % 2);
    data[8..16].copy_from_slice(b"WAVEfmt ");
    put_u32(&mut data, 16, 16);
    put_u16(&mut data, 20, 1);
    put_u16(&mut data, 22, channels as usize);
    put_u32(&mut data, 24, rate as usize);
    put_u32(&mut data, 28, rate as usize * block);
    put_u16(&mut data, 32, block);
    put_u16(&mut data, 34, bits as usize);
    data[36..40].copy_from_slice(b"data");
    put_u32(&mut data, 40, samples.len());
    data.extend_from_slice(samples);

    if !samples.len().is_multiple_of(2) {
        data.push(0);
    }

    Ok(data)
}

/// The sample buffer of a Macintosh 'snd ' resource, as a WAVE file.
pub fn mac_sound(data: &[u8]) -> Result<Vec<u8>, String> {
    if data.len() < 6 {
        return Err("The Macintosh sound resource is truncated.".into());
    }

    let mut cursor = 4;

    match u16_be(data, 0) {
        1 => cursor += u16_be(data, 2) * MAC_FORMAT_1_ENTRY_SIZE,
        2 => {}
        _ => return Err("Unsupported Macintosh sound resource format.".into()),
    }

    let truncated = || "The Macintosh sound command list is truncated.".to_string();

    if !has_range(data, cursor, 2) {
        return Err(truncated());
    }

    let count = u16_be(data, cursor);
    cursor += 2;

    if !has_range(data, cursor, count * MAC_COMMAND_SIZE) {
        return Err(truncated());
    }

    for index in 0..count {
        let command = cursor + index * MAC_COMMAND_SIZE;

        if !MAC_BUFFER_COMMANDS.contains(&(u16_be(data, command) as u16)) {
            continue;
        }

        let header = u32_be(data, command + 4);

        if !has_range(data, header, MAC_SAMPLE_HEADER_SIZE) {
            return Err("The Macintosh sample header is truncated.".into());
        }

        if data[header + 20] != 0 {
            return Err(
                "This Macintosh sound uses an unsupported extended or compressed sample format."
                    .into(),
            );
        }

        let length = u32_be(data, header + 4);
        let rate = (u32_be(data, header + 8) >> 16) as i64;
        let start = header + MAC_SAMPLE_HEADER_SIZE;

        if !has_range(data, start, length) {
            return Err("The Macintosh sample data is truncated.".into());
        }

        return pcm_wave(&data[start..start + length], rate, 1, 8);
    }

    Err("No embedded sample buffer was found in the Macintosh sound.".into())
}

fn append_chunk(bytes: &mut Vec<u8>, id: &[u8; 4], payload: &[u8]) {
    bytes.extend_from_slice(id);
    bytes.extend_from_slice(&(payload.len() as u32).to_le_bytes());
    bytes.extend_from_slice(payload);

    if !payload.len().is_multiple_of(2) {
        bytes.push(0);
    }
}

/// Keep only the format and sample chunks of a RIFF WAVE file. Some Special
/// Edition CD-ROM sounds have a sampler chunk after an odd-sized sample chunk
/// without the RIFF pad byte.
pub fn riff_wave(data: &[u8]) -> Result<Vec<u8>, String> {
    if data.len() < 12 || &data[..4] != b"RIFF" || &data[8..12] != b"WAVE" {
        return Err("The sound is not a RIFF WAVE file.".into());
    }

    let mut format: &[u8] = &[];
    let mut samples: &[u8] = &[];
    let mut cursor = 12;

    while cursor + 8 <= data.len() && (format.is_empty() || samples.is_empty()) {
        let id = &data[cursor..cursor + 4];
        let size = u32_le(data, cursor + 4);
        let available = size.min(data.len() - cursor - 8);
        let body = &data[cursor + 8..cursor + 8 + available];

        if id == b"fmt " && format.is_empty() {
            format = body;
        } else if id == b"data" && samples.is_empty() {
            samples = body;
        }

        cursor += 8 + size + size % 2;
    }

    if format.len() < 16 || samples.is_empty() {
        return Err("The WAVE file has no format or sample data.".into());
    }

    let mut bytes = b"RIFF".to_vec();
    let size = 4 + 8 + format.len() + format.len() % 2 + 8 + samples.len() + samples.len() % 2;
    bytes.extend_from_slice(&(size as u32).to_le_bytes());
    bytes.extend_from_slice(b"WAVE");
    append_chunk(&mut bytes, b"fmt ", format);
    append_chunk(&mut bytes, b"data", samples);

    Ok(bytes)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn pcm_waves_pad_odd_samples() {
        let wave = pcm_wave(&[1, 2, 3], 11025, 1, 8).unwrap();
        assert_eq!(
            (wave.len(), &wave[..4], wave[wave.len() - 1]),
            (48, b"RIFF".as_slice(), 0)
        );
        assert!(pcm_wave(&[1], 999, 1, 8).is_err() && pcm_wave(&[1], 8000, 1, 16).is_err());
        assert_eq!(riff_wave(&wave).unwrap(), wave);
    }
}
