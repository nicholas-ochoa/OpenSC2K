//! One XMIDI sequence as a Standard MIDI File with explicit note-off events.
//! XMIDI delays use a fixed 120 Hz clock, independent of the tempo metadata.

use super::has_range;

const MAX_EVENTS: usize = 200_000;
const MAX_TICK: i64 = 0x0fff_ffff;
const MAX_NESTING: usize = 8;
const MAX_VLQ_BYTES: usize = 4;
/// 500,000 microseconds per quarter note at 60 ticks per quarter: 120 Hz.
const FIXED_TEMPO: [u8; 6] = [0xff, 0x51, 3, 7, 0xa1, 0x20];
const TICKS_PER_QUARTER: u8 = 60;
const META: u8 = 0xff;
const SYSEX: u8 = 0xf0;
const SYSEX_CONTINUATION: u8 = 0xf7;
const END_OF_TRACK: u8 = 0x2f;
const TEMPO: u8 = 0x51;
const CONTROL_CHANGE: u8 = 11;
const NOTE_ON: u8 = 9;
/// Driver-specific bank, branch and loop controllers.
const DRIVER_CONTROLLERS: std::ops::RangeInclusive<u8> = 110..=120;

struct TimedEvent {
    tick: i64,
    order: usize,
    bytes: Vec<u8>,
}

#[derive(Default)]
struct Decoder {
    error: String,
    streams: Vec<Vec<u8>>,
    events: Vec<TimedEvent>,
}

fn vlq(mut value: i64) -> Vec<u8> {
    let mut bytes = vec![(value & 127) as u8];
    value >>= 7;

    while value > 0 {
        bytes.insert(0, ((value & 127) | 128) as u8);
        value >>= 7;
    }

    bytes
}

/// A variable-length value of up to four bytes at `cursor`, or `None`.
fn read_vlq(data: &[u8], cursor: &mut usize) -> Option<i64> {
    let mut value = 0;

    for _ in 0..MAX_VLQ_BYTES {
        let byte = *data.get(*cursor)?;
        *cursor += 1;
        value = (value << 7) | i64::from(byte & 127);

        if byte < 128 {
            return Some(value);
        }
    }

    None
}

impl Decoder {
    fn chunks(&mut self, data: &[u8], start: usize, end: usize, depth: usize, in_sequence: bool) {
        if depth > MAX_NESTING {
            self.error = "XMIDI container nesting is too deep.".into();
            return;
        }

        let mut cursor = start;

        while cursor < end && self.error.is_empty() {
            if end - cursor < 8 {
                self.error = "Truncated XMIDI chunk header.".into();
                return;
            }

            let tag = &data[cursor..cursor + 4];
            let length = u32::from_be_bytes([data[cursor + 4], data[cursor + 5], data[cursor + 6], data[cursor + 7]]) as usize;
            let body = cursor + 8;

            if length > end - body {
                self.error = "XMIDI chunk exceeds its container.".into();
                return;
            }

            if tag == b"FORM" || tag == b"CAT " {
                if length < 4 {
                    self.error = "Missing XMIDI container type.".into();
                    return;
                }

                let kind = &data[body..body + 4];

                if kind != b"XMID" && kind != b"XDIR" {
                    self.error = "Unsupported XMIDI container type.".into();
                    return;
                }

                self.chunks(data, body + 4, body + length, depth + 1, kind == b"XMID");
            } else if tag == b"EVNT" && in_sequence {
                self.streams.push(data[body..body + length].to_vec());
            } else if depth == 0 {
                self.error = "Missing XMIDI FORM or CAT container.".into();
                return;
            }

            cursor = body + length;

            if !length.is_multiple_of(2) && cursor < end {
                cursor += 1;
            }
        }
    }

    fn add(&mut self, tick: i64, bytes: Vec<u8>) {
        if self.events.len() >= MAX_EVENTS {
            self.error = "XMIDI sequence exceeds the event limit.".into();
            return;
        }

        let order = self.events.len();
        self.events.push(TimedEvent { tick, order, bytes });
    }

