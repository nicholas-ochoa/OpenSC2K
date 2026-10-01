//! The annual facility update, as MicrosimAnnualPhase and its utilities,
//! amenities, and services. Records run in record order, and each rule keeps
//! the random-call order of the original.

use crate::gd_object;
use crate::gd_phase_result;
use crate::sim::bytes::{read_i32_be, read_u16_be, read_u32_be, write_u16_be, write_u32_be};
use crate::sim::city::City;
use crate::sim::events::{EffectEvent, NewsEvent, SoundEvent};
use crate::sim::geom::Vec2i;
use crate::sim::ids::building_tile_ids as tiles;
use crate::sim::ids::sc2budget_layout as budget;
use crate::sim::ids::sc2microsim_layout;
use crate::sim::ids::sc2misc_layout as misc_layout;
use crate::sim::ids::sc2tile_flags as flag_bits;
use crate::sim::overlay;
use crate::sim::phase::TimingSpan;
use crate::sim::random::{GameLcgRandom, SimLfsrRandom, SimRandom};
use crate::sim::tools::demolish;
use crate::sim::value::Ints32;

const NEWS_POWER_PLANT: i64 = 0x24;
const NEWS_PRISON: i64 = 0x25;
const NEWS_EDUCATION: i64 = 0x26;
/// Message box string IDs, not newspaper stories.
const NOTICE_ARCOLOGY_LAUNCH_START: i32 = 529;
const NOTICE_ARCOLOGY_LAUNCH_END: i32 = 530;
const SOUND_EXPLOSION: i64 = 504;
/// The launch steps from the ignition of one arcology until its flight
/// ends: 4.5 seconds at 50 ms a step. The launch ends when the last flight
/// ends.
const LAUNCH_LEAD_STEPS: i64 = 90;
const LAUNCH_ARCOLOGY_EDGE: i64 = 4;
/// The renderer draws this effect type as fire and smoke at the effect point.
const LAUNCH_FIRE_EFFECT: &str = "launch_fire";
/// The effect frames of one launch fire, from ignition until it goes out.
const LAUNCH_FIRE_FRAMES: i64 = 30;
/// The renderer draws this effect type as the arcology sprite. It shakes,
/// then lifts off after `frames` effect frames and flies off the screen.
const LAUNCH_ARCOLOGY_EFFECT: &str = "launch_arcology";
/// The effect frames from ignition until liftoff. The dust starts at liftoff.
const LAUNCH_LIFTOFF_FRAMES: i64 = 15;
/// Large view sprites start at this ID.
const LARGE_SPRITE_BASE: i64 = 1000;
/// An effect sprite stands on the top corner of its tile. This large view
/// offset stands the launch fire and dust on the front corner instead.
const LAUNCH_GROUND_OFFSET: Vec2i = Vec2i::new(0, 16);
const DEMOGRAPHIC_RECORD_SIZE: i64 = 0x0c;
const CHANGED_CHUNKS: [&str; 10] = ["ALTM", "XBLD", "XTER", "XZON", "XUND", "XBIT", "XTXT", "XLAB", "XMIC", "MISC"];
const INPUT_CHUNKS: [&str; 10] = ["XBLD", "XTER", "XZON", "XUND", "XBIT", "XTXT", "XLAB", "XMIC", "MISC", "ALTM"];

gd_object! {
    pub struct PowerPlantExpiry as "PowerPlantExpiry" {
        pub record: i64 = 0,
        pub tile: i64 = 0,
        pub x: i64 = 0,
        pub y: i64 = 0,
    }
}

gd_phase_result! {
    pub struct AnnualResult as "MicrosimAnnualPhase.Result" {
        pub updated_subway_records: i64 = 0,
        pub updated_bus_records: i64 = 0,
        pub updated_rail_records: i64 = 0,
        pub updated_hydro_records: i64 = 0,
        pub updated_wind_records: i64 = 0,
        pub updated_city_hall_records: i64 = 0,
        pub updated_museum_records: i64 = 0,
        pub updated_park_records: i64 = 0,
        pub updated_library_records: i64 = 0,
        pub updated_hospital_records: i64 = 0,
        pub updated_police_records: i64 = 0,
        pub updated_fire_records: i64 = 0,
        pub updated_school_records: i64 = 0,
        pub updated_stadium_records: i64 = 0,
        pub updated_prison_records: i64 = 0,
        pub updated_college_records: i64 = 0,
        pub updated_power_records: i64 = 0,
        pub updated_zoo_records: i64 = 0,
        pub updated_statue_records: i64 = 0,
        pub updated_mayor_house_records: i64 = 0,
        pub updated_water_facility_records: i64 = 0,
        pub updated_marina_records: i64 = 0,
        pub updated_arcology_records: i64 = 0,
        pub updated_llamadome_records: i64 = 0,
        pub random_records_pending: i64 = 0,
        pub demolished_power_records: Vec<PowerPlantExpiry> = Vec::new(),
        pub expired_power_records: Vec<PowerPlantExpiry> = Vec::new(),
        pub arcology_launch_pending: bool = false,
        pub arcology_launched: bool = false,
        pub launch_arcology_records: i64 = 0,
        pub launched_structures: i64 = 0,
        pub arcology_launch_staged: bool = false,
        pub passenger_counters_reset: bool = true,
    }
}

gd_phase_result! {
    pub struct LaunchStepResult as "MicrosimAnnualPhase.LaunchStep" {
        pub sites: Vec<Vec2i> = Vec::new(),
        pub wait: i64 = 0,
        pub launched_structures: i64 = 0,
        pub remaining_structures: i64 = 0,
        pub map_changed: bool = false,
    }
}

/// The inputs of one annual update. A missing random generator leaves the
/// records that need it pending, as a null generator does in GDScript.
pub struct AnnualInputs<'a> {
    pub bus_passengers: i64,
    pub rail_passengers: i64,
    pub subway_passengers: i64,
    pub random: Option<&'a mut SimRandom>,
    pub lfsr: Option<&'a mut SimLfsrRandom>,
    pub game: Option<&'a mut GameLcgRandom>,
    pub power_usage_percent: i64,
    pub water_usage_percent: i64,
    pub australian_locale: bool,
    pub mayor_approval: i64,
    /// True to leave the launch arcologies for launch_step. The update still
    /// shows the first notice and pays the launch bonus.
    pub stage_launch: bool,
}

