//! The status messages of the tools, as SimpleEditFlow writes them.

use crate::values::{int, ints};
use sc2k_sim::sim::value::Value;

/// A whole number with thousands separators.
pub fn format_number(value: i64) -> String {
    let digits = value.unsigned_abs().to_string();
    let mut text = String::new();

    for (index, digit) in digits.chars().enumerate() {
        if index > 0 && (digits.len() - index).is_multiple_of(3) {
            text.push(',');
        }

        text.push(digit);
    }

    if value < 0 { format!("-{text}") } else { text }
}

pub fn failure(kind: &str, tool: &str, error: &str) -> String {
    match kind {
        "demolish" => format!("Cannot demolish: {error}"),
        "terrain" => format!("Cannot change terrain: {error}"),
        "hydro" => format!("Cannot build hydroelectric power: {error}"),
        "subway_to_rail" => format!("Cannot build subway-to-rail connection: {error}"),
        "onramp" => format!("Cannot build on-ramp: {error}"),
        "building" => format!("Cannot build {tool}: {error}"),
        _ => format!("Cannot apply {tool}: {error}"),
    }
}

pub fn success(kind: &str, tool: &str, result: &Value) -> String {
    let cost = format_number(int(result, "cost", 0));

    match kind {
        "landscape" => {
            let mut message = format!("{tool} changed {} path tiles for ${cost}.", ints(result, "tile_indices").len());
            let skipped = int(result, "skipped_insufficient", 0);

            if skipped > 0 {
                message += &format!(" Funds were not sufficient for {skipped} later path tiles.");
            }

            message
        }
        "demolish" => {
            let mut message = format!("Applied {} demolition actions for ${cost}.", int(result, "action_count", 0));
            let skipped = int(result, "skipped_specialized", 0);

            if skipped > 0 {
                message += &format!(" {skipped} specialized structures were not changed.");
            }

            message
        }
        "terrain" => {
            let mut message = format!("{tool} applied {} actions for ${cost}.", int(result, "action_count", 0));
            let skipped = int(result, "skipped_conflicts", 0);

            if skipped > 0 {
                message += &format!(" {skipped} structure conflicts were not changed.");
            }

            message
        }
        "hydro" => format!("Built hydroelectric power for ${cost}."),
        "subway_to_rail" => format!(
            "Built a subway-to-rail connection at no charge. Listed cost: ${}.",
            format_number(int(result, "listed_cost", 0))
        ),
        "onramp" => format!("Built an on-ramp for ${cost}."),
        "building" => format!("Built {tool} for ${cost}."),
        _ => format!("{tool} changed {} tiles for ${cost}.", ints(result, "tile_indices").len()),
    }
}
