//! The Query tool, as QueryInfo and QueryDetails: what a click on a tile shows.
//! A facility with a MicroSim record shows its own statistics; any other tile
//! shows the general tile values. Both add the raw tile data. The view adds
//! the sprites.

pub mod actions;
pub mod strings;
pub mod text;

use crate::formats::sc2x::labels;
use crate::sim::city::City;
use crate::sim::geom::Vec2i;
use crate::sim::grid;
use crate::sim::ids::building_tile_ids as tiles;
use crate::sim::ids::sc2misc_layout as misc;
use crate::sim::ids::sc2zone_layout as zone_layout;
use crate::sim::ids::terrain_tile_ids as terrain_ids;
use crate::sim::overlay;
use crate::sim::things;
use crate::sim::tools::commands::building::facilities::microsim_type;
use crate::sim::value::{Strings, ToValue, Value};
use strings::{DIRECTION_NAMES, FLAG_LABELS, THING_NAMES, UNDERGROUND_NAMES, ZONE_DENSITIES, ZONE_NAMES};

/// The data maps that the query reads.
const DATA_MAPS: [&str; 4] = ["XTRF", "XPLT", "XVAL", "XCRM"];
const MICROSIM_RECORD_SIZE: usize = 8;
/// The thing type of the sailboat.
const SAILBOAT: i64 = 9;
/// The thresholds of the Low, Medium, and High levels.
const LEVEL_THRESHOLDS: [i64; 3] = [60, 120, 180];

/// One XMIC record.
#[derive(Clone, Copy, Debug, Default, PartialEq, Eq)]
pub struct Microsim {
    pub tile_id: i64,
    pub stat_0: i64,
    pub stat_1: i64,
    pub stat_2: i64,
    pub stat_3: i64,
}

impl ToValue for Microsim {
    fn to_value(&self) -> Value {
        Value::Object(
            "CityRecords.Microsim",
            vec![
                ("tile_id", Value::Int(self.tile_id)),
                ("stat_0", Value::Int(self.stat_0)),
                ("stat_1", Value::Int(self.stat_1)),
                ("stat_2", Value::Int(self.stat_2)),
                ("stat_3", Value::Int(self.stat_3)),
            ],
        )
    }
}

/// A moving object on the queried tile.
#[derive(Clone, Debug, Default, PartialEq, Eq)]
pub struct Thing {
    pub record: i64,
    pub fields: [i64; 12],
    pub type_name: String,
    pub direction_name: String,
}

/// The stored fields of a thing, in record order.
const THING_FIELDS: [&str; 12] = ["type", "direction", "state", "x", "y", "z", "px", "py", "dx", "dy", "label", "goal"];

impl ToValue for Thing {
    fn to_value(&self) -> Value {
        let mut fields: Vec<(&'static str, Value)> = THING_FIELDS
            .iter()
            .zip(self.fields)
            .map(|(name, value)| (*name, Value::Int(value)))
            .collect();
        fields.push(("record", Value::Int(self.record)));
        fields.push(("type_name", Value::Str(self.type_name.clone())));
        fields.push(("direction_name", Value::Str(self.direction_name.clone())));

        Value::Object("QueryThing", fields)
    }
}

/// What the query dialog shows, as QueryResult. The view sets the sprites.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct QueryInfo {
    /// "specific" for a facility with a MicroSim record, else "general".
    pub kind: String,
    pub point: Vec2i,
    pub title: String,
    pub shows_traffic: bool,
    pub altitude_is_depth: bool,
    pub shows_land_value: bool,
    pub shows_utilities: bool,
    pub powered: bool,
    pub watered: bool,
    pub zone_name: String,
    pub zone_density: String,
    pub crime_level: String,
    pub pollution_level: String,
    pub water_detail: String,
    pub action: String,
    pub corner_name: String,
    pub underground_name: String,
    pub microsim_label: String,
    pub overlay_id: i64,
    pub zone_id: i64,
    pub sprite_id: i64,
    pub building_id: i64,
    pub terrain_id: i64,
    pub traffic: i64,
    pub altitude_feet: i64,
    pub land_value: i64,
    pub crime: i64,
    pub pollution: i64,
    pub microsim_type: i64,
    pub tile_id: i64,
    pub altitude_raw: i64,
    pub land_value_raw: i64,
    pub crime_raw: i64,
    pub pollution_raw: i64,
    pub zone_raw: i64,
    pub flags_raw: i64,
    pub underground_id: i64,
    pub microsim_id: i64,
    pub microsim: Option<Microsim>,
    pub lines: Vec<String>,
    pub flag_names: Vec<String>,
    pub sound_events: Vec<i64>,
    pub things: Vec<Thing>,
}

