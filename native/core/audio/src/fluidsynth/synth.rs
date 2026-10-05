//! A safe owner of one FluidSynth synthesizer and its SoundFont.
use std::ffi::{CString, c_int, c_void};
use std::path::Path;
use std::sync::{Mutex, MutexGuard};

use super::api::{self, Api, FLUID_FAILED, FLUID_OK};
use super::log;
use crate::midi::{Event, Kind};
use crate::sequencer::MidiOutput;

/// FluidSynth renders more voices than the original game needed; this is its default.
const POLYPHONY: c_int = 256;
const MIDI_CHANNELS: c_int = 16;
const ALL_CHANNELS: c_int = -1;
const DATA_MAX: i32 = 127;
const PITCH_BEND_MAX: i32 = 16383;

/// -1 dBFS, which leaves headroom for the sound effects on the same bus.
const LIMITER_OUTPUT_LIMIT: f64 = 0.891;

/// Keep the presets of other SoundFonts when one loads or unloads.
const RESET_PRESETS: c_int = 1;

/// FluidSynth shares loaded samples between synthesizers in a process-wide cache.
/// Creating, loading and deleting take this lock, so two threads never change the
/// cache at once. Rendering never takes it.
static LIFECYCLE: Mutex<()> = Mutex::new(());

fn lifecycle() -> MutexGuard<'static, ()> {
    LIFECYCLE.lock().unwrap_or_else(std::sync::PoisonError::into_inner)
}

pub struct FluidSynth {
    api: &'static Api,
    settings: *mut api::Settings,
    synth: *mut api::Synth,
    font_id: Option<c_int>,
}

// SAFETY: FluidSynth objects may move between threads. `&mut self` on every call
// keeps them on one thread at a time, so the FluidSynth API lock is off.
unsafe impl Send for FluidSynth {}

impl FluidSynth {
    /// A synthesizer at `sample_rate` without a SoundFont. It opens no audio driver.
    pub fn new(sample_rate: f64) -> Result<Self, String> {
        let api = api::shared().map_err(str::to_string)?;
        let _lifecycle = lifecycle();

        // SAFETY: new_fluid_settings has no preconditions.
        let settings = unsafe { (api.new_settings)() };

        if settings.is_null() {
            return Err(String::from("FluidSynth could not create its settings"));
        }

        let mut synth = Self {
            api,
            settings,
            synth: std::ptr::null_mut(),
            font_id: None,
        };

        synth.set_number("synth.sample-rate", sample_rate);
        synth.set_integer("synth.polyphony", POLYPHONY);
        synth.set_integer("synth.midi-channels", MIDI_CHANNELS);
        // one thread renders; extra FluidSynth worker threads would only add latency
        synth.set_integer("synth.cpu-cores", 1);
        synth.set_integer("synth.threadsafe-api", 0);
        synth.set_integer("synth.lock-memory", 0);
        // dense tracks pass full scale at a matching level; the limiter (FluidSynth
        // 2.5 and later) keeps them below it. Older libraries ignore the setting
        synth.set_integer("synth.limiter.active", 1);
        synth.set_number("synth.limiter.output-limit", LIMITER_OUTPUT_LIMIT);

        // SAFETY: settings is a live settings object.
        synth.synth = unsafe { (api.new_synth)(settings) };

        if synth.synth.is_null() {
            return Err(String::from("FluidSynth could not create a synthesizer"));
        }

        Ok(synth)
    }

    fn set_number(&mut self, name: &str, value: f64) {
        let name = CString::new(name).expect("setting names have no NUL");

        // SAFETY: settings is live; name is NUL-terminated. An unknown setting fails harmlessly.
        unsafe { (self.api.settings_setnum)(self.settings, name.as_ptr(), value) };
    }

    fn set_integer(&mut self, name: &str, value: c_int) {
        let name = CString::new(name).expect("setting names have no NUL");

        // SAFETY: settings is live; name is NUL-terminated. An unknown setting fails harmlessly.
        unsafe { (self.api.settings_setint)(self.settings, name.as_ptr(), value) };
    }

