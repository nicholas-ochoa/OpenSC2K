//! Operation dispatch.
//!
//! A request has these fields:
//! - `op`: the operation name.
//! - `city`: `{map_size, large_version, disaster_damage_class, chunks: {id: bytes}}`.
//! - `randoms`: the SimRandom, SimLfsrRandom, and GameLcgRandom states.
//! - `args`: operation arguments.
//!
//! A response has `ok`, `error`, `written` (`{id: bytes}`), `randoms`,
//! `disaster_damage_class`, and `result`.

use godot::prelude::*;

use super::convert;
use crate::sim::city::City;
use crate::sim::civic::{annual, education, milestones, nation, scenario};
use crate::sim::data_maps;
use crate::sim::disasters::{end as disaster_end, map as disaster_map, start as disaster_start, weather};
use crate::sim::economy::{self, budget, city_value};
use crate::sim::engine::month;
use crate::sim::growth;
use crate::sim::growth::{aftermath, demand};
use crate::sim::infrastructure::{power, traffic, water};
use crate::sim::random::Randoms;
use crate::sim::reports::graphs;
use crate::sim::value::{ToValue, Value};

pub const OPERATIONS: &[&str] = &[
    "echo",
    "growth",
    "pollution",
    "data_maps.native",
    "data_maps.coverage",
    "data_maps.land_value",
    "power",
    "water",
    "traffic",
    "budget.settle_year",
    "budget.run_month",
    "budget.run",
    "budget.set_funding",
    "bankruptcy",
    "city_value.calculate",
    "city_value.run",
    "month_start",
    "rci_demand",
    "rci_aftermath",
    "industry",
    "simnation",
    "education_health",
    "graphs",
    "milestones",
    "scenario",
    "microsim_annual",
    "weather",
    "disaster_start",
    "disaster_map.run_all",
    "disaster_map.dispatch",
    "disaster_map.fire",
    "disaster_map.flood",
    "disaster_map.toxic",
    "disaster_map.riot",
    "disaster_end",
    "maxis_man",
    "moving",
    "mayor_approval",
    "tile_recount",
    "military.resolve",
    "military.reserve",
    "day.schedule",
    "engine.initialize",
    "spawn_thing",
    "spawn_maxis_man",
    "trip",
    "trip_reach",
    "trip.highway_step",
    "trip.advance",
    "trip.trace",
    "military.naval_site",
    "graphs.advance",
    "graphs.current_values",
    "rci.connection_counts",
    "budget.requires_annual_budget",
    "budget.funding_values",
    "rotation",
    "new_terrain",
];

pub struct Outcome {
    pub error: String,
    pub result: Value,
}

impl Outcome {
    pub fn value(result: Value) -> Self {
        Self {
            error: String::new(),
            result,
        }
    }

    pub fn failure(message: impl Into<String>) -> Self {
        Self {
            error: message.into(),
            result: Value::Nil,
        }
    }
}

pub fn run(request: &VarDictionary) -> VarDictionary {
    let op = convert::string(request, "op");
    let args = convert::dictionary(request, "args");
    let mut city = convert::city(request);
    let mut randoms = convert::randoms(request);
    let budget = super::budgets::get(convert::int(request, "budget", 0));
    let tool = super::tool_ops::is_tool(&op);
    let outcome = crate::sim::budget::with_budget(budget, || {
        if tool {
            super::tool_ops::dispatch(&op, &args, &mut city, &mut randoms)
        } else {
            dispatch(&op, &args, &mut city, &mut randoms)
        }
    });

    if tool {
        super::tool_ops::mark_written(request, &mut city, &outcome.result);
    }

    let mut response = VarDictionary::new();
    response.set("ok", outcome.error.is_empty());
    response.set("error", outcome.error.as_str());
    response.set("written", &convert::written_chunks(&city));
    response.set("randoms", &convert::randoms_value(&randoms));
    response.set("disaster_damage_class", city.disaster_damage_class);
    response.set("result", &convert::variant(&outcome.result));
    response
}

