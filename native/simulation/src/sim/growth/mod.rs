//! The growth partition of one day, as GrowthScan and its helpers. The scan
//! keeps the original tile order and random-call order.

pub mod development;
pub mod maintenance;
pub mod special;

use crate::gd_phase_result;
use crate::sim::bytes::{add_i32_be, read_i32_be, read_u32_be, write_u32_be};
use crate::sim::city::City;
use crate::sim::events::{EffectEvent, NewsEvent, SoundEvent};
use crate::sim::geom::Vec2i;
use crate::sim::ids::building_tile_ids as tiles;
use crate::sim::ids::sc2misc_layout as misc_layout;
use crate::sim::ids::sc2tile_flags as flag_bits;
use crate::sim::ids::sc2zone_layout as zone;
use crate::sim::phase::TimingSpan;
use crate::sim::random::Randoms;
use crate::sim::tools::network::count_mask;
use crate::sim::trip::{self, TripMaps, TripScratch};
use development::{STATUS_ABANDONED, STATUS_CONSTRUCTION, STATUS_NORMAL, ZoneMaps};

const POPULATION_BY_DENSITY: [i64; 5] = [0, 1, 8, 12, 36];
const ANCHOR_MASKS: [i64; 4] = [0x80, 0x10, 0x20, 0x40];

// Timing indices. The debug window shows the steps in this order.
const PREPARE: i64 = 0;
const TILES: i64 = 1;
const SCAN: i64 = 2;
const SURFACE: i64 = 3;
const FACILITIES: i64 = 4;
const SPECIAL_ZONES: i64 = 5;
const TRIPS: i64 = 6;
const POPULATION: i64 = 7;
const COMPLETION: i64 = 8;
const RECOVERY: i64 = 9;
const DENSITY: i64 = 10;
const SUBWAY: i64 = 11;
const CHANGES: i64 = 12;
const STORE: i64 = 13;
const TIMING_LABELS: [&str; 14] = [
    "prepare and copy city data",
    "all per-tile growth work",
    "tile scan and eligibility",
    "surface maintenance",
    "trains, sailboats and arcologies",
    "airport, seaport and military growth",
    "transport trips",
    "population and abandonment",
    "construction completion",
    "abandoned building recovery",
    "density growth",
    "subway maintenance",
    "find changed chunks",
    "store growth changes",
];
const COARSE_TIMING_STEPS: [i64; 1] = [TILES];
const DETAILED_TIMING_STEPS: [i64; 10] =
    [SCAN, SURFACE, FACILITIES, SPECIAL_ZONES, TRIPS, POPULATION, COMPLETION, RECOVERY, DENSITY, SUBWAY];

/// Chunks that growth may change, in the order it commits them.
const GROWTH_CHUNKS: [&str; 12] =
    ["ALTM", "XTER", "XBLD", "XZON", "XUND", "XTXT", "XLAB", "XMIC", "XTHG", "XBIT", "XTRF", "MISC"];
/// Chunks that growth needs with their document sizes.
const INPUT_CHUNKS: [&str; 15] = [
    "ALTM", "XTER", "XBLD", "XZON", "XUND", "XTXT", "XLAB", "XMIC", "XTHG", "XBIT", "XTRF", "XPLT", "XVAL", "XCRM",
    "MISC",
];

gd_phase_result! {
    pub struct GrowthResult as "GrowthResult" {
        pub scanned_tiles: i64 = 0,
        pub rci_tiles: i64 = 0,
        pub population_added: i64 = 0,
        pub abandoned_population_added: i64 = 0,
        pub started_construction: i64 = 0,
        pub advanced_construction: i64 = 0,
        pub completed_construction: i64 = 0,
        pub abandoned_buildings: i64 = 0,
        pub recovered_buildings: i64 = 0,
        pub churches_built: i64 = 0,
        pub successful_trips: i64 = 0,
        pub failed_trips: i64 = 0,
        pub bus_passengers: i64 = 0,
        pub rail_passengers: i64 = 0,
        pub subway_passengers: i64 = 0,
        pub decayed_roads: i64 = 0,
        pub decayed_rails: i64 = 0,
        pub decayed_highway_tiles: i64 = 0,
        pub decayed_subway_tiles: i64 = 0,
        pub collapsed_bridges: i64 = 0,
        pub removed_subway_stations: i64 = 0,
        pub deferred_bridge_collapses: i64 = 0,
        pub deferred_bridge_effects: i64 = 0,
        pub deferred_station_removals: i64 = 0,
        pub special_growth_attempts: i64 = 0,
        pub special_tiles_placed: i64 = 0,
        pub arcologies_updated: i64 = 0,
        pub spawned_airplanes: i64 = 0,
        pub spawned_helicopters: i64 = 0,
        pub spawned_ships: i64 = 0,
        pub spawned_sailboats: i64 = 0,
        pub spawned_trains: i64 = 0,
        pub bridge_effects: Vec<EffectEvent> = Vec::new(),
        pub ship_home: Vec2i = Vec2i::NONE,
        pub ship_home_found: bool = false,
        pub rci_complete: bool = false,
    }
}