    /// Replaces the SoundFont. This reads the whole file, so never call it on a
    /// thread that feeds the audio device. The old SoundFont stays on failure.
    pub fn load_soundfont(&mut self, path: &str) -> Result<(), String> {
        if !Path::new(path).is_file() {
            return Err(format!("The SoundFont does not exist: {path}"));
        }

        let c_path = CString::new(path).map_err(|_| format!("The SoundFont path is not valid: {path}"))?;
        let _lifecycle = lifecycle();
        log::clear();

        // SAFETY: c_path is NUL-terminated.
        if unsafe { (self.api.is_soundfont)(c_path.as_ptr()) } == 0 {
            return Err(format!("Unsupported SoundFont (not SF2, SF3 or DLS): {path}"));
        }

        // SAFETY: synth is live; c_path is NUL-terminated.
        let font_id = unsafe { (self.api.sfload)(self.synth, c_path.as_ptr(), RESET_PRESETS) };

        if font_id == FLUID_FAILED {
            let detail = log::take();

            return Err(format!("The SoundFont failed to load: {path}. {detail}").trim_end().to_string());
        }

        if let Some(old) = self.font_id.replace(font_id) {
            // SAFETY: old is a SoundFont id of this synth.
            unsafe { (self.api.sfunload)(self.synth, old, RESET_PRESETS) };
        }

        Ok(())
    }

    pub fn has_soundfont(&self) -> bool {
        self.font_id.is_some()
    }

    pub fn set_gain(&mut self, gain: f32) {
        // SAFETY: synth is live.
        unsafe { (self.api.set_gain)(self.synth, gain) };
    }
}

impl MidiOutput for FluidSynth {
    fn send(&mut self, event: &Event) {
        let channel = event.channel.clamp(0, MIDI_CHANNELS - 1);
        let a = event.a.clamp(0, DATA_MAX);
        let b = event.b.clamp(0, DATA_MAX);
        let api = self.api;
        let synth = self.synth;

        // SAFETY: synth is live and the values are in MIDI range. FluidSynth reports
        // a note off without a sounding note as an error, which is harmless.
        unsafe {
            match event.kind {
                Kind::NoteOn => (api.noteon)(synth, channel, a, b),
                Kind::NoteOff => (api.noteoff)(synth, channel, a),
                Kind::ProgramChange => (api.program_change)(synth, channel, a),
                Kind::ControlChange => (api.cc)(synth, channel, a, b),
                Kind::PitchBend => (api.pitch_bend)(synth, channel, event.a.clamp(0, PITCH_BEND_MAX)),
                Kind::ChannelPressure => (api.channel_pressure)(synth, channel, a),
                Kind::KeyPressure => (api.key_pressure)(synth, channel, a, b),
                Kind::Other => FLUID_OK,
            }
        };
    }

    fn reset(&mut self) {
        // SAFETY: synth is live. A reset stops every voice and restores the GM defaults.
        unsafe { (self.api.system_reset)(self.synth) };
    }

    fn release_notes(&mut self) {
        // SAFETY: synth is live.
        unsafe { (self.api.all_notes_off)(self.synth, ALL_CHANNELS) };
    }

    fn render(&mut self, left: &mut [f32], right: &mut [f32]) {
        let frames = left.len().min(right.len());

        // SAFETY: synth is live; both buffers hold `frames` contiguous floats.
        unsafe {
            (self.api.write_float)(
                self.synth,
                frames as c_int,
                left.as_mut_ptr().cast::<c_void>(),
                0,
                1,
                right.as_mut_ptr().cast::<c_void>(),
                0,
                1,
            )
        };
    }

    fn active_voices(&mut self) -> usize {
        // SAFETY: synth is live.
        let count = unsafe { (self.api.active_voice_count)(self.synth) };

        count.max(0) as usize
    }
}

impl Drop for FluidSynth {
    fn drop(&mut self) {
        let _lifecycle = lifecycle();

        // SAFETY: each pointer is live or null, and nothing uses it after this.
        // The synth must go before its settings.
        unsafe {
            if !self.synth.is_null() {
                (self.api.delete_synth)(self.synth);
            }

            (self.api.delete_settings)(self.settings);
        }
    }
}
