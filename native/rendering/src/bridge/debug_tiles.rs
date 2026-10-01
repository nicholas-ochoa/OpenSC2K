//! Godot classes of the debug map layers. See `debug_view`.

use super::super::data_view::DataCity;
use super::super::debug_view::{
    geometry::{self, TileWindow},
    networks,
    snapshot::{self, Snapshot},
    values,
};
use super::{bytes, int, ints};
use godot::prelude::*;

/// Geometry and tile values of the debug tile layer.
#[derive(GodotClass)]
#[class(base=Object, no_init)]
pub struct NativeDebugTiles {}

#[godot_api]
impl NativeDebugTiles {
    /// Tile tops of the window `x0..x1`, `y0..y1`: `{vertices, uvs, indices,
    /// tiles}`, or `{error}`. `altitude` holds the ALTM words.
    #[func]
    fn window_mesh(
        edge: i64,
        visible: i64,
        altitude: PackedInt32Array,
        terrain: PackedByteArray,
        flags: PackedByteArray,
        window: Rect2i,
    ) -> VarDictionary {
        let mut result = VarDictionary::new();
        let city = DataCity {
            edge: edge.max(0) as usize,
            visible: visible as i32,
            altitude: altitude.as_slice(),
            terrain: terrain.as_slice(),
            flags: flags.as_slice(),
        };

        if let Err(error) = city.validate() {
            result.set("error", &GString::from(&error));

            return result;
        }

        let tiles = TileWindow::clipped(
            i64::from(window.position.x),
            i64::from(window.position.y),
            i64::from(window.position.x + window.size.x),
            i64::from(window.position.y + window.size.y),
            city.edge,
        );
        let mesh = geometry::window_tops(&city, tiles);
        let vertices: PackedVector2Array = mesh.vertices.iter().map(|v| Vector2::new(v[0], v[1])).collect();
        let uvs: PackedVector2Array = mesh.uvs.iter().map(|v| Vector2::new(v[0], v[1])).collect();

        result.set("vertices", &vertices);
        result.set("uvs", &uvs);
        result.set("indices", &PackedInt32Array::from(mesh.indices.as_slice()));
        result.set("tiles", mesh.tiles as i64);
        result
    }

    /// `(word >> shift) & mask` of each ALTM word.
    #[func]
    fn altitude_field(altitude: PackedInt32Array, shift: i64, mask: i64) -> PackedByteArray {
        PackedByteArray::from(values::altitude_field(altitude.as_slice(), shift as u32, mask as i32).as_slice())
    }

    /// The unusual value bits of each tile. See `values::unusual_values`.
    #[func]
    fn unusual_values(
        zones: PackedByteArray,
        terrain: PackedByteArray,
        underground: PackedByteArray,
        flags: PackedByteArray,
    ) -> PackedByteArray {
        let found = values::unusual_values(zones.as_slice(), terrain.as_slice(), underground.as_slice(), flags.as_slice());

        PackedByteArray::from(found.as_slice())
    }

    /// The kind of the top overlay value of each of `cells` tiles.
    #[func]
    fn overlay_kinds(overlays: PackedByteArray, cells: i64) -> PackedByteArray {
        PackedByteArray::from(values::overlay_kinds(overlays.as_slice(), cells.max(0) as usize).as_slice())
    }

    /// The networks of the tiles whose flags hold `member`: `{values, count,
    /// supplied, largest}`. A network with a `supplied` tile has values from
    /// SUPPLIED_BASE.
    #[func]
    fn networks(flags: PackedByteArray, edge: i64, member: i64, supplied: i64) -> VarDictionary {
        let found = networks::label(flags.as_slice(), edge.max(0) as usize, member as u8, supplied as u8);
        let mut result = VarDictionary::new();

        result.set("values", &PackedByteArray::from(found.values.as_slice()));
        result.set("count", found.count as i64);
        result.set("supplied", found.supplied as i64);
        result.set("largest", found.largest as i64);
        result
    }

    #[constant]
    const SUPPLIED_BASE: i32 = networks::SUPPLIED_BASE as i32;
    #[constant]
    const UNUSUAL_ZONE: i32 = values::UNUSUAL_ZONE as i32;
    #[constant]
    const UNUSUAL_TERRAIN: i32 = values::UNUSUAL_TERRAIN as i32;
    #[constant]
    const UNUSUAL_UNDERGROUND: i32 = values::UNUSUAL_UNDERGROUND as i32;
    #[constant]
    const UNUSUAL_MARK: i32 = values::UNUSUAL_MARK as i32;
}

/// A copy of the tile arrays, for the changed tiles layer.
#[derive(GodotClass)]
#[class(base=RefCounted, init)]
pub struct NativeTileSnapshot {
    snapshot: Snapshot,
}

#[godot_api]
impl NativeTileSnapshot {
    /// Copy the arrays of `tiles`: `edge`, `buildings`, `zones`, `terrain`,
    /// `altitude`, `underground`, `overlays` and `flags`. Overlays keep their
    /// first byte plane.
    #[func]
    fn capture(&mut self, tiles: VarDictionary) {
        self.snapshot = snapshot_from(&tiles);
    }

    #[func]
    fn is_empty(&self) -> bool {
        !self.snapshot.is_complete()
    }

    #[func]
    fn edge(&self) -> i64 {
        self.snapshot.edge as i64
    }

    /// The changed tiles from this copy to `tiles`: `{values, counts, tiles}`.
    /// `counts` holds the changed tiles of each plane, in bit order.
    #[func]
    fn difference(&self, tiles: VarDictionary, ignored_flags: i64) -> VarDictionary {
        let after = snapshot_from(&tiles);
        let found = self.snapshot.difference(&after, ignored_flags as u8);
        let counts: PackedInt32Array = found.counts.iter().map(|&count| count as i32).collect();
        let mut result = VarDictionary::new();

        result.set("values", &PackedByteArray::from(found.values.as_slice()));
        result.set("counts", &counts);
        result.set("tiles", found.tiles as i64);
        result
    }

    /// Make this copy hold the arrays of `other`.
    #[func]
    fn copy_from(&mut self, other: Gd<NativeTileSnapshot>) {
        self.snapshot = other.bind().snapshot.clone();
    }

    #[constant]
    const CHANGED_BUILDING: i32 = snapshot::CHANGED_BUILDING as i32;
    #[constant]
    const CHANGED_ZONE: i32 = snapshot::CHANGED_ZONE as i32;
    #[constant]
    const CHANGED_TERRAIN: i32 = snapshot::CHANGED_TERRAIN as i32;
    #[constant]
    const CHANGED_ALTITUDE: i32 = snapshot::CHANGED_ALTITUDE as i32;
    #[constant]
    const CHANGED_UNDERGROUND: i32 = snapshot::CHANGED_UNDERGROUND as i32;
    #[constant]
    const CHANGED_OVERLAY: i32 = snapshot::CHANGED_OVERLAY as i32;
    #[constant]
    const CHANGED_FLAGS: i32 = snapshot::CHANGED_FLAGS as i32;
}

fn snapshot_from(tiles: &VarDictionary) -> Snapshot {
    let edge = int(tiles, "edge", 0).max(0) as usize;
    let mut overlays = bytes(tiles, "overlays");
    overlays.truncate(edge * edge);

    Snapshot {
        edge,
        buildings: bytes(tiles, "buildings"),
        zones: bytes(tiles, "zones"),
        terrain: bytes(tiles, "terrain"),
        altitude: ints(tiles, "altitude"),
        underground: bytes(tiles, "underground"),
        overlays,
        flags: bytes(tiles, "flags"),
    }
}
