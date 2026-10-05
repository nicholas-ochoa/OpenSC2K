//! SCURK Place & Print objects in a city, as ScurkPlaceCommand. Artwork stamps
//! for tiles above 255 stay in GDScript; they change no chunk.

use super::EditBase;
use super::building::facilities::{self, Provision};
use super::building::{PAYLOAD_IDS, footprint, footprint_is_in_bounds};
use crate::gd_edit_result;
use crate::sim::bytes::{read_u32_be, write_u32_be};
use crate::sim::city::City;
use crate::sim::geom::{Rect2i, Vec2i};
use crate::sim::ids::building_tile_ids as tiles;
use crate::sim::ids::sc2budget_layout as budget_layout;
use crate::sim::ids::sc2misc_layout as misc_layout;
use crate::sim::ids::sc2tile_flags as flag_bits;
use crate::sim::ids::sc2zone_layout as zone;
use crate::sim::ids::terrain_tile_ids as terrain_ids;
use crate::sim::overlay;
use crate::sim::random::SimRandom;
use crate::sim::tools::demolish::building_area;
use crate::sim::tools::network::replace_building;
use crate::sim::tools::{set_corners, underground};
use crate::sim::value::Ints32;

gd_edit_result! {
    pub struct ScurkPlaceResult as "ScurkPlaceResult" {
        pub tile_id: i64 = tiles::EMPTY,
        pub area: i64 = 1,
        pub zone_id: i64 = 0,
        pub overlay_id: i64 = 0,
        pub scurk_place_history: bool = false,
    }
}

/// ScurkPlaceCommand.apply for a tile of the building table. A flipped object
/// sets the XBIT flip flag on each tile, so the painter mirrors its sprite. The
/// lower flag bits stay otherwise.
pub fn apply(
    city: &mut City,
    tile: i64,
    selected: Vec2i,
    random: &mut SimRandom,
    selected_zone: i64,
    australian_locale: bool,
    flipped: bool,
) -> ScurkPlaceResult {
    let edge = city.map_size;
    let area = building_area(tile);
    let site = footprint(selected, area);

    if !footprint_is_in_bounds(site, area, edge, city.is_extended()) {
        return ScurkPlaceResult::rejected("object does not fit inside the map", 0);
    }

    if city.missing_or_resized(&PAYLOAD_IDS).is_some() {
        return ScurkPlaceResult::rejected("required city data is missing or invalid", 0);
    }

    let error = site_error(&city.xbld.data, &city.xter.data, &city.xbit.data, site, tile, edge);

    if !error.is_empty() {
        return ScurkPlaceResult::rejected(error, 0);
    }

    let record_budget = facilities::individual_record_budget(city);

    if !facilities::record_available(&city.xmic.data, tile, record_budget) {
        return ScurkPlaceResult::rejected(&facilities::record_pool_message(record_budget), 0);
    }

    let random_before = random.state;
    let year = city.current_year();
    let rotation = city.compass_rotation();
    let misc_before = city.misc.data.clone();
    let maps = city.maps();
    let request = Provision {
        tile,
        current_year: year,
        misc: &misc_before,
        australian_locale,
        scurk_place_mode: true,
        record_budget,
        first_free: facilities::DYNAMIC_FIRST,
    };

    let overlay_id = facilities::provision_microsim(maps.microsims, maps.labels, maps.text_overlays, &request, random);
    let zone_id = zone_for_tile(tile, maps.zones, site, selected_zone, edge);

    let mut placed_flags = if tile == tiles::SMALL_PARK || tile == tiles::BIG_PARK {
        flag_bits::PIPED
    } else {
        flag_bits::STRUCTURE_MASK
    };

    if tile < tiles::DEVELOPED_FIRST {
        placed_flags = if tile >= tiles::POWER_LINE_FIRST { flag_bits::POWERABLE } else { 0 };
    }

    if flipped {
        placed_flags |= flag_bits::FLIPPED;
    }

    let mut tile_indices = Vec::new();

    for x in site.position.x..site.end().x {
        for y in site.position.y..site.end().y {
            let index = x * edge + y;
            let i = index as usize;
            replace_building(maps.buildings, maps.zones, maps.misc, index, tile);
            maps.zones[i] = zone_id as u8;
            maps.flags[i] = ((maps.flags[i] as i64 & !flag_bits::STRUCTURE_MASK) | placed_flags) as u8;

            if overlay_id != 0 {
                overlay::write(maps.text_overlays, index, overlay_id);
            }

            tile_indices.push(index as i32);
        }
    }

    set_corners(maps.zones, site.position, area, rotation, edge);

    if tile == tiles::STATUE {
        maps.flags[(selected.x * edge + selected.y) as usize] &= !(flag_bits::POWERABLE as u8);
    } else if tile == tiles::WATER_PUMP {
        underground::place_pipe(maps.underground, maps.terrain, maps.zones, maps.flags, maps.misc, selected, edge);
    } else if tile == tiles::SUBWAY_STATION {
        underground::place_subway_station(maps.underground, maps.terrain, maps.zones, maps.flags, maps.misc, selected, edge);
    }

    if let Some(category) = facilities::budget_category(tile) {
        let offset = misc_layout::BUDGETS + category * budget_layout::RECORD_SIZE;
        write_u32_be(maps.misc, offset, read_u32_be(maps.misc, offset) + 1);
    }

    let mut result = ScurkPlaceResult {
        base: EditBase::accepted("scurk_place_object", -1, -1),
        tile_id: tile,
        area,
        zone_id,
        overlay_id,
        scurk_place_history: true,
    };

    result.base.site = site;
    result.base.tile_indices = Ints32(tile_indices);
    result.base.tracks_random = true;
    result.base.random_state_before = random_before;
    result.base.random_state_after = random.state;

    result
}

