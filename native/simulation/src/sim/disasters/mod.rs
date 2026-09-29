//! Disasters: selection, start, map spread, damage, and end.

pub mod damage;
pub mod end;
pub mod map;
pub mod start;
pub mod things;
pub mod weather;

use crate::gd_object;
use crate::gd_phase_result;
use crate::sim::city::City;
use crate::sim::events::{EffectEvent, SoundEvent};
use crate::sim::geom::{Rect2i, Vec2i};
use crate::sim::tools::Maps;
use crate::sim::value::{Ints32, OrderedMap};

pub const FIRE_OVERLAY: i64 = 0xff;
pub const TOXIC_OVERLAY: i64 = 0xfb;
pub const FLOOD_OVERLAY: i64 = 0xfc;
pub const RIOT_OVERLAY_FORWARD: i64 = 0xfd;
pub const RIOT_OVERLAY_REVERSE: i64 = 0xfe;

/// Map directions in the DisasterMapConstants order.
pub const CARDINAL_DIRECTIONS: [Vec2i; 4] = [Vec2i::new(-1, 0), Vec2i::new(0, -1), Vec2i::new(1, 0), Vec2i::new(0, 1)];

/// The chunks that the DisasterStart phases copy and store.
pub const START_CHUNKS: [&str; 11] =
    ["ALTM", "XBLD", "XTER", "XZON", "XUND", "XBIT", "XTRF", "XTXT", "XLAB", "XMIC", "MISC"];

/// The chunks that the DisasterMap phases copy and store.
pub const MAP_CHUNKS: [&str; 14] =
    ["ALTM", "XBLD", "XTER", "XZON", "XUND", "XBIT", "XTRF", "XVAL", "XTXT", "XLAB", "XMIC", "XTHG", "XFIR", "MISC"];

/// A copy of chunks before an edit. GDScript edits copies and stores the
/// changed copies. This edits the chunks and compares them with the copy.
pub struct Snapshot {
    ids: &'static [&'static str],
    originals: Vec<Vec<u8>>,
}

impl Snapshot {
    /// None when a chunk is missing or has the wrong size.
    pub fn take(city: &City, ids: &'static [&'static str]) -> Option<Self> {
        if city.missing_or_resized(ids).is_some() {
            return None;
        }

        let originals = ids.iter().map(|id| city.chunk(id).map(|chunk| chunk.data.clone()).unwrap_or_default()).collect();

        Some(Self { ids, originals })
    }

    pub fn changed(&self, city: &City) -> bool {
        self.ids
            .iter()
            .zip(&self.originals)
            .any(|(id, original)| city.chunk(id).is_some_and(|chunk| chunk.data != *original))
    }

    /// Mark each changed chunk written, as _apply_map_payloads stores it.
    pub fn commit(&self, city: &mut City) {
        for (id, original) in self.ids.iter().zip(&self.originals) {
            if let Some(chunk) = city.chunk_mut(id) {
                chunk.commit_if_changed(original);
            }
        }
    }

    /// Discard the edits, as GDScript discards its copies.
    pub fn restore(&self, city: &mut City) {
        for (id, original) in self.ids.iter().zip(&self.originals) {
            if let Some(chunk) = city.chunk_mut(id) {
                chunk.data.clone_from(original);
            }
        }
    }
}

/// The maps that disaster damage reads and writes, borrowed from one city.
pub struct DisasterMaps<'a> {
    pub maps: Maps<'a>,
    pub traffic: &'a mut [u8],
    pub things: &'a mut [u8],
    pub land_value: &'a mut [u8],
    pub fire_coverage: &'a [u8],
    pub rotation: i64,
    pub damage_class: &'a mut i64,
}

impl City {
    /// Borrow the disaster maps. This does not mark the chunks written.
    pub fn disaster_maps(&mut self) -> DisasterMaps<'_> {
        let rotation = self.compass_rotation();
        let City {
            map_size,
            altm,
            xbld,
            xter,
            xzon,
            xund,
            xbit,
            xtxt,
            xlab,
            xmic,
            misc,
            xthg,
            xtrf,
            xval,
            xfir,
            disaster_damage_class,
            ..
        } = self;

