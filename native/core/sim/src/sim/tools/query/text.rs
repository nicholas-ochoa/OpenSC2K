//! The text of the query dialog, as QueryText.

use super::strings::{GRADE_NAMES, MICROSIM_LINES, SPORTS};
use super::{Microsim, QueryInfo, label};
use crate::sim::city::City;
use crate::sim::ids::building_tile_ids as tiles;

/// The games of a stadium season.
const SEASON_GAMES: i64 = 40;

/// The sounds of a facility query.
mod sound {
    pub const POWER: i64 = 514;
    pub const LANDMARK: i64 = 513;
    pub const SIREN: i64 = 506;
    pub const FIRE_BELL: i64 = 509;
    pub const SCHOOL_BELL: i64 = 523;
    pub const PRISON: i64 = 522;
    pub const ZOO: i64 = 527;
    pub const BUS: i64 = 521;
    pub const TRAIN: i64 = 524;
    pub const BOAT: i64 = 511;
    pub const ARCOLOGY: i64 = 526;
    pub const CROWD_LOW: i64 = 512;
}

/// The arcology statistic 0 above this cheers, at or below `ARCOLOGY_QUIET` grumbles.
const ARCOLOGY_CHEER: i64 = 9;
const ARCOLOGY_QUIET: i64 = 3;

/// The sounds that a facility query plays.
pub fn specific_sound_events(tile_id: i64, statistic_0: i64) -> Vec<i64> {
    match tile_id {
        tiles::HYDRO_POWER_1
        | tiles::HYDRO_POWER_2
        | tiles::WIND_POWER
        | tiles::GAS_POWER
        | tiles::OIL_POWER
        | tiles::NUCLEAR_POWER
        | tiles::SOLAR_POWER
        | tiles::MICROWAVE_POWER
        | tiles::FUSION_POWER
        | tiles::COAL_POWER => vec![sound::POWER],
        tiles::CITY_HALL | tiles::BIG_PARK | tiles::STADIUM | tiles::STATUE | tiles::MAYOR_HOUSE | tiles::LLAMA_DOME => {
            vec![sound::LANDMARK]
        }
        tiles::HOSPITAL | tiles::POLICE_STATION => vec![sound::SIREN],
        tiles::FIRE_STATION => vec![sound::FIRE_BELL],
        tiles::SCHOOL | tiles::COLLEGE => vec![sound::SCHOOL_BELL],
        tiles::PRISON => vec![sound::PRISON],
        tiles::ZOO => vec![sound::ZOO],
        tiles::BUS_DEPOT => vec![sound::BUS],
        tiles::RAIL_STATION => vec![sound::TRAIN],
        tiles::MARINA => vec![sound::BOAT],
        tiles::PLYMOUTH_ARCOLOGY | tiles::FOREST_ARCOLOGY | tiles::DARCO_ARCOLOGY | tiles::LAUNCH_ARCOLOGY => {
            if statistic_0 > ARCOLOGY_CHEER {
                vec![sound::ARCOLOGY, sound::LANDMARK]
            } else if statistic_0 <= ARCOLOGY_QUIET {
                vec![sound::ARCOLOGY, sound::CROWD_LOW]
            } else {
                vec![sound::ARCOLOGY]
            }
        }
        _ => Vec::new(),
    }
}

/// The statistic lines of a facility of `microsim_type`.
pub fn specific_lines(city: &City, microsim: &Microsim, microsim_type: i64) -> Vec<String> {
    match usize::try_from(microsim_type).ok().and_then(|kind| MICROSIM_LINES.get(kind)) {
        Some(lines) => lines
            .iter()
            .map(|template| expand_specific_template(city, microsim, template))
            .collect(),
        None => Vec::new(),
    }
}

fn indexed(names: &[&str], index: i64) -> String {
    match usize::try_from(index).ok().and_then(|index| names.get(index)) {
        Some(name) => name.to_string(),
        None => index.to_string(),
    }
}

/// Replace the statistic codes of one line, in order.
pub fn expand_specific_template(city: &City, microsim: &Microsim, template: &str) -> String {
    let wins_losses = if microsim.stat_0 != 0 {
        format!("{}-{}", microsim.stat_0, SEASON_GAMES - microsim.stat_0)
    } else {
        String::new()
    };

    template
        .replace("#0", &microsim.stat_0.to_string())
        .replace("#1", &microsim.stat_1.to_string())
        .replace("#2", &microsim.stat_2.to_string())
        .replace("#3", &microsim.stat_3.to_string())
        .replace("#G", &indexed(&GRADE_NAMES, microsim.stat_0))
        .replace("#S", &indexed(&SPORTS, microsim.stat_2))
        .replace("#T", &label(city, microsim.stat_3))
        .replace("#W", &wins_losses)
}

