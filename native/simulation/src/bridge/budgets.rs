//! Slice budgets by handle. GDScript keeps an integer handle, so a budget can
//! cross to the simulation worker without a Godot object.

use std::collections::HashMap;
use std::sync::atomic::{AtomicI64, Ordering};
use std::sync::{Arc, Mutex, OnceLock};

use crate::sim::budget::SliceBudget;

fn registry() -> &'static Mutex<HashMap<i64, Arc<SliceBudget>>> {
    static REGISTRY: OnceLock<Mutex<HashMap<i64, Arc<SliceBudget>>>> = OnceLock::new();

    REGISTRY.get_or_init(|| Mutex::new(HashMap::new()))
}

pub fn create() -> i64 {
    static NEXT: AtomicI64 = AtomicI64::new(1);
    let handle = NEXT.fetch_add(1, Ordering::Relaxed);
    registry()
        .lock()
        .unwrap_or_else(|poisoned| poisoned.into_inner())
        .insert(handle, Arc::new(SliceBudget::new()));
    handle
}

pub fn get(handle: i64) -> Option<Arc<SliceBudget>> {
    registry()
        .lock()
        .unwrap_or_else(|poisoned| poisoned.into_inner())
        .get(&handle)
        .cloned()
}

pub fn free(handle: i64) {
    registry().lock().unwrap_or_else(|poisoned| poisoned.into_inner()).remove(&handle);
}
