//! Additive MIDI synthesizer. The arithmetic keeps the order and widths of the
//! GDScript synthesizer that it replaced: 64-bit voice state and accumulators,
//! 32-bit wavetables and channel controls, and a reverse voice mix order.
use std::sync::OnceLock;

mod events;

#[cfg(test)]
mod tests;
mod waveforms;

use waveforms::*;

pub use waveforms::{band_limited_saw, band_limited_square, note_frequency, waveform_family};

pub const SAMPLE_RATE: f64 = 22050.0;
const MAX_VOICES: usize = 32;
const MAX_TAIL_SECONDS: f64 = 2.0;
const PITCH_BEND_RANGE: f64 = 2.0;
const TAU: f64 = std::f64::consts::PI * 2.0;
const WAVETABLE_SIZE: usize = 2048;
const CHANNELS: usize = 16;

/// The General MIDI percussion channel (channel 10, zero-based).
const PERCUSSION_CHANNEL: usize = 9;
const PITCH_BEND_CENTER: i32 = 8192;
const PITCH_BEND_MAX: i32 = 16383;
// Control change numbers.
const CONTROL_VOLUME: i32 = 7;
const CONTROL_PAN: i32 = 10;
const CONTROL_EXPRESSION: i32 = 11;
const CONTROL_SUSTAIN: i32 = 64;
const CONTROL_ALL_SOUND_OFF: i32 = 120;
const CONTROL_RESET_ALL: i32 = 121;
const CONTROL_ALL_NOTES_OFF: i32 = 123;

/// Controller values from this one hold the sustain pedal.
const SUSTAIN_ON: i32 = 64;
// General MIDI percussion notes.
const BASS_DRUM_2: i32 = 35;
const BASS_DRUM_1: i32 = 36;
const SNARE_1: i32 = 38;
const SNARE_2: i32 = 40;
const CLOSED_HI_HAT: i32 = 42;
const OPEN_HI_HAT: i32 = 46;

/// Percussion voices release after this age.
const PERCUSSION_HOLD_SECONDS: f64 = 0.45;
// The linear congruential noise generator of the percussion voices.
const NOISE_MULTIPLIER: i64 = 1103515245;
const NOISE_INCREMENT: i64 = 12345;
const NOISE_MASK: i64 = 0x7fff_ffff;

/// Event kinds of a sequence. Other MIDI events do not reach the synthesizer.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Kind {
    Other,
    NoteOn,
    NoteOff,
    ProgramChange,
    ControlChange,
    PitchBend,
}

impl Kind {
    pub fn from_code(code: i32) -> Self {
        match code {
            1 => Self::NoteOn,
            2 => Self::NoteOff,
            3 => Self::ProgramChange,
            4 => Self::ControlChange,
            5 => Self::PitchBend,
            _ => Self::Other,
        }
    }
}

/// One timed event. `a` and `b` are the note and velocity, the program, the
/// controller and value, or the pitch-bend value.
#[derive(Clone, Copy, Debug)]
pub struct Event {
    pub time: f64,
    pub kind: Kind,
    pub channel: i32,
    pub a: i32,
    pub b: i32,
}

#[derive(Clone, Debug)]
struct Voice {
    channel: usize,
    note: i32,
    program: i32,
    family: i32,
    velocity: f64,
    frequency: f64,
    phase: f64,
    secondary_phase: f64,
    age_seconds: f64,
    envelope: f64,
    release_rate: f64,
    releasing: bool,
    held_by_pedal: bool,
    percussion: bool,
    noise_state: i64,
}

#[derive(Default)]
pub struct Synth {
    events: Vec<Event>,
    duration: f64,
    cursor: usize,
    position: f64,
    tail_start: f64,
    complete: bool,
    voices: Vec<Voice>,
    programs: [i32; CHANNELS],
    volumes: [f32; CHANNELS],
    expressions: [f32; CHANNELS],
    pans: [f32; CHANNELS],
    sustain: [bool; CHANNELS],
    pitch_bends: [i32; CHANNELS],
    left_gains: [f32; CHANNELS],
    right_gains: [f32; CHANNELS],
    mix_left: Vec<f64>,
    mix_right: Vec<f64>,
    frame_times: Vec<f64>,
}

