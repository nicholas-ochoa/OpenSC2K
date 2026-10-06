//! Audio output of the native shell: a cpal stream that renders the mixer, the
//! sound pack, the wave sound gate, and the music choices of CityAudioController.

use cpal::traits::{DeviceTrait, HostTrait, StreamTrait};
use sc2k_assets::packs::media;
use sc2k_audio::fluidsynth::FluidSynth;
use sc2k_audio::midi::{Event, Kind};
use sc2k_audio::mixer::{MUSIC_RATE, Mixer, Music};
use sc2k_audio::sequencer::Sequencer;
use sc2k_audio::shuffle::Shuffle;
use sc2k_audio::smf;
use sc2k_audio::soundfont;
use sc2k_audio::wav::{self, Sound};
use sc2k_audio::wave_gate::WaveGate;
use sc2k_sim::sim::reports::music;
use std::collections::HashMap;
use std::path::{Path, PathBuf};
use std::sync::{Arc, Mutex};

pub const MAIN_THEME_TRACK: i64 = 10001;
const FIRST_TRACK: i64 = 10000;
const TRACK_COUNT: i64 = 19;
const MUSIC_GAP_MSEC: f64 = 15000.0;
const SOUND_FIRST: i64 = 500;
const SOUND_LAST: i64 = 529;
/// The minimum view of each moving object type that makes a sound.
const THING_MINIMUM_VIEW: [i64; 17] = [0, 0, 2, 0, 0, 0, 1, 0, 0, 2, 2, 2, 2, 3, 0, 0, 2];

pub struct AudioSettings {
    pub music_volume: f32,
    pub effects_volume: f32,
    pub shuffle: bool,
    pub sound_pack: Option<PathBuf>,
    pub music_pack: Option<PathBuf>,
    pub soundfont_choice: String,
    pub soundfont_path: String,
}

pub struct Audio {
    mixer: Arc<Mutex<Mixer>>,
    _stream: Option<cpal::Stream>,
    sounds: HashMap<i64, Arc<Sound>>,
    music_files: HashMap<i64, PathBuf>,
    soundfonts: Vec<String>,
    gate: WaveGate,
    shuffle: Shuffle,
    pub shuffle_music: bool,
    pub menu_music: bool,
    general_index: i64,
    pub current_track: i64,
    gap_msec: f64,
    queued_track: i64,
    pub notice: String,
    pub music_enabled: bool,
    pub sound_enabled: bool,
    pub focused: bool,
}

/// The files of a media pack folder, by resource ID.
fn pack_files(folder: &Path, kind: &str) -> HashMap<i64, PathBuf> {
    let folder = folder.to_string_lossy();
    let root = folder
        .strip_suffix("/pack.json")
        .unwrap_or(&folder)
        .to_string();
    let Ok(text) = std::fs::read_to_string(Path::new(&root).join("pack.json")) else {
        return HashMap::new();
    };
    let manifest = media::read(&text, kind, &root, |path| Path::new(path).is_file());

    manifest
        .files
        .into_iter()
        .map(|(id, path)| (id, PathBuf::from(path)))
        .collect()
}

fn open_stream(mixer: Arc<Mutex<Mixer>>) -> Option<cpal::Stream> {
    let device = cpal::default_host().default_output_device()?;
    let config = device.default_output_config().ok()?;

    if config.sample_format() != cpal::SampleFormat::F32 {
        return None;
    }

    let config: cpal::StreamConfig = config.into();
    let channels = usize::from(config.channels);
    let rate = f64::from(config.sample_rate.0);
    let stream = device
        .build_output_stream(
            &config,
            move |output: &mut [f32], _| match mixer.lock() {
                Ok(mut mixer) => mixer.render(output, channels, rate),
                Err(_) => output.fill(0.0),
            },
            |error| eprintln!("audio: {error}"),
            None,
        )
        .ok()?;

    stream.play().ok()?;

    Some(stream)
}