impl Default for QueryInfo {
    fn default() -> Self {
        Self {
            kind: String::new(),
            point: Vec2i::NONE,
            title: String::new(),
            shows_traffic: false,
            altitude_is_depth: false,
            shows_land_value: false,
            shows_utilities: false,
            powered: false,
            watered: false,
            zone_name: String::new(),
            zone_density: String::new(),
            crime_level: String::new(),
            pollution_level: String::new(),
            water_detail: String::new(),
            action: String::new(),
            corner_name: String::new(),
            underground_name: String::new(),
            microsim_label: String::new(),
            overlay_id: 0,
            zone_id: 0,
            sprite_id: 0,
            building_id: tiles::EMPTY,
            terrain_id: terrain_ids::FLAT,
            traffic: 0,
            altitude_feet: 0,
            land_value: 0,
            crime: 0,
            pollution: 0,
            microsim_type: 0,
            tile_id: tiles::EMPTY,
            altitude_raw: 0,
            land_value_raw: 0,
            crime_raw: 0,
            pollution_raw: 0,
            zone_raw: 0,
            flags_raw: 0,
            underground_id: 0,
            microsim_id: -1,
            microsim: None,
            lines: Vec::new(),
            flag_names: Vec::new(),
            sound_events: Vec::new(),
            things: Vec::new(),
        }
    }
}

impl ToValue for QueryInfo {
    fn to_value(&self) -> Value {
        let text = |value: &str| Value::Str(value.to_string());
        let mut fields = vec![
            ("ok", Value::Bool(true)),
            ("error", text("")),
            ("kind", text(&self.kind)),
            ("point", Value::Vec2i(self.point)),
            ("title", text(&self.title)),
            ("shows_traffic", Value::Bool(self.shows_traffic)),
            ("altitude_is_depth", Value::Bool(self.altitude_is_depth)),
            ("shows_land_value", Value::Bool(self.shows_land_value)),
            ("shows_utilities", Value::Bool(self.shows_utilities)),
            ("powered", Value::Bool(self.powered)),
            ("watered", Value::Bool(self.watered)),
            ("zone_name", text(&self.zone_name)),
            ("zone_density", text(&self.zone_density)),
            ("crime_level", text(&self.crime_level)),
            ("pollution_level", text(&self.pollution_level)),
            ("water_detail", text(&self.water_detail)),
            ("action", text(&self.action)),
            ("corner_name", text(&self.corner_name)),
            ("underground_name", text(&self.underground_name)),
            ("microsim_label", text(&self.microsim_label)),
        ];
        let numbers = [
            ("overlay_id", self.overlay_id),
            ("zone_id", self.zone_id),
            ("building_id", self.building_id),
            ("terrain_id", self.terrain_id),
            ("traffic", self.traffic),
            ("altitude_feet", self.altitude_feet),
            ("land_value", self.land_value),
            ("crime", self.crime),
            ("pollution", self.pollution),
            ("microsim_type", self.microsim_type),
            ("tile_id", self.tile_id),
            ("altitude_raw", self.altitude_raw),
            ("land_value_raw", self.land_value_raw),
            ("crime_raw", self.crime_raw),
            ("pollution_raw", self.pollution_raw),
            ("zone_raw", self.zone_raw),
            ("flags_raw", self.flags_raw),
            ("underground_id", self.underground_id),
            ("microsim_id", self.microsim_id),
        ];
        fields.extend(numbers.into_iter().map(|(name, value)| (name, Value::Int(value))));

        if let Some(microsim) = self.microsim {
            fields.push(("microsim", microsim.to_value()));
        }

        fields.push(("lines", Strings(self.lines.clone()).to_value()));
        fields.push(("flag_names", Strings(self.flag_names.clone()).to_value()));
        fields.push((
            "sound_events",
            Value::Array(self.sound_events.iter().map(|&sound| Value::Int(sound)).collect()),
        ));
        fields.push(("things", Value::Array(self.things.iter().map(ToValue::to_value).collect())));

        Value::Object("QueryResult", fields)
    }
}

/// A failed query as a QueryResult.
pub fn failure(message: &str) -> Value {
    Value::Object(
        "QueryResult",
        vec![("ok", Value::Bool(false)), ("error", Value::Str(message.to_string()))],
    )
}

