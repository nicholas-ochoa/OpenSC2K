//! The state of the engine between calls, as the fields of SimulationEngine.
//! A front end keeps it, and a simulation snapshot copies it.

use crate::clock::DaySchedule;
use sc2k_sim::formats::sc2;
use sc2k_sim::sim::city::City;
use sc2k_sim::sim::civic::scenario::Scenario;
use sc2k_sim::sim::engine::day::EngineState as DayState;
use sc2k_sim::sim::geom::{Rect2i, Vec2i};
use sc2k_sim::sim::growth::demand;
use sc2k_sim::sim::ids::sc2misc_layout as misc;
use sc2k_sim::sim::things;
use sc2k_sim::sim::tools::commands::dispatch::NO_CAPACITY;

#[derive(Clone, Debug, PartialEq)]
pub struct EngineState {
    /// The state that the day phases read and write.
    pub day: DayState,
    /// The city age of the clock.
    pub city_days: i64,
    pub pending_interaction: String,
    pub pending_day_schedule: Option<DaySchedule>,
    pub pending_military_site: Rect2i,
    pub pending_military_base_type: i64,
    /// The base type of a debug proposal, or 0 for the game rules. The answer clears it.
    pub forced_military_base_type: i64,
    pub scenario: Option<Scenario>,
    pub active_disaster_type: i64,
    pub unsupported_disaster_type: i64,
    pub disaster_map_counter: i64,
    pub disaster_hurricane_counter: i64,
    /// The police, fire, and military counts that the last disaster start fixed.
    pub dispatch_capacity: [i64; 3],
    pub dispatch_epoch: i64,
    /// False while the player hides the vehicle layer: airplanes and
    /// helicopters then leave instead of crashing. Never saved.
    pub vehicle_crashes_enabled: bool,
    /// True from a staged launch until its last launch. The days wait.
    pub arcology_launch_active: bool,
    /// The launch arcologies that wait to ignite. Never saved.
    pub arcology_launch_sites: Vec<Vec2i>,
    pub arcology_launch_wait: i64,
}

impl Default for EngineState {
    fn default() -> Self {
        Self {
            day: DayState {
                developed_tiles: -1,
                power_usage_percent: -1,
                water_usage_percent: -1,
                ship_home: Vec2i::NONE,
                city_status_resource_id: -1,
                stage_arcology_launch: true,
                ..DayState::default()
            },
            city_days: 0,
            pending_interaction: String::new(),
            pending_day_schedule: None,
            pending_military_site: Rect2i::default(),
            pending_military_base_type: 0,
            forced_military_base_type: 0,
            scenario: None,
            active_disaster_type: 0,
            unsupported_disaster_type: 0,
            disaster_map_counter: 0,
            disaster_hurricane_counter: 0,
            dispatch_capacity: NO_CAPACITY,
            dispatch_epoch: 0,
            vehicle_crashes_enabled: true,
            arcology_launch_active: false,
            arcology_launch_sites: Vec::new(),
            arcology_launch_wait: 0,
        }
    }
}

impl EngineState {
    /// The state of a loaded city: its age, its music, its pending disaster,
    /// its scenario, its neighbor connections, and the home of its ship.
    pub fn for_city(city: &City) -> Self {
        let mut state = Self {
            city_days: city.age_in_days().max(0),
            ..Self::default()
        };

        state.day.midi_playback_active = city.misc_u32(misc::MUSIC) != 0;
        state.day.pending_disaster_type = city.disaster_type() & 0xffff;

        if city.chunk("SCEN").is_some()
            && let Ok(scenario) = Scenario::from_city(city)
        {
            state.day.pending_disaster_type = scenario.disaster_type;
            state.day.pending_disaster_point = Vec2i::new(scenario.disaster_x, scenario.disaster_y);
            state.scenario = Some(scenario);
        }

        let connections = demand::connection_counts(city);
        state.day.commerce_connections = connections.commerce;
        state.day.industry_connections = connections.industry;

        let thing_data = city.chunk("XTHG").map(|chunk| chunk.data.as_slice()).unwrap_or_default();

        for record in 1..things::count(thing_data) {
            if things::field(thing_data, record, things::FIELD_TYPE) == things::TYPE_SHIP {
                state.day.ship_home = Vec2i::new(
                    things::field(thing_data, record, things::FIELD_X),
                    things::field(thing_data, record, things::FIELD_Y),
                );
                break;
            }
        }

        state
    }

    /// The map edge of `city`, for the rotation of runtime points.
    pub fn map_edge(city: &City) -> i64 {
        if city.map_size > 0 { city.map_size } else { sc2::ORIGINAL_EDGE }
    }
}
