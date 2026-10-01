//! Godot classes of the debug map layers. See `debug_view`.

use super::super::data_view::DataCity;
use super::super::debug_view::{
    bytes,
    geometry::{self, TileWindow},
    networks, order,
    snapshot::{self, Snapshot, Tiles},
    things, values,
};
use super::int;
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

    /// Rows of record, type, x, y, dx and dy of the XTHG records whose tile
    /// is inside `window`.
    #[func]
    fn thing_rows(things: PackedByteArray, edge: i64, window: Rect2i) -> PackedInt32Array {
        let tiles = TileWindow::clipped(
            i64::from(window.position.x),
            i64::from(window.position.y),
            i64::from(window.position.x + window.size.x),
            i64::from(window.position.y + window.size.y),
            edge.max(0) as usize,
        );

        PackedInt32Array::from(things::rows(things.as_slice(), tiles).as_slice())
    }

    /// The differing bytes of two chunk copies: `{offsets, count}`. `offsets`
    /// holds the first `limit` differing offsets.
    #[func]
    fn byte_differences(before: PackedByteArray, after: PackedByteArray, limit: i64) -> VarDictionary {
        let (offsets, count) = bytes::differences(before.as_slice(), after.as_slice(), limit.max(0) as usize);
        let mut result = VarDictionary::new();

        result.set("offsets", &PackedInt32Array::from(offsets.as_slice()));
        result.set("count", count as i64);
        result
    }

    /// Row indices in the order of `keys`. Equal keys keep their record order,
    /// also when `descending` reverses the keys.
    #[func]
    fn stable_order(keys: PackedInt64Array, descending: bool) -> PackedInt32Array {
        PackedInt32Array::from(order::stable_order(keys.as_slice(), descending).as_slice())
    }

    /// The first index of each of the 256 byte values in `data`, or -1.
    #[func]
    fn first_indices(data: PackedByteArray) -> PackedInt32Array {
        PackedInt32Array::from(bytes::first_indices(data.as_slice()).as_slice())
    }

    #[constant]
    const THING_ROW: i32 = things::ROW as i32;

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
        self.snapshot = Snapshot::copy(&GodotTiles::from(&tiles).tiles());
    }

    #[func]
    fn is_empty(&self) -> bool {
        !self.snapshot.tiles().is_complete()
    }

    #[func]
    fn edge(&self) -> i64 {
        self.snapshot.edge as i64
    }

    /// The changed tiles from this copy to `tiles`: `{values, counts, tiles}`.
    /// `counts` holds the changed tiles of each plane, in bit order.
    #[func]
    fn difference(&self, tiles: VarDictionary, ignored_flags: i64) -> VarDictionary {
        let after = GodotTiles::from(&tiles);
        let found = self.snapshot.tiles().difference(&after.tiles(), ignored_flags as u8);
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

/// The tile arrays of a Godot dictionary. The packed arrays share their data
/// with Godot, so the tiles are read without a copy.
struct GodotTiles {
    edge: usize,
    buildings: PackedByteArray,
    zones: PackedByteArray,
    terrain: PackedByteArray,
    altitude: PackedInt32Array,
    underground: PackedByteArray,
    overlays: PackedByteArray,
    flags: PackedByteArray,
}

impl GodotTiles {
    fn from(tiles: &VarDictionary) -> Self {
        let plane = |key: &str| tiles.get(key).and_then(|v| v.try_to::<PackedByteArray>().ok()).unwrap_or_default();

        Self {
            edge: int(tiles, "edge", 0).max(0) as usize,
            buildings: plane("buildings"),
            zones: plane("zones"),
            terrain: plane("terrain"),
            altitude: tiles
                .get("altitude")
                .and_then(|v| v.try_to::<PackedInt32Array>().ok())
                .unwrap_or_default(),
            underground: plane("underground"),
            overlays: plane("overlays"),
            flags: plane("flags"),
        }
    }

    fn tiles(&self) -> Tiles<'_> {
        Tiles {
            edge: self.edge,
            buildings: self.buildings.as_slice(),
            zones: self.zones.as_slice(),
            terrain: self.terrain.as_slice(),
            altitude: self.altitude.as_slice(),
            underground: self.underground.as_slice(),
            overlays: self.overlays.as_slice(),
            flags: self.flags.as_slice(),
        }
    }
}