    fn sequence(&mut self, data: &[u8]) -> Result<Vec<u8>, String> {
        let mut cursor = 0;
        let mut tick = 0;
        let mut ended = false;
        self.add(0, FIXED_TEMPO.to_vec());

        while cursor < data.len() && self.error.is_empty() {
            while cursor < data.len() && data[cursor] < 128 {
                tick += i64::from(data[cursor]);
                cursor += 1;
            }

            if tick > MAX_TICK || cursor >= data.len() {
                return Err("Invalid or truncated XMIDI delay.".into());
            }

            let status = data[cursor];
            cursor += 1;
            let command = status >> 4;

            if status == META || status == SYSEX || status == SYSEX_CONTINUATION {
                let mut meta_type = None;

                if status == META {
                    let Some(&value) = data.get(cursor) else {
                        return Err("Truncated XMIDI meta event.".into());
                    };

                    meta_type = Some(value);
                    cursor += 1;
                }

                let length = match read_vlq(data, &mut cursor) {
                    Some(length) if has_range(data, cursor, length as usize) => length as usize,
                    _ => return Err("Truncated XMIDI meta or SysEx data.".into()),
                };
                let payload = &data[cursor..cursor + length];
                cursor += length;

                if meta_type == Some(END_OF_TRACK) {
                    if length != 0 {
                        return Err("Invalid XMIDI end event.".into());
                    }

                    ended = true;
                    break;
                }

                // a fixed output tempo keeps the 120 Hz event clock of the source
                if meta_type == Some(TEMPO) {
                    if length != 3 {
                        return Err("Invalid XMIDI tempo metadata.".into());
                    }

                    continue;
                }

                let mut event = vec![status];
                event.extend(meta_type);
                event.extend(vlq(length as i64));
                event.extend_from_slice(payload);
                self.add(tick, event);
            } else if (8..=14).contains(&command) {
                let count = if command == 12 || command == 13 { 1 } else { 2 };

                if !has_range(data, cursor, count) {
                    return Err("Truncated XMIDI channel event.".into());
                }

                let mut event = vec![status];

                for _ in 0..count {
                    let value = data[cursor];
                    cursor += 1;

                    if value >= 128 {
                        return Err("Invalid XMIDI channel event data.".into());
                    }

                    event.push(value);
                }

                // a different song would play; refuse the record instead
                if command == CONTROL_CHANGE && DRIVER_CONTROLLERS.contains(&event[1]) {
                    return Err(format!("XMIDI uses unsupported driver controller {}.", event[1]));
                }

                let (key, velocity) = (event[1], event.get(2).copied().unwrap_or(0));
                self.add(tick, event);

                if command == NOTE_ON {
                    // the duration follows the note-on; it schedules the note-off
                    let duration = match read_vlq(data, &mut cursor) {
                        Some(duration) if tick + duration <= MAX_TICK => duration,
                        _ => return Err("Invalid XMIDI note duration.".into()),
                    };

                    if velocity > 0 {
                        self.add(tick + duration.max(1), vec![0x80 | (status & 15), key, 0]);
                    }
                }
            } else {
                return Err(format!("Unsupported XMIDI event 0x{status:02x}."));
            }
        }

        if !self.error.is_empty() {
            return Err(self.error.clone());
        }

        if !ended {
            return Err("XMIDI sequence has no end event.".into());
        }

        self.events.sort_by_key(|event| (event.tick, event.order));
        let mut track = Vec::new();
        let mut previous = 0;

        for event in &self.events {
            track.extend(vlq(event.tick - previous));
            track.extend_from_slice(&event.bytes);
            previous = event.tick;
        }

        track.extend(vlq(tick.max(previous) - previous));
        track.extend_from_slice(&[0xff, 0x2f, 0]);
        let mut output = b"MThd\0\0\0\x06\0\0\0\x01\0".to_vec();
        output.push(TICKS_PER_QUARTER);
        output.extend_from_slice(b"MTrk");
        output.extend_from_slice(&(track.len() as u32).to_be_bytes());
        output.extend(track);

        Ok(output)
    }
}

/// Convert an XMIDI file of one sequence to a Standard MIDI File.
pub fn convert(data: &[u8]) -> Result<Vec<u8>, String> {
    let mut decoder = Decoder::default();
    decoder.chunks(data, 0, data.len(), 0, false);

    if !decoder.error.is_empty() {
        return Err(decoder.error);
    }

    if decoder.streams.len() != 1 {
        return Err(format!("Expected one XMIDI sequence; found {}.", decoder.streams.len()));
    }

    let stream = decoder.streams.remove(0);
    decoder.sequence(&stream)
}

#[cfg(test)]
mod tests {
    use super::*;

    fn xmidi(events: &[u8]) -> Vec<u8> {
        let mut evnt = b"EVNT".to_vec();
        evnt.extend_from_slice(&(events.len() as u32).to_be_bytes());
        evnt.extend_from_slice(events);
        let mut form = b"FORM".to_vec();
        form.extend_from_slice(&((evnt.len() + 4) as u32).to_be_bytes());
        form.extend_from_slice(b"XMID");
        form.extend(evnt);
        form
    }

    #[test]
    fn note_durations_become_note_offs() {
        // note 60 for 120 ticks, then the end
        let midi = convert(&xmidi(&[0x90, 60, 100, 0x78, 0x78, 0xff, 0x2f, 0])).unwrap();
        let sequence = sc2k_formats_check(&midi);
        assert_eq!(sequence, vec![(0, 0x90), (120, 0x80)]);
        assert_eq!(
            convert(&xmidi(&[0x90, 60, 100, 1])).unwrap_err(),
            "XMIDI sequence has no end event."
        );
        assert_eq!(
            convert(&xmidi(&[0xb0, 115, 1, 0xff, 0x2f, 0])).unwrap_err(),
            "XMIDI uses unsupported driver controller 115."
        );
        assert_eq!(convert(b"RIFF\0\0\0\0").unwrap_err(), "Missing XMIDI FORM or CAT container.");
    }

    /// The tick and status of each channel event of a one-track file.
    fn sc2k_formats_check(midi: &[u8]) -> Vec<(i64, u8)> {
        let mut cursor = 22;
        let mut tick = 0;
        let mut events = Vec::new();

        while cursor < midi.len() {
            tick += read_vlq(midi, &mut cursor).unwrap();
            let status = midi[cursor];

            if status == META {
                let length = usize::from(midi[cursor + 2]);
                cursor += 3 + length;
                continue;
            }

            events.push((tick, status));
            cursor += 3;
        }

        events
    }
}
