//! The game mixer: one music source and the sound effect voices, each bus with
//! its own volume. The audio thread renders it; the game thread changes it.

use crate::sequencer::{MidiOutput, Sequencer};
use crate::wav::Sound;
use std::sync::Arc;

/// The rate at which MIDI music renders.
pub const MUSIC_RATE: f64 = 44_100.0;

/// The music that plays: a MIDI sequence on a synthesizer, or decoded frames.
pub enum Music {
    Midi {
        sequencer: Sequencer,
        synth: Box<dyn MidiOutput + Send>,
    },
    Frames {
        sound: Arc<Sound>,
        position: f64,
    },
}

struct Voice {
    sound: Arc<Sound>,
    position: f64,
    looping: bool,
    id: i64,
}

#[derive(Default)]
pub struct Mixer {
    pub music_volume: f32,
    pub effects_volume: f32,
    pub paused: bool,
    music: Option<Music>,
    /// The fractional MIDI frame position when the device rate differs.
    music_phase: f64,
    music_buffer: Vec<[f32; 2]>,
    voices: Vec<Voice>,
    /// Set when the music ends; the game thread reads and clears it.
    pub music_finished: bool,
}

impl Mixer {
    pub fn new(music_volume: f32, effects_volume: f32) -> Self {
        Self {
            music_volume,
            effects_volume,
            ..Self::default()
        }
    }

    pub fn play_music(&mut self, mut music: Music) {
        if let Music::Midi { sequencer, synth } = &mut music {
            sequencer.start(synth.as_mut());
        }

        self.music = Some(music);
        self.music_buffer.clear();
        self.music_phase = 0.0;
        self.music_finished = false;
    }

    pub fn stop_music(&mut self) {
        self.music = None;
        self.music_buffer.clear();
    }

    pub fn music_playing(&self) -> bool {
        self.music.is_some()
    }

    /// Play a sound effect. `looping` repeats it until `stop_sound`.
    pub fn play_sound(&mut self, id: i64, sound: Arc<Sound>, looping: bool) {
        self.voices.push(Voice {
            sound,
            position: 0.0,
            looping,
            id,
        });
    }

    pub fn stop_sound(&mut self, id: i64) {
        self.voices.retain(|voice| voice.id != id);
    }

    pub fn stop_sounds(&mut self) {
        self.voices.clear();
    }

    /// The next music frame at `step` source frames for each device frame.
    fn music_frame(&mut self, step: f64) -> [f32; 2] {
        match &mut self.music {
            None => [0.0, 0.0],
            Some(Music::Frames { sound, position }) => {
                let index = *position as usize;

                if index >= sound.frames.len() {
                    self.music = None;
                    self.music_finished = true;

                    return [0.0, 0.0];
                }

                *position += f64::from(sound.sample_rate) / MUSIC_RATE * step;

                sound.frames[index]
            }
            Some(Music::Midi { sequencer, synth }) => {
                while self.music_phase >= self.music_buffer.len() as f64 {
                    self.music_phase -= self.music_buffer.len() as f64;
                    self.music_buffer = sequencer.render(synth.as_mut(), 512);

                    if self.music_buffer.is_empty() {
                        self.music = None;
                        self.music_finished = true;

                        return [0.0, 0.0];
                    }
                }

                let frame = self.music_buffer[self.music_phase as usize];
                self.music_phase += step;

                frame
            }
        }
    }

    /// Fill `output`, interleaved with `channels` channels at `rate` frames each second.
    pub fn render(&mut self, output: &mut [f32], channels: usize, rate: f64) {
        output.fill(0.0);

        if self.paused || channels == 0 {
            return;
        }

        let step = MUSIC_RATE / rate;

        for frame in output.chunks_exact_mut(channels) {
            let music = if self.music.is_some() { self.music_frame(step) } else { [0.0, 0.0] };
            let mut mixed = [music[0] * self.music_volume, music[1] * self.music_volume];

            for voice in &mut self.voices {
                let index = voice.position as usize;

                if index < voice.sound.frames.len() {
                    let sample = voice.sound.frames[index];
                    mixed[0] += sample[0] * self.effects_volume;
                    mixed[1] += sample[1] * self.effects_volume;
                }

                voice.position += f64::from(voice.sound.sample_rate) / rate;

                if voice.looping && voice.position as usize >= voice.sound.frames.len() {
                    voice.position = 0.0;
                }
            }

            frame[0] = mixed[0].clamp(-1.0, 1.0);

            if channels > 1 {
                frame[1] = mixed[1].clamp(-1.0, 1.0);
            }
        }

        self.voices
            .retain(|voice| voice.looping || (voice.position as usize) < voice.sound.frames.len());
    }
}

#[cfg(test)]
mod tests {
    use super::{Mixer, Music};
    use crate::wav::Sound;
    use std::sync::Arc;

    #[test]
    fn sounds_mix_at_their_volume_and_end() {
        let mut mixer = Mixer::new(1.0, 0.5);
        let sound = Arc::new(Sound {
            sample_rate: 22050,
            frames: vec![[1.0, -1.0]; 2],
        });
        mixer.play_sound(500, sound.clone(), false);
        let mut output = vec![0.0; 10];
        mixer.render(&mut output, 2, 22050.0);
        assert_eq!(&output[..6], &[0.5, -0.5, 0.5, -0.5, 0.0, 0.0]);
        mixer.play_music(Music::Frames { sound, position: 0.0 });
        mixer.render(&mut output, 2, 44100.0);
        assert!(mixer.music_finished && !mixer.music_playing());
    }
}