fn dispatch(op: &str, args: &VarDictionary, city: &mut City, randoms: &mut Randoms) -> Outcome {
    match op {
        "growth" => {
            let step = convert::int(args, "step", -1);
            let substep = convert::int(args, "substep", -1);
            let detailed = convert::boolean(args, "detailed", false);
            Outcome::value(growth::run(city, randoms, step, substep, detailed).to_value())
        }
        "pollution" => {
            if city.full_resolution_maps() {
                Outcome::value(data_maps::native::run(city).to_value())
            } else {
                Outcome::value(data_maps::coarse::run(city).to_value())
            }
        }
        "data_maps.native" => Outcome::value(data_maps::native::run(city).to_value()),
        "data_maps.coverage" => Outcome::value(data_maps::native::run_pollution_and_coverage(city).to_value()),
        "data_maps.land_value" => Outcome::value(data_maps::native::run_land_value_and_crime(city).to_value()),
        "power" => Outcome::value(power::run(city, &mut randoms.random).to_value()),
        "water" => Outcome::value(water::run(city).to_value()),
        "traffic" => Outcome::value(traffic::run(city).to_value()),
        "budget.settle_year" => {
            Outcome::value(budget::settle_year(city, convert::boolean(args, "annual_budget_approved", false)).to_value())
        }
        "budget.run_month" => {
            let mut settlement = budget::BudgetResult {
                settled_year: convert::boolean(args, "settled_year", false),
                funds_before: convert::int(args, "funds_before", 0),
                ..Default::default()
            };
            settlement.base.ok = convert::boolean(args, "settlement_ok", false);
            settlement.base.timing = convert::timing(args, "settlement_timing");
            Outcome::value(budget::run_month(city, &mut randoms.random, &settlement).to_value())
        }
        "budget.run" => {
            Outcome::value(budget::run(city, &mut randoms.random, convert::boolean(args, "annual_budget_approved", false)).to_value())
        }
        "budget.set_funding" => Outcome::value(
            budget::set_funding(city, &convert::ints32(args, "values"), convert::boolean(args, "auto_budget", false)).to_value(),
        ),
        "bankruptcy" => Outcome::value(economy::bankruptcy(city).to_value()),
        "city_value.calculate" => Outcome::value(city_value::calculate(city).to_value()),
        "city_value.run" => Outcome::value(city_value::run(city).to_value()),
        "month_start" => Outcome::value(month::month_start(city).to_value()),
        "rci_demand" => Outcome::value(demand::rci_demand(city).to_value()),
        "rci_aftermath" => Outcome::value(aftermath::run(city, &mut randoms.random, convert::int(args, "season", -1)).to_value()),
        "industry" => Outcome::value(
            demand::industry(
                city,
                &mut randoms.random,
                &mut randoms.lfsr,
                convert::int(args, "population_growth", 0),
            )
            .to_value(),
        ),
        "simnation" => Outcome::value(nation::run(city, &mut randoms.random).to_value()),
        "education_health" => Outcome::value(education::run(city, &mut randoms.random).to_value()),
        "graphs" => Outcome::value(
            graphs::run(
                city,
                convert::int(args, "developed_tiles", -1),
                convert::int(args, "power_usage_percent", -1),
                convert::int(args, "water_usage_percent", -1),
            )
            .to_value(),
        ),
        "milestones" => Outcome::value(milestones::run(city).to_value()),
        "scenario" => {
            let mut state = convert::scenario(args, "scenario");
            let result = scenario::run(city, state.as_mut()).to_value();
            Outcome::value(result)
        }
        "microsim_annual" => {
            let has_random = convert::boolean(args, "has_random", true);
            let has_lfsr = convert::boolean(args, "has_lfsr", true);
            let has_game = convert::boolean(args, "has_game", true);
            let Randoms { random, lfsr, game } = randoms;
            let mut inputs = annual::AnnualInputs {
                bus_passengers: convert::int(args, "bus_passengers", 0),
                rail_passengers: convert::int(args, "rail_passengers", 0),
                subway_passengers: convert::int(args, "subway_passengers", 0),
                random: has_random.then_some(random),
                lfsr: has_lfsr.then_some(lfsr),
                game: has_game.then_some(game),
                power_usage_percent: convert::int(args, "power_usage_percent", -1),
                water_usage_percent: convert::int(args, "water_usage_percent", -1),
                australian_locale: convert::boolean(args, "australian_locale", false),
                mayor_approval: convert::int(args, "mayor_approval", 0),
            };
            Outcome::value(annual::run(city, &mut inputs).to_value())
        }
        "weather" => Outcome::value(
            weather::run(
                city,
                &mut randoms.random,
                &mut randoms.lfsr,
                convert::int(args, "power_usage_percent", 0),
                convert::int(args, "water_usage_percent", 0),
                convert::int(args, "commerce_connections", 0),
                convert::int(args, "industry_connections", 0),
                convert::point(args, "current_disaster_point", crate::sim::geom::Vec2i::ZERO),
            )
            .to_value(),
        ),
        "disaster_start" => {
            let random = convert::boolean(args, "has_random", true).then_some(&mut randoms.random);
            let lfsr = convert::boolean(args, "has_lfsr", true).then_some(&mut randoms.lfsr);
            let disaster_type = convert::int(args, "disaster_type", 0);
            let point = convert::point(args, "point", crate::sim::geom::Vec2i::ZERO);
            Outcome::value(disaster_start::start(city, disaster_type, point, random, lfsr).to_value())
        }
        "disaster_map.run_all"
        | "disaster_map.dispatch"
        | "disaster_map.fire"
        | "disaster_map.flood"
        | "disaster_map.toxic"
        | "disaster_map.riot" => {
            let random = convert::boolean(args, "has_random", true).then_some(&mut randoms.random);
            let lfsr = convert::boolean(args, "has_lfsr", true).then_some(&mut randoms.lfsr);
            let map_counter = convert::int(args, "map_counter", 0);
            let result = match op {
                "disaster_map.run_all" => {
                    disaster_map::run_all(city, random, lfsr, map_counter, convert::int(args, "hurricane_counter", 0))
                }
                "disaster_map.dispatch" => disaster_map::run_dispatch(city, random, lfsr),
                "disaster_map.fire" => disaster_map::run_fire(city, random, lfsr),
                "disaster_map.flood" => disaster_map::run_flood(city, random, lfsr, map_counter),
                "disaster_map.toxic" => disaster_map::run_toxic(city, random, lfsr),
                _ => disaster_map::run_riot(city, random, lfsr),
            };
            Outcome::value(result.to_value())
        }
        "disaster_end" => Outcome::value(disaster_end::finish(city, convert::int(args, "disaster_type", 0)).to_value()),
        "maxis_man" => Outcome::value(
            disaster_end::maxis_man_response(
                city,
                convert::point(args, "point", crate::sim::geom::Vec2i::ZERO),
                convert::int(args, "disaster_type", 0),
                convert::int(args, "record", 0),
                &mut randoms.random,
                &mut randoms.lfsr,
            )
            .to_value(),
        ),
        "moving" => {
            let options = crate::sim::moving::phase::TickOptions {
                ship_home: convert::point(args, "ship_home", crate::sim::geom::Vec2i::NONE),
                allow_disaster_damage: convert::boolean(args, "allow_disaster_damage", true),
                traffic_news_time_msec: convert::int(args, "traffic_news_time_msec", 0),
                traffic_news_deadline_msec: convert::int(args, "traffic_news_deadline_msec", 0),
                suppress_vehicle_crashes: convert::boolean(args, "suppress_vehicle_crashes", false),
            };
            let Randoms { random, lfsr, game } = randoms;
            Outcome::value(crate::sim::moving::phase::run(city, random, lfsr, game, &options).to_value())
        }
        "mayor_approval" => {
            Outcome::value(crate::sim::civic::mayor::run(city, &mut randoms.random, convert::int(args, "previous_approval", 0)).to_value())
        }
        "new_terrain" => new_terrain(args, city, randoms),
        "rotation" => {
            Outcome::value(crate::sim::tools::rotation::rotate(city, convert::boolean(args, "counter_clockwise", false)).to_value())
        }
        "tile_recount" => Outcome::value(Value::Int(crate::sim::civic::mayor::recount_tiles(city))),
        "military.resolve" => {
            let game = convert::boolean(args, "has_game", true).then_some(&mut randoms.game);
            Outcome::value(
                crate::sim::civic::military::resolve(
                    city,
                    convert::boolean(args, "accepted", false),
                    game,
                    convert::boolean(args, "defer_land_plot", false),
                )
                .to_value(),
            )
        }
        "military.reserve" => Outcome::value(
            crate::sim::civic::military::reserve_land_site(
                city,
                convert::int(args, "base_type", 0),
                convert::rect(args, "site"),
                convert::int(args, "notice_id", -1),
            )
            .to_value(),
        ),
        "day.schedule" => {
            // The original asks for the annual budget before it runs the day.
            if convert::boolean(args, "check_annual_budget", false) && budget::requires_annual_budget(city) {
                return Outcome::value(Value::Dict(vec![
                    (Value::Str("ok".to_string()), Value::Bool(true)),
                    (Value::Str("annual_budget".to_string()), Value::Bool(true)),
                    (
                        Value::Str("funding_values".to_string()),
                        Value::Ints32(budget::funding_values(city)),
                    ),
                ]));
            }

            let schedule = convert::schedule(args, "schedule");
            let state = convert::engine_state(args, "engine");
            let scenario = convert::scenario(args, "scenario");
            let (outcome, state, scenario) = crate::sim::engine::day::run_schedule(
                city,
                randoms,
                scenario,
                state,
                &schedule,
                convert::boolean(args, "annual_budget_approved", false),
                convert::boolean(args, "detailed", false),
            );
            let Value::Dict(mut fields) = outcome.to_value() else {
                unreachable!()
            };
            fields.push((Value::Str("engine".to_string()), state.to_value()));
            let time_limit = scenario.map(|scenario| scenario.time_limit_months).unwrap_or(-1);
            fields.push((Value::Str("scenario_time_limit".to_string()), Value::Int(time_limit)));
            Outcome::value(Value::Dict(fields))
        }
        "engine.initialize" => match crate::sim::engine::load::initialize_loaded_city(city, &mut randoms.random) {
            Some(scan) => Outcome::value(Value::Dict(vec![
                (Value::Str("power_usage_percent".to_string()), Value::Int(scan.power_usage_percent)),
                (Value::Str("water_usage_percent".to_string()), Value::Int(scan.water_usage_percent)),
                (Value::Str("developed_tiles".to_string()), Value::Int(scan.developed_tiles)),
            ])),
            None => Outcome::failure("the load scan failed"),
        },
        "spawn_thing" => {
            let points = convert::points(args, "points");
            let Randoms { random, lfsr, game } = randoms;
            let (point, count, record) = crate::sim::moving::spawner::spawn_near(
                city,
                convert::int(args, "kind", -1),
                &points,
                convert::point(args, "view_center", crate::sim::geom::Vec2i::ZERO),
                random,
                lfsr,
                game,
            );
            Outcome::value(Value::Dict(vec![
                (Value::Str("point".to_string()), Value::Vec2i(point)),
                (Value::Str("count".to_string()), Value::Int(count)),
                (Value::Str("record".to_string()), Value::Int(record)),
            ]))
        }
        "spawn_maxis_man" => {
            let map_edge = city.map_size;
            let mut data = city.xthg.data.clone();
            let mut text = city.xtxt.data.clone();
            let spawned = crate::sim::moving::spawner::spawn_maxis_man(
                &mut data,
                &mut text,
                convert::point(args, "point", crate::sim::geom::Vec2i::ZERO),
                convert::point(args, "target", crate::sim::geom::Vec2i::ZERO),
                convert::int(args, "goal", 0),
                convert::int(args, "height", 0),
                map_edge,
                &crate::sim::moving::spawner::VehicleCaps::for_city(city),
            );

            if spawned.spawned {
                city.xthg.replace(data);
                city.xtxt.replace(text);
            }

            Outcome::value(Value::Bool(spawned.spawned))
        }
        "trip" => Outcome::value(
            crate::sim::reach::run_trip(
                city,
                convert::point(args, "origin", crate::sim::geom::Vec2i::ZERO),
                convert::int(args, "zone", 0),
                convert::int(args, "traffic_weight", 0),
                &mut randoms.random,
                convert::int(args, "maximum_cost", 100),
            )
            .to_value(),
        ),
        "trip_reach" => {
            Outcome::value(crate::sim::reach::inspect(city, convert::point(args, "clicked", crate::sim::geom::Vec2i::ZERO)).to_value())
        }
        // Trip rule queries for tests and diagnostics. They do not change the city.
        "trip.highway_step" => Outcome::value(Value::Bool(crate::sim::trip::highway_step(
            &city.xbld.data,
            convert::point(args, "from", crate::sim::geom::Vec2i::ZERO),
            convert::point(args, "to", crate::sim::geom::Vec2i::ZERO),
            city.map_size,
        ))),
        "trip.advance" | "trip.trace" => {
            let edge = city.map_size;
            let maps = crate::sim::trip::TripMaps {
                buildings: &city.xbld.data,
                zones: &city.xzon.data,
                underground: &city.xund.data,
                text_overlays: &city.xtxt.data,
                altitude: &city.altm.data,
                map_edge: edge,
            };

            if op == "trip.advance" {
                let from = convert::point(args, "from", crate::sim::geom::Vec2i::ZERO);
                let to = convert::point(args, "to", crate::sim::geom::Vec2i::ZERO);
                let index = |point: crate::sim::geom::Vec2i| {
                    if point.x >= 0 && point.y >= 0 && point.x < edge && point.y < edge {
                        point.x * edge + point.y
                    } else {
                        -1
                    }
                };
                let mode = convert::int(args, "mode", 0);
                let zone = convert::int(args, "zone", 0);
                Outcome::value(Value::Int(crate::sim::trip::advance(
                    &maps,
                    from,
                    to,
                    index(from),
                    index(to),
                    mode,
                    zone,
                )))
            } else {
                let mut traffic = city.xtrf.data.clone();
                let mut scratch = crate::sim::trip::TripScratch::default();
                let result = crate::sim::trip::trace(
                    &maps,
                    &mut traffic,
                    convert::point(args, "origin", crate::sim::geom::Vec2i::ZERO),
                    convert::int(args, "zone", 0),
                    convert::int(args, "traffic_weight", 0),
                    &mut randoms.random,
                    convert::int(args, "maximum_cost", 100),
                    convert::int(args, "start", -1),
                    None,
                    &mut scratch,
                );
                Outcome::value(result.to_value())
            }
        }
        "military.naval_site" => Outcome::value(Value::Rect2i(crate::sim::civic::military::find_naval_site(city))),
        "graphs.advance" => {
            let values: Vec<i64> = convert::ints64(args, "values");

            match graphs::advance(city, &values) {
                Ok((month, elapsed_years)) => {
                    let mut result = graphs::GraphResult {
                        month,
                        elapsed_years,
                        ..Default::default()
                    };
                    result.base.ok = true;
                    Outcome::value(result.to_value())
                }
                Err(message) => Outcome::value(graphs::GraphResult::failed(message).to_value()),
            }
        }
        "graphs.current_values" => {
            let result = match graphs::calculate_current_values(
                city,
                convert::int(args, "developed_tiles", -1),
                convert::int(args, "power_usage_percent", -1),
                convert::int(args, "water_usage_percent", -1),
            ) {
                Ok((values, unemployment)) => {
                    let mut result = graphs::GraphResult {
                        values: crate::sim::value::Ints64(values),
                        unemployment,
                        ..Default::default()
                    };
                    result.base.ok = true;
                    result
                }
                Err(message) => graphs::GraphResult::failed(message),
            };
            Outcome::value(result.to_value())
        }
        "rci.connection_counts" => {
            let counts = demand::connection_counts(city);
            Outcome::value(Value::Dict(vec![
                (Value::Str("commerce".to_string()), Value::Int(counts.commerce)),
                (Value::Str("industry".to_string()), Value::Int(counts.industry)),
            ]))
        }
        "budget.requires_annual_budget" => Outcome::value(Value::Bool(budget::requires_annual_budget(city))),
        "budget.funding_values" => Outcome::value(Value::Ints32(budget::funding_values(city))),
        "echo" => Outcome::value(Value::Int(convert::int(args, "value", 0) + city.map_size)),
        _ => Outcome::failure(format!("unknown native simulation operation: {op}")),
    }
}

