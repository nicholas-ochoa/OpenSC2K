//! Facility records for new buildings, as BuildingFacilities.
//!
//! A new facility gets a microsimulation record in XMIC, a label in XLAB, and
//! the label ID in XTXT. Shared categories use fixed records.

use crate::formats::sc2x::labels as label_records;
use crate::formats::sc2x::limits;
use crate::sim::bytes::{read_i32_be, read_u16_be, read_u32_be, write_u16_be};
use crate::sim::city::City;
use crate::sim::ids::building_tile_ids::*;
use crate::sim::ids::sc2budget_layout as budget_layout;
use crate::sim::ids::sc2microsim_layout::RECORD_SIZE;
use crate::sim::ids::sc2misc_layout as misc_layout;
use crate::sim::overlay;
use crate::sim::random::SimRandom;

/// The first record that a single facility may own.
pub const DYNAMIC_FIRST: i64 = 10;

/// The highest microsimulation type that owns one record per facility.
const LAST_INDIVIDUAL_TYPE: i64 = 16;

/// FacilityMetadata.MICROSIM_TYPE_BY_TILE. Zero for other tiles.
pub fn microsim_type(tile: i64) -> i64 {
    match tile {
        HYDRO_POWER_1 | HYDRO_POWER_2 => 21,
        WIND_POWER => 20,
        GAS_POWER | OIL_POWER | NUCLEAR_POWER | SOLAR_POWER | MICROWAVE_POWER | FUSION_POWER | COAL_POWER => 1,
        CITY_HALL => 2,
        HOSPITAL => 3,
        POLICE_STATION => 4,
        FIRE_STATION => 5,
        MUSEUM => 23,
        BIG_PARK => 22,
        SCHOOL => 6,
        STADIUM => 7,
        PRISON => 8,
        COLLEGE => 9,
        ZOO => 10,
        STATUE => 11,
        SUBWAY_STATION => 19,
        BUS_DEPOT => 17,
        RAIL_STATION => 18,
        MAYOR_HOUSE => 12,
        WATER_TREATMENT => 13,
        LIBRARY => 24,
        MARINA => 25,
        DESALINIZATION => 14,
        PLYMOUTH_ARCOLOGY | FOREST_ARCOLOGY | DARCO_ARCOLOGY | LAUNCH_ARCOLOGY => 15,
        LLAMA_DOME => 16,
        _ => 0,
    }
}

/// FacilityMetadata.BUDGET_CATEGORY_BY_TILE.
pub fn budget_category(tile: i64) -> Option<i64> {
    match tile {
        HOSPITAL => Some(budget_layout::HEALTH),
        POLICE_STATION => Some(budget_layout::POLICE),
        FIRE_STATION => Some(budget_layout::FIRE),
        SCHOOL => Some(budget_layout::SCHOOL),
        COLLEGE => Some(budget_layout::COLLEGE),
        _ => None,
    }
}

/// BuildingConstants.DEFAULT_MICROSIM_LABELS.
fn default_label(tile: i64) -> &'static str {
    match tile {
        HYDRO_POWER_1 | HYDRO_POWER_2 => "Hydro Power",
        WIND_POWER => "Wind Power",
        GAS_POWER => "Gas Power",
        OIL_POWER => "Oil Power",
        NUCLEAR_POWER => "Nuclear Power",
        SOLAR_POWER => "Solar Power",
        MICROWAVE_POWER => "Microwave Power",
        FUSION_POWER => "Fusion Power",
        COAL_POWER => "Coal Power",
        CITY_HALL => "City Hall",
        HOSPITAL => "Hospital",
        POLICE_STATION => "Police Station",
        FIRE_STATION => "Fire Station",
        MUSEUM => "Museum",
        BIG_PARK => "SimPark System",
        SCHOOL => "School",
        STADIUM => "Stadium",
        PRISON => "Prison",
        COLLEGE => "College",
        ZOO => "Zoo",
        STATUE => "Statue",
        SUBWAY_STATION => "SimSubway",
        BUS_DEPOT => "SimBus System",
        RAIL_STATION => "SimRail System",
        MAYOR_HOUSE => "Mayor's House",
        WATER_TREATMENT => "Water Treatment",
        LIBRARY => "Library System",
        MARINA => "Marina",
        DESALINIZATION => "Desalinization",
        PLYMOUTH_ARCOLOGY => "Plymouth Arco",
        FOREST_ARCOLOGY => "Forest Arco",
        DARCO_ARCOLOGY => "Darco",
        LAUNCH_ARCOLOGY => "Launch Arco",
        LLAMA_DOME => "Llama Dome",
        _ => "",
    }
}