/// The synthesizer events of a parsed MIDI file.
fn midi_events(sequence: &smf::Sequence) -> Vec<Event> {
    sequence
        .events
        .iter()
        .map(|event| {
            let (kind, a, b) = match event.kind {
                smf::Kind::NoteOn => (Kind::NoteOn, event.note, event.velocity),
                smf::Kind::NoteOff => (Kind::NoteOff, event.note, event.velocity),
                smf::Kind::KeyPressure => (Kind::KeyPressure, event.note, event.velocity),
                smf::Kind::ProgramChange => (Kind::ProgramChange, event.program, 0),
                smf::Kind::ControlChange => (Kind::ControlChange, event.controller, event.value),
                smf::Kind::PitchBend => (Kind::PitchBend, event.value, 0),
                smf::Kind::ChannelPressure => (Kind::ChannelPressure, event.value, 0),
                smf::Kind::Tempo => (Kind::Other, 0, 0),
            };

            Event {
                time: event.time_seconds,
                kind,
                channel: event.channel as i32,
                a: a as i32,
                b: b as i32,
            }
        })
        .collect()
}

impl Audio {
    pub fn new(settings: &AudioSettings) -> Self {
        let mixer = Arc::new(Mutex::new(Mixer::new(
            settings.music_volume,
            settings.effects_volume,
        )));
        let stream = open_stream(mixer.clone());
        let mut sounds = HashMap::new();

        if let Some(folder) = &settings.sound_pack {
            for (id, path) in pack_files(folder, "sound") {
                if (SOUND_FIRST..=SOUND_LAST).contains(&id)
                    && let Ok(sound) = std::fs::read(&path)
                        .map_err(|error| error.to_string())
                        .and_then(|bytes| wav::decode(&bytes))
                {
                    sounds.insert(id, Arc::new(sound));
                }
            }
        }

        let music_files = settings
            .music_pack
            .as_deref()
            .map(|folder| pack_files(folder, "music"))
            .unwrap_or_default();
        let system = soundfont::first_existing(&soundfont::sound_set_paths(
            match std::env::consts::OS {
                "macos" => "macOS",
                "windows" => "Windows",
                "linux" => "Linux",
                other => other,
            },
            &std::env::current_exe()
                .ok()
                .and_then(|path| path.parent().map(|p| p.to_string_lossy().into_owned()))
                .unwrap_or_default(),
            &std::env::var("SystemRoot").unwrap_or_default(),
        ));
        let seed = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .map_or(1, |time| time.as_nanos() as u64);

        Self {
            mixer,
            _stream: stream,
            sounds,
            music_files,
            soundfonts: soundfont::candidates(
                &settings.soundfont_choice,
                &settings.soundfont_path,
                &system,
            ),
            gate: WaveGate::default(),
            shuffle: Shuffle::new(seed),
            shuffle_music: settings.shuffle,
            menu_music: false,
            general_index: 0,
            current_track: -1,
            gap_msec: 0.0,
            queued_track: -1,
            notice: String::new(),
            music_enabled: true,
            sound_enabled: true,
            focused: true,
        }
    }

