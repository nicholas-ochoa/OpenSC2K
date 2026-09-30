//! Data map overlay geometry.

use super::super::data_view;
use godot::prelude::*;

/// Data map overlay geometry. See `data_view.rs`.
#[derive(GodotClass)]
#[class(base=Object, no_init)]
pub struct NativeCityDataMesh {}
#[godot_api]
impl NativeCityDataMesh {
    /// `{vertices, colors, uvs, indices}`, or `{error}`. `altitude` holds the ALTM words.
    #[func]
    fn build(
        edge: i64,
        visible: i64,
        height_view: bool,
        altitude: PackedInt32Array,
        terrain: PackedByteArray,
        flags: PackedByteArray,
    ) -> VarDictionary {
        let mut result = VarDictionary::new();
        let city = data_view::DataCity {
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

        let mesh = data_view::build(&city, height_view);
        let vertices: PackedVector2Array = mesh.vertices.iter().map(|v| Vector2::new(v[0], v[1])).collect();
        let colors: PackedColorArray = mesh.colors.iter().map(|c| Color::from_rgba(c[0], c[1], c[2], c[3])).collect();
        let uvs: PackedVector2Array = mesh.uvs.iter().map(|v| Vector2::new(v[0], v[1])).collect();
        result.set("vertices", &vertices);
        result.set("colors", &colors);
        result.set("uvs", &uvs);
        result.set("indices", &PackedInt32Array::from(mesh.indices.as_slice()));
        result
    }
}

/// Tile values of the data maps that have no data chunk. See `data_view.rs`.
#[godot_api(secondary)]
impl NativeCityDataMesh {
    /// The land level of each dry tile, and the underwater base plus the water
    /// depth of each underwater tile. `altitude` holds the ALTM words.
    #[func]
    fn height_values(altitude: PackedInt32Array, flags: PackedByteArray) -> PackedByteArray {
        PackedByteArray::from(data_view::height_values(altitude.as_slice(), flags.as_slice()).as_slice())
    }

    #[constant]
    const UNDERWATER_BASE: i32 = data_view::UNDERWATER_BASE as i32;

    /// 2 where the `supplied` flag is set, 1 where only `connected` is set.
    #[func]
    fn utility_values(flags: PackedByteArray, supplied: i64, connected: i64) -> PackedByteArray {
        PackedByteArray::from(data_view::utility_values(flags.as_slice(), supplied as u8, connected as u8).as_slice())
    }
}
