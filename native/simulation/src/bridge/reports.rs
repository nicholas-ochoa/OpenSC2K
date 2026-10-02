//! Newspaper queue and budget-window entry points. Each call reads a copy of
//! MISC. A call that changes MISC returns the changed copy in `misc`; GDScript
//! stores it in the document.

use godot::prelude::*;

use super::convert;
use crate::sim::economy::{bonds, ordinances};
use crate::sim::events::NewsEvent;
use crate::sim::reports::news;
use crate::sim::value::ToValue;

/// `{ok, error, misc}` of a queue edit. A failed edit returns no MISC.
fn queue_edit(misc: PackedByteArray, edit: impl FnOnce(&mut [u8]) -> Result<(), String>) -> VarDictionary {
    let mut data = misc.to_vec();
    let outcome = edit(&mut data);
    let mut result = VarDictionary::new();
    result.set("ok", outcome.is_ok());
    result.set("error", outcome.err().unwrap_or_default().as_str());
    result.set("misc", &PackedByteArray::from(data.as_slice()));
    result
}

/// `{result, misc}`. `result` is a GDScript result object; `misc` is empty
/// when the command leaves MISC unchanged.
fn command(result: &impl ToValue, misc: Option<Vec<u8>>) -> VarDictionary {
    let mut response = VarDictionary::new();
    response.set("result", &convert::variant(&result.to_value()));
    response.set("misc", &PackedByteArray::from(misc.unwrap_or_default().as_slice()));
    response
}

/// Static NewsQueue entry points.
#[derive(GodotClass)]
#[class(no_init, base = Object)]
pub struct NativeNewsQueue {}

#[godot_api]
impl NativeNewsQueue {
    /// The initial priority of each story type.
    #[func]
    fn story_priorities() -> PackedInt32Array {
        news::STORY_PRIORITIES.iter().map(|&priority| priority as i32).collect()
    }

    /// The monthly priority decay of each story type.
    #[func]
    fn story_decays() -> PackedInt32Array {
        news::STORY_DECAYS.iter().map(|&decay| decay as i32).collect()
    }

    /// The SimRandom draws of a new session.
    #[func]
    fn session_random_calls() -> i64 {
        news::SESSION_RANDOM_CALLS
    }

    /// Deal the papers with the SimRandom `draws` of a new session.
    #[func]
    fn initialize_session(misc: PackedByteArray, draws: PackedInt64Array) -> VarDictionary {
        let mut next = draws.as_slice().iter().copied();

        queue_edit(misc, |data| news::initialize_session(data, || next.next().unwrap_or(0)))
    }

    #[func]
    fn decay_and_sort(misc: PackedByteArray) -> VarDictionary {
        queue_edit(misc, news::decay_and_sort)
    }

    /// `{ok, error, misc, slot, priority}`.
    #[func]
    fn insert(misc: PackedByteArray, story_type: i64, argument: i64) -> VarDictionary {
        let mut inserted = (0, 0);
        let mut result = queue_edit(misc, |data| {
            inserted = news::insert(data, story_type, argument)?;
            Ok(())
        });
        result.set("slot", inserted.0);
        result.set("priority", inserted.1);
        result
    }

    /// `{ok, error, misc, inserted}`. Items of an unknown type are skipped.
    #[func]
    fn insert_items(misc: PackedByteArray, types: PackedInt64Array, arguments: PackedInt64Array) -> VarDictionary {
        let items: Vec<NewsEvent> = types
            .as_slice()
            .iter()
            .zip(arguments.as_slice())
            .map(|(&story_type, &argument)| NewsEvent::new(story_type, argument))
            .collect();
        let mut inserted = 0;
        let mut result = queue_edit(misc, |data| {
            inserted = news::insert_items(data, &items)?;
            Ok(())
        });
        result.set("inserted", inserted);
        result
    }