/// Rare maintenance, special-zone, and spawn outcomes, as GrowthMaintenanceResult.
#[derive(Default)]
pub struct Counters {
    pub decayed_roads: i64,
    pub decayed_rails: i64,
    pub decayed_highway_tiles: i64,
    pub decayed_subway_tiles: i64,
    pub collapsed_bridges: i64,
    pub removed_subway_stations: i64,
    pub deferred_bridge_collapses: i64,
    pub deferred_bridge_effects: i64,
    pub deferred_station_removals: i64,
    pub special_growth_attempts: i64,
    pub special_tiles_placed: i64,
    pub arcologies_updated: i64,
    pub spawned_airplanes: i64,
    pub spawned_helicopters: i64,
    pub spawned_ships: i64,
    pub spawned_sailboats: i64,
    pub spawned_trains: i64,
    pub bridge_effects: Vec<EffectEvent>,
    pub view_center_requests: Vec<Vec2i>,
    pub news_items: Vec<NewsEvent>,
    pub sound_events: Vec<SoundEvent>,
    pub ship_home_found: bool,
    pub ship_home: Vec2i,
}

/// GrowthState.replace_building. Military zones keep no growth counts here.
pub fn replace_building(buildings: &mut [u8], zones: &[u8], misc: &mut [u8], index: i64, new_tile: i64) {
    let old_tile = buildings[index as usize] as i64;

    if old_tile == new_tile {
        return;
    }

    if zones[index as usize] as i64 & zone::TYPE_MASK != 7 {
        let mask = count_mask(buildings.len());
        let old_offset = misc_layout::TILE_COUNTS + old_tile * 4;
        let new_offset = misc_layout::TILE_COUNTS + new_tile * 4;
        let old_count = read_u32_be(misc, old_offset);
        write_u32_be(misc, old_offset, (old_count - 1) & mask);
        let new_count = read_u32_be(misc, new_offset);
        write_u32_be(misc, new_offset, (new_count + 1) & mask);
    }

    buildings[index as usize] = new_tile as u8;
}

/// GrowthSiteRules.has_power. Keep the low-edge checks of city growth.
pub fn has_power(flags: &[u8], x: i64, y: i64, map_edge: i64) -> bool {
    let powered = |index: i64| flags[index as usize] as i64 & flag_bits::POWERED != 0;
    let index = x * map_edge + y;

    powered(index)
        || (x > 1 && powered((x - 1) * map_edge + y))
        || (y > 1 && powered(x * map_edge + y - 1))
        || (x < map_edge - 1 && powered((x + 1) * map_edge + y))
        || (y < map_edge - 1 && powered(x * map_edge + y + 1))
}

