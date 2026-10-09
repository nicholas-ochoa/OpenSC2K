//! Standard MIDI Files of format 0 and 1, as StandardMidiFile: the channel
//! events and tempo changes of every track, in time order, with the time of
//! each event in seconds.

/// The tempo before the first tempo event: 120 quarter notes per minute.
const DEFAULT_MICROSECONDS_PER_QUARTER: i64 = 500_000;
const MICROSECONDS_PER_SECOND: f64 = 1_000_000.0;
const HEADER_SIZE: usize = 14;
const MIN_HEADER_LENGTH: usize = 6;
const TEMPO_META: u8 = 0x51;
const META_STATUS: u8 = 0xff;
const SYSEX_STATUS: u8 = 0xf0;
const SYSEX_CONTINUATION: u8 = 0xf7;
const SMPTE_DIVISION: usize = 0x8000;
const MAX_VARIABLE_LENGTH_BYTES: usize = 4;

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Kind {
    Tempo,
    NoteOn,
    NoteOff,
    KeyPressure,
    ControlChange,
    ProgramChange,
    ChannelPressure,
    PitchBend,
}

impl Kind {
    /// The event type name of the scripts.
    pub fn name(self) -> &'static str {
        match self {
            Self::Tempo => "tempo",
            Self::NoteOn => "note_on",
            Self::NoteOff => "note_off",
            Self::KeyPressure => "key_pressure",
            Self::ControlChange => "control_change",
            Self::ProgramChange => "program_change",
            Self::ChannelPressure => "channel_pressure",
            Self::PitchBend => "pitch_bend",
        }
    }
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub struct Event {
    pub tick: i64,
    /// The position of the event in the file, which orders events of one tick.
    pub order: i64,
    pub track: i64,
    pub kind: Kind,
    pub channel: i64,
    pub note: i64,
    pub velocity: i64,
    pub controller: i64,
    pub value: i64,
    pub program: i64,
    pub microseconds_per_quarter: i64,
    pub time_seconds: f64,
}

impl Event {
    fn new(kind: Kind, tick: i64, order: i64, track: i64) -> Self {
        Self {
            tick,
            order,
            track,
            kind,
            channel: 0,
            note: 0,
            velocity: 0,
            controller: 0,
            value: 0,
            program: 0,
            microseconds_per_quarter: 0,
            time_seconds: 0.0,
        }
    }
}

/// A parsed file. A failed parse keeps the header fields it read and no events.
#[derive(Clone, Debug, PartialEq)]
pub struct Sequence {
    pub format_type: i64,
    pub track_count: i64,
    pub ticks_per_quarter: i64,
    pub events: Vec<Event>,
    pub duration_seconds: f64,
    /// Empty for a valid file.
    pub error: String,
}

impl Default for Sequence {
    fn default() -> Self {
        Self {
            format_type: -1,
            track_count: 0,
            ticks_per_quarter: 0,
            events: Vec::new(),
            duration_seconds: 0.0,
            error: String::new(),
        }
    }
}

fn u16_be(data: &[u8], at: usize) -> usize {
    (usize::from(data[at]) << 8) | usize::from(data[at + 1])
}

fn u32_be(data: &[u8], at: usize) -> usize {
    (u16_be(data, at) << 16) | u16_be(data, at + 2)
}

/// A variable-length value of up to four bytes, and the position after it.
fn variable_length(data: &[u8], offset: usize, end: usize) -> Result<(usize, usize), &'static str> {
    let mut value = 0;
    let mut cursor = offset;

    for index in 0..MAX_VARIABLE_LENGTH_BYTES {
        if cursor >= end {
            return Err("truncated value");
        }

        let current = data[cursor];
        cursor += 1;
        value = (value << 7) | usize::from(current & 0x7f);

        if current & 0x80 == 0 {
            return Ok((value, cursor));
        }

        if index == MAX_VARIABLE_LENGTH_BYTES - 1 {
            return Err("value exceeds four bytes");
        }
    }

    Err("invalid value")
}