impl Synth {
    pub fn new(events: Vec<Event>, duration: f64) -> Self {
        let mut synth = Self {
            events,
            duration,
            tail_start: -1.0,
            ..Default::default()
        };

        synth.reset_channels();
        synth
    }

    pub fn complete(&self) -> bool {
        self.complete
    }

    pub fn position(&self) -> f64 {
        self.position
    }

    fn reset_channels(&mut self) {
        self.programs = [0; CHANNELS];
        self.volumes = [1.0; CHANNELS];
        self.expressions = [1.0; CHANNELS];
        self.pans = [0.5; CHANNELS];
        self.sustain = [false; CHANNELS];
        self.pitch_bends = [PITCH_BEND_CENTER; CHANNELS];

        for channel in 0..CHANNELS {
            self.refresh_gain(channel);
        }
    }

    fn refresh_gain(&mut self, channel: usize) {
        let gain = f64::from(self.volumes[channel]) * f64::from(self.expressions[channel]);
        let pan = f64::from(self.pans[channel]);
        self.left_gains[channel] = (gain * (1.0 - pan).sqrt()) as f32;
        self.right_gains[channel] = (gain * pan.sqrt()) as f32;
    }

    /// Renders up to `frame_count` stereo frames. The render splits the request
    /// at every event, tail and end-of-track boundary, then mixes each block one
    /// voice at a time. Fewer frames return when the track completes.
    pub fn render(&mut self, frame_count: usize) -> Vec<[f32; 2]> {
        self.complete = false;
        self.prepare(frame_count);
        let mut filled = 0;

        while filled < frame_count {
            self.apply_due_events();
            let block = self.block_length(filled, frame_count - filled);
            let empty_at = self.mix_block(filled, block);
            let mut used = block;
            let in_tail = self.tail_start >= 0.0 && self.cursor >= self.events.len();

            if in_tail && empty_at >= 0 {
                used = empty_at as usize + 1;
                self.complete = true;
            }

            self.position = self.frame_times[filled + used - 1];
            filled += used;

            if self.complete || self.cursor < self.events.len() {
                if self.complete {
                    break;
                }

                continue;
            }

            if self.tail_start < 0.0 && self.position >= self.duration {
                self.tail_start = self.position;
                self.release_all();
            }

            if self.tail_start >= 0.0 && (self.voices.is_empty() || self.position - self.tail_start >= MAX_TAIL_SECONDS) {
                self.complete = true;
                break;
            }
        }

        (0..filled)
            .map(|i| {
                [
                    clamp(self.mix_left[i] * 0.18, -0.95, 0.95) as f32,
                    clamp(self.mix_right[i] * 0.18, -0.95, 0.95) as f32,
                ]
            })
            .collect()
    }
    // Every frame time comes from the same repeated addition as the scalar mix,
    // so a block boundary lands on the sample that the per-sample loop chose.
    fn prepare(&mut self, frame_count: usize) {
        if self.mix_left.len() < frame_count {
            self.mix_left.resize(frame_count, 0.0);
            self.mix_right.resize(frame_count, 0.0);
            self.frame_times.resize(frame_count, 0.0);
        }

        self.mix_left.fill(0.0);
        self.mix_right.fill(0.0);
        let step = 1.0 / SAMPLE_RATE;
        let mut position = self.position;

        for time in self.frame_times.iter_mut().take(frame_count) {
            position += step;
            *time = position;
        }
    }

    fn boundary_reached(&self, mode: i32, threshold: f64, position: f64) -> bool {
        match mode {
            0 => threshold <= position + 0.000001,
            1 => position - threshold >= MAX_TAIL_SECONDS,
            _ => position >= threshold,
        }
    }