/// ScurkPlaceCommand._site_error. SCURK places roads, dams, and zone
/// buildings that the tool palette cannot.
pub fn site_error(buildings: &[u8], terrain: &[u8], flags: &[u8], site: Rect2i, tile: i64, edge: i64) -> &'static str {
    let mut marina_water = 0;

    for x in site.position.x..site.end().x {
        for y in site.position.y..site.end().y {
            let index = (x * edge + y) as usize;
            let old = buildings[index] as i64;

            if old >= tiles::FIRST_ROAD || old == tiles::RADIOACTIVE_WASTE || old == tiles::SMALL_PARK {
                return "site contains a protected tile";
            }

            if tile == tiles::SMALL_PARK && old > tiles::TREES_7 {
                return "site contains a protected tile";
            }

            let water = flags[index] as i64 & flag_bits::WATER != 0;
            let flat = terrain[index] as i64 == terrain_ids::FLAT;

            if tile == tiles::MARINA {
                if water {
                    marina_water += 1;
                }
            } else if tile == tiles::HYDRO_POWER_1 || tile == tiles::HYDRO_POWER_2 {
                if flat || !water {
                    return "hydroelectric dam requires water terrain";
                }
            } else if tile >= tiles::DEVELOPED_FIRST && (!flat || water) {
                return "site is not flat clear land";
            }
        }
    }

    if tile == tiles::MARINA && (marina_water == 0 || marina_water == site.size.x * site.size.y) {
        return "marina must span land and water";
    }

    ""
}

/// ScurkPlaceCommand.VARIABLE_ZONE_TILES: construction and abandoned lots take
/// the selected zone. The value is the zone when none is selected.
fn variable_zone(tile: i64) -> Option<i64> {
    use tiles::*;

    match tile {
        CONSTRUCTION_1X1_FIRST | CONSTRUCTION_1X1_LAST => Some(1),
        ABANDONED_1X1_FIRST | DEVELOPED_1X1_LAST => Some(2),
        CONSTRUCTION_2X2_FIRST | CONSTRUCTION_2X2_2 | CONSTRUCTION_2X2_DENSE_FIRST | CONSTRUCTION_2X2_LAST => Some(2),
        ABANDONED_2X2_FIRST | ABANDONED_2X2_2 | ABANDONED_2X2_DENSE_FIRST => Some(2),
        DEVELOPED_2X2_LAST => Some(1),
        CONSTRUCTION_3X3_FIRST | CONSTRUCTION_3X3_LAST => Some(2),
        ABANDONED_3X3_FIRST | DEVELOPED_3X3_LAST => Some(1),
        _ => None,
    }
}