#[derive(Default)]
struct Counts {
    hydro: i64,
    wind: i64,
    city_hall: i64,
    museum: i64,
    park: i64,
    library: i64,
    hospital: i64,
    police: i64,
    fire: i64,
    school: i64,
    stadium: i64,
    prison: i64,
    college: i64,
    power: i64,
    zoo: i64,
    statue: i64,
    mayor_house: i64,
    water_facility: i64,
    marina: i64,
    arcology: i64,
    llamadome: i64,
}

struct Annual<'a, 'b> {
    inputs: &'b mut AnnualInputs<'a>,
    map_edge: i64,
    extended: bool,
    rotation: i64,
    subway_count: i64,
    bus_count: i64,
    rail_count: i64,
    prison_count: i64,
    counts: Counts,
    old_arrests: i64,
    prison_population: i64,
    news_items: Vec<NewsEvent>,
    notice_ids: Vec<i32>,
    random_records_pending: i64,
    low_school_score: bool,
    prison_overcrowded: bool,
    expired_power_records: Vec<PowerPlantExpiry>,
    demolished_power_records: Vec<PowerPlantExpiry>,
    arcology_population: i64,
    arcology_launch_pending: bool,
    launch_arcology_records: i64,
    launched_structures: i64,
    arcology_launched: bool,
    arcology_launch_staged: bool,
    sound_events: Vec<i64>,
    view_center_requests: Vec<Vec2i>,
    effect_events: Vec<EffectEvent>,
    next_effect_frame: i64,
    updated_subway: i64,
    updated_bus: i64,
    updated_rail: i64,
}

fn to_i16(value: i64) -> i64 {
    let word = value & 0xffff;

    if word >= 0x8000 { word - 0x10000 } else { word }
}

fn to_i32(value: i64) -> i64 {
    value as i32 as i64
}

fn tile_count(misc: &[u8], tile: i64, map_edge: i64) -> i64 {
    let value = read_u32_be(misc, misc_layout::TILE_COUNTS + tile * 4);

    if map_edge == 128 { to_i16(value) } else { value }
}

fn budget_funding(misc: &[u8], budget_id: i64) -> i64 {
    read_i32_be(misc, misc_layout::BUDGETS + budget_id * budget::RECORD_SIZE + budget::FUNDING)
}

fn raw_population(misc: &[u8], cohort: i64) -> i64 {
    read_u32_be(misc, misc_layout::POPULATION_TABLE + cohort * DEMOGRAPHIC_RECORD_SIZE)
}

fn arcology_count(misc: &[u8], map_edge: i64) -> i64 {
    (tiles::PLYMOUTH_ARCOLOGY..=tiles::LAUNCH_ARCOLOGY)
        .map(|tile| tile_count(misc, tile, map_edge))
        .sum::<i64>()
        / 16
}

fn service_score(numerator: i64, denominator: i64, slope: i64, best_limit: i64, zero_limit: i64) -> i64 {
    let mut safe = denominator & 0xffff;

    if safe == 0 {
        safe = 1;
    }

    let ratio = numerator / safe;

    if ratio < best_limit {
        12
    } else if ratio < zero_limit {
        (zero_limit - 1 - ratio) / slope
    } else {
        0
    }
}

fn adjusted_population(misc: &[u8], map_edge: i64) -> i64 {
    let count = (tiles::PLYMOUTH_ARCOLOGY..tiles::LLAMA_DOME)
        .map(|tile| tile_count(misc, tile, map_edge))
        .sum::<i64>()
        / 16;
    let adjustment = if count > 140 { (count * 5 - 700) * 4000 } else { 0 };

    read_u32_be(misc, misc_layout::ARCOLOGY_POPULATION) + adjustment + read_u32_be(misc, misc_layout::NORMAL_POPULATION)
}

fn population_cap(misc: &[u8], maximum: i64, divisor: i64, map_edge: i64) -> i64 {
    let divisor = if divisor == 0 { 100 } else { divisor };
    let count = (tiles::PLYMOUTH_ARCOLOGY..tiles::LLAMA_DOME)
        .map(|tile| tile_count(misc, tile, map_edge))
        .sum::<i64>()
        / 16;
    let adjustment = if count >= 141 { count * 20000 - 2800000 } else { 0 };
    let total = adjustment + read_u32_be(misc, misc_layout::ARCOLOGY_POPULATION) + read_u32_be(misc, misc_layout::NORMAL_POPULATION);
    let available = (total / divisor) & if map_edge == 128 { 0xffff } else { 0xffff_ffff };
    let signed_maximum = to_i16(maximum);

    if signed_maximum <= available { signed_maximum } else { available }
}

/// The location of a facility record, or (-1, -1). The origin counts as missing.
fn find_microsim_location(text_overlays: &[u8], record: i64, map_edge: i64) -> Vec2i {
    if overlay::count(text_overlays) != map_edge * map_edge {
        return Vec2i::NONE;
    }

    let text_id = overlay::facility_id(record);

    // a layered index finds the facility under any moving object
    if overlay::is_layered(text_overlays) {
        let found = overlay::find(text_overlays, text_id, 0);

        return if found <= 0 {
            Vec2i::NONE
        } else {
            Vec2i::new(found / map_edge, found % map_edge)
        };
    }

    for x in 0..map_edge {
        crate::sim::budget::checkpoint();

        for y in 0..map_edge {
            if overlay::read(text_overlays, x * map_edge + y) == text_id {
                return if x == 0 && y == 0 { Vec2i::NONE } else { Vec2i::new(x, y) };
            }
        }
    }

    Vec2i::NONE
}

/// Remainder with the GDScript rule for a zero divisor, which yields zero.
fn remainder(value: i64, divisor: i64) -> i64 {
    if divisor == 0 { 0 } else { value % divisor }
}

