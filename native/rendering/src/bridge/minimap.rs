//! City Map window images.

use super::int;
use godot::{
    classes::{Image, image::Format},
    prelude::*,
};
use sc2k_render::minimap;

/// City Map window images. See `minimap.rs`.
#[derive(GodotClass)]
#[class(base=Object, no_init)]
pub struct NativeCityMinimap {}
impl NativeCityMinimap {
    fn with_city<T>(request: &VarDictionary, use_city: impl FnOnce(&minimap::MinimapCity, minimap::Mode) -> T) -> Option<T> {
        let packed = |key: &str| {
            request
                .get(key)
                .and_then(|v| v.try_to::<PackedByteArray>().ok())
                .unwrap_or_default()
        };

        let (buildings, zones, flags, underground, data) = (
            packed("buildings"),
            packed("zones"),
            packed("flags"),
            packed("underground"),
            packed("data"),
        );
        let altitude = request
            .get("altitude")
            .and_then(|v| v.try_to::<PackedInt32Array>().ok())
            .unwrap_or_default();
        let mode = request.get("mode").and_then(|v| v.try_to::<GString>().ok()).unwrap_or_default();
        let city = minimap::MinimapCity {
            edge: int(request, "edge", 0).max(0) as usize,
            buildings: buildings.as_slice(),
            zones: zones.as_slice(),
            flags: flags.as_slice(),
            underground: underground.as_slice(),
            altitude: altitude.as_slice(),
            data: data.as_slice(),
        };

        city.validate().ok()?;
        Some(use_city(&city, minimap::Mode::from_name(&mode.to_string())))
    }
}

#[godot_api]
impl NativeCityMinimap {
    /// The chunk that `mode` reads, or an empty string.
    #[func]
    fn data_chunk(mode: GString) -> GString {
        GString::from(minimap::Mode::from_name(&mode.to_string()).chunk().unwrap_or(""))
    }

    /// The image edge of a map with `edge` tiles.
    #[func]
    fn image_edge(edge: i64) -> i64 {
        minimap::image_edge(edge.max(0) as usize) as i64
    }
    /// An RGBA8 image of the map. `request` has `edge`, `buildings`, `zones`,
    /// `flags`, `underground`, `altitude` (ALTM words), `mode` and `data`, the
    /// mode's data map. `palette` holds 256 RGBA colors. Returns null for invalid arrays.
    #[func]
    fn create_image(request: VarDictionary, palette: PackedByteArray) -> Option<Gd<Image>> {
        let (edge, rgba) = Self::with_city(&request, |city, mode| {
            let indices = minimap::indices(city, mode);
            (minimap::image_edge(city.edge), minimap::colorize(&indices, palette.as_slice()))
        })?;
        Image::create_from_data(
            edge as i32,
            edge as i32,
            false,
            Format::RGBA8,
            &PackedByteArray::from(rgba.as_slice()),
        )
    }

    /// The palette index of one tile, or -1 for invalid arrays.
    #[func]
    fn color_index(request: VarDictionary, x: i64, y: i64) -> i64 {
        Self::with_city(&request, |city, mode| {
            if x < 0 || y < 0 {
                0
            } else {
                i64::from(city.color_index(x as usize, y as usize, mode))
            }
        })
        .unwrap_or(-1)
    }
}
