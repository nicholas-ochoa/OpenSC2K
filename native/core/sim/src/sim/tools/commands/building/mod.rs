//! Shared buildings from the tool palette, as BuildingEdit and BuildingSites.

pub mod facilities;
pub mod facility_repair;

use crate::gd_edit_result;
use crate::sim::bytes::{read_u32_be, write_u32_be};
use crate::sim::city::City;
use crate::sim::civic::milestones::rebuild_reward_mask;
use crate::sim::geom::{Rect2i, Vec2i};
use crate::sim::ids::building_tile_ids as tiles;
use crate::sim::ids::sc2budget_layout as budget_layout;
use crate::sim::ids::sc2misc_layout as misc_layout;
use crate::sim::ids::sc2tile_flags as flag_bits;
use crate::sim::ids::sc2zone_layout as zone;
use crate::sim::ids::terrain_tile_ids as terrain_ids;
use crate::sim::infrastructure::{power, water};
use crate::sim::overlay;
use crate::sim::random::{SimLfsrRandom, SimRandom};
use crate::sim::tools::commands::{EditBase, ToolArgs};
use crate::sim::tools::terrain::update_building_count;
use crate::sim::tools::{set_corners, underground};
use crate::sim::value::Ints32;
use facilities::Provision;

/// The chunks that BuildingState._city_payloads checks.
pub const PAYLOAD_IDS: [&str; 9] = ["XBLD", "XTER", "XZON", "XUND", "XBIT", "XTXT", "XLAB", "XMIC", "MISC"];

/// The residents object to these buildings near their homes.
const NUISANCE_TILES: [i64; 6] = [
    tiles::GAS_POWER,
    tiles::OIL_POWER,
    tiles::NUCLEAR_POWER,
    tiles::COAL_POWER,
    tiles::PRISON,
    tiles::WATER_TREATMENT,
];

/// A nuisance building counts the residential tiles this far around its site.
const NUISANCE_REACH: i64 = 8;

/// The chance that one residential tile objects, out of this many.
const NUISANCE_ODDS: i64 = 200;

const SOUND_NUISANCE: i64 = 0x200;
const NUISANCE_BITMAP_ID: i64 = 403;
const NUISANCE_STRING_ID: i64 = 106;

/// A new structure is piped, powered, and powerable.
const STRUCTURE_FLAGS: i64 = flag_bits::PIPED | flag_bits::POWERED | flag_bits::POWERABLE;

gd_edit_result! {
    pub struct BuildingResult as "BuildingEditResult" {
        pub tile_id: i64 = tiles::EMPTY,
        pub overlay_id: i64 = 0,
        pub lfsr_state_before: i64 = 0,
        pub lfsr_state_after: i64 = 0,
        pub immediate_power_refresh: bool = false,
        pub immediate_water_refresh: bool = false,
        pub stadium_team_selection_required: bool = false,
        pub residential_tiles: i64 = 0,
        pub resident_objection: bool = false,
        pub lfsr_advanced: bool = false,
        pub notice_bitmap_id: i64 = 0,
        pub notice_string_id: i64 = 0,
    }
}

/// The building a tool places, and its footprint.
pub struct Placement {
    pub tile: i64,
    pub area: i64,
    /// ToolAvailability.is_available for this city.
    pub available: bool,
    pub australian_locale: bool,
}

/// BuildingSites.footprint: the pointer is not the origin of the larger buildings.
pub fn footprint(selected: Vec2i, area: i64) -> Rect2i {
    if !(1..=4).contains(&area) {
        return Rect2i::default();
    }

    let origin = if area > 2 { selected - Vec2i::new(1, 1) } else { selected };

    Rect2i::from(origin, Vec2i::new(area, area))
}

/// BuildingSites._footprint_is_in_bounds. Original cities keep larger
/// buildings off the map edge.
pub fn footprint_is_in_bounds(site: Rect2i, area: i64, map_edge: i64, allow_edge: bool) -> bool {
    if site.size != Vec2i::new(area, area) {
        return false;
    }

    let end = site.end();

    if area == 1 || allow_edge {
        return site.position.x >= 0 && site.position.y >= 0 && end.x <= map_edge && end.y <= map_edge;
    }

    site.position.x >= 1 && site.position.y >= 1 && end.x < map_edge && end.y < map_edge
}

