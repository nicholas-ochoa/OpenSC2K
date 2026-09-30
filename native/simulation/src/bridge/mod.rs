//! Godot entry points. Each call receives the saved city chunks and the engine
//! state, runs one simulation operation, and returns the written chunks and
//! the result as Godot values. GDScript builds the result objects.

mod budgets;
mod codec;
mod convert;
mod ops;
mod sc2x;
mod tool_ops;
mod tool_queries;

use godot::prelude::*;

/// Static entry points for GDScript. No instance holds simulation state.
#[derive(GodotClass)]
#[class(no_init, base = Object)]
pub struct NativeSimulation {}

#[godot_api]
impl NativeSimulation {
    /// Run the operation that `request.op` names. See `ops.rs` for the fields.
    #[func]
    fn run(request: VarDictionary) -> VarDictionary {
        ops::run(&request)
    }

    /// A new slice budget. Free it with `budget_free`.
    #[func]
    fn budget_create() -> i64 {
        budgets::create()
    }

    #[func]
    fn budget_free(handle: i64) {
        budgets::free(handle)
    }

    #[func]
    fn budget_checkpoint(handle: i64) {
        if let Some(budget) = budgets::get(handle) {
            budget.checkpoint();
        }
    }

    #[func]
    fn budget_grant(handle: i64, usec: i64) {
        if let Some(budget) = budgets::get(handle) {
            budget.grant(usec);
        }
    }

    #[func]
    fn budget_cancel(handle: i64) {
        if let Some(budget) = budgets::get(handle) {
            budget.cancel();
        }
    }

    #[func]
    fn budget_finish(handle: i64) {
        if let Some(budget) = budgets::get(handle) {
            budget.finish();
        }
    }

    #[func]
    fn budget_parked_usec(handle: i64) -> i64 {
        budgets::get(handle).map_or(0, |budget| budget.parked_usec())
    }

    /// `{slices, max_slice_usec, waiting, cancelled, elapsed_usec, parked_usec}`.
    #[func]
    fn budget_metrics(handle: i64) -> VarDictionary {
        let metrics = budgets::get(handle).map(|budget| budget.metrics()).unwrap_or_default();
        let mut result = VarDictionary::new();
        result.set("slices", metrics.slices);
        result.set("max_slice_usec", metrics.max_slice_usec);
        result.set("waiting", metrics.waiting);
        result.set("cancelled", metrics.cancelled);
        result.set("elapsed_usec", metrics.elapsed_usec);
        result.set("parked_usec", metrics.parked_usec);
        result
    }

    /// The operations that this library implements.
    #[func]
    fn operations() -> PackedStringArray {
        ops::OPERATIONS
            .iter()
            .chain(tool_ops::OPERATIONS)
            .map(|name| GString::from(*name))
            .collect()
    }
}
