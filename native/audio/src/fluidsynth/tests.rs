//! Tests of the FluidSynth backend with the generated test SoundFont. They need
//! the FluidSynth library. Without it they pass with a note, unless
//! OPENSC2K_REQUIRE_FLUIDSYNTH is set, as it is in CI.
use std::path::PathBuf;

use super::test_soundfont;
use super::*;
use crate::midi::{Event, Kind};
use crate::sequencer::Sequencer;

const RATE: f64 = test_soundfont::SAMPLE_RATE as f64;
const FIXTURE: &str = "../../game/tests/fixtures/soundfonts/opensc2k_test_gm.sf2";
const REQUIRE_VARIABLE: &str = "OPENSC2K_REQUIRE_FLUIDSYNTH";
const UPDATE_VARIABLE: &str = "OPENSC2K_UPDATE_FIXTURES";
const DRUM_CHANNEL: i32 = 9;
const SQUARE_PROGRAM: i32 = 80;
// Control change numbers.
const VOLUME: i32 = 7;
const PAN: i32 = 10;
const EXPRESSION: i32 = 11;
const SUSTAIN_PEDAL: i32 = 64;
const REVERB_SEND: i32 = 91;
const CHORUS_SEND: i32 = 93;

/// A synthesizer with the test SoundFont, or `None` when FluidSynth is missing.
fn synth() -> Option<FluidSynth> {
    match FluidSynth::new(RATE) {
        Ok(mut synth) => {
            synth.load_soundfont(&fixture_path()).expect("the test SoundFont loads");

            Some(synth)
        }
        Err(error) if std::env::var_os(REQUIRE_VARIABLE).is_none() => {
            eprintln!("FluidSynth test skipped: {error}");

            None
        }
        Err(error) => panic!("{error}"),
    }
}

fn fixture_path() -> String {
    PathBuf::from(env!("CARGO_MANIFEST_DIR"))
        .join(FIXTURE)
        .to_string_lossy()
        .into_owned()
}

fn temporary_file(name: &str, bytes: &[u8]) -> String {
    let path = std::env::temp_dir().join(format!("opensc2k-{}-{name}", std::process::id()));
    std::fs::write(&path, bytes).expect("the temporary folder is writable");

    path.to_string_lossy().into_owned()
}

fn event(time: f64, kind: Kind, channel: i32, a: i32, b: i32) -> Event {
    Event { time, kind, channel, a, b }
}

fn render(synth: &mut FluidSynth, events: Vec<Event>, seconds: f64) -> Vec<[f32; 2]> {
    let mut sequencer = Sequencer::new(events, seconds, RATE);
    sequencer.start(synth);

    sequencer.render(synth, (seconds * RATE) as usize)
}

fn energy(frames: &[[f32; 2]]) -> f64 {
    frames
        .iter()
        .map(|f| f64::from(f[0]).powi(2) + f64::from(f[1]).powi(2))
        .sum::<f64>()
        / frames.len().max(1) as f64
}

fn note(channel: i32, key: i32) -> Vec<Event> {
    vec![
        event(0.0, Kind::NoteOn, channel, key, 100),
        event(0.2, Kind::NoteOff, channel, key, 0),
    ]
}

#[test]
fn committed_fixture_matches_the_generator() {
    let generated = test_soundfont::bytes();

    if std::env::var_os(UPDATE_VARIABLE).is_some() {
        std::fs::create_dir_all(PathBuf::from(fixture_path()).parent().unwrap()).unwrap();
        std::fs::write(fixture_path(), &generated).unwrap();
    }

    assert_eq!(std::fs::read(fixture_path()).expect("the test SoundFont is committed"), generated);
}

#[test]
fn valid_soundfont_renders_a_note() {
    let Some(mut synth) = synth() else { return };
    let frames = render(&mut synth, note(0, 69), 0.3);

    assert_eq!(frames.len(), (0.3 * RATE) as usize);
    assert!(energy(&frames[..4410]) > 1e-4, "the note is audible");
    assert!(frames.iter().all(|f| f[0].is_finite() && f[1].is_finite()));
}

#[test]
fn soundfont_errors_explain_the_cause() {
    let Some(mut synth) = synth() else { return };
    let missing = synth.load_soundfont("/no/such/folder/music.sf2").unwrap_err();
    let text = synth.load_soundfont(&temporary_file("text.sf2", b"not a SoundFont")).unwrap_err();
    let mut truncated_bytes = test_soundfont::bytes();
    truncated_bytes.truncate(200);
    let truncated = synth
        .load_soundfont(&temporary_file("truncated.sf2", &truncated_bytes))
        .unwrap_err();

    assert!(missing.starts_with("The SoundFont does not exist"), "{missing}");
    assert!(text.starts_with("Unsupported SoundFont"), "{text}");
    assert!(truncated.starts_with("The SoundFont failed to load"), "{truncated}");

    // a failed switch keeps the SoundFont that already plays
    assert!(synth.has_soundfont());
    assert!(energy(&render(&mut synth, note(0, 69), 0.1)) > 1e-4);
}

/// Renders on a new synthesizer. Reverb and chorus keep ringing through a MIDI
/// reset, so renders that tests compare must not share a synthesizer.
fn render_fresh(events: Vec<Event>, seconds: f64) -> Option<Vec<[f32; 2]>> {
    synth().map(|mut synth| render(&mut synth, events, seconds))
}

