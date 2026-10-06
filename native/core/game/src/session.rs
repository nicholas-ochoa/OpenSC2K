//! One open city: its file document, the simulation city of its chunks, the
//! random states, and the engine and speed state between frames. A front end
//! owns one session and presents the results of each call.

use crate::engine::Engine;
use crate::results::TickResult;
use crate::speed::{self, Speed, SpeedState};
use crate::state::EngineState;
use sc2k_sim::formats::document::Document;
use sc2k_sim::sim::city::{CHUNK_IDS, City};
use sc2k_sim::sim::random::Randoms;
use std::path::{Path, PathBuf};

/// The first state of the process random of a new session, as the tool random.
const PROCESS_SEED: i64 = 1;
const GAME_SEED: i64 = 1;

pub struct Session {
    pub document: Document,
    pub city: City,
    pub randoms: Randoms,
    pub engine: EngineState,
    pub speed: SpeedState,
    /// The file of the city, or empty for a new city.
    pub path: PathBuf,
    /// Bumps on each change of the city, so views know when to copy the maps.
    pub revision: u64,
    /// The undo of the last tool edit.
    pub undo: Option<crate::edits::Undo>,
}

/// The simulation city of the chunks of a document.
pub fn city_from_document(document: &Document) -> City {
    let mut city = City::new(document.map_size, document.large_version);

    for id in CHUNK_IDS {
        if let (Some(chunk), Some(slot)) = (document.find(id), city.chunk_slot_mut(id)) {
            slot.present = true;
            slot.data = chunk.decoded.clone();
        }
    }

    city
}

impl Session {
    /// Open a city file. `lfsr_seed` seeds the simulation random; a front end
    /// passes the time.
    pub fn open(path: &Path, lfsr_seed: i64) -> Result<Self, String> {
        let bytes = std::fs::read(path).map_err(|error| format!("Cannot read {}: {error}", path.display()))?;
        let document = Document::parse(&bytes)?;

        Ok(Self::from_document(document, path.to_path_buf(), lfsr_seed))
    }

    pub fn from_document(document: Document, path: PathBuf, lfsr_seed: i64) -> Self {
        let city = city_from_document(&document);
        let engine = EngineState::for_city(&city);
        let mut session = Self {
            document,
            city,
            randoms: Randoms::new(PROCESS_SEED, (lfsr_seed & 0xffff) | 1, GAME_SEED),
            engine,
            speed: SpeedState::default(),
            path,
            revision: 0,
            undo: None,
        };

        session.speed.speed = session.city.simulation_speed().clamp(speed::PAUSED, speed::AFRICAN_SWALLOW);
        session.with_engine(|engine| engine.initialize_loaded_city());

        session
    }

    /// Run `call` on the engine of this session.
    pub fn with_engine<T>(&mut self, call: impl FnOnce(&mut Engine) -> T) -> T {
        let mut engine = Engine {
            city: &mut self.city,
            randoms: &mut self.randoms,
            state: &mut self.engine,
            detailed: false,
        };

        call(&mut engine)
    }

    /// Run `call` on the speed controller of this session.
    pub fn with_speed<T>(&mut self, call: impl FnOnce(&mut Speed) -> T) -> T {
        let mut engine = Engine {
            city: &mut self.city,
            randoms: &mut self.randoms,
            state: &mut self.engine,
            detailed: false,
        };
        let mut controller = Speed {
            engine: &mut engine,
            state: &mut self.speed,
        };

        call(&mut controller)
    }

    /// Run the frame time `delta_msec` at the game speed.
    pub fn advance(&mut self, delta_msec: f64, now_msec: i64, suspended: bool) -> TickResult {
        let result = self.with_speed(|controller| controller.advance_time(delta_msec, now_msec, suspended));

        if result.base_ticks > 0 || !result.day_results.is_empty() {
            self.revision += 1;
        }

        result
    }

    pub fn set_speed(&mut self, value: i64) -> bool {
        self.with_speed(|controller| controller.set_speed(value))
    }

    /// Copy the chunks of the simulation city into the document, for a save.
    pub fn sync_document(&mut self) {
        for id in CHUNK_IDS {
            let Some(chunk) = self.city.chunk(id) else {
                continue;
            };

            if let Some(target) = self.document.find_mut(id) {
                target.set_decoded(chunk.data.clone());
            }
        }
    }

    /// Write the city to `path`. The document keeps its format.
    pub fn save(&mut self, path: &Path) -> Result<(), String> {
        self.sync_document();
        let serialized = self.document.serialize(false)?;
        sc2k_sim::formats::store::write_verified(path, &serialized.bytes, None)?;
        self.path = path.to_path_buf();

        Ok(())
    }

    pub fn city_name(&self) -> String {
        self.document.city_name()
    }
}