/// GrowthScan.run.
pub fn run(city: &mut City, randoms: &mut Randoms, step: i64, substep: i64, detailed: bool) -> GrowthResult {
    if !(0..=3).contains(&step) || !(0..=3).contains(&substep) {
        return GrowthResult::failed("growth partition is outside the supported range");
    }

    let mut span = TimingSpan::with_labels(&TIMING_LABELS);
    span.mark_index(PREPARE);

    if city.missing_or_resized(&INPUT_CHUNKS).is_some() {
        return GrowthResult::failed("growth input chunks are missing or have the wrong size");
    }

    let originals: Vec<Vec<u8>> =
        GROWTH_CHUNKS.iter().map(|id| city.chunk(id).map(|chunk| chunk.data.clone()).unwrap_or_default()).collect();
    let map_edge = city.map_size;
    let rotation = city.compass_rotation() & 3;
    let allow_edge_buildings = city.is_extended();

    {
        let maps = TripMaps {
            buildings: &city.xbld.data,
            zones: &city.xzon.data,
            underground: &city.xund.data,
            text_overlays: &city.xtxt.data,
            altitude: &city.altm.data,
            map_edge,
        };

        if !trip::valid_inputs(&maps, &city.xtrf.data) {
            return GrowthResult::failed("transport input maps have the wrong size");
        }
    }

    span.mark_index(if detailed { SCAN } else { TILES });
    let mut scan = TileScan {
        map_edge,
        rotation,
        anchor_mask: ANCHOR_MASKS[rotation as usize],
        allow_edge_buildings,
        detailed,
        counters: Counters { ship_home: Vec2i::NONE, ..Default::default() },
        walking_access: vec![vec![0u8; (map_edge * map_edge) as usize]; 4],
        scratch: TripScratch::default(),
        totals: Totals::default(),
        error: String::new(),
    };

    if !scan.scan_tiles(city, randoms, &mut span, step, substep) {
        return GrowthResult::failed(scan.error);
    }

    span.mark_index(CHANGES);

    for (position, id) in GROWTH_CHUNKS.iter().enumerate() {
        if let Some(chunk) = city.chunk_mut(id) {
            chunk.commit_if_changed(&originals[position]);
        }
    }

    span.mark_index(STORE);
    scan.result(span)
}

#[derive(Default)]
struct Totals {
    scanned_tiles: i64,
    rci_tiles: i64,
    population_added: i64,
    abandoned_population_added: i64,
    started_construction: i64,
    advanced_construction: i64,
    completed_construction: i64,
    abandoned_buildings: i64,
    recovered_buildings: i64,
    churches_built: i64,
    successful_trips: i64,
    failed_trips: i64,
    bus_passengers: i64,
    rail_passengers: i64,
    subway_passengers: i64,
}

struct TileScan {
    map_edge: i64,
    rotation: i64,
    anchor_mask: i64,
    allow_edge_buildings: bool,
    detailed: bool,
    counters: Counters,
    /// Catchments for this partition: 0 unknown, 1 no destination, 2 destination.
    walking_access: Vec<Vec<u8>>,
    scratch: TripScratch,
    totals: Totals,
    error: String,
}