/// The events of one track, and the tick of its end.
fn parse_track(data: &[u8], start: usize, end: usize, track: i64, order: &mut i64, events: &mut Vec<Event>) -> Result<i64, String> {
    let mut cursor = start;
    let mut tick = 0;
    let mut running_status: Option<u8> = None;

    while cursor < end {
        let (delta, next) =
            variable_length(data, cursor, end).map_err(|error| format!("MIDI track {track} has an invalid delta: {error}"))?;
        cursor = next;
        tick += delta as i64;

        if cursor >= end {
            return Err(format!("MIDI track {track} ends after a delta"));
        }

        let mut status = data[cursor];
        let mut first_data = None;
        cursor += 1;

        if status & 0x80 != 0 {
            running_status = (status < 0xf0).then_some(status);
        } else {
            let Some(running) = running_status else {
                return Err(format!("MIDI track {track} uses data without running status"));
            };

            first_data = Some(status);
            status = running;
        }

        if status == META_STATUS {
            if cursor >= end {
                return Err(format!("MIDI track {track} has a truncated meta event"));
            }

            let meta_type = data[cursor];
            let (length, next) =
                variable_length(data, cursor + 1, end).map_err(|_| format!("MIDI track {track} has an invalid meta length"))?;
            cursor = next;

            if cursor + length > end {
                return Err(format!("MIDI track {track} has a truncated meta payload"));
            }

            if meta_type == TEMPO_META {
                if length != 3 {
                    return Err(format!("MIDI track {track} has an invalid tempo event"));
                }

                let mut event = Event::new(Kind::Tempo, tick, *order, track);
                event.microseconds_per_quarter =
                    (i64::from(data[cursor]) << 16) | (i64::from(data[cursor + 1]) << 8) | i64::from(data[cursor + 2]);
                events.push(event);
                *order += 1;
            }

            cursor += length;
            continue;
        }

        if status == SYSEX_STATUS || status == SYSEX_CONTINUATION {
            match variable_length(data, cursor, end) {
                Ok((length, next)) if next + length <= end => cursor = next + length,
                _ => return Err(format!("MIDI track {track} has a truncated system event")),
            }

            continue;
        }

        let command = status & 0xf0;

        if !(0x80..=0xe0).contains(&command) {
            return Err(format!("MIDI track {track} has unsupported status 0x{status:02x}"));
        }

        let read_data = |cursor: &mut usize| -> Result<i64, String> {
            if *cursor >= end {
                return Err(format!("MIDI track {track} has truncated channel data"));
            }

            let value = data[*cursor];
            *cursor += 1;

            if value & 0x80 != 0 {
                return Err(format!("MIDI track {track} has invalid channel data"));
            }

            Ok(i64::from(value))
        };

        let data_1 = match first_data {
            Some(value) => i64::from(value),
            None => read_data(&mut cursor)?,
        };
        let data_2 = if command == 0xc0 || command == 0xd0 {
            0
        } else {
            read_data(&mut cursor)?
        };
        let kind = match command {
            0x80 => Kind::NoteOff,
            0x90 if data_2 == 0 => Kind::NoteOff,
            0x90 => Kind::NoteOn,
            0xa0 => Kind::KeyPressure,
            0xb0 => Kind::ControlChange,
            0xc0 => Kind::ProgramChange,
            0xd0 => Kind::ChannelPressure,
            _ => Kind::PitchBend,
        };
        let mut event = Event::new(kind, tick, *order, track);
        event.channel = i64::from(status & 0x0f);

        match kind {
            Kind::NoteOff | Kind::NoteOn | Kind::KeyPressure => {
                event.note = data_1;
                event.velocity = data_2;
            }
            Kind::ControlChange => {
                event.controller = data_1;
                event.value = data_2;
            }
            Kind::ProgramChange => event.program = data_1,
            Kind::ChannelPressure => event.value = data_1,
            _ => event.value = data_1 | (data_2 << 7),
        }

        events.push(event);
        *order += 1;
    }

    Ok(tick)
}

/// Parse a Standard MIDI File.
pub fn parse(data: &[u8]) -> Sequence {
    let mut sequence = Sequence::default();

    if let Err(error) = parse_into(data, &mut sequence) {
        sequence.error = error;
        sequence.events.clear();
    }

    sequence
}