/// The individual records that new facilities of an SC2X version 4 city may
/// use, or -1 for other cities, which keep the original allocation.
pub fn individual_record_budget(city: &City) -> i64 {
    if !city.is_sc2x_working() {
        return -1;
    }

    limits::profile_for(city.map_size as usize).map_or(0, |profile| profile.facilities as i64) - DYNAMIC_FIRST
}

fn record_count(microsims: &[u8]) -> i64 {
    microsims.len() as i64 / RECORD_SIZE
}

fn record_tile(microsims: &[u8], record: i64) -> i64 {
    microsims[(record * RECORD_SIZE) as usize] as i64
}

pub fn active_individual_records(microsims: &[u8]) -> i64 {
    (DYNAMIC_FIRST..record_count(microsims))
        .filter(|&record| record_tile(microsims, record) != 0)
        .count() as i64
}

/// True when a facility of `tile` can get its record. Shared categories use
/// their fixed slots. A negative budget keeps the original rules.
pub fn record_available(microsims: &[u8], tile: i64, record_budget: i64) -> bool {
    let kind = microsim_type(tile);

    if record_budget < 0 || kind == 0 || kind > LAST_INDIVIDUAL_TYPE {
        return true;
    }

    if active_individual_records(microsims) >= record_budget {
        return false;
    }

    (DYNAMIC_FIRST..record_count(microsims)).any(|record| record_tile(microsims, record) == 0)
}

pub fn record_pool_message(record_budget: i64) -> String {
    format!("All {record_budget} facility records are in use. Demolish a facility before you build another one.")
}

/// The city values that a new record reads.
pub struct Provision<'a> {
    pub tile: i64,
    pub current_year: i64,
    pub misc: &'a [u8],
    pub australian_locale: bool,
    pub scurk_place_mode: bool,
    pub record_budget: i64,
    /// Every record before this one is in use.
    pub first_free: i64,
}

/// BuildingFacilities.provision_microsim. Returns the facility label ID, or 0
/// when the tile has no record or no record is free.
pub fn provision_microsim(
    microsims: &mut [u8],
    labels: &mut [u8],
    text_overlays: &mut [u8],
    request: &Provision,
    random: &mut SimRandom,
) -> i64 {
    let tile = request.tile;
    let kind = microsim_type(tile);

    if kind == 0 || !record_available(microsims, tile, request.record_budget) {
        return 0;
    }

    let mut record = if kind <= LAST_INDIVIDUAL_TYPE {
        (request.first_free.max(DYNAMIC_FIRST)..record_count(microsims))
            .find(|&checked| record_tile(microsims, checked) == 0)
            .unwrap_or(-1)
    } else {
        kind - LAST_INDIVIDUAL_TYPE
    };

    // An arcology takes the record of an older facility when every record is used.
    if record < 0 && tile >= PLYMOUTH_ARCOLOGY && request.record_budget < 0 {
        for checked in DYNAMIC_FIRST..record_count(microsims) {
            if record_tile(microsims, checked) < PLYMOUTH_ARCOLOGY {
                record = checked;
                release_overlays(text_overlays, overlay::facility_id(checked));

                break;
            }
        }
    }

    if record < 0 {
        return 0;
    }

    let offset = (record * RECORD_SIZE) as usize;

    if kind <= LAST_INDIVIDUAL_TYPE {
        microsims[offset..offset + RECORD_SIZE as usize].fill(0);
    }

    microsims[offset] = tile as u8;
    let map_edge = (overlay::count(text_overlays) as f64).sqrt() as i64;
    initialize_microsim(microsims, record, request, map_edge, random);

    // Sc2LabelLayout reads the record layout from the table size.
    let label = overlay::facility_id(record);
    let wide = label_records::is_wide_table(labels);

    if kind <= LAST_INDIVIDUAL_TYPE || label_is_empty(labels, label, wide) {
        write_label(labels, label, default_label(tile), wide);
    }

    label
}

