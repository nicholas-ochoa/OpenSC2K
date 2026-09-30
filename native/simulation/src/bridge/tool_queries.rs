//! Tool rules that the view and the dialogs read: building sites, building
//! corners, and bridge decks.

use godot::prelude::*;

use crate::sim::geom::Rect2i as SimRect2i;
use crate::sim::geom::Vec2i;
use crate::sim::tools::commands::{network_bridge, scurk_place};
use crate::sim::tools::{demolish, set_corners};

/// Static tool queries for GDScript.
#[derive(GodotClass)]
#[class(no_init, base = Object)]
pub struct NativeCityTools {}

fn point(value: Vector2i) -> Vec2i {
    Vec2i::new(value.x as i64, value.y as i64)
}

#[godot_api]
impl NativeCityTools {
    /// The footprint edge of a building tile: 1 to 4.
    #[func]
    fn building_area(tile: i64) -> i64 {
        demolish::building_area(tile)
    }

    /// The site of the building of `tile` that covers `selected`, or an empty
    /// rectangle when its corners do not match.
    #[func]
    fn find_building_site(
        buildings: PackedByteArray,
        zones: PackedByteArray,
        selected: Vector2i,
        tile: i64,
        area: i64,
        rotation: i64,
        map_edge: i64,
    ) -> Rect2i {
        let site = demolish::find_building_site(
            buildings.as_slice(),
            zones.as_slice(),
            point(selected),
            tile,
            area,
            rotation,
            map_edge,
        );

        Rect2i::new(
            Vector2i::new(site.position.x as i32, site.position.y as i32),
            Vector2i::new(site.size.x as i32, site.size.y as i32),
        )
    }

    /// `zones` with the building corners of a site of `area` at `position`.
    #[func]
    fn set_corners(zones: PackedByteArray, position: Vector2i, area: i64, rotation: i64, map_edge: i64) -> PackedByteArray {
        let mut result = zones.to_vec();
        set_corners(&mut result, point(position), area, rotation, map_edge);

        PackedByteArray::from(result.as_slice())
    }

    /// The deck tile of a road, rail, or power bridge at `span_index`.
    #[func]
    fn bridge_tile(bridge_type: i64, span_length: i64, span_index: i64, direction: i64) -> i64 {
        network_bridge::bridge_tile(bridge_type, span_length, span_index, direction)
    }

    /// The zone of a SCURK object placed on unzoned ground.
    #[func]
    fn object_zone(tile: i64) -> i64 {
        scurk_place::zone_for_tile(tile, &[], SimRect2i::default(), 0, 0)
    }

    /// ScurkPlaceCommand site check: empty when the site can hold `tile`.
    #[func]
    fn scurk_site_error(
        buildings: PackedByteArray,
        terrain: PackedByteArray,
        flags: PackedByteArray,
        site: Rect2i,
        tile: i64,
        map_edge: i64,
    ) -> GString {
        let site = SimRect2i::new(
            site.position.x as i64,
            site.position.y as i64,
            site.size.x as i64,
            site.size.y as i64,
        );

        GString::from(scurk_place::site_error(
            buildings.as_slice(),
            terrain.as_slice(),
            flags.as_slice(),
            site,
            tile,
            map_edge,
        ))
    }
}