#[test]
fn program_change_selects_another_preset() {
    let Some(sine) = render_fresh(note(0, 69), 0.1) else { return };
    let mut events = note(0, 69);
    events.insert(0, event(0.0, Kind::ProgramChange, 0, SQUARE_PROGRAM, 0));
    let square = render_fresh(events, 0.1).unwrap();

    assert!(energy(&sine) > 1e-4 && energy(&square) > 1e-4);
    assert_ne!(sine, square, "programs 0 and 80 use different samples");
}

#[test]
fn channel_ten_plays_the_drum_kit() {
    let Some(kick) = render_fresh(note(DRUM_CHANNEL, 36), 0.1) else {
        return;
    };
    let outside_kit = render_fresh(note(DRUM_CHANNEL, 100), 0.1).unwrap();
    let melodic = render_fresh(note(0, 100), 0.1).unwrap();

    assert!(energy(&kick) > 1e-4, "the bass drum key sounds");
    assert!(energy(&outside_kit) < 1e-9, "keys outside the kit are silent on the drum channel");
    assert!(energy(&melodic) > 1e-4, "the same key sounds on a melodic channel");
}

#[test]
fn sustain_pedal_holds_released_notes() {
    let Some(released) = render_fresh(dry(note(0, 69)), 0.6) else {
        return;
    };
    let mut events = dry(note(0, 69));
    events.insert(0, event(0.0, Kind::ControlChange, 0, SUSTAIN_PEDAL, 127));
    let held = render_fresh(events, 0.6).unwrap();
    let after_release = (0.5 * RATE) as usize;

    assert!(energy(&released[after_release..]) < 1e-6);
    assert!(energy(&held[after_release..]) > 1e-4);
}

/// Turns off the reverb and chorus sends of channel 0, so only the note sounds.
fn dry(mut events: Vec<Event>) -> Vec<Event> {
    events.insert(0, event(0.0, Kind::ControlChange, 0, REVERB_SEND, 0));
    events.insert(0, event(0.0, Kind::ControlChange, 0, CHORUS_SEND, 0));

    events
}

#[test]
fn volume_pan_and_gain_shape_the_output() {
    let mut events = dry(note(0, 69));
    events.insert(0, event(0.0, Kind::ControlChange, 0, PAN, 0));
    let Some(left) = render_fresh(events, 0.1) else { return };
    let left_energy: f64 = left.iter().map(|f| f64::from(f[0]).powi(2)).sum();
    let right_energy: f64 = left.iter().map(|f| f64::from(f[1]).powi(2)).sum();

    assert!(left_energy > right_energy * 100.0, "pan 0 is hard left");

    let full = render_fresh(dry(note(0, 69)), 0.1).unwrap();
    let mut events = dry(note(0, 69));
    events.insert(0, event(0.0, Kind::ControlChange, 0, VOLUME, 32));
    events.insert(0, event(0.0, Kind::ControlChange, 0, EXPRESSION, 64));
    let quiet = render_fresh(events, 0.1).unwrap();

    assert!(energy(&quiet) < energy(&full) * 0.1, "volume and expression lower the level");

    let mut synth = synth().unwrap();
    synth.set_gain(0.0);
    assert!(energy(&render(&mut synth, note(0, 69), 0.1)) < 1e-12);
}

#[test]
fn velocity_and_pitch_bend_change_the_note() {
    let Some(loud) = render_fresh(dry(note(0, 69)), 0.1) else { return };
    let mut soft_events = dry(note(0, 69));
    soft_events[2].b = 20;
    let soft = render_fresh(soft_events, 0.1).unwrap();
    let mut bent_events = dry(note(0, 69));
    bent_events.insert(2, event(0.0, Kind::PitchBend, 0, 16383, 0));
    let bent = render_fresh(bent_events, 0.1).unwrap();

    assert!(energy(&soft) < energy(&loud) * 0.5, "a soft note is quieter");
    assert_ne!(loud, bent, "a pitch bend changes the waveform");
}

#[test]
fn soundfont_switch_keeps_the_synthesizer_working() {
    let Some(before) = render_fresh(note(0, 69), 0.1) else { return };
    let copy = temporary_file("copy.sf2", &test_soundfont::bytes());
    let mut synth = synth().unwrap();
    synth.load_soundfont(&copy).expect("a second SoundFont loads");
    let after = render(&mut synth, note(0, 69), 0.1);

    assert_eq!(before, after, "the same SoundFont renders the same samples after a switch");
}

#[test]
fn every_request_size_renders_the_whole_track() {
    let Some(mut synth) = synth() else { return };
    let events = vec![
        event(0.0, Kind::NoteOn, 0, 60, 100),
        event(0.013, Kind::PitchBend, 0, 12000, 0),
        event(0.021, Kind::NoteOn, DRUM_CHANNEL, 38, 90),
        event(0.05, Kind::NoteOff, 0, 60, 0),
    ];
    let mut sequencer = Sequencer::new(events.clone(), 0.1, RATE);
    sequencer.start(&mut synth);
    let whole = sequencer.render(&mut synth, 4410);
    sequencer = Sequencer::new(events, 0.1, RATE);
    sequencer.start(&mut synth);
    let mut pieces = Vec::new();

    while pieces.len() < 4410 {
        pieces.extend(sequencer.render(&mut synth, 97.min(4410 - pieces.len())));
    }

    // FluidSynth starts events on its own 64-frame blocks, so compare length and sound
    assert_eq!(whole.len(), pieces.len());
    assert!(energy(&pieces) > 1e-4);
    assert!(energy(&whole) > 1e-4);
}

#[test]
fn missing_library_reports_an_error() {
    let error = probe_library("/no/such/folder/libfluidsynth-missing");

    assert!(error.starts_with("The FluidSynth shared library could not be loaded"), "{error}");
}