fn release_overlays(text_overlays: &mut [u8], old_id: i64) {
    for index in 0..overlay::count(text_overlays) {
        if overlay::facility_at(text_overlays, index) == old_id {
            if overlay::is_layered(text_overlays) {
                overlay::set_facility(text_overlays, index, 0);
            } else {
                overlay::write(text_overlays, index, 0);
            }
        }
    }
}

/// BuildingFacilities.initialize_microsim.
fn initialize_microsim(microsims: &mut [u8], record: i64, request: &Provision, map_edge: i64, random: &mut SimRandom) {
    let offset = record * RECORD_SIZE;
    let misc = request.misc;
    let year = request.current_year;
    let scurk = request.scurk_place_mode;
    let add = |microsims: &mut [u8], field: i64, amount: i64| {
        let value = read_u16_be(microsims, offset + field) + amount;
        write_u16_be(microsims, offset + field, value);
    };

    match request.tile {
        HYDRO_POWER_1 | HYDRO_POWER_2 => {
            add(microsims, 2, 1);
            add(microsims, 4, 20);
        }
        WIND_POWER => {
            add(microsims, 2, 1);
            add(microsims, 4, 4);
        }
        GAS_POWER | SOLAR_POWER => write_u16_be(microsims, offset + 2, 50),
        OIL_POWER => write_u16_be(microsims, offset + 2, 220),
        NUCLEAR_POWER => write_u16_be(microsims, offset + 2, 500),
        MICROWAVE_POWER => write_u16_be(microsims, offset + 2, 1600),
        FUSION_POWER => write_u16_be(microsims, offset + 2, 2500),
        COAL_POWER => write_u16_be(microsims, offset + 2, 200),
        CITY_HALL => {
            let cap = if scurk { 0 } else { population_cap(misc, 200, 900, map_edge) };
            write_u16_be(microsims, offset + 2, cap);
            write_u16_be(microsims, offset + 4, year);
        }
        HOSPITAL | SCHOOL | COLLEGE => microsims[(offset + 1) as usize] = 6,
        POLICE_STATION => {
            let cap = if scurk {
                0
            } else {
                let funding = budget_funding(misc, budget_layout::POLICE);
                population_cap(misc, to_i16(funding * 2), 90, map_edge)
            };

            write_u16_be(microsims, offset + 2, cap);
        }
        FIRE_STATION => {
            let cap = if scurk {
                0
            } else {
                let funding = budget_funding(misc, budget_layout::FIRE);
                population_cap(misc, to_i16(funding / 2), 70, map_edge)
            };

            write_u16_be(microsims, offset + 2, cap);
            write_u16_be(microsims, offset + 4, 4);
        }
        MUSEUM => microsims[(offset + 1) as usize] = 100,
        BIG_PARK => add(microsims, 4, 9),
        STATUE => write_u16_be(microsims, offset + 2, year),
        SUBWAY_STATION | BUS_DEPOT | RAIL_STATION => add(microsims, 2, 1),
        MAYOR_HOUSE => {
            write_u16_be(microsims, offset + 2, year);
            write_u16_be(microsims, offset + 4, random.next_u15() % 30 + 10);
            write_u16_be(microsims, offset + 6, random.next_u15() % 60);
        }
        PLYMOUTH_ARCOLOGY | FOREST_ARCOLOGY | DARCO_ARCOLOGY | LAUNCH_ARCOLOGY => {
            let capacity = match request.tile {
                PLYMOUTH_ARCOLOGY => 55,
                FOREST_ARCOLOGY => 30,
                DARCO_ARCOLOGY => 45,
                _ => 65,
            };

            microsims[(offset + 1) as usize] = 5;
            write_u16_be(microsims, offset + 2, capacity);
            write_u16_be(microsims, offset + 6, year);
        }
        LLAMA_DOME => {
            let value = if request.australian_locale {
                year
            } else {
                random.next_u15() & 0x3f
            };

            write_u16_be(microsims, offset + 6, value);
        }
        _ => {}
    }
}

