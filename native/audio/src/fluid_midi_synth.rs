//! The FluidSynth synthesizer for Godot. It renders PCM frames for an
//! `AudioStreamGenerator`, so music passes through the Godot audio buses.
use godot::prelude::*;

use crate::fluidsynth::{self, FluidSynth};
use crate::midi;
use crate::sequencer::Sequencer;

/// FluidSynth renders at the common device rate; Godot resamples to the mix rate.
const SAMPLE_RATE: f64 = 44_100.0;

/// One synthesizer with one SoundFont. Load the SoundFont away from the music
/// thread, then give the object to that thread; only it calls `render`.
#[derive(GodotClass)]
#[class(base=RefCounted)]
pub struct FluidMidiSynth {
    base: Base<RefCounted>,
    synth: Option<FluidSynth>,
    sequencer: Sequencer,
    soundfont_path: GString,
    gain: f32,
}

#[godot_api]
impl IRefCounted for FluidMidiSynth {
    fn init(base: Base<RefCounted>) -> Self {
        Self {
            base,
            synth: None,
            sequencer: Sequencer::default(),
            soundfont_path: GString::new(),
            gain: Self::DEFAULT_GAIN,
        }
    }
}

#[godot_api]
impl FluidMidiSynth {
    /// Event kind codes of `start`.
    #[constant]
    const OTHER: i32 = midi::OTHER;

    #[constant]
    const NOTE_ON: i32 = midi::NOTE_ON;

    #[constant]
    const NOTE_OFF: i32 = midi::NOTE_OFF;

    #[constant]
    const PROGRAM_CHANGE: i32 = midi::PROGRAM_CHANGE;

    #[constant]
    const CONTROL_CHANGE: i32 = midi::CONTROL_CHANGE;

    #[constant]
    const PITCH_BEND: i32 = midi::PITCH_BEND;

    #[constant]
    const CHANNEL_PRESSURE: i32 = midi::CHANNEL_PRESSURE;

    #[constant]
    const KEY_PRESSURE: i32 = midi::KEY_PRESSURE;

    #[constant]
    const SAMPLE_RATE: i32 = SAMPLE_RATE as i32;

    /// Dense General MIDI tracks reach full scale at this level; the FluidSynth
    /// limiter holds them below it.
    const DEFAULT_GAIN: f32 = 0.35;

    /// An empty string when the FluidSynth library loads, or the reason it does not.
    #[func]
    fn library_error() -> GString {
        match fluidsynth::shared() {
            Ok(_) => GString::new(),
            Err(error) => GString::from(error),
        }
    }

    /// The FluidSynth version, such as "2.6.1", or an empty string.
    #[func]
    fn library_version() -> GString {
        fluidsynth::shared()
            .map(|api| GString::from(&api.version_text()))
            .unwrap_or_default()
    }

    /// The path of the loaded FluidSynth library, or an empty string.
    #[func]
    fn library_path() -> GString {
        fluidsynth::shared()
            .map(|api| GString::from(&api.path.to_string_lossy().into_owned()))
            .unwrap_or_default()
    }

    /// Checks a library file without using it. Returns the error or an empty string.
    #[func]
    fn probe_library(path: GString) -> GString {
        GString::from(&fluidsynth::probe_library(&path.to_string()))
    }

    /// Loads an SF2, SF3 or DLS file from an operating system path. This reads
    /// the whole file. Returns the error, or an empty string; the previous
    /// SoundFont stays after an error.
    #[func]
    fn load_soundfont(&mut self, path: GString) -> GString {
        if self.synth.is_none() {
            match FluidSynth::new(SAMPLE_RATE) {
                Ok(mut synth) => {
                    synth.set_gain(self.gain);
                    self.synth = Some(synth);
                }
                Err(error) => return GString::from(&error),
            }
        }

        let synth = self.synth.as_mut().expect("the synthesizer exists");

        match synth.load_soundfont(&path.to_string()) {
            Ok(()) => {
                self.soundfont_path = path;

                GString::new()
            }
            Err(error) => GString::from(&error),
        }
    }

    #[func]
    fn has_soundfont(&self) -> bool {
        self.synth.as_ref().is_some_and(FluidSynth::has_soundfont)
    }

    #[func]
    fn soundfont_path(&self) -> GString {
        self.soundfont_path.clone()
    }

    /// Starts a sequence with General MIDI defaults. `fields` holds kind, channel,
    /// a and b of each event, and `times` holds the event times in seconds, in
    /// play order. Fails without a SoundFont.
    #[func]
    fn start(&mut self, times: PackedFloat64Array, fields: PackedInt32Array, duration_seconds: f64) -> bool {
        let Some(events) = midi::events_from_fields(times.as_slice(), fields.as_slice()) else {
            return false;
        };

        let Some(synth) = self.synth.as_mut().filter(|synth| synth.has_soundfont()) else {
            return false;
        };

        let looping = std::mem::take(&mut self.sequencer).looping();
        self.sequencer = Sequencer::new(events, duration_seconds, SAMPLE_RATE);
        self.sequencer.set_looping(looping);
        self.sequencer.start(synth);

        true
    }

    /// Up to `frame_count` stereo frames. Fewer frames return when the track ends.
    #[func]
    fn render(&mut self, frame_count: i64) -> PackedVector2Array {
        let Some(synth) = self.synth.as_mut() else {
            return PackedVector2Array::new();
        };

        let frames = self.sequencer.render(synth, frame_count.max(0) as usize);

        frames.iter().map(|f| Vector2::new(f[0], f[1])).collect()
    }

    #[func]
    fn is_complete(&self) -> bool {
        self.synth.is_none() || self.sequencer.complete()
    }

    #[func]
    fn position_seconds(&self) -> f64 {
        self.sequencer.position()
    }

    #[func]
    fn duration_seconds(&self) -> f64 {
        self.sequencer.duration()
    }

    /// Moves to `seconds`, with the programs and controllers of that time.
    #[func]
    fn seek(&mut self, seconds: f64) {
        if let Some(synth) = self.synth.as_mut() {
            self.sequencer.seek(synth, seconds);
        }
    }

    /// A looping track restarts at its end and never completes.
    #[func]
    fn set_looping(&mut self, looping: bool) {
        self.sequencer.set_looping(looping);
    }

    /// The FluidSynth output level. Player volume belongs on the Godot player or bus.
    #[func]
    fn set_gain(&mut self, gain: f32) {
        self.gain = gain.clamp(0.0, 10.0);

        if let Some(synth) = self.synth.as_mut() {
            synth.set_gain(self.gain);
        }
    }

    /// The sounding FluidSynth voices, for tests and diagnostics.
    #[func]
    fn active_voices(&mut self) -> i64 {
        use crate::sequencer::MidiOutput;

        self.synth.as_mut().map_or(0, |synth| synth.active_voices() as i64)
    }
}
