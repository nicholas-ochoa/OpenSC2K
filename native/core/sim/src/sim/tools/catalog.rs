//! The city tool catalog, as ToolCatalog: the groups of the tool bar, each
//! tool with its name, its cost, and its square cursor area. The costs and
//! the areas are the executable tables at 0x004dc140 and 0x004dc068. A zero
//! area is a chooser or camera tool.

/// The table slots of each group in the executable tables.
pub const MAX_SLOTS_PER_GROUP: i64 = 12;

pub struct Entry {
    pub id: &'static str,
    pub name: &'static str,
    pub cost: i64,
    pub area: i64,
}

pub struct Group {
    pub id: &'static str,
    pub name: &'static str,
    pub tools: &'static [Entry],
}

/// The values that the Power Plants chooser shows. The output is the nominal
/// megawatt value in XMIC; the grid capacity and the pollution are from the
/// monthly power and pollution phases.
pub struct PowerPlantDetails {
    /// The Power group subtool.
    pub subtool: i64,
    pub output_mw: i64,
    pub grid_capacity: &'static str,
    pub pollution: i64,
    pub service_life: &'static str,
    pub note: &'static str,
}

const fn entry(id: &'static str, name: &'static str, cost: i64, area: i64) -> Entry {
    Entry { id, name, cost, area }
}

pub const GROUPS: [Group; 18] = [
    Group {
        id: "bulldozer",
        name: "Bulldozer",
        tools: &[
            entry("demolish", "Demolish", 1, 1),
            entry("level", "Level Terrain", 25, 1),
            entry("raise", "Raise Terrain", 25, 1),
            entry("lower", "Lower Terrain", 25, 1),
            entry("dezone", "De-zone", 1, 1),
            entry("stretch", "Stretch Terrain", 0, 1),
            entry("raise_sea", "Raise Sea Level", 0, 0),
            entry("lower_sea", "Lower Sea Level", 0, 0),
        ],
    },
    Group {
        id: "nature",
        name: "Landscape",
        tools: &[
            entry("trees", "Trees", 3, 1),
            entry("water", "Water", 100, 1),
            entry("stream", "Place Stream", 0, 1),
            entry("forest", "Place Forest", 3, 7),
        ],
    },
    Group {
        id: "dispatch",
        name: "Dispatch",
        tools: &[
            entry("police", "Police", 0, 1),
            entry("fire", "Fire", 0, 1),
            entry("military", "Military", 0, 1),
            entry("recall", "Cancel Dispatch", 0, 0),
        ],
    },
    Group {
        id: "power",
        name: "Power",
        tools: &[
            entry("wires", "Power Lines", 2, 1),
            entry("plants", "Power Plants", 0, 0),
            entry("coal", "Coal Power Plant", 4000, 4),
            entry("hydro", "Hydroelectric Power Plant", 400, 1),
            entry("oil", "Oil Power Plant", 6600, 4),
            entry("gas", "Gas Power Plant", 2000, 4),
            entry("nuclear", "Nuclear Power Plant", 15000, 4),
            entry("wind", "Wind Power Plant", 100, 1),
            entry("solar", "Solar Power Plant", 1300, 4),
            entry("microwave", "Microwave Power Plant", 28000, 4),
            entry("fusion", "Fusion Power Plant", 40000, 4),
        ],
    },
    Group {
        id: "water",
        name: "Water",
        tools: &[
            entry("pipes", "Water Pipes", 3, 1),
            entry("pump", "Water Pump", 100, 1),
            entry("tower", "Water Tower", 250, 2),
            entry("treatment", "Water Treatment Plant", 500, 2),
            entry("desalinization", "Desalinization Plant", 1000, 3),
        ],
    },
    Group {
        id: "rewards",
        name: "Rewards",
        tools: &[
            entry("mayors_house", "Mayor's House", 0, 2),
            entry("city_hall", "City Hall", 0, 3),
            entry("statue", "Statue", 0, 1),
            entry("llama_dome", "Braun Llama Dome", 0, 4),
            entry("arcologies", "Arcologies", 0, 0),
            entry("plymouth", "Plymouth Arcology", 100000, 4),
            entry("forest", "Forest Arcology", 120000, 4),
            entry("darco", "Darco Arcology", 150000, 4),
            entry("launch", "Launch Arcology", 200000, 4),
        ],
    },
    Group {
        id: "roads",
        name: "Roads",
        tools: &[
            entry("road", "Road", 10, 1),
            entry("highway", "Highway", 100, 2),
            entry("tunnel", "Tunnel", 150, 1),
            entry("onramp", "On-ramp", 25, 1),
            entry("bus_depot", "Bus Depot", 250, 2),
        ],
    },
    Group {
        id: "rail",
        name: "Rail",
        tools: &[
            entry("rail", "Rail", 25, 1),
            entry("subway", "Subway", 100, 1),
            entry("rail_depot", "Rail Depot", 500, 2),
            entry("subway_station", "Subway Station", 250, 1),
            entry("subway_to_rail", "Subway-to-Rail Connection", 250, 1),
        ],
    },
    Group {
        id: "ports",
        name: "Ports",
        tools: &[entry("seaport", "Seaport", 150, 1), entry("airport", "Airport", 250, 1)],
    },
    Group {
        id: "residential",
        name: "Residential",
        tools: &[
            entry("light", "Light Residential", 5, 1),
            entry("dense", "Dense Residential", 10, 1),
        ],
    },
    Group {
        id: "commercial",
        name: "Commercial",
        tools: &[entry("light", "Light Commercial", 5, 1), entry("dense", "Dense Commercial", 10, 1)],
    },
    Group {
        id: "industrial",
        name: "Industrial",
        tools: &[entry("light", "Light Industrial", 5, 1), entry("dense", "Dense Industrial", 10, 1)],
    },
    Group {
        id: "education",
        name: "Education",
        tools: &[
            entry("school", "School", 250, 3),
            entry("college", "College", 1000, 4),
            entry("library", "Library", 500, 2),
            entry("museum", "Museum", 1000, 3),
        ],
    },
    Group {
        id: "services",
        name: "City Services",
        tools: &[
            entry("police_station", "Police Station", 500, 3),
            entry("fire_station", "Fire Station", 500, 3),
            entry("hospital", "Hospital", 500, 3),
            entry("prison", "Prison", 3000, 4),
        ],
    },
    Group {
        id: "parks",
        name: "Recreation",
        tools: &[
            entry("small_park", "Small Park", 20, 1),
            entry("big_park", "Big Park", 150, 3),
            entry("zoo", "Zoo", 3000, 4),
            entry("stadium", "Stadium", 5000, 4),
            entry("marina", "Marina", 1000, 3),
        ],
    },
    Group {
        id: "signs",
        name: "Signs",
        tools: &[entry("sign", "Place Sign", 0, 1)],
    },
    Group {
        id: "query",
        name: "Query",
        tools: &[
            entry("query", "Query", 0, 1),
            entry("trip_reach", "Trip Query", 0, 1),
            entry("tile_inspector", "Tile Inspector", 0, 1),
        ],
    },
    Group {
        id: "centering",
        name: "Center",
        tools: &[entry("center", "Center View", 0, 0)],
    },
];