/// The funding field of one budget category record.
fn budget_funding(misc: &[u8], category: i64) -> i64 {
    read_i32_be(misc, misc_layout::BUDGETS + category * budget_layout::RECORD_SIZE + 4)
}

/// BuildingFacilities.population_cap: the population share of one facility,
/// limited to `maximum` as a signed 16-bit value.
pub fn population_cap(misc: &[u8], maximum: i64, divisor: i64, map_edge: i64) -> i64 {
    let divisor = if divisor == 0 { 100 } else { divisor };
    let mut arcologies = 0;

    for tile in PLYMOUTH_ARCOLOGY..=LAUNCH_ARCOLOGY {
        let count = read_u32_be(misc, misc_layout::TILE_COUNTS + tile * 4);
        arcologies += if map_edge == 128 { to_i16(count) } else { count };
    }

    // GDScript int(value / float(divisor)) truncates toward zero.
    arcologies /= 16;

    let adjustment = if arcologies >= 141 { arcologies * 20000 - 2_800_000 } else { 0 };
    let total = adjustment + read_u32_be(misc, misc_layout::ARCOLOGY_POPULATION) + read_u32_be(misc, misc_layout::NORMAL_POPULATION);
    let available = (total / divisor) & if map_edge == 128 { 0xffff } else { 0xffff_ffff };
    let signed_maximum = to_i16(maximum);

    if signed_maximum <= available { signed_maximum } else { available }
}

fn to_i16(value: i64) -> i64 {
    let wrapped = value & 0xffff;

    if wrapped >= 0x8000 { wrapped - 0x10000 } else { wrapped }
}

fn label_is_empty(labels: &[u8], label: i64, wide: bool) -> bool {
    let size = label_records::record_size(wide);
    let offset = label as usize * size;

    if label < 0 || offset + size > labels.len() {
        return true;
    }

    labels[offset] == 0 && (!wide || labels[offset + 1] == 0)
}

