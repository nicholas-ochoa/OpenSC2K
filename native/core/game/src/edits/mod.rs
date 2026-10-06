//! The edits of the city tools, as ApplicationCityEdits and SimpleEditFlow:
//! which command a tool runs, its arguments, its sounds, its status message,
//! and the undo of the last edit. The commands are in `sc2k_sim::sim::tools`.

mod messages;
mod undo;

#[cfg(test)]
mod tests;

pub use undo::Undo;

use crate::session::Session;
use sc2k_sim::sim::geom::Vec2i;
use sc2k_sim::sim::ids::building_tile_ids as tiles;
use sc2k_sim::sim::ids::sc2misc_layout as misc;
use sc2k_sim::sim::tools::catalog::{self, MAX_SLOTS_PER_GROUP};
use sc2k_sim::sim::tools::commands::building::{self, Placement};
use sc2k_sim::sim::tools::commands::landscape::terrain::TerrainPath;
use sc2k_sim::sim::tools::commands::route::RouteChoices;
use sc2k_sim::sim::tools::commands::zone::ZoneRequest;
use sc2k_sim::sim::tools::commands::{ToolArgs, demolish, hydro, landscape, onramp, route, subway_to_rail, tunnel, zone};
use sc2k_sim::sim::tools::ids::group;
use sc2k_sim::sim::tools::{availability, sounds};
use sc2k_sim::sim::value::{ToValue, Value};

/// The building of each tool slot (group * 12 + subtool), as BuildingSites.TILE_BY_TOOL.
const TILE_BY_TOOL: [(i64, i64); 36] = [
    (38, tiles::COAL_POWER),
    (40, tiles::OIL_POWER),
    (41, tiles::GAS_POWER),
    (42, tiles::NUCLEAR_POWER),
    (43, tiles::WIND_POWER),
    (44, tiles::SOLAR_POWER),
    (45, tiles::MICROWAVE_POWER),
    (46, tiles::FUSION_POWER),
    (49, tiles::WATER_PUMP),
    (50, tiles::WATER_TOWER),
    (51, tiles::WATER_TREATMENT),
    (52, tiles::DESALINIZATION),
    (60, tiles::MAYOR_HOUSE),
    (61, tiles::CITY_HALL),
    (62, tiles::STATUE),
    (63, tiles::LLAMA_DOME),
    (65, tiles::PLYMOUTH_ARCOLOGY),
    (66, tiles::FOREST_ARCOLOGY),
    (67, tiles::DARCO_ARCOLOGY),
    (68, tiles::LAUNCH_ARCOLOGY),
    (76, tiles::BUS_DEPOT),
    (86, tiles::RAIL_STATION),
    (87, tiles::SUBWAY_STATION),
    (144, tiles::SCHOOL),
    (145, tiles::COLLEGE),
    (146, tiles::LIBRARY),
    (147, tiles::MUSEUM),
    (156, tiles::POLICE_STATION),
    (157, tiles::FIRE_STATION),
    (158, tiles::HOSPITAL),
    (159, tiles::PRISON),
    (168, tiles::SMALL_PARK),
    (169, tiles::BIG_PARK),
    (170, tiles::ZOO),
    (171, tiles::STADIUM),
    (172, tiles::MARINA),
];
/// The network tool slots: power lines, pipes, roads, rail, and subways.
const NETWORK_SLOTS: [i64; 5] = [36, 48, 72, 84, 85];
const HIGHWAY_SLOT: i64 = 73;
const TUNNEL_SLOT: i64 = 74;
const ONRAMP_SLOT: i64 = 75;
const HYDRO_SLOT: i64 = 39;
const SUBWAY_TO_RAIL_SLOT: i64 = 88;
const DEMOLISH_SLOT: i64 = 0;
const DEZONE_SLOT: i64 = 4;
const TERRAIN_SLOTS: std::ops::RangeInclusive<i64> = 1..=3;
const LANDSCAPE_SUBTOOLS: [i64; 3] = [0, 1, 3];
/// The zone of each zoning tool: light and dense.
const ZONE_TYPES: [(i64, [i64; 2]); 4] = [
    (group::PORTS, [9, 8]),
    (group::RESIDENTIAL, [1, 2]),
    (group::COMMERCIAL, [3, 4]),
    (group::INDUSTRIAL, [5, 6]),
];
/// An unselected bridge, connection, or tunnel answer: the command asks for it.
pub const UNSELECTED: i64 = -1;
const RECREATION_TRACK: i64 = 10010;

/// The selected tool and its map selection.
#[derive(Clone, Debug)]
pub struct Selection {
    pub group: i64,
    pub subtool: i64,
    pub start: Vec2i,
    pub finish: Vec2i,
    /// The tiles of a brush or bulldozer drag, in order.
    pub path: Vec<Vec2i>,
    pub dragged: bool,
    pub underground: bool,
    /// The answers that a route, highway, or tunnel asked for, or `UNSELECTED`.
    pub bridge: i64,
    pub connection: i64,
    pub confirmation: i64,
}

