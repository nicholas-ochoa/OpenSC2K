//! Test cities and scripted random generators.

use super::city::{CHUNK_IDS, Chunk, City};
use super::ids::sc2misc_layout as misc_layout;
use super::random::{GameLcgRandom, GameRandomScript, LfsrRandomScript, SimLfsrRandom, SimRandom, SimRandomScript};

/// An empty city with each chunk at its decoded size, as EmptyCityTemplate.create.
/// A 128-tile map is an SC2 city. A larger map is an SC2X version 2 city.
pub fn empty_city(edge: i64) -> City {
    empty_city_version(edge, if edge == 128 { 0 } else { 2 })
}

/// An empty city with per-tile data maps, as Sc2File.enable_full_resolution_maps.
pub fn empty_full_resolution_city(edge: i64) -> City {
    empty_city_version(edge, 3)
}

/// An empty SC2X version 4 working city with the record capacities of its map profile.
pub fn empty_sc2x_city(edge: i64) -> City {
    let profile = crate::formats::sc2x::limits::profile_for(edge as usize).expect("an SC2X profile");
    let mut city = empty_city_version(edge, 4);
    city.xtxt = Chunk::new(crate::sim::overlay::layered(edge * edge));
    city.xmic = Chunk::new(vec![0; profile.facilities * 8]);
    city.xthg = Chunk::new(vec![0; profile.things * 24]);
    let last_label = crate::formats::sc2x::project::facility_label(profile.facilities - 1);
    city.xlab = Chunk::new(crate::formats::sc2x::labels::wide_table(last_label));
    city
}

fn empty_city_version(edge: i64, large_version: i64) -> City {
    let mut city = City::new(edge, large_version);

    for id in CHUNK_IDS {
        let size = city.decoded_size(id);

        if size < 0 {
            continue;
        }

        if let Some(chunk) = chunk_slot(&mut city, id) {
            *chunk = Chunk::new(vec![0; size as usize]);
        }
    }

    city.set_misc_u32(misc_layout::CITY_MODE, 1);
    city.set_misc_u32(misc_layout::TILE_COUNTS, edge * edge);
    city.misc.written = false;
    city
}

fn chunk_slot<'a>(city: &'a mut City, id: &str) -> Option<&'a mut Chunk> {
    Some(match id {
        "CNAM" => &mut city.cnam,
        "MISC" => &mut city.misc,
        "ALTM" => &mut city.altm,
        "XTER" => &mut city.xter,
        "XBLD" => &mut city.xbld,
        "XZON" => &mut city.xzon,
        "XUND" => &mut city.xund,
        "XTXT" => &mut city.xtxt,
        "XLAB" => &mut city.xlab,
        "XMIC" => &mut city.xmic,
        "XTHG" => &mut city.xthg,
        "XBIT" => &mut city.xbit,
        "XTRF" => &mut city.xtrf,
        "XPLT" => &mut city.xplt,
        "XVAL" => &mut city.xval,
        "XCRM" => &mut city.xcrm,
        "XPLC" => &mut city.xplc,
        "XFIR" => &mut city.xfir,
        "XPOP" => &mut city.xpop,
        "XROG" => &mut city.xrog,
        "XGRP" => &mut city.xgrp,
        _ => return None,
    })
}

/// A cyclic list of draws, as the Sequence test generators.
#[derive(Clone, Default)]
pub struct Draws {
    values: Vec<i64>,
    position: usize,
}

impl Draws {
    pub fn new(values: &[i64]) -> Self {
        Self {
            values: values.to_vec(),
            position: 0,
        }
    }

    fn next(&mut self) -> i64 {
        let value = self.values[self.position % self.values.len()];
        self.position += 1;
        value
    }
}

impl SimRandomScript for Draws {
    fn next_u15(&mut self) -> i64 {
        self.next()
    }
}

impl LfsrRandomScript for Draws {
    fn next_word(&mut self) -> i64 {
        self.next()
    }

    fn next_mask(&mut self, mask: i64) -> i64 {
        self.next() & mask
    }

    fn next_mod(&mut self, divisor: i64) -> i64 {
        self.next() % divisor
    }
}

impl GameRandomScript for Draws {
    fn next_mod(&mut self, divisor: i64) -> i64 {
        self.next() % divisor
    }
}

/// A SimRandom that returns `values` in turn.
pub fn sequence_random(values: &[i64]) -> SimRandom {
    let mut random = SimRandom::new(1);
    random.script = Some(Box::new(Draws::new(values)));
    random
}

/// A SimLfsrRandom whose draws come from `values` in turn, reduced by the mask or divisor.
pub fn sequence_lfsr(values: &[i64]) -> SimLfsrRandom {
    let mut random = SimLfsrRandom::new(1);
    random.script = Some(Box::new(Draws::new(values)));
    random
}

/// A GameLcgRandom whose draws come from `values` in turn, reduced by the divisor.
pub fn sequence_game(values: &[i64]) -> GameLcgRandom {
    let mut random = GameLcgRandom::new(1);
    random.script = Some(Box::new(Draws::new(values)));
    random
}
