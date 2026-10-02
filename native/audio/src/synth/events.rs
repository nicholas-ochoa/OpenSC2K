//! MIDI events: notes, programs, controllers, and pitch bends.

use super::*;

impl Synth {
    pub(super) fn apply_due_events(&mut self) {
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
            Kind::ChannelPressure | Kind::KeyPressure | Kind::Other => {}
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

    pub(super) fn release_all(&mut self) {
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
