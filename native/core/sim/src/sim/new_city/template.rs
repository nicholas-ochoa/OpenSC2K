//! The empty city that New City starts from, and its neighbors. This is
//! EmptyCityTemplate and NewCitySetup.draw_neighbors of the scripts.

use crate::formats::document::{Chunk, Document};
use crate::formats::sc2::{self, RAW_CHUNKS};
use crate::sim::ids::{sc2budget_layout as budget, sc2industry_layout as industry, sc2misc_layout as misc};
use crate::sim::random::SimRandom;

/// The chunks of an empty city, in the order of the template.
const CHUNKS: [&str; 21] = [
    "CNAM", "MISC", "ALTM", "XTER", "XBLD", "XZON", "XUND", "XTXT", "XLAB", "XMIC", "XTHG", "XBIT", "XTRF", "XPLT", "XVAL", "XCRM", "XPLC",
    "XFIR", "XPOP", "XROG", "XGRP",
];

/// The rate of growth map of a new city holds this neutral value.
pub const NEUTRAL_GROWTH: u8 = 0x7f;

/// The neighbor names of the original, in name index order from 1.
pub const NEIGHBOR_NAMES: [&str; 36] = [
    "Oak Creek",
    "Denmont",
    "Fort Verdegris",
    "Schwinton",
    "Mill Valley",
    "Petaluma",
    "PortVille",
    "Ashland",
    "Eubancs",
    "Aurac",
    "Tent Pegs",
    "Cherryton",
    "Blake",
    "Pioneers",
    "Fortune",
    "Phippsville",
    "Jeromi",
    "Harpersville",
    "Washers Grove",
    "Stars County",
    "Villa",
    "Serviland",
    "Newton",
    "Avon",
    "Dexter",
    "Sinistrel",
    "Jenna",
    "Yestonia",
    "New Boots",
    "Hoek Creek",
    "Stimpleton",
    "Little Rouge",
    "Krighton",
    "Cats Corner",
    "Rimmer",
    "Lister",
];

pub const NEIGHBOR_COUNT: i64 = 4;
pub const NEIGHBOR_STRIDE: i64 = 0x10;
pub const NEIGHBOR_POPULATION: i64 = 4;
pub const NEIGHBOR_VALUE: i64 = 8;
pub const NEIGHBOR_FAME: i64 = 12;
const NEIGHBOR_MIN_POPULATION: i64 = 100;
const NEIGHBOR_POPULATION_RANGE: i64 = 7400;
const NEIGHBOR_VALUE_DIVISORS: i64 = 3;

/// The MISC version word of a city that the Windows game saves.
const MISC_VERSION: u32 = 0x122;
const TEMPLATE_NAME: &str = "New City";
const INDUSTRY_TAX_RATE: u32 = 7;

/// The independent starting policy of an empty city. New City then sets the
/// difficulty and year values.
const MISC_VALUES: [(i64, u32); 17] = [
    (misc::CITY_MODE, 1),
    (misc::START_YEAR, 1900),
    (misc::FUNDS, 20000),
    (misc::DIFFICULTY, 1),
    (misc::NATIONAL_POPULATION, 10000),
    (misc::NATIONAL_VALUE, 3000),
    (misc::NATIONAL_FEDERAL_RATE, 3),
    (misc::WEATHER_HEAT, 150),
    (misc::WEATHER_WIND, 10),
    (misc::WEATHER_RAIN, 15),
    (misc::WEATHER_TREND, 4),
    (misc::SIMULATION_SPEED, 2),
    (misc::AUTO_GOTO, 1),
    (misc::SOUND, 1),
    (misc::MUSIC, 1),
    (misc::NEWSPAPER_EXTRAS, 1),
    (0, MISC_VERSION),
];

/// An empty original city of `edge` tiles with the starting values.
pub fn empty_city(edge: i64) -> Document {
    let mut document = Document::default();

    for id in CHUNKS {
        let size = sc2::decoded_size(id, sc2::ORIGINAL_EDGE, sc2::ORIGINAL_LARGE_VERSION);
        let mut chunk = Chunk::new(id, Vec::new(), size);
        chunk.compressed = !RAW_CHUNKS.contains(&id);
        chunk.set_decoded(vec![0; size as usize]);
        document.chunks.push(chunk);
    }

    for (offset, value) in MISC_VALUES {
        document.set_misc_u32(offset, value);
    }

    document.set_misc_u32(misc::TILE_COUNTS, (edge * edge) as u32);

    for record in 0..industry::COUNT {
        document.set_misc_u32(
            misc::INDUSTRIES + record * industry::RECORD_SIZE + industry::TAX_RATE,
            INDUSTRY_TAX_RATE,
        );
    }

    for record in 0..budget::COUNT {
        let funding = match record {
            0..=2 => 7,
            3 => 1,
            4 => 0,
            _ => 100,
        };

        let offset = misc::BUDGETS + record * budget::RECORD_SIZE;
        document.set_misc_u32(offset + budget::FUNDING, funding);

        // the original also stores the rate as the first month of history
        document.set_misc_u32(offset + budget::MONTHS + budget::MONTH_FUNDING, funding);
    }

    // a new city draws its own neighbors. These fixed ones are never the ocean
    draw_neighbors(&mut document, &mut SimRandom::new(1));

    document.set_city_name(TEMPLATE_NAME);
    document.resize_empty_map(edge);
    fill_neutral_growth(&mut document);

    document
}

/// FUN_0040e250 fills the rate of growth map with the neutral value.
pub fn fill_neutral_growth(document: &mut Document) {
    if let Some(chunk) = document.find_mut("XROG") {
        let size = chunk.expected_size.max(0) as usize;
        chunk.set_decoded(vec![NEUTRAL_GROWTH; size]);
    }
}

/// FUN_0040e250: four different random neighbor names, each with a population
/// that is the smallest of three draws and a value of 1/1, 1/2, or 1/3 of it.
pub fn draw_neighbors(document: &mut Document, random: &mut SimRandom) {
    let names = NEIGHBOR_NAMES.len() as i64;
    let mut chosen: Vec<i64> = Vec::new();

    for slot in 0..NEIGHBOR_COUNT {
        let mut name = random.next_u15() % names + 1;

        while chosen.contains(&name) {
            name = random.next_u15() % names + 1;
        }

        chosen.push(name);
        let mut population = random.next_u15() % NEIGHBOR_POPULATION_RANGE + NEIGHBOR_MIN_POPULATION;

        for _ in 0..2 {
            population = population.min(random.next_u15() % NEIGHBOR_POPULATION_RANGE + NEIGHBOR_MIN_POPULATION);
        }

        let value = population / (random.next_u15() % NEIGHBOR_VALUE_DIVISORS + 1);
        let offset = misc::NEIGHBORS + slot * NEIGHBOR_STRIDE;
        document.set_misc_u32(offset, name as u32);
        document.set_misc_u32(offset + NEIGHBOR_POPULATION, population as u32);
        document.set_misc_u32(offset + NEIGHBOR_VALUE, value as u32);
        document.set_misc_u32(offset + NEIGHBOR_FAME, 0);
    }
}