/// BuildingSites._site_error. Empty when the site can hold the building.
pub fn site_error(city: &City, site: Rect2i, tile: i64) -> &'static str {
    let edge = city.map_size;
    let mut marina_water = 0;

    for x in site.position.x..site.end().x {
        for y in site.position.y..site.end().y {
            let index = (x * edge + y) as usize;
            let old = city.xbld.data[index] as i64;

            if old >= tiles::FIRST_ROAD || old == tiles::RADIOACTIVE_WASTE || old == tiles::SMALL_PARK {
                return "site contains a protected tile";
            }

            if tile == tiles::SMALL_PARK && old > tiles::TREES_7 {
                return "site contains a protected tile";
            }

            if city.xzon.data[index] as i64 & zone::TYPE_MASK == zone::MILITARY {
                return "site is in a military zone";
            }

            let water = city.xbit.data[index] as i64 & flag_bits::WATER != 0;

            if tile == tiles::MARINA && water {
                marina_water += 1;
            } else if city.xter.data[index] as i64 != terrain_ids::FLAT || water {
                return "site is not clear";
            }
        }
    }

    if tile == tiles::MARINA && (marina_water == 0 || marina_water == site.size.x * site.size.y) {
        return "marina must span land and water";
    }

    ""
}

/// BuildingSites.preview_error after the tool and availability checks.
pub fn preview_error(city: &City, cost: i64, placement: &Placement, point: Vec2i) -> &'static str {
    if !placement.available {
        return "This building is not available in this city.";
    }

    if city.funds() < cost {
        return "Insufficient funds.";
    }

    let site = footprint(point, placement.area);

    if !footprint_is_in_bounds(site, placement.area, city.map_size, city.is_extended()) {
        return "The building footprint extends outside the map.";
    }

    site_error(city, site, placement.tile)
}

fn count_nearby_residential(zones: &[u8], selected: Vec2i, area: i64, map_edge: i64) -> i64 {
    let mut count = 0;

    for x in (selected.x - NUISANCE_REACH).max(0)..(selected.x + area + NUISANCE_REACH).min(map_edge) {
        for y in (selected.y - NUISANCE_REACH).max(0)..(selected.y + area + NUISANCE_REACH).min(map_edge) {
            let zone_type = zones[(x * map_edge + y) as usize] as i64 & zone::TYPE_MASK;

            if zone_type == zone::LIGHT_RESIDENTIAL || zone_type == zone::DENSE_RESIDENTIAL {
                count += 1;
            }
        }
    }

    count
}

