//! Tool rules that the view and the dialogs read: tool availability, building
//! sites, building corners, and bridge decks.

use godot::prelude::*;

use sc2k_sim::sim::geom::Rect2i as SimRect2i;
use sc2k_sim::sim::geom::Vec2i;
use sc2k_sim::sim::tools::commands::{network, scurk_place};
use sc2k_sim::sim::tools::edit_state::{self, View};
use sc2k_sim::sim::tools::query::{self, Microsim, QueryInfo, Thing};
use sc2k_sim::sim::tools::{availability, catalog, demolish, set_corners, sounds};

/// Static tool queries for GDScript.
#[derive(GodotClass)]
#[class(no_init, base = Object)]
pub struct NativeCityTools {}

/// A field of a script object.
fn object_field<T: FromGodot>(object: &Gd<Object>, name: &str) -> Option<T> {
    object.get(name).try_to::<T>().ok()
}

fn object_int(object: &Gd<Object>, name: &str) -> i64 {
    object_field(object, name).unwrap_or(0)
}

fn object_text(object: &Gd<Object>, name: &str) -> String {
    object_field::<GString>(object, name)
        .map(|text| text.to_string())
        .unwrap_or_default()
}

fn object_strings(object: &Gd<Object>, name: &str) -> Vec<String> {
    object_field::<PackedStringArray>(object, name)
        .map(|texts| texts.as_slice().iter().map(GString::to_string).collect())
        .unwrap_or_default()
}

/// A QueryResult of the script, as the view completed it with its sprites.
fn query_info(info: &Gd<Object>) -> QueryInfo {
    let flag = |name: &str| object_field::<bool>(info, name).unwrap_or(false);
    let microsim = object_field::<Gd<Object>>(info, "microsim").map(|microsim| Microsim {
        tile_id: object_int(&microsim, "tile_id"),
        stat_0: object_int(&microsim, "stat_0"),
        stat_1: object_int(&microsim, "stat_1"),
        stat_2: object_int(&microsim, "stat_2"),
        stat_3: object_int(&microsim, "stat_3"),
    });
    // a typed script array does not convert to an untyped array; read its items
    let things_value = info.get("things");
    let count = things_value.call("size", &[]).try_to::<i64>().unwrap_or(0);
    let things = (0..count)
        .filter_map(|index| things_value.call("get", &[index.to_variant()]).try_to::<Gd<Object>>().ok())
        .map(|thing| Thing {
            record: object_int(&thing, "record"),
            fields: ["type", "direction", "state", "x", "y", "z", "px", "py", "dx", "dy", "label", "goal"]
                .map(|name| object_int(&thing, name)),
            type_name: object_text(&thing, "type_name"),
            direction_name: object_text(&thing, "direction_name"),
        })
        .collect();

    QueryInfo {
        kind: object_text(info, "kind"),
        point: object_field::<Vector2i>(info, "point").map_or(Vec2i::NONE, point),
        title: object_text(info, "title"),
        shows_traffic: flag("shows_traffic"),
        altitude_is_depth: flag("altitude_is_depth"),
        shows_land_value: flag("shows_land_value"),
        shows_utilities: flag("shows_utilities"),
        powered: flag("powered"),
        watered: flag("watered"),
        zone_name: object_text(info, "zone_name"),
        zone_density: object_text(info, "zone_density"),
        crime_level: object_text(info, "crime_level"),
        pollution_level: object_text(info, "pollution_level"),
        water_detail: object_text(info, "water_detail"),
        action: object_text(info, "action"),
        corner_name: object_text(info, "corner_name"),
        underground_name: object_text(info, "underground_name"),
        microsim_label: object_text(info, "microsim_label"),
        overlay_id: object_int(info, "overlay_id"),
        zone_id: object_int(info, "zone_id"),
        sprite_id: object_int(info, "sprite_id"),
        building_id: object_int(info, "building_id"),
        terrain_id: object_int(info, "terrain_id"),
        traffic: object_int(info, "traffic"),
        altitude_feet: object_int(info, "altitude_feet"),
        land_value: object_int(info, "land_value"),
        crime: object_int(info, "crime"),
        pollution: object_int(info, "pollution"),
        microsim_type: object_int(info, "microsim_type"),
        tile_id: object_int(info, "tile_id"),
        altitude_raw: object_int(info, "altitude_raw"),
        land_value_raw: object_int(info, "land_value_raw"),
        crime_raw: object_int(info, "crime_raw"),
        pollution_raw: object_int(info, "pollution_raw"),
        zone_raw: object_int(info, "zone_raw"),
        flags_raw: object_int(info, "flags_raw"),
        underground_id: object_int(info, "underground_id"),
        microsim_id: object_int(info, "microsim_id"),
        microsim,
        lines: object_strings(info, "lines"),
        flag_names: object_strings(info, "flag_names"),
        sound_events: Vec::new(),
        things,
    }
}