/// The text of a label, or an empty string outside a valid XLAB table.
pub fn label(city: &City, label_id: i64) -> String {
    let data = &city.xlab.data;

    if city.chunk("XLAB").is_none() || data.len() as i64 != city.decoded_size("XLAB") || label_id < 0 {
        return String::new();
    }

    labels::read(data, label_id as usize, labels::is_wide_table(data)).unwrap_or_default()
}

/// The XMIC record `microsim_id`, or `None` outside the table.
pub fn microsim(city: &City, microsim_id: i64) -> Option<Microsim> {
    let count = city.decoded_size("XMIC").max(0) as usize / MICROSIM_RECORD_SIZE;
    let id = usize::try_from(microsim_id).ok().filter(|&id| id < count)?;
    city.chunk("XMIC")?;
    let record = city.xmic.data.get(id * MICROSIM_RECORD_SIZE..(id + 1) * MICROSIM_RECORD_SIZE)?;
    let word = |at: usize| i64::from(u16::from_be_bytes([record[at], record[at + 1]]));

    Some(Microsim {
        tile_id: i64::from(record[0]),
        stat_0: i64::from(record[1]),
        stat_1: word(2),
        stat_2: word(4),
        stat_3: word(6),
    })
}

/// The facility layer of a tile: the layer of a layered index, else its value.
fn facility_overlay_id(city: &City, point: Vec2i) -> i64 {
    let index = city.index_of(point.x, point.y);

    if index < 0 {
        0
    } else {
        overlay::facility_at(&city.xtxt.data, index)
    }
}

fn name<'a>(names: &[&'a str], index: i64, fallback: &'a str) -> &'a str {
    usize::try_from(index)
        .ok()
        .and_then(|index| names.get(index))
        .copied()
        .unwrap_or(fallback)
}

/// The executable selects the first level whose threshold is above the value.
pub fn level_name(value: i64) -> &'static str {
    if value < 1 {
        return "None";
    }

    match LEVEL_THRESHOLDS.iter().position(|&threshold| value < threshold) {
        Some(0) => "Low",
        Some(1) => "Medium",
        Some(_) => "High",
        None => "Very High",
    }
}

fn corner_name(mask: i64) -> &'static str {
    match mask {
        0x10 => "Bottom-left corner",
        0x20 => "Bottom-right corner",
        0x40 => "Top-left corner",
        0x80 => "Top-right corner",
        0xf0 => "All four corners",
        _ => "No corners",
    }
}

fn is_traffic_tile(building: i64) -> bool {
    (tiles::ROAD_STRAIGHT_1..=tiles::ROAD_CROSSROADS).contains(&building)
        || (tiles::TUNNEL_ENTRANCE_1..=tiles::ROAD_RAIL_CROSSING_2).contains(&building)
        || (tiles::HIGHWAY_STRAIGHT_1..=tiles::RAIL_BRIDGE_PYLON).contains(&building)
        || (tiles::HIGHWAY_ONRAMP_1..=tiles::REINFORCED_HIGHWAY_BRIDGE).contains(&building)
}

fn is_highway_traffic_tile(building: i64) -> bool {
    (tiles::HIGHWAY_STRAIGHT_1..=tiles::HIGHWAY_POWER_CROSSING_2).contains(&building)
        || (tiles::HIGHWAY_SLOPE_1..=tiles::REINFORCED_HIGHWAY_BRIDGE).contains(&building)
}

/// The cars per minute of a road tile. A full-resolution map holds the value;
/// a half-resolution map averages the four neighbors.
pub fn traffic(edge: i64, values: &[u8], point: Vec2i, building: i64) -> i64 {
    if !is_traffic_tile(building) {
        return 0;
    }

    if values.len() as i64 == edge * edge {
        let value = i64::from(values[(point.x * edge + point.y) as usize]);

        return if is_highway_traffic_tile(building) { value } else { value / 2 };
    }

    let neighbors = [
        Vec2i::new(point.x - 1, point.y),
        Vec2i::new(point.x, point.y - 1),
        Vec2i::new(point.x + 1, point.y),
        Vec2i::new(point.x, point.y + 1),
    ];
    let mut total: i64 = neighbors
        .iter()
        .filter(|neighbor| (0..edge).contains(&neighbor.x) && (0..edge).contains(&neighbor.y))
        .map(|neighbor| i64::from(values[grid::index(values, edge, neighbor.x, neighbor.y) as usize]))
        .sum();

    if is_highway_traffic_tile(building) {
        total *= 2;
    }

    total / 8
}