/// Sc2LabelLayout.write for ASCII text: clear the record, then store the length and text.
pub fn write_label(labels: &mut [u8], label: i64, text: &str, wide: bool) {
    if label < 0 {
        return;
    }

    if wide {
        label_records::write_wide(labels, label as usize, text);

        return;
    }

    let size = label_records::LEGACY_RECORD_SIZE;
    let offset = label as usize * size;

    if offset + size > labels.len() {
        return;
    }

    let bytes = &text.as_bytes()[..text.len().min(label_records::LEGACY_MAX_TEXT)];
    let record = &mut labels[offset..offset + size];
    record.fill(0);
    record[0] = bytes.len() as u8;
    record[1..1 + bytes.len()].copy_from_slice(bytes);
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::sim::bytes::write_u32_be;

    const RECORDS: usize = 150;

    fn request(tile: i64, misc: &[u8], record_budget: i64) -> Provision<'_> {
        Provision {
            tile,
            current_year: 2050,
            misc,
            australian_locale: false,
            scurk_place_mode: false,
            record_budget,
            first_free: DYNAMIC_FIRST,
        }
    }

    /// Each facility takes the lowest free record, and a full table gives none.
    #[test]
    fn facilities_take_the_lowest_free_record() {
        let misc = vec![0u8; 4800];
        let mut microsims = vec![0u8; RECORDS * RECORD_SIZE as usize];
        let mut labels = vec![0u8; 256 * label_records::LEGACY_RECORD_SIZE];
        let mut overlays = vec![0u8; 128 * 128];
        let mut random = SimRandom::new(123);
        let selected = [10, 149];

        for record in DYNAMIC_FIRST..RECORDS as i64 {
            if !selected.contains(&record) {
                microsims[(record * RECORD_SIZE) as usize] = POLICE_STATION as u8;
            }
        }

        for record in selected {
            let id = provision_microsim(
                &mut microsims,
                &mut labels,
                &mut overlays,
                &request(POLICE_STATION, &misc, -1),
                &mut random,
            );
            assert_eq!(id, overlay::facility_id(record));
            assert_eq!(label_records::read(&labels, id as usize, false).as_deref(), Some("Police Station"));
        }

        let full = provision_microsim(
            &mut microsims,
            &mut labels,
            &mut overlays,
            &request(POLICE_STATION, &misc, -1),
            &mut random,
        );
        assert_eq!(full, 0, "a full table gives no record");
    }

    /// With a record budget, an arcology never takes the record of another
    /// facility. The original allocation replaces one.
    #[test]
    fn budgets_keep_the_records_of_other_facilities() {
        let misc = vec![0u8; 4800];
        let mut microsims = vec![0u8; RECORDS * RECORD_SIZE as usize];

        for record in DYNAMIC_FIRST..RECORDS as i64 {
            microsims[(record * RECORD_SIZE) as usize] = HOSPITAL as u8;
        }

        let mut labels = vec![0u8; 256 * label_records::LEGACY_RECORD_SIZE];
        let mut overlays = vec![0u8; 16 * 16];
        let mut random = SimRandom::new(1);

        let budgeted = provision_microsim(
            &mut microsims.clone(),
            &mut labels,
            &mut overlays,
            &request(PLYMOUTH_ARCOLOGY, &misc, 54),
            &mut random,
        );
        let original = provision_microsim(
            &mut microsims,
            &mut labels,
            &mut overlays,
            &request(PLYMOUTH_ARCOLOGY, &misc, -1),
            &mut random,
        );

        assert_eq!(budgeted, 0);
        assert_ne!(original, 0);
        assert!(!record_available(&microsims, POLICE_STATION, 0));
        assert!(record_available(&microsims, POLICE_STATION, -1));
    }

    /// Classic cities keep a 16-bit population share. Larger maps do not wrap.
    #[test]
    fn population_caps_follow_the_map_width() {
        let mut misc = vec![0u8; 4800];
        write_u32_be(&mut misc, misc_layout::NORMAL_POPULATION, 65536 * 900);

        for (edge, expected) in [(128, 0), (256, 200), (1024, 200)] {
            assert_eq!(population_cap(&misc, 200, 900, edge), expected);

            let mut microsims = vec![0u8; RECORDS * RECORD_SIZE as usize];
            let mut random = SimRandom::new(1);
            initialize_microsim(&mut microsims, DYNAMIC_FIRST, &request(CITY_HALL, &misc, -1), edge, &mut random);
            assert_eq!(
                read_u16_be(&microsims, DYNAMIC_FIRST * RECORD_SIZE + 2),
                expected,
                "city hall at {edge}"
            );
        }
    }

    /// Unknown tiles take no record and draw no random number.
    #[test]
    fn other_tiles_take_no_record() {
        let misc = vec![0u8; 4800];
        let mut microsims = vec![0u8; RECORDS * RECORD_SIZE as usize];
        let mut labels = vec![0u8; 256 * label_records::LEGACY_RECORD_SIZE];
        let mut overlays = vec![0u8; 16 * 16];
        let mut random = SimRandom::new(19);
        let before = (microsims.clone(), labels.clone());

        assert_eq!(
            provision_microsim(
                &mut microsims,
                &mut labels,
                &mut overlays,
                &request(TREES_1, &misc, -1),
                &mut random
            ),
            0
        );
        assert_eq!(random.state, 19);
        assert_eq!((microsims, labels), before);
    }
}