/// MicrosimAnnualPhase.run.
pub fn run(city: &mut City, inputs: &mut AnnualInputs) -> AnnualResult {
    if inputs.bus_passengers < 0 || inputs.rail_passengers < 0 || inputs.subway_passengers < 0 {
        return AnnualResult::failed("passenger totals cannot be negative");
    }

    let xmic_valid = city.xmic.present && city.xmic.data.len() as i64 == city.decoded_size("XMIC");

    if !xmic_valid || !city.misc.present || city.misc.data.len() as i64 != misc_layout::SIZE {
        return AnnualResult::failed("XMIC or MISC has the wrong size");
    }

    let mut span = TimingSpan::new();
    span.mark("prepare data");

    if city.missing_or_resized(&INPUT_CHUNKS).is_some() {
        return AnnualResult::failed("annual map payloads are missing or invalid");
    }

    let originals: Vec<Vec<u8>> = CHANGED_CHUNKS
        .iter()
        .map(|id| city.chunk(id).map(|chunk| chunk.data.clone()).unwrap_or_default())
        .collect();
    let map_edge = city.map_size;
    let misc = &city.misc.data;
    let mut annual = Annual {
        map_edge,
        extended: city.is_extended(),
        rotation: city.compass_rotation(),
        subway_count: tile_count(misc, tiles::SUBWAY_STATION, map_edge),
        bus_count: tile_count(misc, tiles::BUS_DEPOT, map_edge),
        rail_count: tile_count(misc, tiles::RAIL_STATION, map_edge),
        prison_count: tile_count(misc, tiles::PRISON, map_edge) / 16,
        inputs,
        counts: Counts::default(),
        old_arrests: 0,
        prison_population: 0,
        news_items: Vec::new(),
        notice_ids: Vec::new(),
        random_records_pending: 0,
        low_school_score: false,
        prison_overcrowded: false,
        expired_power_records: Vec::new(),
        demolished_power_records: Vec::new(),
        arcology_population: 0,
        arcology_launch_pending: false,
        launch_arcology_records: 0,
        launched_structures: 0,
        arcology_launched: false,
        arcology_launch_staged: false,
        sound_events: Vec::new(),
        view_center_requests: Vec::new(),
        effect_events: Vec::new(),
        next_effect_frame: 0,
        updated_subway: 0,
        updated_bus: 0,
        updated_rail: 0,
    };
    span.mark("facility records");
    annual.update_facility_records(city, &mut span);
    span.mark("annual totals and arcology launch");

    if annual.inputs.random.is_some() {
        annual.store_prison_and_school_totals(city);
    }

    if annual.inputs.lfsr.is_some() {
        annual.store_arcology_population(city);

        if annual.arcology_launch_pending && annual.inputs.random.is_some() {
            annual.launch_arcologies(city);
        }
    }

    span.mark("compare payloads");

    for (position, id) in CHANGED_CHUNKS.iter().enumerate() {
        if let Some(chunk) = city.chunk_mut(id) {
            chunk.commit_if_changed(&originals[position]);
        }
    }

    span.mark("store annual changes");
    let complete = annual.inputs.random.is_some()
        && annual.inputs.lfsr.is_some()
        && annual.random_records_pending == 0
        && annual.expired_power_records.is_empty()
        && !annual.arcology_launch_pending;
    let counts = &annual.counts;
    let mut result = AnnualResult {
        updated_subway_records: annual.updated_subway,
        updated_bus_records: annual.updated_bus,
        updated_rail_records: annual.updated_rail,
        updated_hydro_records: counts.hydro,
        updated_wind_records: counts.wind,
        updated_city_hall_records: counts.city_hall,
        updated_museum_records: counts.museum,
        updated_park_records: counts.park,
        updated_library_records: counts.library,
        updated_hospital_records: counts.hospital,
        updated_police_records: counts.police,
        updated_fire_records: counts.fire,
        updated_school_records: counts.school,
        updated_stadium_records: counts.stadium,
        updated_prison_records: counts.prison,
        updated_college_records: counts.college,
        updated_power_records: counts.power,
        updated_zoo_records: counts.zoo,
        updated_statue_records: counts.statue,
        updated_mayor_house_records: counts.mayor_house,
        updated_water_facility_records: counts.water_facility,
        updated_marina_records: counts.marina,
        updated_arcology_records: counts.arcology,
        updated_llamadome_records: counts.llamadome,
        random_records_pending: annual.random_records_pending,
        expired_power_records: annual.expired_power_records,
        demolished_power_records: annual.demolished_power_records,
        arcology_launch_pending: annual.arcology_launch_pending,
        arcology_launched: annual.arcology_launched,
        launch_arcology_records: annual.launch_arcology_records,
        launched_structures: annual.launched_structures,
        arcology_launch_staged: annual.arcology_launch_staged,
        ..Default::default()
    };
    result.base.ok = true;
    result.base.news_items = annual.news_items;
    result.base.notice_ids = Ints32(annual.notice_ids);
    result.base.effect_events = annual.effect_events;
    result.base.sound_events = annual.sound_events.into_iter().map(SoundEvent::new).collect();
    result.base.view_center_requests = annual.view_center_requests;
    result.base.complete = complete;
    result.base.timing = span.finish();
    result
}

