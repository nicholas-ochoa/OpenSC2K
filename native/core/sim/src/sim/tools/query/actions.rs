//! The City Hall analysis of the query dialog, as QueryActions: the acres of
//! each land use from the MISC tile counts.

use crate::sim::city::City;
use crate::sim::ids::building_tile_ids as tiles;
use crate::sim::ids::sc2misc_layout as misc;

pub const CATEGORY_COUNT: usize = 12;
const UNCOUNTED: usize = 0;
const TRANSPORTATION: usize = 1;
const POWER: usize = 2;
const WATER: usize = 3;
const RESIDENTIAL: usize = 4;
const COMMERCIAL: usize = 5;
const INDUSTRIAL: usize = 6;
const PORTS: usize = 7;
const EDUCATION: usize = 8;
const HEALTH: usize = 9;
const RECREATION: usize = 10;
const ARCOLOGIES: usize = 11;

pub const HEADER: &str = "LAND USE\t\tACRES\t% of CITY";
pub const CATEGORY_NAMES: [&str; CATEGORY_COUNT] = [
    "",
    "Transportation",
    "Power",
    "Water",
    "Residential",
    "Commercial",
    "Industrial",
    "Ports/Airports",
    "Education",
    "Health/Safety",
    "Recreation",
    "Arcologies",
];

/// A building belongs to the first row whose tile bound is above its ID.
const CATEGORY_BY_TILE_BOUND: [(i64, usize); 40] = [
    (tiles::POWER_LINE_FIRST, RECREATION),
    (tiles::FIRST_ROAD, POWER),
    (tiles::DEVELOPED_FIRST, TRANSPORTATION),
    (tiles::COMMERCIAL_1X1_FIRST, RESIDENTIAL),
    (tiles::INDUSTRIAL_1X1_FIRST, COMMERCIAL),
    (tiles::CONSTRUCTION_1X1_FIRST, INDUSTRIAL),
    (tiles::RESIDENTIAL_2X2_FIRST, UNCOUNTED),
    (tiles::COMMERCIAL_2X2_FIRST, RESIDENTIAL),
    (tiles::INDUSTRIAL_2X2_FIRST, COMMERCIAL),
    (tiles::CONSTRUCTION_2X2_FIRST, INDUSTRIAL),
    (tiles::RESIDENTIAL_3X3_FIRST, UNCOUNTED),
    (tiles::COMMERCIAL_3X3_FIRST, RESIDENTIAL),
    (tiles::INDUSTRIAL_3X3_FIRST, COMMERCIAL),
    (tiles::CONSTRUCTION_3X3_FIRST, INDUSTRIAL),
    (tiles::HYDRO_POWER_1, UNCOUNTED),
    (tiles::CITY_HALL, POWER),
    (tiles::MUSEUM, HEALTH),
    (tiles::BIG_PARK, EDUCATION),
    (tiles::SCHOOL, RECREATION),
    (tiles::STADIUM, EDUCATION),
    (tiles::PRISON, RECREATION),
    (tiles::COLLEGE, HEALTH),
    (tiles::ZOO, EDUCATION),
    (tiles::WATER_PUMP, RECREATION),
    (tiles::RUNWAY, WATER),
    (tiles::SUBWAY_STATION, PORTS),
    (tiles::WATER_TOWER, TRANSPORTATION),
    (tiles::BUS_DEPOT, WATER),
    (tiles::PARKING_LOT_1, TRANSPORTATION),
    (tiles::MAYOR_HOUSE, PORTS),
    (tiles::WATER_TREATMENT, UNCOUNTED),
    (tiles::LIBRARY, WATER),
    (tiles::HANGAR_2, EDUCATION),
    (tiles::CHURCH, PORTS),
    (tiles::MARINA, RESIDENTIAL),
    (tiles::MISSILE_SILO, RECREATION),
    (tiles::DESALINIZATION, PORTS),
    (tiles::PLYMOUTH_ARCOLOGY, WATER),
    (tiles::LLAMA_DOME, ARCOLOGIES),
    (tiles::EMPTY, RECREATION),
];

#[derive(Clone, Debug, Default, PartialEq, Eq)]
pub struct Analysis {
    /// The tiles of each category; category 0 is not counted.
    pub counts: [i64; CATEGORY_COUNT],
    pub total: i64,
}

impl Analysis {
    /// The share of the city of a counted category, in whole percent.
    pub fn percent(&self, category: usize) -> i64 {
        if self.total != 0 {
            self.counts[category] * 100 / self.total
        } else {
            0
        }
    }

    /// The text of the analysis: a header and one line for each category.
    pub fn text(&self) -> String {
        let mut lines = vec![HEADER.to_string()];

        for (category, name) in CATEGORY_NAMES.iter().enumerate().skip(1) {
            lines.push(format!("{name}\t{}\t{}%", self.counts[category], self.percent(category)));
        }

        lines.join("\n")
    }
}

/// The land use of the city from the MISC tile counts.
pub fn city_analysis(city: &City) -> Result<Analysis, String> {
    if (city.misc.data.len() as i64) < misc::TILE_COUNTS + tiles::COUNT * 4 {
        return Err("MISC tile counts are missing or invalid".into());
    }

    let mut analysis = Analysis::default();

    for building in tiles::SMALL_PARK..tiles::COUNT {
        let count = city.misc_i32(misc::TILE_COUNTS + building * 4);

        if let Some(&(_, category)) = CATEGORY_BY_TILE_BOUND.iter().find(|(bound, _)| building < *bound) {
            analysis.counts[category] += count;
        }
    }

    analysis.total = analysis.counts[1..].iter().sum();

    Ok(analysis)
}
