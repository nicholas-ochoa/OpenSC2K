//! Facility record repair on activation, as FacilityRecordRepair. An SC2X city
//! can hold facility buildings without records; each one gets its record and
//! its label links. Parsing and simulation snapshots keep the saved bytes.

use std::collections::HashSet;

use super::facilities::{self, DYNAMIC_FIRST, Provision, microsim_type};
use crate::gd_object;
use crate::sim::city::City;
use crate::sim::geom::Rect2i;
use crate::sim::ids::building_tile_ids as tiles;
use crate::sim::ids::sc2microsim_layout::RECORD_SIZE;
use crate::sim::ids::sc2thing_layout as thing_layout;
use crate::sim::ids::sc2zone_layout as zone;
use crate::sim::overlay;
use crate::sim::random::SimRandom;
use crate::sim::things;
use crate::sim::tools::CORNER_BOTTOM_LEFT;
use crate::sim::tools::demolish::{building_area, site_matches};

/// The highest microsimulation type with one record per facility.
const LAST_INDIVIDUAL_TYPE: i64 = 16;

gd_object! {
    pub struct RepairResult as "FacilityRecordRepair.Result" {
        pub ok: bool = false,
        pub error: String = String::new(),
        pub created: i64 = 0,
        pub linked: i64 = 0,
        pub unfilled: i64 = 0,
    }
}

/// Where a facility label goes: a tile of XTXT, or a label field of a thing
/// record that stands on the tile.
#[derive(Clone, Copy, PartialEq)]
enum Target {
    Overlay(i64),
    Thing(i64),
}

