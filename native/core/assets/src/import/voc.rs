//! Creative Voice files: the PCM blocks as a WAVE file. Sample loops stay in
//! the WAVE smpl chunk.

use super::has_range;
use super::wave::{pcm_wave, put_u32};

const MAX_PCM_BYTES: usize = 64 * 1024 * 1024;
const HEADER_SIZE: usize = 26;
const SIGNATURE: &[u8; 20] = b"Creative Voice File\x1a";
const ENDLESS_REPEAT: usize = 65535;
const SAMPLER_SIZE: usize = 68;
const SAMPLER_UNITY_NOTE: usize = 60;
const MIN_RATE: i64 = 1000;
const MAX_RATE: i64 = 192_000;

fn u16_le(data: &[u8], at: usize) -> usize {
    usize::from(u16::from_le_bytes([data[at], data[at + 1]]))
}

/// The sample rate of a time constant byte.
fn rate_of(time_constant: u8) -> i64 {
    1_000_000 / (256 - i64::from(time_constant))
}

/// Convert a Creative Voice file to a WAVE file.
pub fn convert(data: &[u8]) -> Result<Vec<u8>, String> {
    if data.len() < HEADER_SIZE || &data[..20] != SIGNATURE {
        return Err("Missing Creative Voice header.".into());
    }

    let mut cursor = u16_le(data, 20);

    if cursor < HEADER_SIZE || cursor > data.len() {
        return Err("Invalid Creative Voice data offset.".into());
    }

    let mut samples: Vec<u8> = Vec::new();
    let (mut rate, mut channels, mut bits) = (0i64, 1i64, 8i64);
    let (mut extended_rate, mut extended_channels) = (0i64, 1i64);
    let (mut repeat_start, mut repeat_count): (Option<usize>, usize) = (None, 0);
    let mut endless_loop: Option<(usize, usize)> = None;

    while cursor < data.len() {
        let block_type = data[cursor];
        cursor += 1;

        if block_type == 0 {
            break;
        }

        if !has_range(data, cursor, 3) {
            return Err("Truncated Creative Voice block header.".into());
        }

        let length = usize::from(data[cursor]) | (usize::from(data[cursor + 1]) << 8) | (usize::from(data[cursor + 2]) << 16);
        cursor += 3;

        if !has_range(data, cursor, length) {
            return Err("Truncated Creative Voice block.".into());
        }

        let block = &data[cursor..cursor + length];
        cursor += length;
        let (mut next_rate, mut next_channels, mut next_bits) = (rate, channels, bits);

        let pcm: Vec<u8> = match block_type {
            1 => {
                if length < 2 || block[1] != 0 {
                    return Err("Unsupported Creative Voice sample codec.".into());
                }

                next_rate = if extended_rate > 0 { extended_rate } else { rate_of(block[0]) };
                next_channels = if extended_rate > 0 { extended_channels } else { 1 };
                next_bits = 8;
                extended_rate = 0;
                block[2..].to_vec()
            }
            2 => {
                if rate == 0 {
                    return Err("Creative Voice continuation has no sample format.".into());
                }

                block.to_vec()
            }
            3 => {
                if length != 3 {
                    return Err("Invalid Creative Voice silence block.".into());
                }

                next_rate = rate_of(block[2]);
                next_channels = 1;
                next_bits = 8;
                vec![128; u16_le(block, 0) + 1]
            }
            // marker and annotation blocks have no sample data
            4 | 5 => continue,
            6 => {
                if length != 2 || repeat_start.is_some() {
                    return Err("Invalid or nested Creative Voice repeat block.".into());
                }

                repeat_start = Some(samples.len());
                repeat_count = u16_le(block, 0);
                continue;
            }
            7 => {
                let start = match repeat_start {
                    Some(start) if length == 0 && samples.len() != start => start,
                    _ => return Err("Invalid Creative Voice repeat end.".into()),
                };

                if repeat_count == ENDLESS_REPEAT {
                    if endless_loop.is_some() {
                        return Err("Multiple endless Creative Voice loops are unsupported.".into());
                    }

                    endless_loop = Some((start, samples.len()));
                } else {
                    let repeated = samples[start..].to_vec();

                    if samples.len() + repeated.len() * repeat_count > MAX_PCM_BYTES {
                        return Err("Creative Voice repeats exceed the sample limit.".into());
                    }

                    for _ in 0..repeat_count {
                        samples.extend_from_slice(&repeated);
                    }
                }

                repeat_start = None;
                continue;
            }
            8 => {
                if length != 4 || block[2] != 0 || block[3] > 1 {
                    return Err("Unsupported Creative Voice extended format.".into());
                }

                extended_channels = i64::from(block[3]) + 1;
                extended_rate = 256_000_000 / ((65536 - u16_le(block, 0) as i64) * extended_channels);
                continue;
            }
            9 => {
                if length < 12 {
                    return Err("Truncated Creative Voice sample header.".into());
                }

                next_rate = i64::from(u32::from_le_bytes([block[0], block[1], block[2], block[3]]));
                next_bits = i64::from(block[4]);
                next_channels = i64::from(block[5]);
                let codec = u16_le(block, 6);

                if !((codec == 0 && next_bits == 8) || (codec == 4 && next_bits == 16)) {
                    return Err("Unsupported Creative Voice sample codec.".into());
                }

                block[12..].to_vec()
            }
            other => return Err(format!("Unsupported Creative Voice block {other}.")),
        };

        if !(MIN_RATE..=MAX_RATE).contains(&next_rate) || !(1..=2).contains(&next_channels) {
            return Err("Invalid Creative Voice sample format.".into());
        }

        if !samples.is_empty() && (rate != next_rate || channels != next_channels || bits != next_bits) {
            return Err("Creative Voice changes sample format within one sound.".into());
        }

        (rate, channels, bits) = (next_rate, next_channels, next_bits);
        let frame = (channels * (bits / 8)) as usize;

        if frame == 0 || !pcm.len().is_multiple_of(frame) || samples.len() + pcm.len() > MAX_PCM_BYTES {
            return Err("Invalid or oversized Creative Voice sample data.".into());
        }

        samples.extend_from_slice(&pcm);
    }

    if repeat_start.is_some() || extended_rate > 0 {
        return Err("Incomplete Creative Voice repeat or extended block.".into());
    }

    let mut wave = pcm_wave(&samples, rate, channels, bits)?;

    if let Some((loop_start, loop_end)) = endless_loop {
        let frame = (channels * (bits / 8)) as usize;
        let mut sampler = vec![0; SAMPLER_SIZE];
        sampler[..4].copy_from_slice(b"smpl");
        put_u32(&mut sampler, 4, SAMPLER_SIZE - 8);
        put_u32(&mut sampler, 16, (1_000_000_000 / rate) as usize);
        put_u32(&mut sampler, 20, SAMPLER_UNITY_NOTE);
        put_u32(&mut sampler, 36, 1);
        put_u32(&mut sampler, 52, loop_start / frame);
        put_u32(&mut sampler, 56, (loop_end / frame).wrapping_sub(1));
        wave.extend_from_slice(&sampler);
        let size = wave.len() - 8;
        put_u32(&mut wave, 4, size);
    }

    Ok(wave)
}

#[cfg(test)]
mod tests {
    use super::*;

    fn voc(blocks: &[u8]) -> Vec<u8> {
        let mut data = SIGNATURE.to_vec();
        data.extend_from_slice(&[26, 0, 0x0a, 0x01, 0x29, 0x11]);
        data.extend_from_slice(blocks);
        data
    }

    #[test]
    fn sample_blocks_and_endless_loops_convert() {
        // repeat forever: 4 samples of 8-bit PCM at 1,000,000 / (256 - 156) = 10,000 Hz
        let data = voc(&[6, 2, 0, 0, 0xff, 0xff, 1, 6, 0, 0, 156, 0, 1, 2, 3, 4, 7, 0, 0, 0, 0]);
        let wave = convert(&data).unwrap();
        assert_eq!(&wave[wave.len() - 68..wave.len() - 64], b"smpl");
        assert_eq!(u32::from_le_bytes([wave[24], wave[25], wave[26], wave[27]]), 10_000);
        assert_eq!(
            convert(&voc(&[2, 1, 0, 0, 0])).unwrap_err(),
            "Creative Voice continuation has no sample format."
        );
        assert_eq!(convert(b"RIFF").unwrap_err(), "Missing Creative Voice header.");
    }
}
