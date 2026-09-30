//! Additive MIDI synthesizer. The arithmetic keeps the order and widths of the
//! GDScript synthesizer that it replaced: 64-bit voice state and accumulators,
//! 32-bit wavetables and channel controls, and a reverse voice mix order.
use std::sync::OnceLock;

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

struct Tables {
    families: [Vec<f32>; 5],
}
fn tables() -> &'static Tables {
    static TABLES: OnceLock<Tables> = OnceLock::new();
    TABLES.get_or_init(|| {
        // Keep the interpolation endpoint: family 1's 3.01 harmonic does not wrap at phase 1.
        let make =
            |f: &dyn Fn(f64) -> f64| -> Vec<f32> { (0..=WAVETABLE_SIZE).map(|i| f(i as f64 / WAVETABLE_SIZE as f64) as f32).collect() };
        let s = |p: f64| (TAU * p).sin();
        Tables {
            families: [
                make(&|p| s(p) * 0.72 + (TAU * p * 2.0).sin() * 0.20 + (TAU * p * 3.0).sin() * 0.08),
                make(&|p| s(p) * 0.65 + (TAU * p * 3.01).sin() * 0.35),
                make(&|p| s(p) * 0.65 + (TAU * p * 2.0).sin() * 0.25 + (TAU * p * 4.0).sin() * 0.10),
                // family 6 still needs its pitch-dependent saw at runtime
                make(&|p| s(p) * 0.55),
                make(&|p| s(p) * 0.88 + (TAU * p * 2.0).sin() * 0.12),
            ],
        }
    })
}
fn family_table(family: i32) -> Option<&'static [f32]> {
    let index = match family {
        0 => 0,
        1 => 1,
        2 => 2,
        6 => 3,
        7 => 4,
        _ => return None,
    };
    Some(&tables().families[index])
}

// Godot's clampf, minf and maxf, including their comparison order.
fn clamp(value: f64, low: f64, high: f64) -> f64 {
    if value < low {
        low
    } else if value > high {
        high
    } else {
        value
    }
}
fn min(a: f64, b: f64) -> f64 {
    if a < b { a } else { b }
}
fn max(a: f64, b: f64) -> f64 {
    if a > b { a } else { b }
}
fn lerp(from: f64, to: f64, weight: f64) -> f64 {
    from + (to - from) * weight
}

pub fn note_frequency(note: i32, pitch_bend: i32) -> f64 {
    let center = f64::from(PITCH_BEND_CENTER);
    let bend = (f64::from(pitch_bend.clamp(0, PITCH_BEND_MAX)) - center) / center * PITCH_BEND_RANGE;
    440.0 * 2.0_f64.powf((f64::from(note.clamp(0, 127)) - 69.0 + bend) / 12.0)
}

pub fn waveform_family(program: i32) -> i32 {
    match program.clamp(0, 127) {
        0..8 => 0,
        8..16 => 1,
        16..24 => 2,
        24..32 => 3,
        32..40 => 4,
        40..56 => 5,
        56..72 => 6,
        72..80 => 7,
        80..104 => 8,
        _ => 9,
    }
}
fn attack_seconds(program: i32, percussion: bool) -> f64 {
    if percussion {
        return 0.001;
    }
    match waveform_family(program) {
        5 => 0.08,
        6 | 7 => 0.025,
        _ => 0.006,
    }
}
fn release_rate(program: i32, percussion: bool) -> f64 {
    if percussion {
        return 10.0;
    }
    match waveform_family(program) {
        2 | 5 => 1.8,
        6 | 7 => 2.6,
        _ => 4.0,
    }
}

