//! Founding a new city: the starting funds, bonds, national values, invention
//! years, founding newspaper and graph history. This is NewCitySetup.create of
//! the scripts.

use super::template::{NEIGHBOR_COUNT, NEIGHBOR_FAME, NEIGHBOR_POPULATION, NEIGHBOR_STRIDE, NEIGHBOR_VALUE, draw_neighbors};
use super::{Generated, Options, generate_document, is_island};
use crate::formats::document::{Document, ascii_byte};
use crate::formats::sc2x::labels;
use crate::sim::bytes::{read_u32_be, write_u32_be};
use crate::sim::ids::{sc2budget_layout as budget, sc2graph_layout as graph, sc2label_layout, sc2misc_layout as misc};
use crate::sim::random::{GameLcgRandom, SimRandom};
use crate::sim::reports::news;

pub const STARTING_YEARS: [i64; 4] = [1900, 1950, 2000, 2050];
const NATIONAL_POPULATIONS: [i64; 4] = [10000, 25000, 60000, 150000];

/// The 17 invention years at SIMCITY.EXE 0x004e99e8.
const INVENTION_BASE_YEARS: [i64; 17] = [
    1940, 1950, 1980, 1970, 2020, 2050, 1920, 1920, 1910, 1900, 1925, 1980, 1990, 2040, 2090, 2140, 2190,
];
const INVENTION_SPREAD: i64 = 20;

const MAX_BONDS: i64 = 50;
const HARD_BOND_RATE: u32 = 3;
const HARD_BOND_AMOUNT: u32 = 30000;
const FEDERAL_RATE: u32 = 3;
const FOUNDING_STORY_TYPE: i64 = 2;
const GRAPH_GNP: i64 = 13;
const GRAPH_NATIONAL_POPULATION: i64 = 14;
const DEFAULT_CITY_NAME: &str = "New City";
const DEFAULT_MAYOR_NAME: &str = "Mayor";

/// The settings of a new city.
#[derive(Clone, Debug, Default)]
pub struct Founding {
    pub city_name: String,
    pub mayor_name: String,
    pub difficulty: i64,
    pub starting_year: i64,
    /// New terrain. `None` keeps the terrain of the template.
    pub terrain: Option<Options>,
    /// The MISC newspaper papers and stories of the session, or empty.
    pub newspaper_session: Vec<u8>,
    pub island: bool,
}

#[derive(Clone, Debug, Default)]
pub struct Founded {
    pub document: Document,
    pub city_name: String,
    pub mayor_name: String,
    pub invention_years: Vec<i64>,
    pub terrain: Option<Generated>,
}