impl Annual<'_, '_> {
    fn update_facility_records(&mut self, city: &mut City, span: &mut TimingSpan) {
        let records = city.xmic.data.len() as i64 / sc2microsim_layout::RECORD_SIZE;

        for record in 1..records {
            crate::sim::budget::checkpoint();
            let offset = record * sc2microsim_layout::RECORD_SIZE;
            let tile = city.xmic.data[offset as usize] as i64;

            match tile {
                tiles::HYDRO_POWER_1 | tiles::HYDRO_POWER_2 => {
                    let count = tile_count(&city.misc.data, tiles::HYDRO_POWER_1, self.map_edge)
                        + tile_count(&city.misc.data, tiles::HYDRO_POWER_2, self.map_edge);
                    write_u16_be(&mut city.xmic.data, offset + 2, count);
                    write_u16_be(&mut city.xmic.data, offset + 4, count * 20);
                    self.counts.hydro += 1;
                }
                tiles::WIND_POWER => {
                    let count = tile_count(&city.misc.data, tiles::WIND_POWER, self.map_edge);
                    write_u16_be(&mut city.xmic.data, offset + 2, count);
                    write_u16_be(&mut city.xmic.data, offset + 4, count * 4);
                    self.counts.wind += 1;
                }
                tiles::GAS_POWER..=tiles::COAL_POWER => self.update_power(city, span, record, offset, tile),
                tiles::CITY_HALL => {
                    let cap = population_cap(&city.misc.data, 200, 900, self.map_edge);
                    write_u16_be(&mut city.xmic.data, offset + 2, cap);
                    self.counts.city_hall += 1;
                }
                tiles::HOSPITAL => self.update_hospital(city, offset),
                tiles::POLICE_STATION => self.update_police_station(city, offset),
                tiles::FIRE_STATION => self.update_fire_station(city, offset),
                tiles::MUSEUM => self.update_museum(city, offset),
                tiles::BIG_PARK => self.update_big_park(city, offset),
                tiles::SCHOOL => self.update_school(city, offset),
                tiles::STADIUM => self.update_stadium(city, offset),
                tiles::PRISON => self.update_prison(city, offset),
                tiles::COLLEGE => self.update_college(city, offset),
                tiles::ZOO => self.update_zoo(city, offset),
                tiles::STATUE => self.update_statue(city, offset),
                tiles::SUBWAY_STATION => {
                    write_u16_be(&mut city.xmic.data, offset + 2, self.subway_count);
                    write_u16_be(&mut city.xmic.data, offset + 6, self.inputs.subway_passengers);
                    self.updated_subway += 1;
                }
                tiles::BUS_DEPOT => {
                    write_u16_be(&mut city.xmic.data, offset + 2, self.bus_count / 4);
                    write_u16_be(&mut city.xmic.data, offset + 4, self.bus_count);
                    write_u16_be(&mut city.xmic.data, offset + 6, self.inputs.bus_passengers);
                    self.updated_bus += 1;
                }
                tiles::RAIL_STATION => {
                    write_u16_be(&mut city.xmic.data, offset + 2, self.rail_count / 4);
                    write_u16_be(&mut city.xmic.data, offset + 6, self.inputs.rail_passengers);
                    self.updated_rail += 1;
                }
                tiles::MAYOR_HOUSE => self.update_mayor_house(city, offset),
                tiles::WATER_TREATMENT | tiles::DESALINIZATION => self.update_water_treatment(city, offset),
                tiles::LIBRARY => self.update_library(city, offset),
                tiles::MARINA => self.update_marina(city, offset),
                tiles::PLYMOUTH_ARCOLOGY..=tiles::LAUNCH_ARCOLOGY => self.update_arcology(city, offset, tile),
                tiles::LLAMA_DOME => self.update_llamadome(city, offset),
                _ => {}
            }
        }
    }

    fn store_prison_and_school_totals(&mut self, city: &mut City) {
        let misc = &mut city.misc.data;
        write_u32_be(misc, misc_layout::OLD_ARRESTS, self.old_arrests);
        let bonus = if self.prison_count < 1 || self.prison_population / self.prison_count > 79 {
            0
        } else {
            1
        };
        write_u32_be(misc, misc_layout::PRISON_BONUS, bonus);

        if self.low_school_score {
            self.news_items.push(NewsEvent::new(NEWS_EDUCATION, 0));
        }

        if self.prison_overcrowded {
            self.news_items.push(NewsEvent::new(NEWS_PRISON, 0));
        }
    }

    fn store_arcology_population(&mut self, city: &mut City) {
        write_u32_be(&mut city.misc.data, misc_layout::ARCOLOGY_POPULATION, self.arcology_population);
        self.arcology_launch_pending =
            tile_count(&city.misc.data, tiles::LAUNCH_ARCOLOGY, self.map_edge) / 16 > 300 && self.arcology_population > 6000000;
    }

    /// Demolish every launch arcology, pay the launch bonus, and request the
    /// notices that the original shows before and after the launch. The
    /// original scans XBLD for the launch arcology tile. XTXT 0xfe is a riot
    /// marker and does not mark a launch arcology.
    ///
    /// A staged launch leaves the arcologies and the second notice to
    /// launch_step, so the player can see each arcology go.
    fn launch_arcologies(&mut self, city: &mut City) {
        self.notice_ids.push(NOTICE_ARCOLOGY_LAUNCH_START);

        if !self.inputs.stage_launch {
            self.demolish_launch_arcologies(city);
        }

        let funds = read_i32_be(&city.misc.data, misc_layout::FUNDS);
        write_u32_be(
            &mut city.misc.data,
            misc_layout::FUNDS,
            to_i32(funds + self.launch_arcology_records * 100000),
        );

        if self.inputs.stage_launch {
            self.arcology_launch_staged = true;
        } else {
            self.notice_ids.push(NOTICE_ARCOLOGY_LAUNCH_END);
        }

        self.arcology_launched = true;
        self.arcology_launch_pending = false;
    }

    fn demolish_launch_arcologies(&mut self, city: &mut City) {
        let edge = self.map_edge;

        for x in 0..edge {
            for y in 0..edge {
                if city.xbld.data[(x * edge + y) as usize] as i64 != tiles::LAUNCH_ARCOLOGY {
                    continue;
                }

                let random = self.inputs.random.as_deref_mut().expect("the launch needs a random generator");
                let mut maps = city.maps();
                let demolition = demolish::damage_structure(&mut maps, Vec2i::new(x, y), random, self.rotation, true);

                if demolition.changed {
                    self.next_effect_frame =
                        demolish::append_effect_sequence(&mut self.effect_events, &demolition.effect_events, self.next_effect_frame);
                    self.launched_structures += 1;
                    self.sound_events.push(SOUND_EXPLOSION);
                }
            }
        }
    }