/// `args`: the 128 by 128 `heights` and `coast_flags`, and the generator options.
fn new_terrain(args: &VarDictionary, city: &mut City, randoms: &mut Randoms) -> Outcome {
    use crate::sim::tools::new_terrain::{self, LANDFORM_EDGE, Landform};

    let landform = Landform {
        heights: convert::ints32(args, "heights"),
        coast_flags: convert::bytes(args, "coast_flags"),
        extended: convert::boolean(args, "extended", false),
        smooth_slopes: convert::boolean(args, "smooth_slopes", false),
        has_ocean: convert::boolean(args, "has_ocean", false),
        has_river: convert::boolean(args, "has_river", false),
        water_level: convert::int(args, "water_level", 0),
        water: convert::int(args, "water", 0),
        trees: convert::int(args, "trees", 0),
    };
    let cells = (city.map_size * city.map_size) as usize;

    if landform.heights.len() != LANDFORM_EDGE * LANDFORM_EDGE
        || landform.coast_flags.len() != LANDFORM_EDGE * LANDFORM_EDGE
        || city.map_size < 2
        || city.altm.data.len() != cells * 2
        || [&city.xter, &city.xbld, &city.xzon, &city.xbit]
            .iter()
            .any(|chunk| chunk.data.len() != cells)
        || city.xtxt.data.len() < cells
        || city.misc.data.len() != crate::sim::ids::sc2misc_layout::SIZE as usize
    {
        return Outcome::failure("terrain data is missing or invalid");
    }

    Outcome::value(new_terrain::generate(city, &landform, &mut randoms.random).to_value())
}
