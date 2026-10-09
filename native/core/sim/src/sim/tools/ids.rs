//! Stable city tool indices of the catalog and the availability tables, as
//! CityToolIds. SCURK object groups use a separate set of IDs.

pub mod group {
    pub const BULLDOZER: i64 = 0;
    pub const LANDSCAPE: i64 = 1;
    pub const DISPATCH: i64 = 2;
    pub const POWER: i64 = 3;
    pub const WATER: i64 = 4;
    pub const REWARDS: i64 = 5;
    pub const ROADS: i64 = 6;
    pub const RAIL: i64 = 7;
    pub const PORTS: i64 = 8;
    pub const RESIDENTIAL: i64 = 9;
    pub const COMMERCIAL: i64 = 10;
    pub const INDUSTRIAL: i64 = 11;
    pub const EDUCATION: i64 = 12;
    pub const SERVICES: i64 = 13;
    pub const RECREATION: i64 = 14;
    pub const SIGNS: i64 = 15;
    pub const QUERY: i64 = 16;
    pub const CENTERING: i64 = 17;
    pub const COUNT: usize = 18;
}

pub mod landscape {
    pub const TREES: i64 = 0;
    pub const WATER: i64 = 1;
    pub const STREAM: i64 = 2;
    pub const FOREST: i64 = 3;
}

pub mod power {
    pub const WIRES: i64 = 0;
    pub const PLANTS: i64 = 1;
    pub const COAL: i64 = 2;
}

pub mod rewards {
    pub const ARCOLOGIES: i64 = 4;
    pub const PLYMOUTH: i64 = 5;
}
