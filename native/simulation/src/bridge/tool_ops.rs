//! Player tool operations: `tool.*` requests.
//!
//! Each command edits the chunks of the request city. A chunk goes back to the
//! document only when the command succeeds and the chunk bytes changed, as the
//! GDScript commands compare their payload copies.

use godot::prelude::*;

use super::convert;
use super::ops::Outcome;
use sc2k_sim::sim::city::{CHUNK_IDS, City};
use sc2k_sim::sim::effect_sampling;
use sc2k_sim::sim::geom::Vec2i;
use sc2k_sim::sim::random::Randoms;
use sc2k_sim::sim::tools::commands::building::{self, Placement};
use sc2k_sim::sim::tools::commands::landscape::terrain::TerrainPath;
use sc2k_sim::sim::tools::commands::route::{self, RouteChoices};
use sc2k_sim::sim::tools::commands::zone::{self, ZoneRequest};
use sc2k_sim::sim::tools::commands::{
    ToolArgs, building::facility_repair, demolish, dispatch, highway, hydro, landscape, onramp, scurk_place, sign, subway_to_rail, tunnel,
};

use sc2k_sim::sim::value::{ToValue, Value};

pub const OPERATIONS: &[&str] = &[
    "tool.route",
    "tool.highway_preview",
    "tool.tunnel",
    "tool.onramp",
    "tool.hydro",
    "tool.subway_to_rail",
    "tool.building",
    "tool.building_preview",
    "tool.zone",
    "tool.zone_preview",
    "tool.demolish",
    "tool.terrain",
    "tool.landscape",
    "tool.landscape_editor",
    "tool.scurk_place",
    "tool.facility_repair",
    "tool.dispatch",
    "tool.dispatch_recall",
    "tool.dispatch_availability",
    "tool.dispatch_begin_disaster",
    "tool.sign",
];

pub fn is_tool(op: &str) -> bool {
    op.starts_with("tool.")
}

fn tool_args(args: &VarDictionary) -> ToolArgs {
    ToolArgs {
        group: convert::int(args, "group", -1),
        subtool: convert::int(args, "subtool", -1),
        cost: convert::int(args, "cost", 0),
        free_mode: convert::boolean(args, "free_mode", false),
    }
}

fn point(args: &VarDictionary, key: &str) -> Vec2i {
    convert::point(args, key, Vec2i::NONE)
}