    fn update_power(&mut self, city: &mut City, span: &mut TimingSpan, record: i64, offset: i64, tile: i64) {
        let Some(random) = self.inputs.random.as_deref_mut() else {
            self.random_records_pending += 1;
            return;
        };

        let age = offset as usize + 1;
        city.xmic.data[age] = city.xmic.data[age].wrapping_add(1);
        let power_random = random.next_u15();

        if self.inputs.power_usage_percent >= 0 {
            write_u16_be(
                &mut city.xmic.data,
                offset + 4,
                (power_random & 0x07) + self.inputs.power_usage_percent,
            );
        } else {
            self.random_records_pending += 1;
        }

        if city.xmic.data[age] > 48 {
            self.news_items.push(NewsEvent::new(NEWS_POWER_PLANT, tile + 0x37));
        }

        if city.xmic.data[age] > 50 {
            span.mark("expired plant search and demolition");
            let location = find_microsim_location(&city.xtxt.data, record, self.map_edge);

            if location.x >= 0 {
                let plant_cost = match tile {
                    tiles::GAS_POWER => 2000,
                    tiles::OIL_POWER => 6600,
                    tiles::NUCLEAR_POWER => 15000,
                    tiles::SOLAR_POWER => 1300,
                    tiles::MICROWAVE_POWER => 28000,
                    tiles::FUSION_POWER => 40000,
                    tiles::COAL_POWER => 4000,
                    _ => 0,
                };
                let funds = read_i32_be(&city.misc.data, misc_layout::FUNDS);

                if read_u32_be(&city.misc.data, misc_layout::NO_DISASTERS) != 0 && funds >= plant_cost {
                    write_u32_be(&mut city.misc.data, misc_layout::FUNDS, funds - plant_cost);
                    city.xmic.data[age] = 0;
                } else {
                    let expired = PowerPlantExpiry {
                        record,
                        tile,
                        x: location.x,
                        y: location.y,
                    };
                    let random = self.inputs.random.as_deref_mut().expect("checked above");
                    let mut maps = city.maps();
                    let demolition = demolish::damage_structure(&mut maps, location, random, self.rotation, true);

                    if demolition.changed {
                        self.next_effect_frame =
                            demolish::append_effect_sequence(&mut self.effect_events, &demolition.effect_events, self.next_effect_frame);
                        self.demolished_power_records.push(expired);
                        self.sound_events.push(SOUND_EXPLOSION);

                        if read_u32_be(&city.misc.data, misc_layout::AUTO_GOTO) != 0 {
                            self.view_center_requests.push(location);
                        }
                    } else {
                        self.expired_power_records.push(expired);
                    }
                }
            }
        }

        span.mark("facility records");
        self.counts.power += 1;
    }

    fn update_water_treatment(&mut self, city: &mut City, offset: i64) {
        let Some(random) = self.inputs.random.as_deref_mut() else {
            self.random_records_pending += 1;
            return;
        };

        let first = random.next_u15();
        let second = random.next_u15();
        let third = random.next_u15();

        if self.inputs.water_usage_percent >= 0 {
            city.xmic.data[offset as usize + 1] = ((first & 0x07) + self.inputs.water_usage_percent) as u8;
        } else {
            self.random_records_pending += 1;
        }

        write_u16_be(&mut city.xmic.data, offset + 2, second % 100);
        let population = read_u32_be(&city.misc.data, misc_layout::NORMAL_POPULATION);
        write_u16_be(&mut city.xmic.data, offset + 4, ((third & 0x1f) + 135).min(population / 50));
        self.counts.water_facility += 1;
    }

    fn update_arcology(&mut self, city: &mut City, offset: i64, tile: i64) {
        let Some(lfsr) = self.inputs.lfsr.as_deref_mut() else {
            self.random_records_pending += 1;
            return;
        };

        let misc = &city.misc.data;
        let microsims = &mut city.xmic.data;
        let count = arcology_count(misc, self.map_edge).max(1);
        let capacity = read_u16_be(microsims, offset + 2);
        let arcology_capacity = population_cap(misc, to_i16((capacity * 1000) / 10), count * 20, self.map_edge) & 0xffff;
        let tax_effect =
            (60 - budget_funding(misc, 0) - budget_funding(misc, 1) - budget_funding(misc, 2)) / 6 + microsims[offset as usize + 1] as i64;
        let growth = ((tax_effect * 5 - 50) * 40).min(arcology_capacity);
        let population = read_u16_be(microsims, offset + 4);
        let next_population = (growth + population / 50 + population).min(capacity * 1000);
        let record_population = to_i16(lfsr.next_mask(0x3f)) + to_i16(next_population);
        write_u16_be(microsims, offset + 4, record_population);
        self.arcology_population = to_i32(self.arcology_population + (record_population & 0xffff));

        if tile == tiles::LAUNCH_ARCOLOGY {
            self.launch_arcology_records += 1;
        }

        self.counts.arcology += 1;
    }

    fn update_museum(&mut self, city: &mut City, offset: i64) {
        let misc = &city.misc.data;
        let museum_count = tile_count(misc, tiles::MUSEUM, self.map_edge);
        let college_funding = budget_funding(misc, budget::COLLEGE);
        let cap = population_cap(misc, to_i16(museum_count * college_funding * 4), 20, self.map_edge);
        write_u16_be(&mut city.xmic.data, offset + 2, cap);
        write_u16_be(&mut city.xmic.data, offset + 4, (college_funding / 10) * museum_count);
        self.counts.museum += 1;
    }

    fn update_big_park(&mut self, city: &mut City, offset: i64) {
        let misc = &city.misc.data;
        let old_visitors = read_u16_be(&city.xmic.data, offset + 4);
        let mut visitors = (old_visitors * 412).min(65000);
        visitors = visitors.min((read_u32_be(misc, misc_layout::NORMAL_POPULATION) / 6).min(65000));
        let park_count = tile_count(misc, tiles::SMALL_PARK, self.map_edge) + tile_count(misc, tiles::BIG_PARK, self.map_edge);
        let cap = population_cap(misc, park_count / 9, 120, self.map_edge);
        write_u16_be(&mut city.xmic.data, offset + 2, visitors);
        write_u16_be(&mut city.xmic.data, offset + 4, park_count);
        write_u16_be(&mut city.xmic.data, offset + 6, cap);
        self.counts.park += 1;
    }

    fn update_stadium(&mut self, city: &mut City, offset: i64) {
        let Some(random) = self.inputs.random.as_deref_mut() else {
            self.random_records_pending += 1;
            return;
        };

        let misc = &city.misc.data;
        let stadium_count = tile_count(misc, tiles::STADIUM, self.map_edge).max(1);
        let mut visitors = adjusted_population(misc, self.map_edge) / stadium_count;

        if visitors > 25000 {
            visitors = 25000 - (random.next_u15() & 0xff);
        }

        visitors = population_cap(misc, to_i16(visitors), 5, self.map_edge);
        let stored = visitors + (random.next_u15() & 0xff);
        write_u16_be(&mut city.xmic.data, offset + 2, stored);
        city.xmic.data[offset as usize + 1] = ((random.next_u15() & 0x1f) + 9) as u8;
        self.counts.stadium += 1;
    }

