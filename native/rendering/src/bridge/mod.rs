//! Bulk Godot boundary. Each builder belongs to one region worker thread. A
//! region's draw index is immutable, so the main thread may read it later.

mod changes;
mod compositor;
mod data_mesh;
mod debug_tiles;
mod minimap;
mod region_builder;
mod region_draws;
mod view_queries;

use godot::prelude::*;

fn int(d: &VarDictionary, k: &str, default: i64) -> i64 {
    d.get(k).and_then(|v| v.try_to().ok()).unwrap_or(default)
}

fn bytes(d: &VarDictionary, k: &str) -> Vec<u8> {
    d.get(k)
        .and_then(|v| v.try_to::<PackedByteArray>().ok())
        .map_or_else(Vec::new, |v| v.to_vec())
}

fn ints(d: &VarDictionary, k: &str) -> Vec<i32> {
    d.get(k)
        .and_then(|v| v.try_to::<PackedInt32Array>().ok())
        .map_or_else(Vec::new, |v| v.to_vec())
}
