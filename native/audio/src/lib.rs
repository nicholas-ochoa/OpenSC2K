//! Native music synthesis. `synth.rs` has no Godot types, so `cargo test` runs it.
//! The GDScript player owns the audio thread and the stream; this library only
//! renders frames.
mod synth;

use godot::prelude::*;
use synth::{Event, Kind, Synth};

struct OpenSc2kAudio;
#[gdextension(entry_symbol = opensc2k_audio_init)]
unsafe impl ExtensionLibrary for OpenSc2kAudio {}

/// One playing sequence. Only the music thread renders it.
#[derive(GodotClass)]
#[class(base=RefCounted)]
pub struct NativeMidiSynth {
    base: Base<RefCounted>,
    synth: Synth,
}
#[godot_api]
impl IRefCounted for NativeMidiSynth {
    fn init(base: Base<RefCounted>) -> Self {
        Self {
            base,
            synth: Synth::new(Vec::new(), 0.0),
        }
    }
}
#[godot_api]
impl NativeMidiSynth {
    /// Event kind codes of `start`.
    #[constant]
    const OTHER: i32 = 0;
    #[constant]
    const NOTE_ON: i32 = 1;
    #[constant]
    const NOTE_OFF: i32 = 2;
    #[constant]
    const PROGRAM_CHANGE: i32 = 3;
    #[constant]
    const CONTROL_CHANGE: i32 = 4;
    #[constant]
    const PITCH_BEND: i32 = 5;
    #[constant]
    const SAMPLE_RATE: i32 = synth::SAMPLE_RATE as i32;

    /// Starts a sequence. `fields` holds kind, channel, a and b of each event,
    /// and `times` holds the event times in seconds, in play order.
    #[func]
    fn start(&mut self, times: PackedFloat64Array, fields: PackedInt32Array, duration_seconds: f64) -> bool {
        let fields = fields.as_slice();
        if fields.len() != times.len() * 4 {
            return false;
        }
        let events = times
            .as_slice()
            .iter()
            .zip(fields.chunks_exact(4))
            .map(|(time, f)| Event {
                time: *time,
                kind: Kind::from_code(f[0]),
                channel: f[1],
                a: f[2],
                b: f[3],
            })
            .collect();
        self.synth = Synth::new(events, duration_seconds);
        true
    }
    /// Up to `frame_count` stereo frames. Fewer frames return when the track ends.
    #[func]
    fn render(&mut self, frame_count: i64) -> PackedVector2Array {
        let frames = self.synth.render(frame_count.max(0) as usize);
        frames.iter().map(|f| Vector2::new(f[0], f[1])).collect()
    }
    #[func]
    fn is_complete(&self) -> bool {
        self.synth.complete()
    }
    #[func]
    fn position_seconds(&self) -> f64 {
        self.synth.position()
    }
    #[func]
    fn note_frequency(note: i64, pitch_bend: i64) -> f64 {
        synth::note_frequency(note.clamp(-1, 128) as i32, pitch_bend.clamp(-1, 16384) as i32)
    }
    #[func]
    fn waveform_family(program: i64) -> i64 {
        i64::from(synth::waveform_family(program.clamp(-1, 128) as i32))
    }
    #[func]
    fn band_limited_saw(phase: f64, phase_step: f64) -> f64 {
        synth::band_limited_saw(phase, phase_step)
    }
    #[func]
    fn band_limited_square(phase: f64, phase_step: f64) -> f64 {
        synth::band_limited_square(phase, phase_step)
    }
}