fn point(value: Vector2i) -> Vec2i {
    Vec2i::new(value.x as i64, value.y as i64)
}

#[godot_api]
impl NativeCityTools {
    /// `{ok, error, group_masks, power_plant_mask, released_inventions,
    /// arcology_count, progression, military_base_type}` of a MISC payload.
    #[func]
    fn tool_availability(misc: PackedByteArray) -> VarDictionary {
        let mut result = VarDictionary::new();

        match availability::inspect(misc.as_slice()) {
            Ok(masks) => {
                let group_masks: Vec<i32> = masks.group_masks.iter().map(|&mask| mask as i32).collect();
                let released: Vec<u8> = masks.released_inventions.iter().map(|&released| u8::from(released)).collect();
                result.set("ok", true);
                result.set("error", "");
                result.set("group_masks", &PackedInt32Array::from(group_masks.as_slice()));
                result.set("power_plant_mask", masks.power_plant_mask);
                result.set("released_inventions", &PackedByteArray::from(released.as_slice()));
                result.set("arcology_count", masks.arcology_count);
                result.set("progression", masks.progression);
                result.set("military_base_type", masks.military_base_type);
            }
            Err(error) => {
                result.set("ok", false);
                result.set("error", error.as_str());
            }
        }

        result
    }

    /// The tool groups: `{id, name, tools}`, where each tool is `{id, name, cost, area}`.
    #[func]
    fn tool_catalog() -> VarArray {
        let mut groups = VarArray::new();

        for group in &catalog::GROUPS {
            let mut tools = VarArray::new();

            for entry in group.tools {
                let mut tool = VarDictionary::new();
                tool.set("id", entry.id);
                tool.set("name", entry.name);
                tool.set("cost", entry.cost);
                tool.set("area", entry.area);
                tools.push(&tool.to_variant());
            }

            let mut fields = VarDictionary::new();
            fields.set("id", group.id);
            fields.set("name", group.name);
            fields.set("tools", &tools);
            groups.push(&fields.to_variant());
        }

        groups
    }

    /// The Power Plants chooser values: `{subtool, output_mw, grid_capacity,
    /// pollution, service_life, note}` of each plant.
    #[func]
    fn power_plant_details() -> VarArray {
        let mut plants = VarArray::new();

        for details in &catalog::POWER_PLANT_DETAILS {
            let mut fields = VarDictionary::new();
            fields.set("subtool", details.subtool);
            fields.set("output_mw", details.output_mw);
            fields.set("grid_capacity", details.grid_capacity);
            fields.set("pollution", details.pollution);
            fields.set("service_life", details.service_life);
            fields.set("note", details.note);
            plants.push(&fields.to_variant());
        }

        plants
    }

    /// The name tables of the query dialog.
    #[func]
    fn query_strings() -> VarDictionary {
        use query::strings;

        let texts = |items: &[&str]| items.iter().map(|item| GString::from(*item)).collect::<PackedStringArray>();
        let mut lines = VarArray::new();

        for group in strings::MICROSIM_LINES {
            lines.push(&texts(group).to_variant());
        }

        let mut flags = VarArray::new();

        for (mask, name) in strings::FLAG_LABELS {
            flags.push(&varray![mask, name].to_variant());
        }

        let bounds: Vec<i32> = strings::GENERAL_NAME_UPPER_BOUNDS.iter().map(|&bound| bound as i32).collect();
        let mut result = VarDictionary::new();
        result.set("tile_names", &texts(&strings::TILE_NAMES));
        result.set("general_name_upper_bounds", &PackedInt32Array::from(bounds.as_slice()));
        result.set("clear_terrain", strings::CLEAR_TERRAIN);
        result.set("fresh_water", strings::FRESH_WATER);
        result.set("salt_water", strings::SALT_WATER);
        result.set("sailboat", strings::SAILBOAT);
        result.set("sports", &texts(&strings::SPORTS));
        result.set("microsim_lines", &lines);
        result.set("grade_names", &texts(&strings::GRADE_NAMES));
        result.set("zone_names", &texts(&strings::ZONE_NAMES));
        result.set("zone_densities", &texts(&strings::ZONE_DENSITIES));
        result.set("underground_names", &texts(&strings::UNDERGROUND_NAMES));
        result.set("thing_names", &texts(&strings::THING_NAMES));
        result.set("direction_names", &texts(&strings::DIRECTION_NAMES));
        result.set("flag_labels", &flags);
        result
    }