    fn update_zoo(&mut self, city: &mut City, offset: i64) {
        let Some(game) = self.inputs.game.as_deref_mut() else {
            self.random_records_pending += 1;
            return;
        };

        city.xmic.data[offset as usize + 1] = game.next_mod(100) as u8;
        write_u16_be(&mut city.xmic.data, offset + 2, game.next_mod(100));
        write_u16_be(&mut city.xmic.data, offset + 4, game.next_mod(100));
        write_u16_be(&mut city.xmic.data, offset + 6, game.next_mod(100));
        self.counts.zoo += 1;
    }

    fn update_statue(&mut self, city: &mut City, offset: i64) {
        let Some(random) = self.inputs.random.as_deref_mut() else {
            self.random_records_pending += 1;
            return;
        };

        write_u16_be(&mut city.xmic.data, offset + 4, random.next_u15() % 42);
        self.counts.statue += 1;
    }

    fn update_mayor_house(&mut self, city: &mut City, offset: i64) {
        let microsims = &mut city.xmic.data;
        write_u16_be(microsims, offset + 4, self.inputs.mayor_approval);
        let remaining = read_u16_be(microsims, offset + 6);

        if remaining != 0 {
            write_u16_be(microsims, offset + 6, remaining - 1);
            microsims[offset as usize + 1] = microsims[offset as usize + 1].wrapping_add(1);
        }

        self.counts.mayor_house += 1;
    }

    fn update_library(&mut self, city: &mut City, offset: i64) {
        let misc = &city.misc.data;
        let microsims = &mut city.xmic.data;
        let library_count = tile_count(misc, tiles::LIBRARY, self.map_edge);
        let school_funding = budget_funding(misc, budget::SCHOOL);
        write_u16_be(
            microsims,
            offset + 2,
            population_cap(misc, to_i16(library_count * school_funding * 4), 18, self.map_edge),
        );
        let books = read_u16_be(microsims, offset + 4) + (school_funding - 50) * library_count;

        if books > 0 && books < 32000 {
            write_u16_be(microsims, offset + 4, books);
        }

        let population = read_u32_be(misc, misc_layout::NORMAL_POPULATION).max(1);
        let score = (library_count * school_funding * 300) / population;
        microsims[offset as usize + 1] = score.min(12) as u8;
        self.counts.library += 1;
    }

    fn update_marina(&mut self, city: &mut City, offset: i64) {
        let Some(lfsr) = self.inputs.lfsr.as_deref_mut() else {
            self.random_records_pending += 1;
            return;
        };

        let misc = &city.misc.data;
        let boats = lfsr.next_mod(20) + tile_count(misc, tiles::MARINA, self.map_edge) * 8;
        write_u16_be(
            &mut city.xmic.data,
            offset + 2,
            population_cap(misc, to_i16(boats), 150, self.map_edge),
        );
        self.counts.marina += 1;
    }

    fn update_llamadome(&mut self, city: &mut City, offset: i64) {
        let Some(random) = self.inputs.random.as_deref_mut() else {
            self.random_records_pending += 1;
            return;
        };

        let population = read_u32_be(&city.misc.data, misc_layout::NORMAL_POPULATION);
        let microsims = &mut city.xmic.data;

        if self.inputs.australian_locale {
            let visitors = (random.next_u15() & 0x3ff) + (population >> 3);
            write_u16_be(microsims, offset + 2, visitors);
            microsims[offset as usize + 1] = (random.next_u15() & 0x7f) as u8;
            let events = (random.next_u15() & 0x7f) + 10;
            write_u16_be(microsims, offset + 4, events);
        } else {
            microsims[offset as usize + 1] = (random.next_u15() & 0xff) as u8;
            let dome_population = (population >> 3) + (random.next_u15() & 0x3ff);
            write_u16_be(microsims, offset + 2, dome_population);
            let events = (random.next_u15() & 0x7f) + (dome_population >> 3);
            write_u16_be(microsims, offset + 4, events);
            let staff = (random.next_u15() & 0x3f) + (dome_population >> 4);
            write_u16_be(microsims, offset + 6, staff);
        }

        self.counts.llamadome += 1;
    }

    fn update_hospital(&mut self, city: &mut City, offset: i64) {
        let Some(random) = self.inputs.random.as_deref_mut() else {
            self.random_records_pending += 1;
            return;
        };

        let misc = &city.misc.data;
        let microsims = &mut city.xmic.data;
        let health_funding = budget_funding(misc, budget::HEALTH);
        write_u16_be(microsims, offset + 6, health_funding / 2);
        let divisor = ((tile_count(misc, tiles::HOSPITAL, self.map_edge) / 9) * 25).max(1);
        let mut patients = read_u32_be(misc, misc_layout::NORMAL_POPULATION) / divisor + (random.next_u15() & 0x0f);

        if patients > 1000 {
            patients = (random.next_u15() & 0x7f) + 1000;
        }

        let capacity = population_cap(misc, to_i16(patients), 30, self.map_edge);
        write_u16_be(microsims, offset + 2, capacity);
        let quality = (health_funding + (random.next_u15() & 0x07) + microsims[offset as usize + 1] as i64 * 2 - 24).max(0);
        let staff = population_cap(misc, to_i16(quality), 120, self.map_edge);
        write_u16_be(microsims, offset + 4, staff);
        microsims[offset as usize + 1] = service_score(capacity * 10, staff, 5, 50, 111) as u8;
        self.counts.hospital += 1;
    }

    fn update_police_station(&mut self, city: &mut City, offset: i64) {
        let Some(random) = self.inputs.random.as_deref_mut() else {
            self.random_records_pending += 1;
            return;
        };

        let misc = &city.misc.data;
        let microsims = &mut city.xmic.data;
        let police_funding = budget_funding(misc, budget::POLICE);
        microsims[offset as usize + 1] = police_funding as u8;
        write_u16_be(
            microsims,
            offset + 2,
            population_cap(misc, to_i16(police_funding * 2), 90, self.map_edge),
        );
        let police_count = tile_count(misc, tiles::POLICE_STATION, self.map_edge).max(1);
        let crime_per_station = read_u32_be(misc, misc_layout::CITY_CRIME) / police_count;
        write_u16_be(microsims, offset + 4, crime_per_station);
        let arrest_divisor = (5 - read_u32_be(misc, misc_layout::PRISON_BONUS)).max(1);
        let arrests = (random.next_u15() & 0x0f) + crime_per_station / arrest_divisor;
        write_u16_be(microsims, offset + 6, arrests);
        self.old_arrests = (self.old_arrests + (arrests & 0xffff)).min(0xffff);
        self.counts.police += 1;
    }

