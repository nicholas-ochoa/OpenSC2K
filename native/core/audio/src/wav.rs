//! PCM WAVE files: 8-bit unsigned or 16-bit signed samples, mono or stereo.

/// Decoded stereo frames and their sample rate.
#[derive(Clone, Debug, Default, PartialEq)]
pub struct Sound {
    pub sample_rate: u32,
    pub frames: Vec<[f32; 2]>,
}

fn u16_le(data: &[u8], at: usize) -> u16 {
    u16::from_le_bytes([data[at], data[at + 1]])
}

fn u32_le(data: &[u8], at: usize) -> u32 {
    u32::from_le_bytes([data[at], data[at + 1], data[at + 2], data[at + 3]])
}

pub fn decode(data: &[u8]) -> Result<Sound, String> {
    if data.len() < 12 || &data[..4] != b"RIFF" || &data[8..12] != b"WAVE" {
        return Err("Not a WAVE file".into());
    }

    let mut position = 12;
    let mut format: Option<(u16, u16, u32, u16)> = None;

    while position + 8 <= data.len() {
        let id = &data[position..position + 4];
        let size = u32_le(data, position + 4) as usize;
        let body = position + 8;
        let end = (body + size).min(data.len());

        if id == b"fmt " && size >= 16 && body + 16 <= data.len() {
            format = Some((
                u16_le(data, body),
                u16_le(data, body + 2),
                u32_le(data, body + 4),
                u16_le(data, body + 14),
            ));
        } else if id == b"data" {
            let (kind, channels, rate, bits) = format.ok_or("WAVE data before its format")?;

            if kind != 1 || !(1..=2).contains(&channels) || !(bits == 8 || bits == 16) || rate == 0 {
                return Err("Unsupported WAVE format".into());
            }

            let bytes = &data[body..end];
            let samples: Vec<f32> = if bits == 8 {
                bytes.iter().map(|byte| (f32::from(*byte) - 128.0) / 128.0).collect()
            } else {
                bytes
                    .chunks_exact(2)
                    .map(|pair| f32::from(i16::from_le_bytes([pair[0], pair[1]])) / 32768.0)
                    .collect()
            };
            let frames = if channels == 1 {
                samples.iter().map(|sample| [*sample, *sample]).collect()
            } else {
                samples.chunks_exact(2).map(|pair| [pair[0], pair[1]]).collect()
            };

            return Ok(Sound { sample_rate: rate, frames });
        }

        position = body + size + (size & 1);
    }

    Err("WAVE file has no data".into())
}

#[cfg(test)]
mod tests {
    use super::decode;

    #[test]
    fn mono_bytes_become_stereo_frames() {
        let mut data = b"RIFF\0\0\0\0WAVEfmt ".to_vec();
        data.extend(16_u32.to_le_bytes());
        data.extend([1, 0, 1, 0]);
        data.extend(11025_u32.to_le_bytes());
        data.extend(11025_u32.to_le_bytes());
        data.extend([1, 0, 8, 0]);
        data.extend(b"data");
        data.extend(2_u32.to_le_bytes());
        data.extend([128, 255]);
        let sound = decode(&data).unwrap();
        assert_eq!(sound.sample_rate, 11025);
        assert_eq!(sound.frames, [[0.0, 0.0], [127.0 / 128.0, 127.0 / 128.0]]);
    }
}