    /// The name of a building ID.
    #[func]
    fn query_tile_name(tile_id: i64) -> GString {
        GString::from(query::strings::tile_name(tile_id))
    }

    /// The crime or pollution level of a data-map value.
    #[func]
    fn query_level_name(value: i64) -> GString {
        GString::from(query::level_name(value))
    }

    /// The cars per minute of a road tile from the traffic map `values`.
    #[func]
    fn query_traffic(values: PackedByteArray, edge: i64, at: Vector2i, building: i64) -> i64 {
        query::traffic(edge, values.as_slice(), point(at), building)
    }

    /// The sounds that a facility query plays.
    #[func]
    fn query_sound_events(tile_id: i64, statistic_0: i64) -> PackedInt32Array {
        query::text::specific_sound_events(tile_id, statistic_0)
            .iter()
            .map(|&sound| sound as i32)
            .collect()
    }

    /// `{available, enabled, selection, area, landscape, repeat_placement,
    /// show_status, status_text, status_detail}` of a catalog tool. `view` is
    /// "city", "underground", "data", or another view.
    #[func]
    fn edit_state(has_city: bool, available: bool, view: GString, group: i64, subtool: i64, dispatch_units: i64) -> VarDictionary {
        let view = match view.to_string().as_str() {
            "city" => View::City,
            "underground" => View::Underground,
            "data" => View::Data,
            _ => View::Other,
        };
        let state = edit_state::normal(has_city, available, view, group, subtool, dispatch_units);
        let mut result = VarDictionary::new();
        result.set("available", state.available);
        result.set("enabled", state.enabled);
        result.set("selection", state.selection);
        result.set("area", state.area);
        result.set("landscape", state.landscape);
        result.set("repeat_placement", state.repeat_placement);
        result.set("show_status", state.show_status);
        result.set("status_text", state.status_text.as_str());
        result.set("status_detail", state.status_detail.as_str());
        result
    }

    /// The sounds of a successful edit of a tool.
    #[func]
    fn tool_success_sounds(group: i64, subtool: i64) -> PackedInt32Array {
        sounds::success_events(group, subtool).iter().map(|&sound| sound as i32).collect()
    }

    /// The sounds of a zone edit.
    #[func]
    fn zone_success_sounds(zone_type: i64) -> PackedInt32Array {
        sounds::zone_success_events(zone_type).iter().map(|&sound| sound as i32).collect()
    }

    /// The sounds of a failed edit of a tool.
    #[func]
    fn tool_failure_sounds(group: i64, subtool: i64, error: GString) -> PackedInt32Array {
        sounds::failure_events(group, subtool, &error.to_string())
            .iter()
            .map(|&sound| sound as i32)
            .collect()
    }

    /// The dialog text of a QueryResult.
    #[func]
    fn query_text(info: Gd<Object>) -> GString {
        if !object_field::<bool>(&info, "ok").unwrap_or(false) {
            return GString::from(query::text::failure_text(&object_text(&info, "error")).as_str());
        }

        GString::from(query::text::format_text(&query_info(&info)).as_str())
    }

    /// True when a city with `misc` in `city_mode` allows the tool.
    #[func]
    fn tool_available(misc: PackedByteArray, city_mode: i64, group: i64, subtool: i64) -> bool {
        availability::is_available(misc.as_slice(), city_mode, group, subtool)
    }

    /// The tiles of each building ID outside military zones, as CityTileCounts.count.
    #[func]
    fn building_counts(buildings: PackedByteArray, zones: PackedByteArray) -> PackedInt32Array {
        let counts = sc2k_sim::sim::civic::mayor::building_counts(buildings.as_slice(), zones.as_slice());

        counts.iter().map(|&count| count.min(i32::MAX as i64) as i32).collect()
    }

    /// The map bounds of each of `records` MicroSim records: min x, min y,
    /// max x, max y and the tile count. A record with no tile counts 0 tiles.
    #[func]
    fn facility_bounds(overlays: PackedByteArray, things: PackedByteArray, edge: i64, records: i64) -> PackedInt32Array {
        let bounds = sc2k_sim::sim::facility_sites::bounds(overlays.as_slice(), things.as_slice(), edge, records.max(0) as usize);

        PackedInt32Array::from(bounds.as_slice())
    }

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
        network::bridge::bridge_tile(bridge_type, span_length, span_index, direction)
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