fn parse_into(data: &[u8], sequence: &mut Sequence) -> Result<(), String> {
    if data.len() < HEADER_SIZE || &data[..4] != b"MThd" {
        return Err("MIDI header is missing or truncated".into());
    }

    let header_length = u32_be(data, 4);

    if header_length < MIN_HEADER_LENGTH || 8 + header_length > data.len() {
        return Err("MIDI header length is invalid".into());
    }

    sequence.format_type = u16_be(data, 8) as i64;
    sequence.track_count = u16_be(data, 10) as i64;
    let division = u16_be(data, 12);

    if sequence.format_type > 1 {
        return Err(format!("MIDI format {} is not supported", sequence.format_type));
    }

    if sequence.track_count < 1 {
        return Err("MIDI file has no tracks".into());
    }

    if division == 0 || division & SMPTE_DIVISION != 0 {
        return Err("SMPTE or zero MIDI time division is not supported".into());
    }

    sequence.ticks_per_quarter = division as i64;
    let mut cursor = 8 + header_length;
    let mut order = 0;
    let mut maximum_tick = 0;

    for track in 0..sequence.track_count {
        if cursor + 8 > data.len() || &data[cursor..cursor + 4] != b"MTrk" {
            return Err(format!("MIDI track {track} header is missing or truncated"));
        }

        let start = cursor + 8;
        let end = start + u32_be(data, cursor + 4);

        if end > data.len() {
            return Err(format!("MIDI track {track} extends past the file"));
        }

        maximum_tick = maximum_tick.max(parse_track(data, start, end, track, &mut order, &mut sequence.events)?);
        cursor = end;
    }

    if cursor != data.len() {
        return Err("Data follows the declared MIDI tracks".into());
    }

    sequence.events.sort_by_key(|event| (event.tick, event.order));
    assign_times(sequence, maximum_tick);

    Ok(())
}

fn assign_times(sequence: &mut Sequence, maximum_tick: i64) {
    let ticks_per_quarter = sequence.ticks_per_quarter as f64;
    let mut tempo = DEFAULT_MICROSECONDS_PER_QUARTER;
    let mut previous_tick = 0;
    let mut seconds = 0.0;

    for event in &mut sequence.events {
        seconds += (event.tick - previous_tick) as f64 * tempo as f64 / ticks_per_quarter / MICROSECONDS_PER_SECOND;
        event.time_seconds = seconds;
        previous_tick = event.tick;

        if event.kind == Kind::Tempo {
            tempo = event.microseconds_per_quarter;
        }
    }

    sequence.duration_seconds =
        seconds + (maximum_tick - previous_tick) as f64 * tempo as f64 / ticks_per_quarter / MICROSECONDS_PER_SECOND;
}

#[cfg(test)]
mod tests {
    use super::*;

    /// A format 0 file with one track of `events`.
    fn file(events: &[u8]) -> Vec<u8> {
        let mut data = b"MThd\0\0\0\x06\0\0\0\x01\0\x78".to_vec();
        data.extend_from_slice(b"MTrk");
        data.extend_from_slice(&(events.len() as u32).to_be_bytes());
        data.extend_from_slice(events);
        data
    }

    #[test]
    fn events_take_their_times_from_the_tempo() {
        // tempo 1 s per quarter, note on, running-status note off after 120 ticks, end
        let sequence = parse(&file(&[
            0, 0xff, 0x51, 3, 0x0f, 0x42, 0x40, 0, 0x90, 60, 100, 0x78, 60, 0, 0, 0xff, 0x2f, 0,
        ]));
        assert_eq!(sequence.error, "");
        let kinds: Vec<Kind> = sequence.events.iter().map(|event| event.kind).collect();
        assert_eq!(kinds, vec![Kind::Tempo, Kind::NoteOn, Kind::NoteOff]);
        assert_eq!(sequence.events[2].time_seconds, 1.0);
        assert_eq!(sequence.duration_seconds, 1.0);
    }

    #[test]
    fn malformed_files_keep_their_header() {
        assert_eq!(parse(b"RIFF").error, "MIDI header is missing or truncated");
        let truncated = parse(&file(&[0, 0x90, 60]));
        assert_eq!(
            (truncated.error.as_str(), truncated.format_type),
            ("MIDI track 0 has truncated channel data", 0)
        );
        assert_eq!(parse(&file(&[0, 60, 1])).error, "MIDI track 0 uses data without running status");
        assert_eq!(
            parse(&file(&[0x80, 0x80, 0x80, 0x80, 0])).error,
            "MIDI track 0 has an invalid delta: value exceeds four bytes"
        );
    }
}