/// BuildingEdit.apply.
pub fn apply(
    city: &mut City,
    args: &ToolArgs,
    placement: &Placement,
    selected: Vec2i,
    lfsr: &mut SimLfsrRandom,
    random: &mut SimRandom,
) -> BuildingResult {
    let edge = city.map_size;

    if !placement.available {
        return BuildingResult::rejected("tool is not available in this city", 0);
    }

    let cost = args.cost;

    if cost != 0 && city.funds() < cost {
        return BuildingResult::rejected("insufficient funds", cost);
    }

    let tile = placement.tile;
    let area = placement.area;
    let site = footprint(selected, area);

    if city.missing_or_resized(&PAYLOAD_IDS).is_some() {
        return BuildingResult::rejected("required city data is missing or invalid", 0);
    }

    let lfsr_before = lfsr.state;
    let random_before = random.state;

    if NUISANCE_TILES.contains(&tile) {
        let residential = count_nearby_residential(&city.xzon.data, selected, area, edge);

        if lfsr.next_mod(NUISANCE_ODDS) < residential {
            let mut objection = BuildingResult::rejected("residents rejected this site", cost);
            objection.residential_tiles = residential;
            objection.resident_objection = true;
            objection.lfsr_advanced = lfsr.state != lfsr_before;
            objection.base.sound_events = vec![SOUND_NUISANCE];
            objection.notice_bitmap_id = NUISANCE_BITMAP_ID;
            objection.notice_string_id = NUISANCE_STRING_ID;

            return objection;
        }
    }

    let rejected_after_draw = |message: &str, lfsr: &SimLfsrRandom| {
        let mut blocked = BuildingResult::rejected(message, cost);
        blocked.lfsr_advanced = lfsr.state != lfsr_before;

        blocked
    };

    if !footprint_is_in_bounds(site, area, edge, city.is_extended()) {
        return rejected_after_draw("building does not fit inside the map", lfsr);
    }

    let error = site_error(city, site, tile);

    if !error.is_empty() {
        return rejected_after_draw(error, lfsr);
    }

    // An SC2X version 4 city never builds a facility without its record.
    let record_budget = facilities::individual_record_budget(city);

    if !facilities::record_available(&city.xmic.data, tile, record_budget) {
        return rejected_after_draw(&facilities::record_pool_message(record_budget), lfsr);
    }

    let year = city.current_year();
    let funds = city.funds();
    let rotation = city.compass_rotation();
    let misc_before = city.misc.data.clone();
    let maps = city.maps();
    let request = Provision {
        tile,
        current_year: year,
        misc: &misc_before,
        australian_locale: placement.australian_locale,
        scurk_place_mode: false,
        record_budget,
        first_free: facilities::DYNAMIC_FIRST,
    };

    let overlay_id = facilities::provision_microsim(maps.microsims, maps.labels, maps.text_overlays, &request, random);
    let placed_flags = if tile == tiles::SMALL_PARK || tile == tiles::BIG_PARK {
        flag_bits::PIPED
    } else {
        STRUCTURE_FLAGS
    };

    let mut tile_indices = Vec::new();

    for x in site.position.x..site.end().x {
        for y in site.position.y..site.end().y {
            let index = x * edge + y;
            let i = index as usize;
            update_building_count(
                maps.misc,
                maps.zones[i] as i64 & zone::TYPE_MASK,
                maps.buildings[i] as i64,
                tile,
                edge,
            );
            maps.buildings[i] = tile as u8;
            maps.zones[i] = 0;
            maps.flags[i] = ((maps.flags[i] as i64 & !flag_bits::STRUCTURE_MASK & 0xff) | placed_flags) as u8;

            if overlay_id != 0 {
                overlay::write(maps.text_overlays, index, overlay_id);
            }

            tile_indices.push(index as i32);
        }
    }

    set_corners(maps.zones, site.position, area, rotation, edge);

    let selected_index = (selected.x * edge + selected.y) as usize;

    if tile == tiles::STATUE {
        maps.flags[selected_index] &= !(flag_bits::POWERABLE as u8);
    } else if tile == tiles::WATER_PUMP {
        underground::place_pipe(maps.underground, maps.terrain, maps.zones, maps.flags, maps.misc, selected, edge);
    } else if tile == tiles::SUBWAY_STATION {
        underground::place_subway_station(maps.underground, maps.terrain, maps.zones, maps.flags, maps.misc, selected, edge);
    }

    update_budget(maps.misc, tile, args, funds - cost);

    let mut power_refresh = false;
    let mut water_refresh = false;
    let mut power_usage = -1;
    let mut water_usage = -1;

    if city.misc_u32(misc_layout::NORMAL_POPULATION) < super::hydro::IMMEDIATE_UTILITY_POPULATION_LIMIT {
        if city.xbit.data[selected_index] as i64 & flag_bits::POWERABLE != 0 {
            let refreshed = power::run(city, random);

            if !refreshed.base.ok {
                lfsr.state = lfsr_before;
                random.state = random_before;

                return BuildingResult::rejected("cannot refresh power after placement", 0);
            }

            power_refresh = true;
            power_usage = refreshed.usage_percent;
        }

        if city.xbit.data[selected_index] as i64 & flag_bits::PIPED != 0 {
            let refreshed = water::run(city);

            if !refreshed.base.ok {
                lfsr.state = lfsr_before;
                random.state = random_before;

                return BuildingResult::rejected("cannot refresh water after placement", 0);
            }

            water_refresh = true;
            water_usage = refreshed.usage_percent;
        }
    }

    let mut result = BuildingResult {
        base: EditBase::accepted("building", args.group, args.subtool),
        tile_id: tile,
        overlay_id,
        lfsr_state_before: lfsr_before,
        lfsr_state_after: lfsr.state,
        immediate_power_refresh: power_refresh,
        immediate_water_refresh: water_refresh,
        stadium_team_selection_required: tile == tiles::STADIUM && overlay_id != 0,
        ..Default::default()
    };

    result.base.site = site;
    result.base.tile_indices = Ints32(tile_indices);
    result.base.cost = cost;
    result.base.tracks_random = true;
    result.base.random_state_before = random_before;
    result.base.random_state_after = random.state;
    result.base.power_usage_percent = power_usage;
    result.base.water_usage_percent = water_usage;

    result
}

/// BuildingEdit._update_budget: count the facility in its budget category,
/// use up a reward, and charge the funds.
fn update_budget(misc: &mut [u8], tile: i64, args: &ToolArgs, funds: i64) {
    if let Some(category) = facilities::budget_category(tile) {
        let offset = misc_layout::BUDGETS + category * budget_layout::RECORD_SIZE;
        write_u32_be(misc, offset, read_u32_be(misc, offset) + 1);
    }

    if args.group == REWARDS_GROUP && args.subtool < ARCOLOGIES_SUBTOOL {
        let mask = rebuild_reward_mask(misc);
        write_u32_be(misc, misc_layout::GRANTED_REWARDS, mask & !(1 << args.subtool));
    }

    write_u32_be(misc, misc_layout::FUNDS, funds);
}

/// CityToolIds.Group.REWARDS and CityToolIds.Rewards.ARCOLOGIES.
const REWARDS_GROUP: i64 = 5;
const ARCOLOGIES_SUBTOOL: i64 = 4;