/// The water of a pump or a tower.
fn water_detail(city: &City, point: Vec2i, building: i64) -> String {
    let edge = city.map_size;

    if building == tiles::WATER_PUMP {
        let mut supply = 0;

        if city.is_powered(point.x, point.y) {
            supply = city.misc_u32(misc::WATER_LEVEL) * 5 + (city.misc_u32(misc::WEATHER_RAIN) & 0xff) / 2;

            for x in (point.x - 1).max(0)..(point.x + 2).min(edge) {
                for y in (point.y - 1).max(0)..(point.y + 2).min(edge) {
                    if city.is_water(x, y) && !city.is_salt_water(x, y) {
                        supply += 10;
                    }
                }
            }
        }

        return format!("Water: {} gallons per month", supply * 720);
    }

    if building == tiles::WATER_TOWER {
        return format!("Water: {} stored gallons", water_tower_storage(city, point));
    }

    String::new()
}

/// A whole tower stores 10,000 gallons for each watered tile.
fn water_tower_storage(city: &City, point: Vec2i) -> i64 {
    for origin_x in point.x - 1..point.x + 1 {
        for origin_y in point.y..point.y + 2 {
            let tiles = [
                Vec2i::new(origin_x, origin_y),
                Vec2i::new(origin_x + 1, origin_y),
                Vec2i::new(origin_x, origin_y - 1),
                Vec2i::new(origin_x + 1, origin_y - 1),
            ];

            if tiles.iter().any(|tile| city.building_id(tile.x, tile.y) != tiles::WATER_TOWER) {
                continue;
            }

            return tiles.iter().filter(|tile| city.is_watered(tile.x, tile.y)).count() as i64 * 10000;
        }
    }

    if city.is_watered(point.x, point.y) { 10000 } else { 0 }
}

/// The name of a tile: its building, clear terrain, water, or the sailboat.
pub fn tile_name(city: &City, point: Vec2i, building: i64) -> String {
    if city.index_of(point.x, point.y) < 0 {
        return String::new();
    }

    if building != tiles::EMPTY {
        return strings::tile_name(building).to_string();
    }

    if !city.is_water(point.x, point.y) {
        return strings::CLEAR_TERRAIN.to_string();
    }

    let value = city.text_overlay_id(point.x, point.y);
    let data = &city.xthg.data;

    if overlay::is_thing(value) {
        let record = overlay::thing_record(value);

        if (0..things::count(data)).contains(&record) && things::field(data, record, things::FIELD_TYPE) & 0xff == SAILBOAT {
            return strings::SAILBOAT.to_string();
        }
    }

    if city.is_salt_water(point.x, point.y) {
        strings::SALT_WATER
    } else {
        strings::FRESH_WATER
    }
    .to_string()
}

/// The moving objects whose tile is `point`.
fn things_at(city: &City, point: Vec2i) -> Vec<Thing> {
    let data = &city.xthg.data;
    let mut result = Vec::new();

    for record in 1..things::count(data) {
        let offset = record * things::RECORD_SIZE;
        // the type, direction, and altitude bytes have no high plane
        let fields: [i64; 12] = std::array::from_fn(|field| match field as i64 {
            things::FIELD_TYPE | things::FIELD_DIRECTION | things::FIELD_Z => i64::from(data[(offset + field as i64) as usize]),
            field => things::read(data, offset + field),
        });

        if fields[0] == 0 || fields[things::FIELD_X as usize] != point.x || fields[things::FIELD_Y as usize] != point.y {
            continue;
        }

        result.push(Thing {
            record,
            fields,
            type_name: name(&THING_NAMES, fields[0], "Unknown").to_string(),
            direction_name: name(&DIRECTION_NAMES, fields[things::FIELD_DIRECTION as usize], "Unknown").to_string(),
        });
    }

    result
}

