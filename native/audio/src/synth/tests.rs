//! Tests of the synthesizer.

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
