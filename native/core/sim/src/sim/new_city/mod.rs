//! New-city terrain: the 128 by 128 landform and its features. `generate`
//! makes the landform and hands it to `tools::new_terrain`, which scales it to
//! the map, grades it, retiles the terrain, grows trees, and runs the streams.
//!
//! This replaced NewCityTerrain, NewTerrainHeights, TerrainFeatures,
//! TerrainElevation and TerrainLakes of the scripts. The landform must stay
//! equal to theirs; `gd.rs` repeats their number rules and `noise.rs` repeats
//! Godot's noise.

pub mod elevation;
pub mod features;
pub mod gd;
pub mod heights;
pub mod noise;
pub mod setup;
pub mod template;

#[cfg(test)]
mod tests;

use crate::formats::document::Document;
use crate::formats::sc2;
use crate::sim::city::{CHUNK_IDS, City};
use crate::sim::random::{GameLcgRandom, SimRandom};
use crate::sim::tools::new_terrain::{self, Landform, TerrainSummary};

pub const LAYOUTS: [&str; 19] = [
    "classic",
    "meander",
    "delta",
    "peninsula",
    "crossing",
    "branch",
    "rejoin",
    "bay",
    "island",
    "islands",
    "plateau",
    "ridge",
    "valley",
    "rolling",
    "basin",
    "canyon",
    "cliffs",
    "lake",
    "lakes",
];

/// River features that a canyon replaces.
const RIVER_FEATURES: [&str; 6] = ["meander", "delta", "crossing", "branch", "rejoin", "valley"];

pub const MIN_SLIDER: i64 = 0;
pub const MAX_SLIDER: i64 = 47;

/// The chunks that the terrain writes, which must have their decoded sizes.
const REQUIRED_CHUNKS: [&str; 7] = ["ALTM", "XTER", "XBLD", "XZON", "XBIT", "XTXT", "MISC"];

/// The New City terrain options.
#[derive(Clone, Debug, Default)]
pub struct Options {
    pub ocean: bool,
    pub river: bool,
    pub hills: i64,
    pub water: i64,
    pub trees: i64,
    pub layout: String,
    pub features: Vec<String>,
    pub smooth_slopes: bool,
}

/// The settings that the terrain used, and its counts.
#[derive(Clone, Debug, Default, PartialEq, Eq)]
pub struct Generated {
    pub has_ocean: bool,
    pub has_river: bool,
    pub water_level: i64,
    pub summary: TerrainSummary,
}

/// An island map has ocean on all four sides.
pub fn is_island(layout: &str, features: &[String]) -> bool {
    ["island", "islands"].contains(&layout) || features.iter().any(|feature| feature == "island" || feature == "islands")
}