/// ScurkPlaceCommand._zone_for_tile: the zone that a placed object belongs to.
pub fn zone_for_tile(tile: i64, zones: &[u8], site: Rect2i, selected_zone: i64, map_edge: i64) -> i64 {
    use tiles::*;

    if let Some(default_zone) = variable_zone(tile) {
        let mut result = if (1..=9).contains(&selected_zone) {
            selected_zone
        } else {
            default_zone
        };

        for x in site.position.x..site.end().x {
            for y in site.position.y..site.end().y {
                let existing = zones[(x * map_edge + y) as usize] as i64 & zone::TYPE_MASK;

                if existing != 0 {
                    result = existing;
                }
            }
        }

        return result;
    }

    let within = |first: i64, last: i64| (first..=last).contains(&tile);

    if within(DEVELOPED_FIRST, RESIDENTIAL_1X1_LAST) {
        zone::LIGHT_RESIDENTIAL
    } else if within(RESIDENTIAL_2X2_FIRST, RESIDENTIAL_2X2_LAST) || within(RESIDENTIAL_3X3_FIRST, RESIDENTIAL_3X3_LAST) {
        zone::DENSE_RESIDENTIAL
    } else if within(COMMERCIAL_1X1_FIRST, COMMERCIAL_1X1_LAST) {
        zone::LIGHT_COMMERCIAL
    } else if within(COMMERCIAL_2X2_FIRST, COMMERCIAL_2X2_LAST) || within(COMMERCIAL_3X3_FIRST, COMMERCIAL_3X3_LAST) {
        zone::DENSE_COMMERCIAL
    } else if within(INDUSTRIAL_1X1_FIRST, INDUSTRIAL_1X1_LAST) || within(FACTORY_2X2_5, INDUSTRIAL_2X2_LAST) {
        zone::LIGHT_INDUSTRIAL
    } else if within(INDUSTRIAL_2X2_FIRST, FACTORY_2X2_4) || within(INDUSTRIAL_3X3_FIRST, INDUSTRIAL_3X3_LAST) {
        zone::DENSE_INDUSTRIAL
    } else if [CONTROL_TOWER_2, FIGHTER_JET, PARKING_LOT_2, TOP_SECRET, MISSILE_SILO].contains(&tile) {
        zone::MILITARY
    } else if [
        CONTROL_TOWER_1,
        AIRPORT_BUILDING_1,
        AIRPORT_BUILDING_2,
        TARMAC,
        HANGAR_1,
        RADAR,
        PARKING_LOT_1,
        HANGAR_2,
    ]
    .contains(&tile)
    {
        zone::AIRPORT
    } else if [CRANE, LOADING_BAY, CARGO_YARD].contains(&tile) {
        zone::SEAPORT
    } else {
        zone::NONE
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::sim::testing::{empty_full_resolution_city, sequence_random};

    /// A flipped object sets the flip flag on its tiles. An object that is not
    /// flipped leaves the flag off.
    #[test]
    fn placement_sets_the_flip_flag_of_a_flipped_object() {
        let edge = 128;
        let mut city = empty_full_resolution_city(edge);

        for (point, flipped) in [(Vec2i::new(10, 10), true), (Vec2i::new(20, 20), false)] {
            let result = apply(&mut city, tiles::SMALL_PARK, point, &mut sequence_random(&[0]), 0, false, flipped);
            assert!(result.base.ok, "{}", result.base.error);
            let flags = city.xbit.data[(point.x * edge + point.y) as usize] as i64;
            assert_eq!(flags & flag_bits::FLIPPED != 0, flipped);
        }
    }
}
