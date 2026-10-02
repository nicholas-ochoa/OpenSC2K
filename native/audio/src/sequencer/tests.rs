//! Tests of event timing, seeking, looping and the release tail.
use super::*;
use crate::midi::Kind;

const RATE: f64 = 1000.0;

/// Records each event with its frame, and renders the count of held notes.
#[derive(Default)]
struct Recorder {
    frame: u64,
    sent: Vec<(u64, Kind, i32)>,
    held: Vec<i32>,
    resets: usize,
    releases: usize,
    /// Voices that keep sounding after a release, for the tail checks.
    ringing_frames: u64,
}

impl MidiOutput for Recorder {
    fn send(&mut self, event: &Event) {
        self.sent.push((self.frame, event.kind, event.a));

        match event.kind {
            Kind::NoteOn => self.held.push(event.a),
            Kind::NoteOff => self.held.retain(|note| *note != event.a),
            _ => {}
        }
    }

    fn reset(&mut self) {
        self.resets += 1;
        self.held.clear();
    }

    fn release_notes(&mut self) {
        self.releases += 1;
        self.held.clear();
    }

    fn render(&mut self, left: &mut [f32], right: &mut [f32]) {
        left.fill(self.held.len() as f32);
        right.fill(self.held.len() as f32);
        self.frame += left.len() as u64;
        self.ringing_frames = self.ringing_frames.saturating_sub(left.len() as u64);
    }

    fn active_voices(&mut self) -> usize {
        self.held.len() + usize::from(self.ringing_frames > 0)
    }
}

fn event(time: f64, kind: Kind, a: i32) -> Event {
    Event {
        time,
        kind,
        channel: 0,
        a,
        b: 100,
    }
}

fn song() -> Vec<Event> {
    vec![
        event(0.0, Kind::ProgramChange, 5),
        event(0.0, Kind::NoteOn, 60),
        event(0.25, Kind::ControlChange, 7),
        event(0.5, Kind::NoteOff, 60),
        event(0.5, Kind::NoteOn, 64),
        event(0.75, Kind::PitchBend, 9000),
        event(1.0, Kind::NoteOff, 64),
    ]
}

fn render_all(sequencer: &mut Sequencer, output: &mut Recorder, chunk: usize) -> Vec<[f32; 2]> {
    let mut frames = Vec::new();

    for _ in 0..10_000 {
        if sequencer.complete() {
            break;
        }

        frames.extend(sequencer.render(output, chunk));
    }

    frames
}

#[test]
fn events_start_on_their_own_frame_at_every_chunk_size() {
    let mut reference = None;

    for chunk in [1, 7, 97, 1024] {
        let mut output = Recorder::default();
        let mut sequencer = Sequencer::new(song(), 1.0, RATE);
        sequencer.start(&mut output);
        let frames = render_all(&mut sequencer, &mut output, chunk);
        let frames_of_events: Vec<u64> = output.sent.iter().map(|sent| sent.0).collect();

        assert_eq!(frames_of_events, vec![0, 0, 250, 500, 500, 750, 1000]);
        assert!(sequencer.complete());

        match &reference {
            None => reference = Some(frames),
            Some(expected) => assert_eq!(&frames, expected),
        }
    }
}

#[test]
fn track_completes_after_the_release_tail() {
    let mut output = Recorder {
        ringing_frames: 1300,
        ..Default::default()
    };
    let mut sequencer = Sequencer::new(song(), 1.0, RATE);
    sequencer.start(&mut output);
    let frames = render_all(&mut sequencer, &mut output, 64);

    // the voice rings for 300 frames past the end; the tail renders in whole blocks
    assert!(frames.len() >= 1300 && frames.len() < 1300 + TAIL_BLOCK_FRAMES);
    assert!(sequencer.complete());
}

#[test]
fn tail_stops_at_its_limit() {
    let mut output = Recorder {
        ringing_frames: u64::MAX,
        ..Default::default()
    };
    let mut sequencer = Sequencer::new(song(), 1.0, RATE);
    sequencer.start(&mut output);
    let frames = render_all(&mut sequencer, &mut output, 500);

    assert_eq!(frames.len() as f64, (1.0 + MAX_TAIL_SECONDS) * RATE);
}

#[test]
fn seek_restores_channel_state_without_old_notes() {
    let mut output = Recorder::default();
    let mut sequencer = Sequencer::new(song(), 1.0, RATE);
    sequencer.start(&mut output);
    sequencer.render(&mut output, 100);
    output.sent.clear();
    sequencer.seek(&mut output, 0.8);
    let replayed: Vec<Kind> = output.sent.iter().map(|sent| sent.1).collect();

    assert_eq!(replayed, vec![Kind::ProgramChange, Kind::ControlChange, Kind::PitchBend]);
    assert!(output.held.is_empty());
    assert!((sequencer.position() - 0.8).abs() < 1e-9);
    assert_eq!(output.resets, 2);

    output.sent.clear();
    sequencer.render(&mut output, 300);

    assert_eq!(output.sent.len(), 1);
    assert_eq!(output.sent[0].1, Kind::NoteOff);
}

#[test]
fn seek_past_the_end_stops_at_the_end() {
    let mut output = Recorder::default();
    let mut sequencer = Sequencer::new(song(), 1.0, RATE);
    sequencer.seek(&mut output, 99.0);

    assert!((sequencer.position() - sequencer.duration()).abs() < 1e-9);
}

#[test]
fn looping_track_restarts_and_never_completes() {
    let mut output = Recorder::default();
    let mut sequencer = Sequencer::new(song(), 1.0, RATE);
    sequencer.set_looping(true);
    sequencer.start(&mut output);
    let frames = sequencer.render(&mut output, 3500);

    assert_eq!(frames.len(), 3500);
    assert!(!sequencer.complete());
    assert_eq!(output.releases, 3);
    assert_eq!(output.sent.iter().filter(|sent| sent.1 == Kind::ProgramChange).count(), 4);
    assert!((sequencer.position() - 0.5).abs() < 1e-9);
}

#[test]
fn empty_looping_track_completes() {
    let mut output = Recorder::default();
    let mut sequencer = Sequencer::new(Vec::new(), 0.0, RATE);
    sequencer.set_looping(true);
    sequencer.start(&mut output);
    sequencer.render(&mut output, 1000);

    assert!(sequencer.complete());
}