        DisasterMaps {
            maps: Maps {
                map_edge: *map_size,
                altitude: &mut altm.data,
                buildings: &mut xbld.data,
                terrain: &mut xter.data,
                zones: &mut xzon.data,
                underground: &mut xund.data,
                flags: &mut xbit.data,
                text_overlays: &mut xtxt.data,
                labels: &mut xlab.data,
                microsims: &mut xmic.data,
                misc: &mut misc.data,
            },
            traffic: &mut xtrf.data,
            things: &mut xthg.data,
            land_value: &mut xval.data,
            fire_coverage: &xfir.data,
            rotation,
            damage_class: disaster_damage_class,
        }
    }
}

/// DisasterDamage.RuntimeEvents.
#[derive(Default)]
pub struct RuntimeEvents {
    pub effect_events: Vec<EffectEvent>,
    pub sound_events: Vec<i64>,
    pub next_effect_frame: i64,
}

/// DisasterMapState._index and DisasterStartObjectsState._index. -1 is outside.
#[inline]
pub fn index(point: Vec2i, map_edge: i64) -> i64 {
    if point.x < 0 || point.y < 0 || point.x >= map_edge || point.y >= map_edge {
        return -1;
    }

    point.x * map_edge + point.y
}

#[inline]
pub fn altitude_word(altitude: &[u8], index: i64) -> i64 {
    ((altitude[(index * 2) as usize] as i64) << 8) | altitude[(index * 2 + 1) as usize] as i64
}

pub fn sounds(ids: &[i64]) -> Vec<SoundEvent> {
    ids.iter().map(|id| SoundEvent::new(*id)).collect()
}

gd_phase_result! {
    pub struct DisasterMapResult as "DisasterMapResult" {
        pub active: bool = false,
        pub map_counter: i64 = 0,
        pub hurricane_counter: i64 = 0,
        pub map_changed: bool = false,
        pub disaster_type: i64 = 0,
        pub ended_type: i64 = 0,
        pub counters: OrderedMap<i64> = OrderedMap::new(),
        pub active_markers: OrderedMap<bool> = OrderedMap::new(),
        pub dispatch_map: Option<Box<DisasterMapResult>> = None,
    }
}

gd_object! {
    pub struct MaxisManArrival as "DisasterStartResult.MaxisManArrival" {
        pub record: i64 = 0,
        pub point: Vec2i = Vec2i::ZERO,
        pub target: Vec2i = Vec2i::ZERO,
        pub goal: i64 = 0,
    }
}

gd_phase_result! {
    pub struct DisasterStartResult as "DisasterStartResult" {
        pub disaster_type: i64 = 0,
        pub point: Vec2i = Vec2i::ZERO,
        pub started: bool = false,
        pub implemented: bool = false,
        pub record: i64 = 0,
        pub map_counter: i64 = 0,
        pub hurricane_counter: i64 = 0,
        pub map_changed: bool = false,
        pub plant_point: Vec2i = Vec2i::ZERO,
        pub plant_site: Rect2i = Rect2i::default(),
        pub path_finish: Vec2i = Vec2i::ZERO,
        pub requested_point: Vec2i = Vec2i::ZERO,
        pub scan_finish: Vec2i = Vec2i::ZERO,
        pub direction: i64 = 0,
        pub terrain_indices: Ints32 = Ints32::default(),
        pub result_codes: Ints32 = Ints32::default(),
        pub seed_points: Vec<Vec2i> = Vec::new(),
        pub candidate_points: Vec<Vec2i> = Vec::new(),
        pub damage_points: Vec<Vec2i> = Vec::new(),
        pub flood_points: Vec<Vec2i> = Vec::new(),
        pub accepted_points: Vec<Vec2i> = Vec::new(),
        pub counters: OrderedMap<i64> = OrderedMap::new(),
        pub maxis_man_response: Option<MaxisManArrival> = None,
    }
}