    fn block_length(&self, offset: usize, remaining: usize) -> usize {
        let (mode, threshold) = if self.cursor < self.events.len() {
            (0, self.events[self.cursor].time)
        } else if self.tail_start >= 0.0 {
            (1, self.tail_start)
        } else {
            (2, self.duration)
        };

        if !self.boundary_reached(mode, threshold, self.frame_times[offset + remaining - 1]) {
            return remaining;
        }

        let (mut low, mut high) = (1, remaining);

        while low < high {
            let middle = (low + high) / 2;

            if self.boundary_reached(mode, threshold, self.frame_times[offset + middle - 1]) {
                high = middle;
            } else {
                low = middle + 1;
            }
        }

        low
    }

    // The reverse voice order keeps the accumulated sums of the scalar mix.
    // Returns the frame that emptied the voice list, or -1 while a voice survives.
    fn mix_block(&mut self, offset: usize, count: usize) -> i64 {
        if self.voices.is_empty() {
            return 0;
        }

        let mut empty_at = -1;
        let mut survivors = 0;

        for index in (0..self.voices.len()).rev() {
            let removed_at = self.mix_voice(index, offset, count);

            if removed_at < 0 {
                survivors += 1;
                continue;
            }

            self.voices.remove(index);
            empty_at = empty_at.max(removed_at);
        }

        if survivors > 0 { -1 } else { empty_at }
    }

    fn mix_voice(&mut self, index: usize, offset: usize, count: usize) -> i64 {
        let voice = &mut self.voices[index];
        let left_gain = f64::from(self.left_gains[voice.channel]);
        let right_gain = f64::from(self.right_gains[voice.channel]);
        let percussion = voice.percussion;
        let family = voice.family;
        let table = if percussion { None } else { family_table(family) };
        let add_saw = family == 6;
        let age_step = 1.0 / SAMPLE_RATE;
        let phase_step = min(voice.frequency / SAMPLE_RATE, 0.49);
        let secondary_step = phase_step * 1.006;
        let release_step = voice.release_rate / SAMPLE_RATE;
        let attack_step = 1.0 / (attack_seconds(voice.program, percussion) * SAMPLE_RATE);

        // A 1.0 factor keeps the sustained families exact without a branch.
        let sustain_decay = if percussion {
            0.9990
        } else if family == 0 || family == 1 || family == 3 {
            0.99994
        } else {
            1.0
        };

        let (mut envelope, mut releasing, mut age) = (voice.envelope, voice.releasing, voice.age_seconds);
        let (mut phase, mut secondary, mut noise) = (voice.phase, voice.secondary_phase, voice.noise_state);

        for frame in offset..offset + count {
            age += age_step;

            if releasing {
                envelope = max(envelope - release_step, 0.0);
            } else {
                envelope = min(envelope + attack_step, 1.0) * sustain_decay;

                if percussion && age > PERCUSSION_HOLD_SECONDS {
                    releasing = true;
                }
            }

            if envelope <= 0.0 && releasing {
                return (frame - offset) as i64;
            }

            phase = (phase + phase_step) % 1.0;
            secondary = (secondary + secondary_step) % 1.0;
            let sample = if percussion {
                noise = (noise * NOISE_MULTIPLIER + NOISE_INCREMENT) & NOISE_MASK;
                let value = ((noise >> 8) & 0xffff) as f64 / 32767.5 - 1.0;
                percussion_sample(voice.note, phase, age, value, phase_step)
            } else if let Some(table) = table {
                let sample = wavetable_sample(table, phase);

                if add_saw {
                    band_limited_saw(phase, phase_step) * 0.45 + sample
                } else {
                    sample
                }
            } else {
                family_sample(family, phase, secondary, phase_step)
            };

            let gain = voice.velocity * envelope;
            self.mix_left[frame] += sample * gain * left_gain;
            self.mix_right[frame] += sample * gain * right_gain;
        }

        voice.envelope = envelope;
        voice.releasing = releasing;
        voice.age_seconds = age;
        voice.phase = phase;
        voice.secondary_phase = secondary;
        voice.noise_state = noise;
        -1
    }
}
