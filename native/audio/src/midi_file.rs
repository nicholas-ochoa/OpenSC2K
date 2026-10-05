//! Standard MIDI File parsing for GDScript.

use godot::prelude::*;
use sc2k_audio::smf;

/// Standard MIDI File parsing.
#[derive(GodotClass)]
#[class(no_init, base = Object)]
pub struct NativeMidiFile {}

#[godot_api]
impl NativeMidiFile {
    /// `{error, format_type, track_count, ticks_per_quarter, duration_seconds}`
    /// and one array for each event field: `ticks`, `orders`, `tracks`,
    /// `types`, `channels`, `notes`, `velocities`, `controllers`, `values`,
    /// `programs`, `tempos`, and `times`.
    #[func]
    fn parse(data: PackedByteArray) -> VarDictionary {
        let sequence = smf::parse(data.as_slice());
        let events = &sequence.events;
        let ints = |field: fn(&smf::Event) -> i64| events.iter().map(field).collect::<PackedInt64Array>();
        let mut result = VarDictionary::new();
        result.set("error", sequence.error.as_str());
        result.set("format_type", sequence.format_type);
        result.set("track_count", sequence.track_count);
        result.set("ticks_per_quarter", sequence.ticks_per_quarter);
        result.set("duration_seconds", sequence.duration_seconds);
        result.set("ticks", &ints(|event| event.tick));
        result.set("orders", &ints(|event| event.order));
        result.set("tracks", &ints(|event| event.track));
        result.set("channels", &ints(|event| event.channel));
        result.set("notes", &ints(|event| event.note));
        result.set("velocities", &ints(|event| event.velocity));
        result.set("controllers", &ints(|event| event.controller));
        result.set("values", &ints(|event| event.value));
        result.set("programs", &ints(|event| event.program));
        result.set("tempos", &ints(|event| event.microseconds_per_quarter));
        result.set(
            "types",
            &events
                .iter()
                .map(|event| GString::from(event.kind.name()))
                .collect::<PackedStringArray>(),
        );
        result.set(
            "times",
            &events.iter().map(|event| event.time_seconds).collect::<PackedFloat64Array>(),
        );
        result
    }
}