/// FacilityRecordRepair.apply.
pub fn apply(city: &mut City) -> RepairResult {
    let mut result = RepairResult {
        ok: true,
        ..Default::default()
    };

    if !city.is_extended() {
        return result;
    }

    for id in ["XMIC", "XLAB", "XTHG", "MISC"] {
        if city.missing_or_resized(&[id]).is_some() {
            return RepairResult {
                error: format!("Cannot repair facility records: {id} is missing or invalid."),
                ..Default::default()
            };
        }
    }

    // Local, repeatable initialization must not use the simulation generator.
    let mut random = SimRandom::new(1);
    let edge = city.map_size;
    let rotation = city.compass_rotation();
    let year = city.current_year();
    let record_count = city.xmic.data.len() as i64 / RECORD_SIZE;
    let record_budget = facilities::individual_record_budget(city);
    let misc = city.misc.data.clone();
    let mut active = facilities::active_individual_records(&city.xmic.data);
    let mut next_free = DYNAMIC_FIRST;
    let mut rebuilt_shared = HashSet::new();

    for origin in facility_tiles(&city.xbld.data) {
        let (x, y) = (origin / edge, origin % edge);
        let tile = city.xbld.data[origin as usize] as i64;
        let kind = microsim_type(tile);
        let area = building_area(tile);
        let site = Rect2i::new(x, y, area, area);

        if site.end().x > edge || site.end().y > edge {
            continue;
        }

        // The origin of a larger building holds its first corner flag. This
        // quick test gives the same answer as the full site match.
        let corner = city.xzon.data[origin as usize] as i64 & zone::CORNERS_MASK;

        if area > 1
            && (corner != CORNER_BOTTOM_LEFT[(rotation & 3) as usize]
                || !site_matches(&city.xbld.data, &city.xzon.data, site, tile, rotation, edge))
        {
            continue;
        }

        let mut targets = Vec::new();
        let mut has_record = false;
        let mut blocked = false;

        for sx in x..site.end().x {
            for sy in y..site.end().y {
                let index = sx * edge + sy;
                let target = overlay_target(&city.xtxt.data, &city.xthg.data, index, edge);
                let mut existing = match target {
                    Some(Target::Overlay(at)) => overlay::read(&city.xtxt.data, at),
                    Some(Target::Thing(offset)) => things::read(&city.xthg.data, offset),
                    None => -1,
                };

                // In a layered index the facility layer, else a marker, blocks.
                if overlay::is_layered(&city.xtxt.data) {
                    existing = overlay::facility(&city.xtxt.data, index);

                    if existing == 0 {
                        existing = overlay::marker(&city.xtxt.data, index);
                    }
                }

                if overlay::is_facility(existing) {
                    let record = overlay::facility_record(existing);
                    let saved = if record < record_count {
                        city.xmic.data[(record * RECORD_SIZE) as usize] as i64
                    } else {
                        0
                    };

                    has_record |=
                        saved == tile || (kind > LAST_INDIVIDUAL_TYPE && saved != tiles::EMPTY && record == kind - LAST_INDIVIDUAL_TYPE);
                }

                match (existing, target) {
                    (0, Some(target)) => targets.push(target),
                    _ => blocked = true,
                }
            }
        }

        // Keep existing links, signs, disaster markers, and unclear data.
        if has_record || blocked {
            continue;
        }

        let mut record = kind - LAST_INDIVIDUAL_TYPE;
        let mut initialize = kind <= LAST_INDIVIDUAL_TYPE;

        if kind <= LAST_INDIVIDUAL_TYPE {
            while next_free < record_count && city.xmic.data[(next_free * RECORD_SIZE) as usize] != 0 {
                next_free += 1;
            }

            if next_free == record_count || (record_budget >= 0 && active >= record_budget) {
                result.unfilled += 1;
                continue;
            }

            record = next_free;
            active += 1;
        } else {
            let offset = (record * RECORD_SIZE) as usize;

            if city.xmic.data[offset] == 0 {
                rebuilt_shared.insert(record);
                city.xmic.data[offset..offset + RECORD_SIZE as usize].fill(0);
            }

            initialize = rebuilt_shared.contains(&record);
        }

        let id = overlay::facility_id(record);

        if initialize {
            if city.xmic.data[(record * RECORD_SIZE) as usize] == 0 {
                result.created += 1;
            }

            let request = Provision {
                tile,
                current_year: year,
                misc: &misc,
                australian_locale: false,
                scurk_place_mode: false,
                record_budget: -1,
                first_free: next_free,
            };

            facilities::provision_microsim(&mut city.xmic.data, &mut city.xlab.data, &mut city.xtxt.data, &request, &mut random);
        }

        for target in targets {
            match target {
                Target::Overlay(at) => overlay::write(&mut city.xtxt.data, at, id),
                Target::Thing(offset) => things::write(&mut city.xthg.data, offset, id),
            }
        }

        result.linked += 1;
    }

    result
}

/// Ascending indices of every tile that holds a facility building.
fn facility_tiles(buildings: &[u8]) -> Vec<i64> {
    let mut result: Vec<i64> = buildings
        .iter()
        .enumerate()
        .filter(|(_, tile)| microsim_type(**tile as i64) != 0)
        .map(|(index, _)| index as i64)
        .collect();

    result.sort_unstable();
    result
}

/// FacilityRecordRepair._overlay_target: the tile, or the label field of the
/// thing records that stand on it. None when a thing record is broken.
fn overlay_target(text: &[u8], things_data: &[u8], index: i64, edge: i64) -> Option<Target> {
    let mut id = overlay::read(text, index);

    if !overlay::is_thing(id) || overlay::is_layered(text) {
        return Some(Target::Overlay(index));
    }

    let mut target = Target::Overlay(index);
    let mut visited = HashSet::new();

    while overlay::is_thing(id) {
        let record = overlay::thing_record(id);

        if record <= 0 || record >= things::count(things_data) || !visited.insert(record) {
            return None;
        }

        let offset = record * thing_layout::RECORD_SIZE;

        if things::read(things_data, offset) == 0
            || things::read(things_data, offset + thing_layout::FIELD_X) != index / edge
            || things::read(things_data, offset + thing_layout::FIELD_Y) != index % edge
        {
            return None;
        }

        target = Target::Thing(offset + thing_layout::FIELD_LABEL);
        id = things::read(things_data, offset + thing_layout::FIELD_LABEL);
    }

    Some(target)
}
