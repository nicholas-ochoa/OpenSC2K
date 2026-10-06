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
    /// Bumps when the days, an edit, or a rotation change the maps; moving
    /// objects alone do not change it.
    pub map_revision: u64,
    /// The undo of the last tool edit.
    pub undo: Option<crate::edits::Undo>,
}

/// The simulation city of the chunks of a document.
pub use sc2k_sim::sim::new_city::city_of as city_from_document;

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
            map_revision: 0,
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

        if !result.day_results.is_empty() || !result.disaster_results.is_empty() {
            self.map_revision += 1;
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

/// The chunks that a rotation turns, as CityRotationCommand.REQUIRED_CHUNKS.
const ROTATION_CHUNKS: [&str; 17] = [
    "MISC", "ALTM", "XTER", "XBLD", "XZON", "XUND", "XTXT", "XTHG", "XBIT", "XTRF", "XPLT", "XVAL", "XCRM", "XPLC", "XFIR", "XPOP", "XROG",
];
const SIGN_CHUNK: &str = "XSGN";

impl Session {
    /// Turn the city a quarter turn, as the rotate buttons do. The saved
    /// coordinates, the runtime coordinates of the engine, and the signs turn.
    pub fn rotate(&mut self, counter_clockwise: bool) -> Result<(), String> {
        use sc2k_sim::formats::sc2x::xsgn::Xsgn;
        use sc2k_sim::sim::tools::rotation;

        for id in ROTATION_CHUNKS {
            let size = self.city.chunk(id).map(|chunk| chunk.data.len() as i64);

            if size != Some(self.city.decoded_size(id)) {
                return Err("rotation data is missing or invalid".into());
            }
        }

        let edge = self.city.map_size as usize;
        let mut turned_signs = None;

        if self.document.is_sc2x()
            && let Some(chunk) = self.document.find(SIGN_CHUNK)
        {
            let mut table = Xsgn::decode(&chunk.decoded, edge).map_err(|error| format!("sign data is invalid: {error}"))?;
            let last = edge as u16 - 1;

            for sign in table.signs.iter_mut().filter(|sign| sign.is_active()) {
                let (x, y) = (sign.x, sign.y);
                (sign.x, sign.y) = if counter_clockwise { (y, last - x) } else { (last - y, x) };
            }

            turned_signs = Some(table.encode(edge)?);
        }

        rotation::rotate(&mut self.city, counter_clockwise);

        if let (Some(data), Some(chunk)) = (turned_signs, self.document.find_mut(SIGN_CHUNK)) {
            chunk.set_decoded(data);
        }

        self.with_engine(|engine| engine.rotate_runtime_coordinates(counter_clockwise));
        self.undo = None;
        self.revision += 1;
        self.map_revision += 1;

        Ok(())
    }
}
