//! Hydroelectric dams on waterfalls, as HydroCommand.

use super::facilities::{self, Provision};
use super::{EditBase, ToolArgs};
use crate::gd_edit_result;
use crate::sim::city::City;
use crate::sim::geom::Vec2i;
use crate::sim::ids::building_tile_ids as tiles;
use crate::sim::ids::sc2misc_layout as misc_layout;
use crate::sim::ids::sc2tile_flags as flag_bits;
use crate::sim::ids::sc2zone_layout as zone;
use crate::sim::ids::terrain_tile_ids as terrain_ids;
use crate::sim::infrastructure::power;
use crate::sim::overlay;
use crate::sim::random::SimRandom;
use crate::sim::tools::terrain::update_building_count;
use crate::sim::value::Ints32;

/// Small cities refresh power and water at once after a utility is placed.
pub const IMMEDIATE_UTILITY_POPULATION_LIMIT: i64 = 50_000_000;

/// The dam faces across the waterfall. Index by the higher neighbors: 1 north,
/// 2 east, 4 south, 8 west.
const HYDRO_ORIENTATION: [i64; 16] = [1, 1, 0, 1, 1, 0, 1, 0, 0, 1, 1, 1, 1, 0, 1, 1];

gd_edit_result! {
    pub struct HydroResult as "HydroEditResult" {
        pub tile_id: i64 = tiles::EMPTY,
        pub overlay_id: i64 = 0,
        pub immediate_power_refresh: bool = false,
    }
}

pub fn apply(city: &mut City, args: &ToolArgs, point: Vec2i, random: &mut SimRandom) -> HydroResult {
    let index = city.index_of(point.x, point.y);

    if index < 0 {
        return HydroResult::rejected("hydroelectric site is outside the city", 0);
    }

    // The shore tile 0x2e is a waterfall too.
    let terrain = city.xter.data[index as usize] as i64;

    if terrain != terrain_ids::FORBIDDEN_COAST && terrain != terrain_ids::WATERFALL {
        return HydroResult::rejected("hydroelectric power requires a waterfall", 0);
    }

    if city.xbld.data[index as usize] as i64 != tiles::EMPTY {
        return HydroResult::rejected("waterfall already contains a building", 0);
    }

    let cost = args.cost;

    if city.funds() < cost {
        return HydroResult::rejected("insufficient funds", cost);
    }

    if city.missing_or_resized(&super::building::PAYLOAD_IDS).is_some() {
        return HydroResult::rejected("required city data is missing or invalid", 0);
    }

    let tile = hydro_tile(city, point);
    let random_before = random.state;
    let year = city.current_year();
    let funds = city.funds();
    let edge = city.map_size;
    let misc_copy = city.misc.data.clone();
    let maps = city.maps();
    let i = index as usize;

    update_building_count(
        maps.misc,
        maps.zones[i] as i64 & zone::TYPE_MASK,
        maps.buildings[i] as i64,
        tile,
        edge,
    );
    maps.buildings[i] = tile as u8;
    maps.flags[i] |= flag_bits::POWERABLE as u8;
    maps.zones[i] = zone::CORNERS_MASK as u8;

    let request = Provision {
        tile,
        current_year: year,
        misc: &misc_copy,
        australian_locale: false,
        scurk_place_mode: false,
        record_budget: -1,
        first_free: facilities::DYNAMIC_FIRST,
    };
    let overlay_id = facilities::provision_microsim(maps.microsims, maps.labels, maps.text_overlays, &request, random);

    if overlay_id != 0 {
        overlay::write(maps.text_overlays, index, overlay_id);
    }

    city.set_funds(funds - cost);

    let mut refreshed = false;
    let mut usage = -1;

    if city.misc_u32(misc_layout::NORMAL_POPULATION) < IMMEDIATE_UTILITY_POPULATION_LIMIT {
        let power = power::run(city, random);

        if !power.base.ok {
            random.state = random_before;

            return HydroResult::rejected("cannot refresh power after hydroelectric placement", 0);
        }

        refreshed = true;
        usage = power.usage_percent;
    }

    let mut result = HydroResult {
        base: EditBase::accepted("hydro", args.group, args.subtool),
        tile_id: tile,
        overlay_id,
        immediate_power_refresh: refreshed,
    };
    result.base.tile_indices = Ints32(vec![index as i32]);
    result.base.cost = cost;
    result.base.tracks_random = true;
    result.base.random_state_before = random_before;
    result.base.random_state_after = random.state;
    result.base.power_usage_percent = usage;

    result
}

/// The dam orientation from the higher neighbors, turned with the view.
fn hydro_tile(city: &City, point: Vec2i) -> i64 {
    let edge = city.map_size;
    let altitude = city.land_altitude(point.x, point.y);
    let mut higher = 0;

    if point.y > 0 && altitude < city.land_altitude(point.x, point.y - 1) {
        higher |= 1;
    }

    if point.x < edge - 1 && altitude < city.land_altitude(point.x + 1, point.y) {
        higher |= 2;
    }

    if point.y < edge - 1 && altitude < city.land_altitude(point.x, point.y + 1) {
        higher |= 4;
    }

    if point.x > 0 && altitude < city.land_altitude(point.x - 1, point.y) {
        higher |= 8;
    }

    let mut orientation = HYDRO_ORIENTATION[higher];

    if city.compass_rotation() & 1 != 0 {
        orientation ^= 1;
    }

    tiles::HYDRO_POWER_1 + orientation
}