impl Selection {
    pub fn new(group: i64, subtool: i64, start: Vec2i, finish: Vec2i) -> Self {
        Self {
            group,
            subtool,
            start,
            finish,
            path: vec![finish],
            dragged: start != finish,
            underground: false,
            bridge: UNSELECTED,
            connection: UNSELECTED,
            confirmation: UNSELECTED,
        }
    }

    fn slot(&self) -> i64 {
        self.group * MAX_SLOTS_PER_GROUP + self.subtool
    }
}

/// What a tool did.
#[derive(Clone, Debug)]
pub struct Outcome {
    pub ok: bool,
    /// The status line text, or an error.
    pub message: String,
    pub cost: i64,
    pub sounds: Vec<i64>,
    pub effects: Vec<Value>,
    /// The command family, as the scripts name it: "zone", "network", ...
    pub kind: &'static str,
    /// The command result, for dialogs that need its fields.
    pub result: Value,
    /// A view tool: the front end centers, queries, or edits a sign at `finish`.
    pub view_action: Option<&'static str>,
    /// The music track that the edit starts, or -1.
    pub music_track: i64,
}

fn tool_args(group: i64, subtool: i64, free_mode: bool) -> ToolArgs {
    ToolArgs {
        group,
        subtool,
        cost: catalog::tool(group, subtool).map_or(0, |tool| tool.cost),
        free_mode,
    }
}

/// The zone that a tool paints, 0 for De-zone, or -1.
pub fn zone_type(group: i64, subtool: i64) -> i64 {
    if group == group::BULLDOZER && subtool == DEZONE_SLOT {
        return 0;
    }

    ZONE_TYPES
        .iter()
        .find(|(known, _)| *known == group)
        .and_then(|(_, types)| types.get(usize::try_from(subtool).ok()?).copied())
        .unwrap_or(-1)
}

/// The building that a tool places, or `None`.
pub fn building_tile(group: i64, subtool: i64) -> Option<i64> {
    let slot = group * MAX_SLOTS_PER_GROUP + subtool;

    TILE_BY_TOOL.iter().find(|(known, _)| *known == slot).map(|(_, tile)| *tile)
}

pub fn is_available(session: &Session, group: i64, subtool: i64) -> bool {
    let misc_data = session.city.chunk("MISC").map(|chunk| chunk.data.as_slice()).unwrap_or_default();

    availability::is_available(misc_data, session.city.city_mode(), group, subtool)
}

fn int(value: &Value, name: &str) -> i64 {
    crate::values::int(value, name, 0)
}

fn sounds_of(value: &Value) -> Vec<i64> {
    crate::values::ints(value, "sound_events").into_iter().map(i64::from).collect()
}

/// Apply the selected tool, as ApplicationCityEdits.apply_map_selection. The
/// session records the undo of a changing edit.
pub fn apply(session: &mut Session, selection: &Selection) -> Outcome {
    let (group, subtool) = (selection.group, selection.subtool);
    let Some(tool) = catalog::tool(group, subtool) else {
        return failure("No tool is selected.", Vec::new());
    };

    match group {
        group::CENTERING => return view_tool("center"),
        group::QUERY => return view_tool("query"),
        group::SIGNS => return view_tool("sign"),
        group::DISPATCH => return view_tool("dispatch"),
        _ => {}
    }

    if !is_available(session, group, subtool) {
        return failure(&format!("{} is not available in this city.", tool.name), Vec::new());
    }

    let before = Undo::capture(session);
    let slot = selection.slot();
    let args = tool_args(group, subtool, false);
    let (kind, result) = run(session, selection, slot, &args);
    let ok = crate::values::boolean(&result, "ok");

    if !ok {
        let error = crate::values::text(&result, "error");
        let sounds = if ["landscape", "hydro", "subway_to_rail", "onramp", "zone", "building", "network"].contains(&kind) {
            sounds::failure_events(group, subtool, &error)
        } else {
            Vec::new()
        };

        // a rejected building can still draw from the LFSR; drop the undo then
        session.undo = None;

        return Outcome {
            result: result.clone(),
            kind,
            ..failure(
                &messages::failure(kind, tool.name, if error.is_empty() { "unknown error" } else { &error }),
                sounds,
            )
        };
    }

    publish_utility_usage(session, &result);
    session.undo = before.finish(session, kind);
    session.revision += 1;
    session.map_revision += 1;

    let mut sounds = sounds_of(&result);

    match kind {
        "zone" => sounds.extend(sounds::zone_success_events(zone_type(group, subtool))),
        "terrain" => sounds.push(sounds::TRACTOR),
        "landscape" | "hydro" | "subway_to_rail" | "onramp" | "building" | "network" | "tunnel" | "highway" => {
            sounds.extend(sounds::success_events(group, subtool))
        }
        _ => {}
    }

    let music_track = if kind == "building" && group == group::RECREATION && session.city.music_enabled() {
        RECREATION_TRACK
    } else {
        -1
    };

    Outcome {
        ok: true,
        message: messages::success(kind, tool.name, &result),
        cost: int(&result, "cost"),
        sounds,
        effects: crate::values::items(&result, "effect_events"),
        kind,
        result,
        view_action: None,
        music_track,
    }
}