impl TileScan {
    fn zone_maps<'a>(&self, city: &'a mut City) -> ZoneMaps<'a> {
        ZoneMaps {
            buildings: &mut city.xbld.data,
            zones: &mut city.xzon.data,
            flags: &mut city.xbit.data,
            misc: &mut city.misc.data,
            land_value: &city.xval.data,
            altitude: &city.altm.data,
            rotation: self.rotation,
            map_edge: self.map_edge,
            allow_edge_buildings: self.allow_edge_buildings,
        }
    }

    /// Visit every fourth column and row from the partition origin. Each tile
    /// gets its zone-class work and then subway maintenance.
    fn scan_tiles(&mut self, city: &mut City, randoms: &mut Randoms, span: &mut TimingSpan, step: i64, substep: i64) -> bool {
        let edge = self.map_edge;
        let mut tile_count = 0;
        let mut x = step;

        while x < edge {
            crate::sim::budget::checkpoint();
            let mut y = substep;

            while y < edge {
                tile_count += 1;

                // The scanned-tile count strides the worker checkpoint.
                if tile_count & 15 == 0 {
                    crate::sim::budget::checkpoint();
                }

                let index = x * edge + y;
                let zone_byte = city.xzon.data[index as usize] as i64;
                let zone_type = zone_byte & zone::TYPE_MASK;
                let tile = Vec2i::new(x, y);

                if zone_type == 0 {
                    self.process_unzoned_tile(city, randoms, span, tile, index);
                } else if zone_type > 6 {
                    self.process_special_zone_tile(city, randoms, span, tile);
                } else if !self.process_rci_tile(city, randoms, span, tile, index, zone_byte, zone_type) {
                    return false;
                }

                if self.detailed {
                    span.mark_index(SUBWAY);
                }

                let parts = city.parts();
                let mut maps = parts.maps;
                maintenance::process_subway(
                    &mut maps,
                    parts.things,
                    tile,
                    &mut randoms.random,
                    &mut randoms.lfsr,
                    &mut self.counters,
                );

                if self.detailed {
                    span.mark_index(SCAN);
                }

                y += 4;
            }

            x += 4;
        }

        self.totals.scanned_tiles = tile_count;

        true
    }

    fn process_unzoned_tile(&mut self, city: &mut City, randoms: &mut Randoms, span: &mut TimingSpan, tile: Vec2i, index: i64) {
        let maintenance_tile = city.xbld.data[index as usize] as i64;

        if self.detailed {
            span.mark_index(SURFACE);
        }

        {
            let mut maps = city.maps();
            maintenance::process_surface(
                &mut maps,
                tile,
                &mut randoms.random,
                &mut randoms.lfsr,
                self.rotation,
                &mut self.counters,
            );
        }

        if self.detailed {
            span.mark_index(FACILITIES);
        }

        let parts = city.parts();
        let mut maps = parts.maps;
        maintenance::process_microsim(
            &mut maps,
            parts.things,
            parts.land_value,
            parts.crime,
            parts.pollution,
            tile,
            maintenance_tile,
            &mut randoms.game,
            &mut randoms.lfsr,
            &mut self.counters,
        );
    }

    fn process_special_zone_tile(&mut self, city: &mut City, randoms: &mut Randoms, span: &mut TimingSpan, tile: Vec2i) {
        if self.detailed {
            span.mark_index(SPECIAL_ZONES);
        }

        let City { altm, xbld, xter, xzon, xund, xbit, xtxt, misc, xthg, .. } = city;
        let mut maps = special::SpecialMaps {
            buildings: &mut xbld.data,
            zones: &mut xzon.data,
            underground: &mut xund.data,
            flags: &mut xbit.data,
            terrain: &xter.data,
            altitude: &altm.data,
            text_overlays: &mut xtxt.data,
            things: &mut xthg.data,
            misc: &mut misc.data,
            rotation: self.rotation,
            map_edge: self.map_edge,
            allow_edge_buildings: self.allow_edge_buildings,
        };
        special::process(&mut maps, tile, &mut randoms.random, &mut self.counters);
    }

    /// Residential, commercial, and industrial growth. Returns false and sets
    /// the error when a trip search fails.
    #[allow(clippy::too_many_arguments)]
    fn process_rci_tile(
        &mut self,
        city: &mut City,
        randoms: &mut Randoms,
        span: &mut TimingSpan,
        tile: Vec2i,
        index: i64,
        zone_byte: i64,
        zone_type: i64,
    ) -> bool {
        let edge = self.map_edge;
        let building = city.xbld.data[index as usize] as i64;
        let mut density = 0;
        let mut status = STATUS_NORMAL;

        if building < tiles::DEVELOPED_FIRST {
            if building >= tiles::ROAD_STRAIGHT_1 || !trip::has_nearby_transport(&city.xbld.data, tile, edge) {
                return true;
            }
        } else {
            if building > tiles::DEVELOPED_3X3_LAST || zone_byte & self.anchor_mask == 0 {
                return true;
            }

            density = development::density(building);
            status = development::status(building);
        }

        self.totals.rci_tiles += 1;
        let mut growth_pressure = 0;

        if has_power(&city.xbit.data, tile.x, tile.y, edge) {
            if self.detailed {
                span.mark_index(TRIPS);
            }

            let maps = TripMaps {
                buildings: &city.xbld.data,
                zones: &city.xzon.data,
                underground: &city.xund.data,
                text_overlays: &city.xtxt.data,
                altitude: &city.altm.data,
                map_edge: edge,
            };
            let access = &mut self.walking_access[((zone_type + 1) / 2) as usize];
            let trip = trip::trace(
                &maps,
                &mut city.xtrf.data,
                tile,
                zone_type,
                density,
                &mut randoms.random,
                100,
                -1,
                Some(access.as_mut_slice()),
                &mut self.scratch,
            );

            if !trip.ok {
                self.error = trip.error;

                return false;
            }

            growth_pressure = self.record_trip(&trip, &city.misc.data, zone_type, density);
        }

        if self.detailed {
            span.mark_index(POPULATION);
        }

        if density > 0 && status == STATUS_NORMAL && self.count_population_or_abandon(city, randoms, tile, zone_type, density, 4000 - growth_pressure) {
            return true;
        }

        if self.detailed {
            span.mark_index(COMPLETION);
        }

        if status == STATUS_CONSTRUCTION {
            if self.try_complete_construction(city, randoms, tile, zone_type, density) {
                return true;
            }
        } else if status == STATUS_ABANDONED {
            self.try_recover_abandoned(city, randoms, span, tile, zone_type, density, growth_pressure);

            return true;
        }

        if self.detailed {
            span.mark_index(DENSITY);
        }

        self.try_advance_density(city, randoms, tile, zone_byte, zone_type, density, growth_pressure);

        true
    }

    /// Count the trip and its passengers. A completed trip returns the zone
    /// class demand plus 2000 as growth pressure.
    fn record_trip(&mut self, trip: &trip::TripResult, misc: &[u8], zone_type: i64, density: i64) -> i64 {
        if !trip.reached_destination {
            self.totals.failed_trips += 1;

            return 0;
        }

        self.totals.successful_trips += 1;

        if trip.used_bus {
            self.totals.bus_passengers += density;
        }

        if trip.used_rail {
            self.totals.rail_passengers += density;
        }

        if trip.used_subway {
            self.totals.subway_passengers += density;
        }

        read_i32_be(misc, misc_layout::DEMAND + ((zone_type - 1) / 2) * 4) + 2000
    }

    /// Add a developed building's population, then roll for abandonment.
    fn count_population_or_abandon(
        &mut self,
        city: &mut City,
        randoms: &mut Randoms,
        tile: Vec2i,
        zone_type: i64,
        density: i64,
        decline_pressure: i64,
    ) -> bool {
        let population = POPULATION_BY_DENSITY[density as usize];
        add_i32_be(&mut city.misc.data, misc_layout::ZONE_POPULATIONS + zone_type * 4, population);
        self.totals.population_added += population;

        if randoms.random.next_u15() >= decline_pressure / density {
            return false;
        }

        let pattern = randoms.random.next_u15() & 1;
        let mut maps = self.zone_maps(city);
        development::abandon(&mut maps, tile, density, pattern, &mut randoms.random);
        self.totals.abandoned_buildings += 1;

        true
    }

    /// Roll to finish a construction site as a zone building, or as a church
    /// when the population outgrows the existing churches.
    fn try_complete_construction(&mut self, city: &mut City, randoms: &mut Randoms, tile: Vec2i, zone_type: i64, density: i64) -> bool {
        if randoms.random.next_u15() >= 0x4000 / density {
            return false;
        }

        let misc = &city.misc.data;

        if read_u32_be(misc, misc_layout::NORMAL_POPULATION) > read_u32_be(misc, misc_layout::TILE_COUNTS + tiles::CHURCH * 4) * 2500
            && density & 2 != 0
            && zone_type < 3
        {
            let mut maps = self.zone_maps(city);
            development::place_church(&mut maps, tile);
            self.invalidate_church_walking_access(tile);
            self.totals.churches_built += 1;
        } else {
            let mut maps = self.zone_maps(city);
            development::place_zone(&mut maps, tile, density, (zone_type - 1) / 2, &mut randoms.random);
        }

        self.totals.completed_construction += 1;

        true
    }

    /// Church placement clears a two-by-two zone footprint. No other growth
    /// operation changes a low zone nibble between successive trip searches.
    fn invalidate_church_walking_access(&mut self, tile: Vec2i) {
        let edge = self.map_edge;

        for x in (tile.x - 3).max(0)..(tile.x + 5).min(edge) {
            for y in (tile.y - 4).max(0)..(tile.y + 4).min(edge) {
                for access in self.walking_access.iter_mut() {
                    access[(x * edge + y) as usize] = 0;
                }
            }
        }
    }

    #[allow(clippy::too_many_arguments)]
    fn try_recover_abandoned(
        &mut self,
        city: &mut City,
        randoms: &mut Randoms,
        span: &mut TimingSpan,
        tile: Vec2i,
        zone_type: i64,
        density: i64,
        growth_pressure: i64,
    ) {
        if self.detailed {
            span.mark_index(RECOVERY);
        }

        let abandoned_population = POPULATION_BY_DENSITY[density as usize];
        add_i32_be(&mut city.misc.data, misc_layout::ZONE_POPULATIONS + 7 * 4, abandoned_population);
        self.totals.abandoned_population_added += abandoned_population;

        if randoms.random.next_u15() >= (growth_pressure * 15) / density {
            return;
        }

        let mut maps = self.zone_maps(city);
        development::place_zone(&mut maps, tile, density, (zone_type - 1) / 2, &mut randoms.random);
        self.totals.recovered_buildings += 1;
    }

    #[allow(clippy::too_many_arguments)]
    fn try_advance_density(
        &mut self,
        city: &mut City,
        randoms: &mut Randoms,
        tile: Vec2i,
        zone_byte: i64,
        zone_type: i64,
        density: i64,
        growth_pressure: i64,
    ) {
        if !development::can_advance_density(zone_byte, zone_type, density, &city.xval.data, tile.x, tile.y, self.map_edge) {
            return;
        }

        if randoms.random.next_u15() >= (growth_pressure * 3) / (density + 1) {
            return;
        }

        let mut maps = self.zone_maps(city);

        if !development::advance_construction(&mut maps, tile, density, zone_type, &mut randoms.random) {
            return;
        }

        if density == 0 {
            self.totals.started_construction += 1;
        } else {
            self.totals.advanced_construction += 1;
        }
    }

    fn result(self, mut span: TimingSpan) -> GrowthResult {
        let totals = self.totals;
        let counters = self.counters;
        let mut growth = GrowthResult {
            rci_complete: true,
            scanned_tiles: totals.scanned_tiles,
            rci_tiles: totals.rci_tiles,
            population_added: totals.population_added,
            abandoned_population_added: totals.abandoned_population_added,
            started_construction: totals.started_construction,
            advanced_construction: totals.advanced_construction,
            completed_construction: totals.completed_construction,
            abandoned_buildings: totals.abandoned_buildings,
            recovered_buildings: totals.recovered_buildings,
            churches_built: totals.churches_built,
            successful_trips: totals.successful_trips,
            failed_trips: totals.failed_trips,
            bus_passengers: totals.bus_passengers,
            rail_passengers: totals.rail_passengers,
            subway_passengers: totals.subway_passengers,
            decayed_roads: counters.decayed_roads,
            decayed_rails: counters.decayed_rails,
            decayed_highway_tiles: counters.decayed_highway_tiles,
            decayed_subway_tiles: counters.decayed_subway_tiles,
            collapsed_bridges: counters.collapsed_bridges,
            removed_subway_stations: counters.removed_subway_stations,
            deferred_bridge_collapses: counters.deferred_bridge_collapses,
            deferred_bridge_effects: counters.deferred_bridge_effects,
            deferred_station_removals: counters.deferred_station_removals,
            special_growth_attempts: counters.special_growth_attempts,
            special_tiles_placed: counters.special_tiles_placed,
            arcologies_updated: counters.arcologies_updated,
            spawned_airplanes: counters.spawned_airplanes,
            spawned_helicopters: counters.spawned_helicopters,
            spawned_ships: counters.spawned_ships,
            spawned_sailboats: counters.spawned_sailboats,
            spawned_trains: counters.spawned_trains,
            bridge_effects: counters.bridge_effects,
            ship_home_found: counters.ship_home_found,
            ship_home: counters.ship_home,
            ..Default::default()
        };
        growth.base.ok = true;
        growth.base.news_items = counters.news_items;
        growth.base.sound_events = counters.sound_events;
        growth.base.view_center_requests = counters.view_center_requests;
        growth.base.timing = span.finish();

        // Report only the steps that this timing mode measures.
        let removed: &[i64] = if self.detailed { &COARSE_TIMING_STEPS } else { &DETAILED_TIMING_STEPS };

        for step in removed {
            growth.base.timing.steps.erase(TIMING_LABELS[*step as usize]);
        }

        growth
    }
}