/// Found a city from `template`. The random generators advance only when the
/// city is founded.
pub fn create(
    template: &Document,
    founding: &Founding,
    random: &mut SimRandom,
    game: Option<&mut GameLcgRandom>,
) -> Result<Founded, String> {
    if !(1..=3).contains(&founding.difficulty) {
        return Err("difficulty must be Easy, Medium, or Hard".into());
    }

    let Some(year_index) = STARTING_YEARS.iter().position(|year| *year == founding.starting_year) else {
        return Err("starting year must be 1900, 1950, 2000, or 2050".into());
    };

    if founding.terrain.is_some() && game.is_none() {
        return Err("terrain game-random state is missing".into());
    }

    if !founding.newspaper_session.is_empty() && founding.newspaper_session.len() as i64 != misc::SIZE {
        return Err("newspaper session state has the wrong size".into());
    }

    if template.find("MISC").is_none_or(|chunk| chunk.decoded.len() as i64 != misc::SIZE) {
        return Err("default MISC data is missing or invalid".into());
    }

    if template.find("XGRP").is_none_or(|chunk| chunk.decoded.len() as i64 != graph::SIZE) {
        return Err("default XGRP data is missing or invalid".into());
    }

    if template.find("CNAM").is_none() || template.find("XLAB").is_none() {
        return Err("default name data is missing".into());
    }

    let mut document = template.clone();
    let city_name = default_name(&founding.city_name, DEFAULT_CITY_NAME);
    let mayor_name = default_name(&founding.mayor_name, DEFAULT_MAYOR_NAME);

    if !document.set_city_name(&city_name) {
        return Err("cannot store the city name".into());
    }

    if !set_mayor_label(&mut document, &mayor_name) {
        return Err("cannot store the mayor name".into());
    }

    let mut staged_random = SimRandom::new(random.state);
    let mut staged_game = game.as_ref().map(|game| GameLcgRandom::new(game.state));
    let mut island = founding.island;
    let mut terrain = None;

    if let (Some(options), Some(staged_game)) = (&founding.terrain, staged_game.as_mut()) {
        // the original draws the neighbors before it makes the terrain
        draw_neighbors(&mut document, &mut staged_random);
        island = island || is_island(&options.layout, &options.features);

        let generated = generate_document(&mut document, options, &mut staged_random, staged_game)
            .map_err(|error| format!("cannot generate terrain: {error}"))?;
        terrain = Some(generated);
    }

    let mut data = document.payload("MISC").to_vec();
    let national_population = NATIONAL_POPULATIONS[year_index];
    write_u32_be(&mut data, misc::CITY_MODE, 1);
    write_u32_be(&mut data, misc::START_YEAR, founding.starting_year);
    write_u32_be(&mut data, misc::FUNDS, if founding.difficulty == 1 { 20000 } else { 10000 });
    write_u32_be(&mut data, misc::BONDS, 0);
    write_u32_be(&mut data, misc::DIFFICULTY, founding.difficulty);
    write_u32_be(&mut data, misc::NATIONAL_POPULATION, national_population);
    write_u32_be(&mut data, misc::NATIONAL_FEDERAL_RATE, i64::from(FEDERAL_RATE));
    write_u32_be(&mut data, misc::NATIONAL_ECONOMY_TREND, founding.difficulty - 1);

    for bond in 0..MAX_BONDS {
        write_u32_be(&mut data, misc::BOND_RATES + bond * 4, 0);
    }

    let bond_budget = (misc::BUDGETS + budget::BONDS * budget::RECORD_SIZE) as usize;
    data[bond_budget..bond_budget + budget::RECORD_SIZE as usize].fill(0);

    if founding.difficulty == 3 {
        let bonds = bond_budget as i64;
        write_u32_be(&mut data, misc::BONDS, 1);
        write_u32_be(&mut data, misc::BOND_RATES, i64::from(HARD_BOND_RATE));
        write_u32_be(&mut data, bonds + budget::CURRENT, 1);
        write_u32_be(&mut data, bonds + budget::FUNDING, i64::from(HARD_BOND_AMOUNT));
        write_u32_be(&mut data, bonds + budget::YEAR_TO_DATE, i64::from(HARD_BOND_AMOUNT));
        write_u32_be(&mut data, bonds + budget::MONTHS, 1);
        write_u32_be(
            &mut data,
            bonds + budget::MONTHS + budget::MONTH_FUNDING,
            i64::from(HARD_BOND_AMOUNT),
        );
    }

    set_ocean_neighbors(&mut data, island);

    if !founding.newspaper_session.is_empty() {
        let papers = misc::PAPERS as usize;
        let paper_bytes = (news::PAPER_COUNT * news::PAPER_RECORD_SIZE) as usize;
        data[papers..papers + paper_bytes].copy_from_slice(&founding.newspaper_session[papers..papers + paper_bytes]);

        let stories = misc::STORIES as usize;
        let story_bytes = (news::STORY_RECORD_COUNT * news::STORY_RECORD_SIZE) as usize;
        data[stories..stories + story_bytes].copy_from_slice(&founding.newspaper_session[stories..stories + story_bytes]);
    }

    let mut invention_years = Vec::with_capacity(INVENTION_BASE_YEARS.len());

    for (index, base) in INVENTION_BASE_YEARS.iter().enumerate() {
        let mut year = base + staged_random.next_u15() % INVENTION_SPREAD;

        if year < founding.starting_year {
            year = 0;
        }

        invention_years.push(year);
        write_u32_be(&mut data, misc::INVENTION_YEARS + index as i64 * 4, year);
    }

    news::insert(&mut data, FOUNDING_STORY_TYPE, 0).map_err(|error| format!("cannot initialize the founding newspaper: {error}"))?;

    if !document.find_mut("MISC").is_some_and(|chunk| chunk.set_decoded(data)) {
        return Err("cannot store new-city settings".into());
    }

    let mut history = vec![0_u8; graph::SIZE as usize];
    write_graph_value(&mut history, GRAPH_GNP, 0, i64::from(FEDERAL_RATE));
    write_graph_value(&mut history, GRAPH_NATIONAL_POPULATION, 0, national_population);

    if !document.find_mut("XGRP").is_some_and(|chunk| chunk.set_decoded(history)) {
        return Err("cannot initialize graph history".into());
    }

    random.state = staged_random.state;

    if let (Some(game), Some(staged_game)) = (game, staged_game) {
        game.state = staged_game.state;
    }

    let mayor = labels::read(document.payload("XLAB"), 0, false).unwrap_or_default();

    Ok(Founded {
        city_name: document.city_name(),
        mayor_name: mayor,
        document,
        invention_years,
        terrain,
    })
}

/// Godot's `strip_edges`, or `fallback` for an empty name.
fn default_name(name: &str, fallback: &str) -> String {
    let stripped = crate::formats::sc2x::document::strip_edges(name);

    if stripped.is_empty() { fallback.into() } else { stripped.into() }
}

/// Label 0 of an original city: a length byte, up to 23 ASCII bytes and a
/// terminator. The bytes after the terminator stay, as the original label
/// editor keeps them.
fn set_mayor_label(document: &mut Document, name: &str) -> bool {
    let expected = document.decoded_size("XLAB");

    let Some(chunk) = document.find_mut("XLAB") else {
        return false;
    };

    if chunk.decoded.len() as i64 != expected || chunk.decoded.len() < sc2label_layout::RECORD_SIZE as usize {
        return false;
    }

    let text: Vec<u8> = name
        .chars()
        .map(ascii_byte)
        .take(sc2label_layout::MAX_TEXT_BYTES as usize)
        .collect();
    let mut changed = chunk.decoded.clone();
    changed[0] = text.len() as u8;
    changed[1..1 + text.len()].copy_from_slice(&text);
    changed[1 + text.len()] = 0;

    chunk.set_decoded(changed)
}

/// FUN_0042e460 makes the first neighbor the ocean on an ocean map. An island
/// map has the ocean on all sides.
fn set_ocean_neighbors(data: &mut [u8], island: bool) {
    if read_u32_be(data, misc::HAS_OCEAN) == 0 {
        return;
    }

    let slots = if island { NEIGHBOR_COUNT } else { 1 };

    for slot in 0..slots {
        let offset = misc::NEIGHBORS + slot * NEIGHBOR_STRIDE;

        for field in [0, NEIGHBOR_POPULATION, NEIGHBOR_VALUE, NEIGHBOR_FAME] {
            write_u32_be(data, offset + field, 0);
        }
    }
}

fn write_graph_value(data: &mut [u8], series: i64, index: i64, value: i64) {
    write_u32_be(data, (series * graph::VALUES_PER_SERIES + index) * graph::VALUE_SIZE, value);
}