    #[func]
    fn prepare_weather_report(misc: PackedByteArray, weather: i64) -> VarDictionary {
        queue_edit(misc, |data| news::prepare_weather_report(data, weather))
    }

    #[func]
    fn prepare_opinion_report(misc: PackedByteArray, style: i64, subject: i64) -> VarDictionary {
        queue_edit(misc, |data| news::prepare_opinion_report(data, style, subject))
    }

    #[func]
    fn update_story_substitutions(misc: PackedByteArray, slot: i64, argument: i64, auxiliary: PackedByteArray) -> VarDictionary {
        queue_edit(misc, |data| {
            news::update_story_substitutions(data, slot, argument, auxiliary.as_slice())
        })
    }

    /// `{type, priority, argument, auxiliary}`, or an empty Dictionary.
    #[func]
    fn story_record(misc: PackedByteArray, slot: i64) -> VarDictionary {
        let mut result = VarDictionary::new();

        if let Some(record) = news::story_record(misc.as_slice(), slot) {
            result.set("type", record.story_type);
            result.set("priority", record.priority);
            result.set("argument", record.argument);
            result.set("auxiliary", &PackedByteArray::from(record.auxiliary.as_slice()));
        }

        result
    }

    /// Name, layout, price, opinion, and weather style, or an empty array.
    #[func]
    fn paper_record(misc: PackedByteArray, paper: i64) -> PackedInt32Array {
        news::paper_record(misc.as_slice(), paper)
            .map(|fields| fields.iter().map(|&field| field as i32).collect())
            .unwrap_or_default()
    }

    #[func]
    fn available_paper_count(progression: i64) -> i64 {
        news::available_paper_count(progression)
    }

    #[func]
    fn is_story_type(story_type: i64) -> bool {
        news::is_story_type(story_type)
    }

    #[func]
    fn opens_extra_edition(story_type: i64) -> bool {
        news::opens_extra_edition(story_type)
    }
}

/// Static BondCommand and OrdinanceCommand entry points.
#[derive(GodotClass)]
#[class(no_init, base = Object)]
pub struct NativeEconomy {}

#[godot_api]
impl NativeEconomy {
    /// BondCommand.issue with the rebuilt `city_value`.
    #[func]
    fn bond_issue(misc: PackedByteArray, city_value: i64, confirmation: i64) -> VarDictionary {
        let outcome = bonds::issue(misc.as_slice(), city_value, confirmation);

        command(&outcome.result, outcome.misc)
    }

    #[func]
    fn bond_repay(misc: PackedByteArray, confirmation: i64) -> VarDictionary {
        let outcome = bonds::repay(misc.as_slice(), confirmation);

        command(&outcome.result, outcome.misc)
    }

    /// The monthly cost of each ordinance. Revenue is negative.
    #[func]
    fn ordinance_costs(misc: PackedByteArray) -> PackedInt32Array {
        ordinances::costs_for_misc(misc.as_slice())
            .iter()
            .map(|&cost| cost as i32)
            .collect()
    }

    #[func]
    fn ordinance_current_cost(misc: PackedByteArray) -> i64 {
        ordinances::current_cost_for_misc(misc.as_slice())
    }

    /// An OrdinanceCommand.Result Dictionary for NativeSimulationBridge.decode.
    #[func]
    fn ordinance_snapshot(misc: PackedByteArray) -> Variant {
        convert::variant(&ordinances::snapshot(misc.as_slice()).to_value())
    }

    #[func]
    fn ordinance_synchronize(misc: PackedByteArray) -> VarDictionary {
        let (result, changed) = ordinances::synchronize_current(misc.as_slice());

        command(&result, changed)
    }

    #[func]
    fn ordinance_set_enabled(misc: PackedByteArray, ordinance: i64, enabled: bool) -> VarDictionary {
        let (result, changed) = ordinances::set_enabled(misc.as_slice(), ordinance, enabled);

        command(&result, changed)
    }
}
