//! Timed MIDI channel events. The GDScript player parses the standard MIDI file
//! and sends these events to either synthesizer.

/// Event kinds, by the code that GDScript sends. The built-in synthesizer ignores
/// the pressure events.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Kind {
    Other,
    NoteOn,
    NoteOff,
    ProgramChange,
    ControlChange,
    PitchBend,
    ChannelPressure,
    KeyPressure,
}

pub const OTHER: i32 = 0;
pub const NOTE_ON: i32 = 1;
pub const NOTE_OFF: i32 = 2;
pub const PROGRAM_CHANGE: i32 = 3;
pub const CONTROL_CHANGE: i32 = 4;
pub const PITCH_BEND: i32 = 5;
pub const CHANNEL_PRESSURE: i32 = 6;
pub const KEY_PRESSURE: i32 = 7;

/// Fields of one event in the flat array that GDScript sends: kind, channel, a, b.
pub const FIELDS_PER_EVENT: usize = 4;

impl Kind {
    pub fn from_code(code: i32) -> Self {
        match code {
            NOTE_ON => Self::NoteOn,
            NOTE_OFF => Self::NoteOff,
            PROGRAM_CHANGE => Self::ProgramChange,
            CONTROL_CHANGE => Self::ControlChange,
            PITCH_BEND => Self::PitchBend,
            CHANNEL_PRESSURE => Self::ChannelPressure,
            KEY_PRESSURE => Self::KeyPressure,
            _ => Self::Other,
        }
    }

    /// Notes sound; every other kind only changes channel state.
    pub fn is_note(self) -> bool {
        matches!(self, Self::NoteOn | Self::NoteOff | Self::KeyPressure)
    }
}

/// One timed event. `a` and `b` are the note and velocity, the program, the
/// controller and value, the pitch-bend value, or the note and pressure.
#[derive(Clone, Copy, Debug)]
pub struct Event {
    pub time: f64,
    pub kind: Kind,
    pub channel: i32,
    pub a: i32,
    pub b: i32,
}

/// Events from the flat arrays of GDScript, or `None` when the lengths differ.
pub fn events_from_fields(times: &[f64], fields: &[i32]) -> Option<Vec<Event>> {
    if fields.len() != times.len() * FIELDS_PER_EVENT {
        return None;
    }

    let events = times
        .iter()
        .zip(fields.chunks_exact(FIELDS_PER_EVENT))
        .map(|(time, f)| Event {
            time: *time,
            kind: Kind::from_code(f[0]),
            channel: f[1],
            a: f[2],
            b: f[3],
        })
        .collect();

    Some(events)
}