    fn mixer(&self) -> std::sync::MutexGuard<'_, Mixer> {
        self.mixer
            .lock()
            .unwrap_or_else(std::sync::PoisonError::into_inner)
    }

    #[allow(dead_code)]
    pub fn set_volumes(&self, music_volume: f32, effects_volume: f32) {
        let mut mixer = self.mixer();
        mixer.music_volume = music_volume;
        mixer.effects_volume = effects_volume;
    }

    pub fn set_focus(&mut self, focused: bool) {
        self.focused = focused;
        self.mixer().paused = !focused;
    }

    /// True while a track plays or waits in the gap between tracks.
    pub fn music_active(&self) -> bool {
        self.gap_msec > 0.0 || self.queued_track >= 0 || self.mixer().music_playing()
    }

    pub fn next_general_track(&mut self) -> i64 {
        let (track, index) = music::next_general_track(self.general_index);
        self.general_index = index;

        track
    }

    /// Play a sound effect that the wave gate accepts.
    pub fn play_sound(&mut self, id: i64, ambient: bool, simulation: bool) {
        if !self.sound_enabled || !self.focused {
            return;
        }

        if let Some(sound) = self.sounds.get(&id).cloned()
            && self.gate.request(id, ambient, simulation)
        {
            self.mixer().play_sound(id, sound, false);
        }
    }

    /// Play the sound events of a simulation tick for graphics size `view`.
    pub fn play_sound_events(&mut self, events: &[sc2k_sim::sim::value::Value], view: i64) {
        use sc2k_game::values::{boolean, int};

        for event in events {
            let id = int(event, "sound_id", -1);
            let from_thing = boolean(event, "from_thing");

            if from_thing {
                let kind = int(event, "thing_type", -1);

                if !(0..THING_MINIMUM_VIEW.len() as i64).contains(&kind)
                    || view < THING_MINIMUM_VIEW[kind as usize]
                {
                    continue;
                }
            }

            self.play_sound(id, from_thing, true);
        }
    }

    #[allow(dead_code)]
    pub fn stop_music(&mut self) {
        self.gap_msec = 0.0;
        self.queued_track = -1;
        self.current_track = -1;
        self.mixer().stop_music();
    }

    /// Start track `id`, or queue it while the gap between tracks runs.
    pub fn play_music_track(&mut self, mut id: i64, choose_shuffle: bool) -> bool {
        if !self.music_enabled
            || !self.focused
            || !(FIRST_TRACK..FIRST_TRACK + TRACK_COUNT).contains(&id)
        {
            return false;
        }

        if self.gap_msec > 0.0 {
            self.queued_track = id;

            return true;
        }

        if self.shuffle_music && choose_shuffle {
            if self.mixer().music_playing() {
                return true;
            }

            id = self.shuffle.next_track(FIRST_TRACK, TRACK_COUNT);
        }

        let Some(path) = self.music_files.get(&id).cloned() else {
            return false;
        };

        self.mixer().stop_music();
        self.current_track = id;

        match self.load_music(&path) {
            Ok(music) => {
                self.mixer().play_music(music);
                self.notice = format!("Playing: Track {id}");

                true
            }
            Err(error) => {
                self.notice = format!("Music: {error}");
                self.current_track = -1;

                false
            }
        }
    }

    fn load_music(&self, path: &Path) -> Result<Music, String> {
        let bytes = std::fs::read(path).map_err(|error| error.to_string())?;
        let extension = path
            .extension()
            .map(|text| text.to_string_lossy().to_lowercase())
            .unwrap_or_default();

        if extension == "wav" {
            return wav::decode(&bytes).map(|sound| Music::Frames {
                sound: Arc::new(sound),
                position: 0.0,
            });
        }

        if extension != "mid" && extension != "midi" {
            return Err(format!(
                "{extension} music needs a decoder that this build does not have"
            ));
        }

        let sequence = smf::parse(&bytes);

        if !sequence.error.is_empty() {
            return Err(sequence.error);
        }

        let mut synth = FluidSynth::new(MUSIC_RATE)?;
        let mut loaded = Err(String::from("No SoundFont is installed"));

        for path in &self.soundfonts {
            loaded = synth.load_soundfont(path);

            if loaded.is_ok() {
                break;
            }
        }

        loaded?;
        let sequencer = Sequencer::new(
            midi_events(&sequence),
            sequence.duration_seconds,
            MUSIC_RATE,
        );

        Ok(Music::Midi {
            sequencer,
            synth: Box::new(synth),
        })
    }

    /// Advance the clocks: the wave gate, the end of a track, and the gap between tracks.
    pub fn advance(&mut self, delta_msec: f64) {
        self.gate.advance(delta_msec);

        let finished = std::mem::take(&mut self.mixer().music_finished);

        if finished {
            self.current_track = -1;
            self.gap_msec = MUSIC_GAP_MSEC;

            if self.shuffle_music || self.menu_music {
                self.queued_track = MAIN_THEME_TRACK;
            }
        }

        if self.gap_msec > 0.0 {
            if !self.focused || !self.music_enabled {
                return;
            }

            self.gap_msec = (self.gap_msec - delta_msec.max(0.0)).max(0.0);

            if self.gap_msec > 0.0 {
                return;
            }

            let queued = std::mem::replace(&mut self.queued_track, -1);

            if queued >= 0 {
                self.play_music_track(queued, true);
            }
        }

        if self.menu_music && self.focused && self.music_enabled && !self.music_active() {
            self.play_music_track(MAIN_THEME_TRACK, false);
        }
    }
}