/// The raw tile data that both kinds of query show.
fn advanced_details(city: &City, point: Vec2i, microsim_id: i64) -> QueryInfo {
    let edge = city.map_size;
    let index = city.index_of(point.x, point.y) as usize;
    let detail_index = grid::index(&city.xval.data, edge, point.x, point.y) as usize;
    let overlay_id = facility_overlay_id(city, point);
    let microsim_id = if microsim_id < 0 && overlay::is_facility(overlay_id) {
        overlay::facility_record(overlay_id)
    } else {
        microsim_id
    };
    let flags = i64::from(city.xbit.data[index]);
    let underground_id = city.underground_id(point.x, point.y);
    let zone_raw = i64::from(city.xzon.data[index]);
    let mut result = QueryInfo {
        tile_id: city.building_id(point.x, point.y),
        zone_id: zone_raw & zone_layout::TYPE_MASK,
        altitude_raw: city.altitude_word(index as i64),
        land_value_raw: i64::from(city.xval.data[detail_index]),
        crime_raw: i64::from(city.xcrm.data[detail_index]),
        pollution_raw: i64::from(city.xplt.data[detail_index]),
        zone_raw,
        corner_name: corner_name(zone_raw & zone_layout::CORNERS_MASK).to_string(),
        flags_raw: flags,
        flag_names: FLAG_LABELS
            .iter()
            .filter(|(mask, _)| flags & mask != 0)
            .map(|(_, name)| name.to_string())
            .collect(),
        underground_id,
        underground_name: name(&UNDERGROUND_NAMES, underground_id, "Unknown").to_string(),
        microsim_id,
        things: things_at(city, point),
        ..QueryInfo::default()
    };

    if microsim_id >= 0 {
        result.microsim = microsim(city, microsim_id);
        result.microsim_label = label(city, overlay_id);
    }

    result
}

/// What a query of `point` shows. The view sets the sprites.
pub fn inspect(city: &City, point: Vec2i) -> Result<QueryInfo, String> {
    if city.index_of(point.x, point.y) < 0 {
        return Err("query position is outside the city".into());
    }

    if let Some(id) = DATA_MAPS
        .iter()
        .find(|id| city.chunk(id).is_none_or(|chunk| chunk.data.len() as i64 != city.decoded_size(id)))
    {
        return Err(format!("{id} data is missing or invalid"));
    }

    let overlay_id = facility_overlay_id(city, point);

    if overlay::is_facility(overlay_id) {
        let record = overlay::facility_record(overlay_id);

        if let Some(facility) = microsim(city, record).filter(|facility| facility.tile_id != tiles::EMPTY) {
            let kind = microsim_type(facility.tile_id);
            let action = match facility.tile_id {
                tiles::CITY_HALL => "city_analysis",
                tiles::LIBRARY => "library_ruminate",
                _ => "",
            };

            return Ok(QueryInfo {
                kind: "specific".into(),
                point,
                title: label(city, overlay_id),
                overlay_id,
                microsim_id: record,
                microsim: Some(facility),
                microsim_type: kind,
                lines: text::specific_lines(city, &facility, kind),
                action: action.into(),
                sound_events: text::specific_sound_events(facility.tile_id, facility.stat_0),
                ..advanced_details(city, point, record)
            });
        }
    }

    let building = city.building_id(point.x, point.y);
    let zone = city.zone_id(point.x, point.y);
    let water_level = city.misc_u32(misc::WATER_LEVEL);
    let land_altitude = city.land_altitude(point.x, point.y);
    let terrain = city.terrain_id(point.x, point.y);
    let (altitude_feet, altitude_is_depth, wet_tile) = if land_altitude < water_level {
        (100 * (water_level - land_altitude) - 50, true, true)
    } else if terrain == terrain_ids::FLAT || terrain >= terrain_ids::DEEP_WATER_FIRST {
        (
            100 * (land_altitude - water_level) + 50,
            false,
            terrain >= terrain_ids::DEEP_WATER_FIRST,
        )
    } else {
        (25 * (4 * (land_altitude - water_level) + 4), false, false)
    };
    let detail_index = grid::index(&city.xval.data, city.map_size, point.x, point.y) as usize;
    let crime = i64::from(city.xcrm.data[detail_index]);
    let pollution = i64::from(city.xplt.data[detail_index]);

    Ok(QueryInfo {
        kind: "general".into(),
        point,
        title: tile_name(city, point, building),
        building_id: building,
        terrain_id: terrain,
        zone_id: zone,
        zone_name: name(&ZONE_NAMES, zone, "Unknown zone").to_string(),
        zone_density: name(&ZONE_DENSITIES, zone, "").to_string(),
        shows_traffic: is_traffic_tile(building),
        traffic: traffic(city.map_size, &city.xtrf.data, point, building),
        altitude_feet,
        altitude_is_depth,
        shows_land_value: !wet_tile,
        land_value: i64::from(city.xval.data[detail_index]) + 1,
        crime,
        crime_level: level_name(crime).into(),
        pollution,
        pollution_level: level_name(pollution).into(),
        shows_utilities: building >= tiles::SMALL_PARK && zone != zone_layout::MILITARY && !wet_tile,
        powered: city.is_powered(point.x, point.y),
        watered: city.is_watered(point.x, point.y),
        water_detail: water_detail(city, point, building),
        overlay_id,
        ..advanced_details(city, point, -1)
    })
}

#[cfg(test)]
mod tests;