impl Default for Outcome {
    fn default() -> Self {
        Self {
            ok: false,
            message: String::new(),
            cost: 0,
            sounds: Vec::new(),
            effects: Vec::new(),
            kind: "",
            result: Value::Nil,
            view_action: None,
            music_track: -1,
        }
    }
}

fn view_tool(action: &'static str) -> Outcome {
    Outcome {
        ok: true,
        view_action: Some(action),
        music_track: -1,
        ..Outcome::default()
    }
}

fn failure(message: &str, sounds: Vec<i64>) -> Outcome {
    Outcome {
        message: message.to_string(),
        sounds,
        music_track: -1,
        ..Outcome::default()
    }
}

/// Run the command of a tool slot. Returns its family and result.
fn run(session: &mut Session, selection: &Selection, slot: i64, args: &ToolArgs) -> (&'static str, Value) {
    let city = &mut session.city;
    let randoms = &mut session.randoms;
    let (group, subtool) = (selection.group, selection.subtool);

    if group == group::LANDSCAPE && LANDSCAPE_SUBTOOLS.contains(&subtool) {
        return (
            "landscape",
            landscape::apply(city, args, &selection.path, &mut randoms.random, false).to_value(),
        );
    }

    if slot == DEMOLISH_SLOT {
        return (
            "demolish",
            demolish::apply(city, args, &selection.path, &mut randoms.random, selection.underground, false).to_value(),
        );
    }

    if TERRAIN_SLOTS.contains(&slot) {
        let path = TerrainPath {
            start: selection.start,
            points: &selection.path,
            target_override: -1,
        };

        return (
            "terrain",
            landscape::terrain::apply(city, args, &path, Some(&mut randoms.random)).to_value(),
        );
    }

    if slot == HYDRO_SLOT {
        return ("hydro", hydro::apply(city, args, selection.finish, &mut randoms.random).to_value());
    }

    if slot == SUBWAY_TO_RAIL_SLOT {
        return (
            "subway_to_rail",
            subway_to_rail::apply(city, args, selection.finish, false).to_value(),
        );
    }

    if slot == ONRAMP_SLOT {
        return ("onramp", onramp::apply(city, args, selection.finish, false).to_value());
    }

    if NETWORK_SLOTS.contains(&slot) || slot == HIGHWAY_SLOT {
        let choices = RouteChoices {
            bridge: selection.bridge,
            connection: selection.connection,
            highway: slot == HIGHWAY_SLOT,
        };
        let kind = if slot == HIGHWAY_SLOT { "highway" } else { "network" };

        return (
            kind,
            route::drag(city, args, selection.start, selection.finish, &choices).to_value(),
        );
    }

    if slot == TUNNEL_SLOT {
        return (
            "tunnel",
            tunnel::apply(city, args, selection.finish, selection.confirmation).to_value(),
        );
    }

    if let Some(tile) = building_tile(group, subtool) {
        let placement = Placement {
            tile,
            area: catalog::tool(group, subtool).map_or(1, |tool| tool.area),
            available: true,
            australian_locale: false,
        };

        return (
            "building",
            building::apply(city, args, &placement, selection.finish, &mut randoms.lfsr, &mut randoms.random).to_value(),
        );
    }

    let request = ZoneRequest {
        start: selection.start,
        finish: selection.finish,
        dragged: selection.dragged,
        tool_zone: zone_type(group, subtool),
        has_tool: true,
        zone_type_override: -1,
    };

    ("zone", zone::apply(city, args, &request).to_value())
}

/// A placement scans power and water at once; the engine shows the new usage.
fn publish_utility_usage(session: &mut Session, result: &Value) {
    let power = crate::values::int(result, "power_usage_percent", -1);
    let water = crate::values::int(result, "water_usage_percent", -1);

    if power >= 0 {
        session.engine.day.power_usage_percent = power;
    }

    if water >= 0 {
        session.engine.day.water_usage_percent = water;
    }
}

/// The funds of the city, as the status bar shows them.
pub fn funds(session: &Session) -> i64 {
    session.city.misc_i32(misc::FUNDS)
}