pub fn band_limited_saw(phase: f64, step: f64) -> f64 {
    phase * 2.0 - 1.0 - poly_blep(phase, step)
}
pub fn band_limited_square(phase: f64, step: f64) -> f64 {
    let mut value = if phase < 0.5 { 1.0 } else { -1.0 };
    value += poly_blep(phase, step);
    value -= poly_blep((phase + 0.5) % 1.0, step);
    value
}
fn triangle(phase: f64) -> f64 {
    1.0 - 4.0 * (phase - 0.5).abs()
}
fn poly_blep(phase: f64, step: f64) -> f64 {
    let step = clamp(step, 0.000001, 0.49);
    if phase < step {
        let position = phase / step;
        return position + position - position * position - 1.0;
    }
    if phase > 1.0 - step {
        let position = (phase - 1.0) / step;
        return position * position + position + position + 1.0;
    }
    0.0
}
fn wavetable_sample(table: &[f32], phase: f64) -> f64 {
    let scaled = phase * WAVETABLE_SIZE as f64;
    let index = (scaled as i64 as usize) & (WAVETABLE_SIZE - 1);
    lerp(f64::from(table[index]), f64::from(table[index + 1]), scaled - index as f64)
}
fn family_sample(family: i32, phase: f64, secondary: f64, step: f64) -> f64 {
    match family {
        0..=2 | 7 => wavetable_sample(family_table(family).unwrap(), phase),
        3 => triangle(phase) * 0.70 + band_limited_saw(phase, step) * 0.30,
        4 => triangle(phase) * 0.80 + band_limited_square(phase, step) * 0.20,
        5 => band_limited_saw(phase, step) * 0.52 + band_limited_saw(secondary, step * 1.006) * 0.48,
        6 => band_limited_saw(phase, step) * 0.45 + wavetable_sample(family_table(6).unwrap(), phase),
        8 => band_limited_square(phase, step) * 0.55 + band_limited_saw(phase, step) * 0.45,
        _ => triangle(phase) * 0.55 + (TAU * phase * 2.0).sin() * 0.45,
    }
}
fn percussion_sample(note: i32, phase: f64, age: f64, noise: f64, step: f64) -> f64 {
    if note == BASS_DRUM_2 || note == BASS_DRUM_1 {
        let drop = max(0.35, 1.0 - age * 2.5);
        return (TAU * phase * drop).sin() * 0.85 + noise * 0.15;
    }
    if (CLOSED_HI_HAT..=OPEN_HI_HAT).contains(&note) {
        return noise * 0.82 + band_limited_square(phase, step) * 0.18;
    }
    if note == SNARE_1 || note == SNARE_2 {
        return noise * 0.72 + (TAU * phase).sin() * 0.28;
    }
    noise * 0.55 + (TAU * phase).sin() * 0.45
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
    fn apply_due_events(&mut self) {
        while self.cursor < self.events.len() {
            let event = self.events[self.cursor];
            if event.time > self.position + 0.000001 {
                break;
            }
            self.apply_event(event);
            self.cursor += 1;
        }
    }
    fn apply_event(&mut self, event: Event) {
        let channel = event.channel.clamp(0, 15) as usize;
        match event.kind {
            Kind::NoteOn => self.start_voice(channel, event.a, event.b),
            Kind::NoteOff => self.stop_voice(channel, event.a),
            Kind::ProgramChange => self.programs[channel] = event.a.clamp(0, 127),
            Kind::ControlChange => self.control_change(channel, event.a, event.b),
            Kind::PitchBend => {
                self.pitch_bends[channel] = event.a.clamp(0, PITCH_BEND_MAX);
                self.update_pitch(channel);
            }
            Kind::Other => {}
        }
    }
    fn start_voice(&mut self, channel: usize, note: i32, velocity: i32) {
        if velocity <= 0 {
            self.stop_voice(channel, note);
            return;
        }
        if self.voices.len() >= MAX_VOICES {
            self.steal_voice();
        }
        let note = note.clamp(0, 127);
        let program = self.programs[channel];
        let percussion = channel == PERCUSSION_CHANNEL;
        self.voices.push(Voice {
            channel,
            note,
            program,
            family: waveform_family(program),
            velocity: clamp(f64::from(velocity) / 127.0, 0.0, 1.0),
            frequency: note_frequency(note, self.pitch_bends[channel]),
            phase: 0.0,
            secondary_phase: 0.0,
            age_seconds: 0.0,
            envelope: 0.0,
            release_rate: release_rate(program, percussion),
            releasing: false,
            held_by_pedal: false,
            percussion,
            noise_state: ((i64::from(note) + 1) * NOISE_MULTIPLIER + self.cursor as i64 + 1) & NOISE_MASK,
        });
    }
    fn stop_voice(&mut self, channel: usize, note: i32) {
        let sustained = self.sustain[channel];
        if let Some(voice) = self
            .voices
            .iter_mut()
            .find(|v| v.channel == channel && v.note == note && !v.releasing)
        {
            if sustained {
                voice.held_by_pedal = true;
            } else {
                voice.releasing = true;
            }
        }
    }
    fn control_change(&mut self, channel: usize, controller: i32, value: i32) {
        let normalized = clamp(f64::from(value) / 127.0, 0.0, 1.0) as f32;
        match controller {
            CONTROL_VOLUME => {
                self.volumes[channel] = normalized;
                self.refresh_gain(channel);
            }
            CONTROL_PAN => {
                self.pans[channel] = normalized;
                self.refresh_gain(channel);
            }
            CONTROL_EXPRESSION => {
                self.expressions[channel] = normalized;
                self.refresh_gain(channel);
            }
            CONTROL_SUSTAIN => {
                let was_sustained = self.sustain[channel];
                self.sustain[channel] = value >= SUSTAIN_ON;
                if was_sustained && value < SUSTAIN_ON {
                    self.release_sustained(channel);
                }
            }
            CONTROL_ALL_SOUND_OFF => self.voices.retain(|v| v.channel != channel),
            CONTROL_RESET_ALL => {
                self.volumes[channel] = 1.0;
                self.expressions[channel] = 1.0;
                self.pans[channel] = 0.5;
                self.sustain[channel] = false;
                self.pitch_bends[channel] = PITCH_BEND_CENTER;
                self.refresh_gain(channel);
                self.release_sustained(channel);
                self.update_pitch(channel);
            }
            CONTROL_ALL_NOTES_OFF => {
                for voice in self.voices.iter_mut().filter(|v| v.channel == channel) {
                    voice.held_by_pedal = false;
                    voice.releasing = true;
                }
            }
            _ => {}
        }
    }
    fn release_sustained(&mut self, channel: usize) {
        for voice in self.voices.iter_mut().filter(|v| v.channel == channel && v.held_by_pedal) {
            voice.held_by_pedal = false;
            voice.releasing = true;
        }
    }
    fn release_all(&mut self) {
        for voice in &mut self.voices {
            voice.held_by_pedal = false;
            voice.releasing = true;
        }
    }
    fn update_pitch(&mut self, channel: usize) {
        let bend = self.pitch_bends[channel];
        for voice in self.voices.iter_mut().filter(|v| v.channel == channel) {
            voice.frequency = note_frequency(voice.note, bend);
        }
    }
    fn steal_voice(&mut self) {
        let mut quietest = 0;
        let mut level_min = f64::INFINITY;
        for (index, voice) in self.voices.iter().enumerate() {
            let mut level = voice.envelope * voice.velocity;
            if voice.releasing {
                level *= 0.5;
            }
            if level < level_min {
                level_min = level;
                quietest = index;
            }
        }
        self.voices.remove(quietest);
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn note(time: f64, kind: Kind, channel: i32, a: i32, b: i32) -> Event {
        Event { time, kind, channel, a, b }
    }

    #[test]
    fn helpers_match_midi_rules() {
        assert!((note_frequency(69, 8192) - 440.0).abs() < 1e-9);
        assert!((note_frequency(81, 8192) - 880.0).abs() < 1e-9);
        assert!((note_frequency(69, 16383) - 493.88).abs() < 0.02);
        assert_eq!(waveform_family(0), 0);
        assert_eq!(waveform_family(56), 6);
        assert_eq!(waveform_family(127), 9);
        assert!(band_limited_saw(0.0, 0.01).abs() < 1e-9);
    }

    #[test]
    fn track_ends_after_release_tail() {
        let events = vec![note(0.0, Kind::NoteOn, 0, 60, 100), note(0.5, Kind::NoteOff, 0, 60, 0)];
        let mut synth = Synth::new(events, 0.5);
        let mut frames = 0;
        while !synth.complete() && frames < SAMPLE_RATE as usize * 5 {
            frames += synth.render(1024).len();
        }
        assert!(synth.complete());
        // the note plays for half a second and releases within the tail limit
        assert!(frames > SAMPLE_RATE as usize / 2 && frames < SAMPLE_RATE as usize * 3);
    }

    #[test]
    fn voices_are_limited_and_percussion_is_noise() {
        let mut events: Vec<Event> = (0..40).map(|n| note(0.0, Kind::NoteOn, 0, 40 + n, 90)).collect();
        events.push(note(0.0, Kind::NoteOn, 9, 38, 127));
        let mut synth = Synth::new(events, 1.0);
        let output = synth.render(512);
        assert_eq!(synth.voices.len(), MAX_VOICES);
        assert!(output.iter().any(|f| f[0] != 0.0));
        assert!(output.iter().all(|f| f[0].abs() <= 0.95 && f[1].abs() <= 0.95));
    }

    #[test]
    fn pan_and_sustain_controls() {
        let events = vec![
            note(0.0, Kind::ControlChange, 0, 10, 0),
            note(0.0, Kind::ControlChange, 0, 64, 127),
            note(0.0, Kind::NoteOn, 0, 60, 100),
            note(0.01, Kind::NoteOff, 0, 60, 0),
        ];
        let mut synth = Synth::new(events, 1.0);
        let output = synth.render(2048);
        // hard left pan leaves the right channel silent
        assert!(output.iter().all(|f| f[1] == 0.0));
        assert!(output.iter().any(|f| f[0] != 0.0));
        // the pedal holds the released note
        assert!(synth.voices[0].held_by_pedal && !synth.voices[0].releasing);
    }
}