/// The dialog text of a failed query.
pub fn failure_text(error: &str) -> String {
    format!("Query failed: {error}")
}

/// The dialog text of a query.
pub fn format_text(info: &QueryInfo) -> String {
    let point = info.point;

    if info.kind == "specific" {
        let title = if info.title.is_empty() {
            "City facility"
        } else {
            info.title.as_str()
        };
        let mut lines = vec![title.to_string(), String::new()];
        lines.extend(info.lines.iter().cloned());
        lines.push(String::new());
        lines.extend(advanced_lines(info));

        return lines.join("\n");
    }

    let mut lines = vec![info.title.clone(), format!("Tile: {}, {}", point.x, point.y)];

    if info.zone_id != 0 {
        lines.push(format!("Zone: {}", info.zone_name));

        if !info.zone_density.is_empty() {
            lines.push(format!("Density: {}", info.zone_density));
        }
    }

    if info.shows_traffic {
        lines.push(format!("Traffic: {} cars/minute", info.traffic));
    }

    let depth = if info.altitude_is_depth { " deep" } else { "" };
    lines.push(format!("Altitude: {} feet{depth}", info.altitude_feet));

    if info.shows_land_value {
        lines.push(format!("Land value: ${},000/acre", info.land_value));
    }

    lines.push(format!("Crime: {}", info.crime_level));
    lines.push(format!("Pollution: {}", info.pollution_level));

    if info.shows_utilities {
        lines.push(format!("Powered: {}", if info.powered { "Yes" } else { "No" }));

        if info.water_detail.is_empty() {
            lines.push(format!("Watered: {}", if info.watered { "Yes" } else { "No" }));
        } else {
            lines.push(info.water_detail.clone());
        }
    }

    lines.push(String::new());
    lines.extend(advanced_lines(info));

    lines.join("\n")
}

fn advanced_lines(info: &QueryInfo) -> Vec<String> {
    let point = info.point;
    let flag_text = if info.flag_names.is_empty() {
        "none".to_string()
    } else {
        info.flag_names.join(" ")
    };
    let mut result = vec![
        "Advanced tile data".to_string(),
        format!("Tile ID: {} / 0x{:02X}", info.tile_id, info.tile_id),
        format!("Sprite ID: {} / 0x{:04X}", info.sprite_id, info.sprite_id),
        format!("Coordinates: X={}  Y={}", point.x, point.y),
        format!("ALTM: 0x{:04X}", info.altitude_raw),
        format!("XVAL: {} / 0x{:02X}", info.land_value_raw, info.land_value_raw),
        format!("XCRM: {} / 0x{:02X}", info.crime_raw, info.crime_raw),
        format!("XPLT: {} / 0x{:02X}", info.pollution_raw, info.pollution_raw),
        format!("XTXT: {} / 0x{:02X}", info.overlay_id, info.overlay_id),
        format!(
            "XZON: {}, zone 0x{:X} (raw 0x{:02X})",
            info.corner_name, info.zone_id, info.zone_raw
        ),
        format!("XBIT: {flag_text} (0x{:02X})", info.flags_raw),
        format!(
            "Underground: {} (XUND {} / 0x{:02X})",
            info.underground_name, info.underground_id, info.underground_id
        ),
    ];

    if info.microsim_id < 0 {
        result.push("Microsim ID: None".into());
    } else {
        if !info.microsim_label.is_empty() {
            result.push(format!("Microsim name: {}", info.microsim_label));
        }

        result.push(format!("Microsim ID: {} / 0x{:02X}", info.microsim_id, info.microsim_id));

        match &info.microsim {
            None => result.push("XMIC data: unavailable".into()),
            Some(microsim) => {
                result.push(format!("Data 0: {} / 0x{:02X}", microsim.stat_0, microsim.stat_0));

                for (index, value) in [microsim.stat_1, microsim.stat_2, microsim.stat_3].into_iter().enumerate() {
                    result.push(format!("Data {}: {value} / 0x{value:04X}", index + 1));
                }
            }
        }
    }

    if !info.things.is_empty() {
        result.push(String::new());
        result.push("XTHG moving objects".into());

        for thing in &info.things {
            let [kind, direction, state, x, y, z, px, py, dx, dy, label, goal] = thing.fields;
            result.push(format!("Record {}: {} (type {kind} / 0x{kind:02X})", thing.record, thing.type_name));
            result.push(format!(
                "Direction: {} ({direction})  State: {state} / 0x{state:02X}",
                thing.direction_name
            ));
            result.push(format!("Position: X={x} Y={y} Z={z}  PX={px} PY={py}"));
            result.push(format!("Target/data: DX={dx} DY={dy}  Label={label}  Goal={goal}"));
        }
    }

    result
}