pub const POWER_PLANT_DETAILS: [PowerPlantDetails; 9] = [
    PowerPlantDetails {
        subtool: 2,
        output_mw: 200,
        grid_capacity: "44 demand tiles",
        pollution: 50,
        service_life: "50 years",
        note: "Can be blocked by nearby residential zones.",
    },
    PowerPlantDetails {
        subtool: 3,
        output_mw: 20,
        grid_capacity: "40 demand tiles",
        pollution: 0,
        service_life: "No age limit",
        note: "Must be built on an unused waterfall tile.",
    },
    PowerPlantDetails {
        subtool: 4,
        output_mw: 220,
        grid_capacity: "48 demand tiles",
        pollution: 25,
        service_life: "50 years",
        note: "Can be blocked by nearby residential zones.",
    },
    PowerPlantDetails {
        subtool: 5,
        output_mw: 50,
        grid_capacity: "11 demand tiles",
        pollution: 10,
        service_life: "50 years",
        note: "Can be blocked by nearby residential zones.",
    },
    PowerPlantDetails {
        subtool: 6,
        output_mw: 500,
        grid_capacity: "111 demand tiles",
        pollution: 2,
        service_life: "50 years",
        note: "The Nuclear-Free ordinance disables this plant.",
    },
    PowerPlantDetails {
        subtool: 7,
        output_mw: 4,
        grid_capacity: "Varies with altitude and wind",
        pollution: 0,
        service_life: "No age limit",
        note: "Higher land and stronger wind increase grid capacity.",
    },
    PowerPlantDetails {
        subtool: 8,
        output_mw: 50,
        grid_capacity: "5 to 14 demand tiles; varies with rain",
        pollution: 0,
        service_life: "50 years",
        note: "Drier weather increases grid capacity.",
    },
    PowerPlantDetails {
        subtool: 9,
        output_mw: 1600,
        grid_capacity: "355 demand tiles",
        pollution: 0,
        service_life: "50 years",
        note: "A microwave disaster can start at this plant.",
    },
    PowerPlantDetails {
        subtool: 10,
        output_mw: 2500,
        grid_capacity: "555 demand tiles",
        pollution: 2,
        service_life: "50 years",
        note: "This plant becomes available after its invention.",
    },
];

/// The catalog entry of a tool.
pub fn tool(group_index: i64, subtool: i64) -> Option<&'static Entry> {
    let group = GROUPS.get(usize::try_from(group_index).ok()?)?;

    group.tools.get(usize::try_from(subtool).ok()?)
}

/// The details of a power plant subtool.
pub fn power_plant_details(subtool: i64) -> Option<&'static PowerPlantDetails> {
    POWER_PLANT_DETAILS.iter().find(|details| details.subtool == subtool)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::sim::tools::ids::{group, power};

    #[test]
    fn the_catalog_follows_the_tool_ids() {
        assert_eq!(GROUPS.len(), group::COUNT);
        assert!(GROUPS.iter().all(|group| group.tools.len() as i64 <= MAX_SLOTS_PER_GROUP));
        assert_eq!(
            tool(group::POWER, power::COAL).map(|entry| (entry.cost, entry.area)),
            Some((4000, 4))
        );
        assert_eq!(tool(group::CENTERING, 0).map(|entry| entry.area), Some(0));
        assert!(tool(group::COUNT as i64, 0).is_none() && tool(0, -1).is_none());
        assert_eq!(power_plant_details(power::COAL).map(|details| details.output_mw), Some(200));
        assert!(power_plant_details(power::PLANTS).is_none());
    }
}