    fn update_fire_station(&mut self, city: &mut City, offset: i64) {
        let Some(random) = self.inputs.random.as_deref_mut() else {
            self.random_records_pending += 1;
            return;
        };

        let misc = &city.misc.data;
        let microsims = &mut city.xmic.data;
        let fire_funding = budget_funding(misc, budget::FIRE);
        microsims[offset as usize + 1] = fire_funding as u8;
        let capacity = population_cap(misc, to_i16(fire_funding / 2), 70, self.map_edge);
        write_u16_be(microsims, offset + 2, capacity);
        write_u16_be(microsims, offset + 4, ((capacity & 0xffff) >> 4) + 1);
        write_u16_be(microsims, offset + 6, random.next_u15() % 20 + 2);
        self.counts.fire += 1;
    }

    fn update_school(&mut self, city: &mut City, offset: i64) {
        let Some(random) = self.inputs.random.as_deref_mut() else {
            self.random_records_pending += 1;
            return;
        };

        let misc = &city.misc.data;
        let microsims = &mut city.xmic.data;
        let school_funding = budget_funding(misc, budget::SCHOOL);
        let quarter = school_funding / 4;
        write_u16_be(microsims, offset + 6, quarter);

        if quarter & 0xffff < 20 {
            self.news_items.push(NewsEvent::new(NEWS_EDUCATION, 0));
        }

        let school_count = (tile_count(misc, tiles::SCHOOL, self.map_edge) / 9).max(1);
        let mut students = (raw_population(misc, 1) + raw_population(misc, 2)) / school_count + (random.next_u15() & 0x0f);

        if students > 1500 {
            students = (random.next_u15() & 0xff) + 1500;
        }

        let capacity = population_cap(misc, to_i16(students), 20, self.map_edge);
        write_u16_be(microsims, offset + 2, capacity);
        let quality = ((random.next_u15() & 0x07) + (school_funding * 6) / 10 + microsims[offset as usize + 1] as i64 - 12).max(0);
        let staff = population_cap(misc, to_i16(quality), 100, self.map_edge);
        write_u16_be(microsims, offset + 4, staff);
        let score = service_score(capacity, staff, 3, 15, 52);
        microsims[offset as usize + 1] = score as u8;
        self.low_school_score = self.low_school_score || score < 4;
        self.counts.school += 1;
    }

    fn update_prison(&mut self, city: &mut City, offset: i64) {
        let Some(random) = self.inputs.random.as_deref_mut() else {
            self.random_records_pending += 1;
            return;
        };

        let misc = &city.misc.data;
        let microsims = &mut city.xmic.data;
        let divisor = self.prison_count.max(1);
        let stored = read_u16_be(microsims, offset + 2);
        let mut prisoners = stored - stored / 4 + read_u32_be(misc, misc_layout::OLD_ARRESTS) / divisor;

        if prisoners > 10000 {
            prisoners = (random.next_u15() & 0x3ff) + 10000;
        }

        write_u16_be(microsims, offset + 2, population_cap(misc, to_i16(prisoners), 20, self.map_edge));
        let police_funding = budget_funding(misc, budget::POLICE);
        write_u16_be(
            microsims,
            offset + 4,
            population_cap(misc, to_i16(police_funding * 3), 120, self.map_edge),
        );
        let prison_stat = prisoners / 100;
        write_u16_be(microsims, offset + 6, prison_stat);
        self.prison_population += to_i16(prison_stat);

        if !self.extended {
            self.prison_population &= 0xffff;
        }

        // More than 105 hundred prisoners is only possible after the 10,000 limit.
        if prison_stat > 105 {
            self.prison_overcrowded = true;
        }

        if prison_stat < 91 {
            microsims[offset as usize + 1] = 0;
        } else {
            let range = prison_stat - 90 + (100 - police_funding) / 10;
            microsims[offset as usize + 1] = remainder(random.next_u15(), range) as u8;
        }

        self.counts.prison += 1;
    }

    fn update_college(&mut self, city: &mut City, offset: i64) {
        let Some(random) = self.inputs.random.as_deref_mut() else {
            self.random_records_pending += 1;
            return;
        };

        let misc = &city.misc.data;
        let microsims = &mut city.xmic.data;
        let college_funding = budget_funding(misc, budget::COLLEGE);
        write_u16_be(microsims, offset + 6, college_funding);
        let college_count = (tile_count(misc, tiles::COLLEGE, self.map_edge) / 16).max(1);
        let mut students = raw_population(misc, 3) / college_count + (random.next_u15() & 0x1f);

        if students > 5000 {
            students = (random.next_u15() & 0x1ff) + 5000;
        }

        let capacity = population_cap(misc, to_i16(students), 30, self.map_edge);
        write_u16_be(microsims, offset + 2, capacity);
        let quality = ((random.next_u15() & 0x0f) + college_funding * 2 + microsims[offset as usize + 1] as i64 * 4 - 48).max(0);
        let staff = population_cap(misc, to_i16(quality), 100, self.map_edge);
        write_u16_be(microsims, offset + 4, staff);
        microsims[offset as usize + 1] = service_score(capacity * 4, staff, 5, 50, 111) as u8;
        self.counts.college += 1;
    }
}

