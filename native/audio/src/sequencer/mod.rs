//! Plays a timed event list through a synthesizer. Each event starts on its own
//! sample: a render splits at every event, so the output does not depend on the
//! size of the requests.
#[cfg(test)]
mod tests;

use crate::midi::Event;

/// Rendering stops this long after the last event when voices still sound.
const MAX_TAIL_SECONDS: f64 = 2.0;

/// The tail renders in small blocks, so that it ends soon after the last voice.
const TAIL_BLOCK_FRAMES: usize = 256;

/// A synthesizer that takes MIDI events and renders stereo samples.
pub trait MidiOutput {
    fn send(&mut self, event: &Event);

    /// Stops every voice and restores the General MIDI channel defaults.
    fn reset(&mut self);

    /// Releases every note, so that each voice fades out normally.
    fn release_notes(&mut self);

    /// Fills both buffers. They have the same length.
    fn render(&mut self, left: &mut [f32], right: &mut [f32]);

    fn active_voices(&mut self) -> usize;
}

#[derive(Default)]
pub struct Sequencer {
    events: Vec<Event>,
    event_frames: Vec<u64>,
    end_frame: u64,
    sample_rate: f64,
    cursor: usize,
    frame: u64,
    tail_frames: u64,
    looping: bool,
    complete: bool,
    left: Vec<f32>,
    right: Vec<f32>,
}

impl Sequencer {
    /// A sequence of `events` in play order. The track lasts `duration` seconds,
    /// or until its last event when that is later.
    pub fn new(events: Vec<Event>, duration: f64, sample_rate: f64) -> Self {
        let event_frames: Vec<u64> = events.iter().map(|event| seconds_to_frame(event.time, sample_rate)).collect();
        let last_event = event_frames.iter().copied().max().unwrap_or(0);
        let end_frame = seconds_to_frame(duration, sample_rate).max(last_event);

        Self {
            events,
            event_frames,
            end_frame,
            sample_rate,
            ..Default::default()
        }
    }

    /// Restarts at the first event with General MIDI defaults.
    pub fn start(&mut self, output: &mut impl MidiOutput) {
        output.reset();
        self.cursor = 0;
        self.frame = 0;
        self.tail_frames = 0;
        self.complete = false;
    }

    pub fn set_looping(&mut self, looping: bool) {
        self.looping = looping;
    }

    pub fn looping(&self) -> bool {
        self.looping
    }

    pub fn complete(&self) -> bool {
        self.complete
    }

    pub fn position(&self) -> f64 {
        self.frame as f64 / self.sample_rate
    }

    pub fn duration(&self) -> f64 {
        self.end_frame as f64 / self.sample_rate
    }

    /// Moves to `seconds`. Notes before that time stay silent, but programs,
    /// controllers, bends and pressure take the values that they had there.
    pub fn seek(&mut self, output: &mut impl MidiOutput, seconds: f64) {
        let target = seconds_to_frame(seconds, self.sample_rate).min(self.end_frame);
        self.start(output);

        while self.cursor < self.events.len() && self.event_frames[self.cursor] < target {
            let event = self.events[self.cursor];

            if !event.kind.is_note() {
                output.send(&event);
            }

            self.cursor += 1;
        }

        self.frame = target;
    }

    /// Up to `frame_count` stereo frames. Fewer frames return when the track
    /// completes: after its end, once no voice sounds or the tail limit passes.
    pub fn render(&mut self, output: &mut impl MidiOutput, frame_count: usize) -> Vec<[f32; 2]> {
        let mut frames = Vec::with_capacity(frame_count);

        while frames.len() < frame_count && !self.complete {
            self.send_due_events(output);
            let at_end = self.frame >= self.end_frame && self.cursor >= self.events.len();

            if at_end && self.looping && self.end_frame > 0 {
                output.release_notes();
                self.cursor = 0;
                self.frame = 0;

                continue;
            }

            if at_end && self.tail_is_over(output) {
                self.complete = true;

                break;
            }

            let block = self.block_length(frame_count - frames.len(), at_end);
            self.render_block(output, block, &mut frames);
            self.frame += block as u64;

            if at_end {
                self.tail_frames += block as u64;
            }
        }

        frames
    }

    fn send_due_events(&mut self, output: &mut impl MidiOutput) {
        while self.cursor < self.events.len() && self.event_frames[self.cursor] <= self.frame {
            output.send(&self.events[self.cursor]);
            self.cursor += 1;
        }
    }

    /// The tail checks for silence only between whole tail blocks, so it ends on
    /// the same frame for every request size.
    fn tail_is_over(&self, output: &mut impl MidiOutput) -> bool {
        let limit = seconds_to_frame(MAX_TAIL_SECONDS, self.sample_rate);
        let block_done = self.tail_frames > 0 && self.tail_frames.is_multiple_of(TAIL_BLOCK_FRAMES as u64);

        self.tail_frames >= limit || (block_done && output.active_voices() == 0)
    }

    /// Frames until the next event or the end of the track, at most `remaining`.
    fn block_length(&self, remaining: usize, at_end: bool) -> usize {
        if at_end {
            let into_block = (self.tail_frames % TAIL_BLOCK_FRAMES as u64) as usize;

            return remaining.min(TAIL_BLOCK_FRAMES - into_block);
        }

        let boundary = self
            .event_frames
            .get(self.cursor)
            .copied()
            .unwrap_or(self.end_frame)
            .min(self.end_frame);
        let until_boundary = boundary.saturating_sub(self.frame).max(1);

        remaining.min(until_boundary.min(usize::MAX as u64) as usize)
    }

    fn render_block(&mut self, output: &mut impl MidiOutput, block: usize, frames: &mut Vec<[f32; 2]>) {
        // the buffers grow to the largest request and are then reused
        if self.left.len() < block {
            self.left.resize(block, 0.0);
            self.right.resize(block, 0.0);
        }

        let left = &mut self.left[..block];
        let right = &mut self.right[..block];
        output.render(left, right);
        frames.extend(left.iter().zip(right.iter()).map(|(l, r)| [*l, *r]));
    }
}

fn seconds_to_frame(seconds: f64, sample_rate: f64) -> u64 {
    (seconds.max(0.0) * sample_rate).round() as u64
}