/// Make the terrain of `city`. `process` and `game` advance as the original
/// generators do. The written chunks are ALTM, XTER, XBLD, XZON, XBIT, and MISC.
pub fn generate(city: &mut City, options: &Options, process: &mut SimRandom, game: &mut GameLcgRandom) -> Result<Generated, String> {
    if !LAYOUTS.contains(&options.layout.as_str()) {
        return Err("unknown terrain layout".into());
    }

    let mut selected = options.features.clone();

    if options.layout != "classic" && !selected.contains(&options.layout) {
        selected.push(options.layout.clone());
    }

    if selected
        .iter()
        .any(|feature| !LAYOUTS.contains(&feature.as_str()) || feature == "classic")
    {
        return Err("unknown terrain feature".into());
    }

    let has = |list: &[String], feature: &str| list.iter().any(|name| name == feature);

    if has(&selected, "canyon") {
        for river_feature in RIVER_FEATURES {
            // the scripts erase the first occurrence
            if let Some(position) = selected.iter().position(|name| name == river_feature) {
                selected.remove(position);
            }
        }
    }

    let extended = !selected.is_empty() || (options.smooth_slopes && options.ocean && options.river);
    let island = is_island(&options.layout, &selected);
    let ocean_requested = options.ocean || has(&selected, "delta") || has(&selected, "peninsula") || has(&selected, "cliffs");
    let has_ocean = ocean_requested || island || has(&selected, "bay");
    let has_river = !island
        && !has(&selected, "canyon")
        && (options.river
            || ["valley", "delta", "meander", "crossing", "branch", "rejoin"]
                .iter()
                .any(|name| has(&selected, name)));

    if [options.hills, options.water, options.trees]
        .iter()
        .any(|value| !(MIN_SLIDER..=MAX_SLIDER).contains(value))
    {
        return Err("terrain sliders must be between 0 and 47".into());
    }

    for id in REQUIRED_CHUNKS {
        let size = sc2::decoded_size(id, city.map_size, city.large_version);

        if city.chunk(id).is_none_or(|chunk| chunk.data.len() as i64 != size) {
            return Err(format!("required {id} data is missing or invalid"));
        }
    }

    let mut staged_process = SimRandom::new(process.state);
    let mut staged_game = GameLcgRandom::new(game.state);

    // one original-size landform. The map stage scales it, so larger maps do
    // not gain extra basins
    let cells = (heights::EDGE * heights::EDGE) as usize;
    let mut landform_heights = vec![0_i32; cells];
    let mut coast_flags = vec![0_u8; cells];

    heights::seed_hills(&mut landform_heights, options.hills + 11, &mut staged_process);

    for (step, mask) in heights::INTERPOLATION_PASSES {
        heights::interpolate(
            &mut landform_heights,
            step,
            mask,
            options.hills + 10,
            has_ocean && !extended,
            &mut staged_process,
        );
    }

    let mut water_level = (options.water + 4) >> 3;

    if has_ocean || has_river || has(&selected, "lake") || has(&selected, "lakes") {
        water_level = water_level.max(4);
    }

    if has_ocean && !extended {
        heights::carve_ocean(&mut landform_heights, &mut coast_flags, water_level, &mut staged_game);
    }

    if has_river && !extended {
        heights::carve_river(&mut landform_heights, water_level, &mut staged_game);
    }

    heights::smooth(&mut landform_heights);
    heights::smooth(&mut landform_heights);
    heights::scale(&mut landform_heights);
    heights::smooth(&mut landform_heights);

    if extended {
        let carve = features::Carve {
            sea: water_level,
            features: &selected,
            ocean: ocean_requested,
            river: has_river,
            water: options.water,
            hills: options.hills,
        };

        features::carve(&mut landform_heights, &mut coast_flags, &carve, &mut staged_game);
    }

    let landform = Landform {
        heights: landform_heights,
        coast_flags,
        extended,
        smooth_slopes: options.smooth_slopes,
        has_ocean,
        has_river,
        water_level,
        water: options.water,
        trees: options.trees,
    };

    let summary = new_terrain::generate(city, &landform, &mut staged_process);
    process.state = staged_process.state;
    game.state = staged_game.state;

    Ok(Generated {
        has_ocean,
        has_river,
        water_level,
        summary,
    })
}

/// The chunks of `document` that the simulation reads, as a city.
pub fn city_of(document: &Document) -> City {
    let mut city = City::new(document.map_size, document.large_version);

    for id in CHUNK_IDS {
        if let (Some(chunk), Some(slot)) = (document.find(id), city.chunk_slot_mut(id)) {
            slot.present = true;
            slot.data = chunk.decoded.clone();
        }
    }

    city
}

/// The chunks that New City terrain writes.
pub const WRITTEN_CHUNKS: [&str; 6] = ["ALTM", "XTER", "XBLD", "XZON", "XBIT", "MISC"];

/// Generate the terrain of `document` in place.
pub fn generate_document(
    document: &mut Document,
    options: &Options,
    process: &mut SimRandom,
    game: &mut GameLcgRandom,
) -> Result<Generated, String> {
    let mut city = city_of(document);
    let generated = generate(&mut city, options, process, game)?;

    for id in WRITTEN_CHUNKS {
        let data = city.chunk(id).map(|chunk| chunk.data.clone()).unwrap_or_default();

        if !document.find_mut(id).is_some_and(|chunk| chunk.set_decoded(data)) {
            return Err(format!("cannot store generated {id} data"));
        }
    }

    Ok(generated)
}

/// The settings of a New City preview: the map, the terrain, and the random
/// states that the preview starts from.
#[derive(Clone, Debug, Default)]
pub struct Preview {
    pub size: i64,
    pub native_maps: bool,
    pub terrain: Options,
    pub process_start: i64,
    pub game_start: i64,
}

/// The preview city of NewCityTerrainSession: an empty city, its neighbors, and
/// its terrain. Returns the document and the random states after it.
pub fn preview(settings: &Preview) -> Result<(Document, Generated, i64, i64), String> {
    if !sc2::MAP_SIZES.contains(&settings.size) {
        return Err("Unsupported city size".into());
    }

    let mut document = template::empty_city(settings.size);

    if settings.native_maps && !document.enable_full_resolution_maps() {
        return Err("Cannot enable per-tile data maps".into());
    }

    let mut process = SimRandom::new(settings.process_start);
    let mut game = GameLcgRandom::new(settings.game_start);

    // the original draws the neighbors before it makes the terrain
    template::draw_neighbors(&mut document, &mut process);
    let generated = generate_document(&mut document, &settings.terrain, &mut process, &mut game)?;

    Ok((document, generated, process.state, game.state))
}