/// One step of a staged arcology launch. `sites` holds the origins of the
/// launch arcologies that wait to ignite, and `wait` the steps until the last
/// flight ends. Each step ignites one random waiting arcology. The ignition
/// turns the arcology to rubble at once: the renderer then draws it as it
/// burns, shakes, and flies away. An empty `sites` with no `wait` scans the
/// map again. The end of the last flight requests the second launch notice.
///
/// The fire is a visual effect only. It cannot spread.
pub fn launch_step(city: &mut City, random: &mut SimRandom, sites: Vec<Vec2i>, wait: i64, steps: i64) -> LaunchStepResult {
    if city.missing_or_resized(&INPUT_CHUNKS).is_some() {
        return LaunchStepResult::failed("launch map payloads are missing or invalid");
    }

    let originals: Vec<Vec<u8>> = CHANGED_CHUNKS
        .iter()
        .map(|id| city.chunk(id).map(|chunk| chunk.data.clone()).unwrap_or_default())
        .collect();
    let mut result = LaunchStepResult {
        sites,
        wait: wait.max(0),
        ..Default::default()
    };

    if result.sites.is_empty() && result.wait == 0 {
        result.sites = launch_sites(city);
    }

    for _ in 0..steps.max(0) {
        if result.sites.is_empty() && result.wait == 0 {
            break;
        }

        if result.sites.is_empty() {
            result.wait -= 1;
            continue;
        }

        let draw = (random.next_u15() << 15) | random.next_u15();
        let site = result.sites.swap_remove(draw as usize % result.sites.len());
        result.wait = LAUNCH_LEAD_STEPS;
        ignite_launch_arcology(city, site, random, &mut result);
    }

    result.remaining_structures = result.sites.len() as i64;
    result.map_changed = result.launched_structures > 0;

    if result.map_changed {
        result.base.sound_events.push(SoundEvent::new(SOUND_EXPLOSION));
    }

    let finished = result.sites.is_empty() && result.wait == 0;

    if finished {
        result.base.notice_ids.0.push(NOTICE_ARCOLOGY_LAUNCH_END);
    }

    for (position, id) in CHANGED_CHUNKS.iter().enumerate() {
        if let Some(chunk) = city.chunk_mut(id) {
            chunk.commit_if_changed(&originals[position]);
        }
    }

    result.base.ok = true;
    result.base.complete = finished;
    result
}

/// Request the fire and the flight of the arcology at `site`, then change it
/// to rubble. Its dust starts at liftoff, when the rubble comes into view.
fn ignite_launch_arcology(city: &mut City, site: Vec2i, random: &mut SimRandom, result: &mut LaunchStepResult) {
    let edge = city.map_size;
    let last = LAUNCH_ARCOLOGY_EDGE - 1;

    if site.x + last >= edge || site.y + last >= edge {
        return;
    }

    // the painter draws a building from its screen-left corner, at that depth
    let anchor = Vec2i::new(site.x, site.y + last);
    let index = anchor.x * edge + anchor.y;

    if city.xbld.data[index as usize] as i64 != tiles::LAUNCH_ARCOLOGY {
        return;
    }

    let rotation = city.compass_rotation();
    let height = demolish::effect_altitude(&city.altm.data, &city.xbit.data, index);
    // an odd compass rotation mirrors buildings
    let flip = (city.xbit.data[index as usize] as i64 & flag_bits::FLIPPED != 0) ^ (rotation & 1 != 0);
    let right_edge = (0..LAUNCH_ARCOLOGY_EDGE).map(|offset| Vec2i::new(site.x + last, site.y + offset));
    let left_edge = (0..last).map(|offset| Vec2i::new(site.x + offset, site.y + last));
    let effects = &mut result.base.effect_events;
    effects.push(EffectEvent {
        type_: LAUNCH_ARCOLOGY_EFFECT.to_string(),
        point: anchor,
        depth_point: anchor,
        sprite_id: LARGE_SPRITE_BASE + tiles::LAUNCH_ARCOLOGY,
        flip,
        altitude: height,
        frames: LAUNCH_LIFTOFF_FRAMES,
        ..Default::default()
    });

    for point in right_edge.chain(left_edge) {
        effects.push(EffectEvent {
            type_: LAUNCH_FIRE_EFFECT.to_string(),
            point,
            screen_offset: LAUNCH_GROUND_OFFSET,
            depth_point: anchor,
            altitude: height,
            frames: LAUNCH_FIRE_FRAMES,
            ..Default::default()
        });
    }

    let mut maps = city.maps();
    let demolition = demolish::damage_structure(&mut maps, site, random, rotation, true);

    if demolition.changed {
        let dust: Vec<EffectEvent> = demolition
            .effect_events
            .iter()
            .map(|event| EffectEvent {
                screen_offset: event.screen_offset + LAUNCH_GROUND_OFFSET,
                ..event.clone()
            })
            .collect();
        demolish::append_effect_sequence(effects, &dust, LAUNCH_LIFTOFF_FRAMES);
        result.launched_structures += 1;
    }
}

/// The origin of each launch arcology. A scan in map order meets the origin
/// of a whole 4×4 arcology before its other tiles.
fn launch_sites(city: &City) -> Vec<Vec2i> {
    let edge = city.map_size;
    let mut claimed = vec![false; city.xbld.data.len()];
    let mut sites = Vec::new();

    for x in 0..edge {
        for y in 0..edge {
            let index = (x * edge + y) as usize;

            if claimed[index] || city.xbld.data[index] as i64 != tiles::LAUNCH_ARCOLOGY {
                continue;
            }

            sites.push(Vec2i::new(x, y));

            for claim_x in x..(x + LAUNCH_ARCOLOGY_EDGE).min(edge) {
                for claim_y in y..(y + LAUNCH_ARCOLOGY_EDGE).min(edge) {
                    claimed[(claim_x * edge + claim_y) as usize] = true;
                }
            }
        }
    }

    sites
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::sim::bytes::write_u32_be;
    use crate::sim::testing::empty_city;

    /// Classic cities read 16-bit signed counts. Larger maps read full counts.
    #[test]
    fn counts_and_population_caps_keep_the_map_width() {
        for edge in [16i64, 32, 64, 128, 256, 384, 512, 640, 1024] {
            let mut city = empty_city(edge);
            write_u32_be(&mut city.misc.data, misc_layout::TILE_COUNTS + 0xd2 * 4, 40000);
            assert_eq!(tile_count(&city.misc.data, 0xd2, edge), if edge == 128 { -25536 } else { 40000 });
            write_u32_be(&mut city.misc.data, misc_layout::NORMAL_POPULATION, 65536 * 900);
            assert_eq!(
                population_cap(&city.misc.data, 200, 900, edge),
                if edge == 128 { 0 } else { 200 },
                "availability does not wrap"
            );
        }
    }

    /// The annual facility lookup finds the last extended record at the far map edge.
    #[test]
    fn facility_lookup_finds_far_extended_records() {
        for edge in [16i64, 128, 512, 1024] {
            let mut city = empty_city(edge);
            let record = city.xmic.data.len() as i64 / sc2microsim_layout::RECORD_SIZE - 1;
            let origin = Vec2i::new(edge - 3, edge - 3);
            overlay::write(&mut city.xtxt.data, origin.x * edge + origin.y, overlay::facility_id(record));
            assert_eq!(find_microsim_location(&city.xtxt.data, record, edge), origin);
        }
    }
}
