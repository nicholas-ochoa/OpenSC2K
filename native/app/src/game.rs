//! The game of the native shell: the simulation runner, what it publishes,
//! the city art, the audio, and the view.

use crate::audio::{self, Audio};
use crate::city_view::CityView;
use crate::settings::Settings;
use sc2k_assets::packs::graphics::GraphicsPack;
use sc2k_game::edits;
use sc2k_game::results::TickResult;
use sc2k_game::runner::Runner;
use sc2k_game::session::Session;
use sc2k_sim::sim::ids::sc2misc_layout as misc;
use sc2k_view::art::CityArt;
use sc2k_view::scene::{self, Publisher};

/// The values of the status line.
#[derive(Clone, Debug, Default)]
pub struct Status {
    pub city_name: String,
    pub days: i64,
    pub funds: i64,
    pub speed: i64,
    pub music_enabled: bool,
}

/// What the simulation thread publishes after each step.
pub struct Published {
    pub scene: scene::Update,
    pub status: Status,
}

fn status_of(session: &Session) -> Status {
    Status {
        city_name: session.city_name(),
        days: session.city.age_in_days(),
        funds: edits::funds(session),
        speed: session.speed.speed,
        music_enabled: session.city.music_enabled(),
    }
}

pub struct Game {
    pub audio: Audio,
    pub art: CityArt,
    pub runner: Runner<Published>,
    pub status: Status,
    pub view: CityView,
    /// The map revision of the data view values.
    pub data_revision: u64,
}

impl Game {
    pub fn load(city_path: &std::path::Path) -> Result<Self, String> {
        let settings = Settings::load();
        let folder = settings
            .graphics_folder()
            .ok_or("No graphics pack is set. Import the game assets first.")?;
        let pack = GraphicsPack::load(&folder.to_string_lossy())?;
        let art = CityArt::new(&pack);
        let seed = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .map_or(1, |time| time.as_millis() as i64);
        let session = Session::open(city_path, seed)?;
        let center = (
            session.city.misc_u32(misc::CITY_CENTER_X) as i32,
            session.city.misc_u32(misc::CITY_CENTER_Y) as i32,
        );
        let (mut publisher, first) =
            Publisher::new(&session.city, session.revision, session.map_revision);
        let view = CityView::new(&first, center);
        let status = status_of(&session);
        let music = status.music_enabled;
        let runner = Runner::spawn(session, move |session, _| Published {
            scene: publisher.update(&session.city, session.revision, session.map_revision),
            status: status_of(session),
        });
        let config = &settings.config;
        let mut audio = Audio::new(&audio::AudioSettings {
            music_volume: config.float("audio", "music_volume", 0.8) as f32,
            effects_volume: config.float("audio", "effects_volume", 0.8) as f32,
            shuffle: config.bool("audio", "shuffle_music", false),
            sound_pack: settings.path("audio", "sound_pack_folder"),
            music_pack: settings.path("audio", "music_pack_folder"),
            soundfont_choice: config.string("audio", "music_soundfont", "system"),
            soundfont_path: config.string("audio", "music_soundfont_path", ""),
        });

        if music {
            let track = audio.next_general_track();
            audio.play_music_track(track, true);
        }

        Ok(Self {
            audio,
            art,
            runner,
            status,
            view,
            data_revision: u64::MAX,
        })
    }

    /// Take the updates of the simulation thread: the scene, the status, and
    /// the sounds, music, and questions of each tick.
    pub fn receive(&mut self) {
        for update in self.runner.poll() {
            self.view.apply(&update.published.scene);
            self.status = update.published.status;

            if let Some(tick) = &update.tick {
                self.present_tick(tick);
            }
        }

        if self.view.data_mode.is_some() && self.data_revision != self.view.map_revision {
            self.refresh_data_values();
        }
    }

    pub fn refresh_data_values(&mut self) {
        if let Some(mode) = self.view.data_mode {
            self.view.data_values = self
                .runner
                .call(move |session| sc2k_view::data_view::values(&session.city, mode));
            self.data_revision = self.view.map_revision;
        }
    }

    fn present_tick(&mut self, tick: &TickResult) {
        if !tick.error.is_empty() {
            eprintln!("simulation: {}", tick.error);
        }

        self.audio
            .play_sound_events(&tick.sound_events, self.view.camera.graphics_view() as i64);

        for track in &tick.music_track_requests {
            if self.status.music_enabled {
                self.audio.play_music_track(i64::from(*track), true);
            }
        }

        // until the dialogs exist, the budget keeps its rates and a military base is declined
        for request in &tick.interaction_requests {
            match sc2k_game::values::text(request, "type").as_str() {
                "annual_budget" => {
                    let values = sc2k_game::values::ints(request, "funding_values");
                    let automatic = sc2k_game::values::boolean(request, "auto_budget");
                    self.runner.call(move |session| {
                        session.with_speed(|speed| speed.resolve_annual_budget(&values, automatic))
                    });
                }
                "military_proposal" => {
                    self.runner.call(|session| {
                        session.with_speed(|speed| speed.resolve_military_proposal(false))
                    });
                }
                "military_notice" => {
                    self.runner.call(|session| {
                        session.with_speed(|speed| speed.resolve_military_notice())
                    });
                }
                _ => {}
            }
        }
    }
}