pub fn dispatch(op: &str, args: &VarDictionary, city: &mut City, randoms: &mut Randoms) -> Outcome {
    let tool = tool_args(args);

    let result: Value = match op {
        "tool.route" => {
            let choices = RouteChoices {
                bridge: convert::int(args, "bridge", -1),
                connection: convert::int(args, "connection", -1),
                highway: convert::boolean(args, "highway", false),
            };

            route::drag(city, &tool, point(args, "start"), point(args, "finish"), &choices).to_value()
        }
        "tool.highway_preview" => Value::Str(highway::segment::preview_error(city, point(args, "point"))),
        "tool.tunnel" => tunnel::apply(city, &tool, point(args, "point"), convert::int(args, "confirmation", -1)).to_value(),
        "tool.onramp" => onramp::apply(city, &tool, point(args, "point"), convert::boolean(args, "preview_only", false)).to_value(),
        "tool.hydro" => hydro::apply(city, &tool, point(args, "point"), &mut randoms.random).to_value(),
        "tool.subway_to_rail" => {
            subway_to_rail::apply(city, &tool, point(args, "point"), convert::boolean(args, "preview_only", false)).to_value()
        }
        "tool.building" => {
            let placement = building_placement(args);

            building::apply(
                city,
                &tool,
                &placement,
                point(args, "point"),
                &mut randoms.lfsr,
                &mut randoms.random,
            )
            .to_value()
        }
        "tool.building_preview" => {
            let placement = building_placement(args);

            Value::Str(building::preview_error(city, tool.cost, &placement, point(args, "point")).to_string())
        }
        "tool.zone" | "tool.zone_preview" => {
            let request = ZoneRequest {
                start: point(args, "start"),
                finish: point(args, "finish"),
                dragged: convert::boolean(args, "dragged", true),
                tool_zone: convert::int(args, "tool_zone", -1),
                has_tool: convert::boolean(args, "has_tool", true),
                zone_type_override: convert::int(args, "zone_type_override", -1),
            };

            if op == "tool.zone" {
                zone::apply(city, &tool, &request).to_value()
            } else {
                zone::preview(city, &tool, &request).to_value()
            }
        }
        "tool.demolish" => {
            let mut result = demolish::apply(
                city,
                &tool,
                &convert::points(args, "points"),
                &mut randoms.random,
                convert::boolean(args, "underground_view", false),
                convert::boolean(args, "scurk_mode", false),
            );

            // the view shows the dust of only a spread of tiles near it
            let effects = std::mem::take(&mut result.base.effect_events);
            let tile_limit = convert::int(args, "effect_tile_limit", 0).max(0) as usize;
            result.base.effect_events = effect_sampling::sample(effects, convert::rect(args, "effect_window"), tile_limit);
            result.to_value()
        }
        "tool.terrain" => {
            let points = convert::points(args, "points");
            let path = TerrainPath {
                start: point(args, "start"),
                points: &points,
                target_override: convert::int(args, "target_override", -1),
            };

            let random = convert::boolean(args, "has_random", true).then_some(&mut randoms.random);

            landscape::terrain::apply(city, &tool, &path, random).to_value()
        }
        "tool.landscape" => landscape::apply(
            city,
            &tool,
            &convert::points(args, "points"),
            &mut randoms.random,
            convert::boolean(args, "use_brush_points", false),
        )
        .to_value(),
        "tool.landscape_editor" => landscape::editor::apply(
            city,
            tool.group,
            tool.subtool,
            point(args, "point"),
            &mut randoms.random,
            convert::int(args, "stretch_levels", 1),
        )
        .to_value(),
        "tool.scurk_place" => scurk_place::apply(
            city,
            convert::int(args, "tile", 0),
            point(args, "point"),
            &mut randoms.random,
            convert::int(args, "selected_zone", 0),
            convert::boolean(args, "australian_locale", false),
            convert::boolean(args, "flipped", false),
        )
        .to_value(),
        "tool.facility_repair" => facility_repair::apply(city).to_value(),
        "tool.dispatch" => {
            let capacity = match convert::ints32(args, "capacity").as_slice() {
                [police, fire, military] => [i64::from(*police), i64::from(*fire), i64::from(*military)],
                _ => dispatch::NO_CAPACITY,
            };
            let edit = dispatch::apply(
                city,
                tool.subtool,
                point(args, "target"),
                convert::int(args, "cycle_index", 0),
                &slot_points(args),
                capacity,
            );

            edit.map_or_else(|error| dispatch::rejected(&error), |edit| edit.to_value())
        }
        "tool.sign" => sign::set_sign(city, point(args, "point"), &convert::string(args, "text"))
            .map_or_else(|error| sign::rejected(&error), |edit| edit.to_value()),
        "tool.dispatch_recall" => dispatch::recall_all(city).to_value(),
        "tool.dispatch_availability" => dispatch::availability_value(dispatch::availability(city)),
        "tool.dispatch_begin_disaster" => dispatch::availability_value(dispatch::begin_disaster(city)),
        _ => return Outcome::failure(format!("unknown tool operation: {op}")),
    };

    Outcome::value(result)
}

/// The tile of each dispatch slot: a dictionary of slot numbers and points.
fn slot_points(args: &VarDictionary) -> Vec<(i64, Vec2i)> {
    convert::dictionary(args, "slot_points")
        .iter_shared()
        .filter_map(|(slot, point)| {
            let point = point.try_to::<Vector2i>().ok()?;

            Some((slot.try_to::<i64>().ok()?, Vec2i::new(i64::from(point.x), i64::from(point.y))))
        })
        .collect()
}

fn building_placement(args: &VarDictionary) -> Placement {
    Placement {
        tile: convert::int(args, "tile", 0),
        area: convert::int(args, "area", 1),
        available: convert::boolean(args, "available", false),
        australian_locale: convert::boolean(args, "australian_locale", false),
    }
}

/// True for an object result whose `ok` field is true.
fn succeeded(result: &Value) -> bool {
    match result {
        Value::Object(_, fields) => fields.iter().any(|(name, value)| *name == "ok" && *value == Value::Bool(true)),
        _ => false,
    }
}

/// Mark the chunks that a successful command changed. A failed command
/// writes nothing.
pub fn mark_written(request: &VarDictionary, city: &mut City, result: &Value) {
    let keep = succeeded(result);
    let source = convert::dictionary(request, "city");
    let chunks = convert::dictionary(&source, "chunks");

    for id in CHUNK_IDS {
        let original = chunks.get(id).and_then(|value| value.try_to::<PackedByteArray>().ok());

        if let Some(chunk) = city.chunk_mut(id) {
            chunk.written = keep && chunk.present && original.is_some_and(|bytes| bytes.as_slice() != chunk.data.as_slice());
        }
    }
}
