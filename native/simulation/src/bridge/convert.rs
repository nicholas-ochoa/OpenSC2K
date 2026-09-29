//! Conversions between Godot values and simulation values.

use godot::prelude::*;

use crate::sim::city::{CHUNK_IDS, City};
use crate::sim::geom::{Rect2i as SimRect2i, Vec2i};
use crate::sim::random::{GameRandomScript, LfsrRandomScript, Randoms, SimRandomScript};
use crate::sim::value::Value;

/// Read an integer field. Missing fields use `fallback`.
pub fn int(dictionary: &VarDictionary, key: &str, fallback: i64) -> i64 {
    match dictionary.get(key) {
        Some(value) => value.try_to::<i64>().unwrap_or(fallback),
        None => fallback,
    }
}

pub fn boolean(dictionary: &VarDictionary, key: &str, fallback: bool) -> bool {
    match dictionary.get(key) {
        Some(value) => value.try_to::<bool>().unwrap_or(fallback),
        None => fallback,
    }
}

pub fn string(dictionary: &VarDictionary, key: &str) -> String {
    match dictionary.get(key) {
        Some(value) => value.try_to::<GString>().map(|text| text.to_string()).unwrap_or_default(),
        None => String::new(),
    }
}

pub fn point(dictionary: &VarDictionary, key: &str, fallback: Vec2i) -> Vec2i {
    match dictionary.get(key).and_then(|value| value.try_to::<Vector2i>().ok()) {
        Some(value) => Vec2i::new(value.x as i64, value.y as i64),
        None => fallback,
    }
}

pub fn rect(dictionary: &VarDictionary, key: &str) -> SimRect2i {
    match dictionary.get(key).and_then(|value| value.try_to::<Rect2i>().ok()) {
        Some(value) => SimRect2i::new(
            value.position.x as i64,
            value.position.y as i64,
            value.size.x as i64,
            value.size.y as i64,
        ),
        None => SimRect2i::default(),
    }
}

pub fn dictionary(dictionary: &VarDictionary, key: &str) -> VarDictionary {
    match dictionary.get(key) {
        Some(value) => value.try_to::<VarDictionary>().unwrap_or_default(),
        None => VarDictionary::new(),
    }
}

pub fn ints32(dictionary: &VarDictionary, key: &str) -> Vec<i32> {
    match dictionary.get(key).and_then(|value| value.try_to::<PackedInt32Array>().ok()) {
        Some(values) => values.to_vec(),
        None => Vec::new(),
    }
}

pub fn strings(dictionary: &VarDictionary, key: &str) -> Vec<String> {
    match dictionary.get(key).and_then(|value| value.try_to::<PackedStringArray>().ok()) {
        Some(values) => values.as_slice().iter().map(|text| text.to_string()).collect(),
        None => Vec::new(),
    }
}

/// Build the city from `{map_size, large_version, disaster_damage_class, chunks: {id: bytes}}`.
pub fn city(request: &VarDictionary) -> City {
    let source = dictionary(request, "city");
    let mut city = City::new(int(&source, "map_size", 128), int(&source, "large_version", 2));
    city.disaster_damage_class = int(&source, "disaster_damage_class", -1);
    let chunks = dictionary(&source, "chunks");

    for id in CHUNK_IDS {
        let Some(value) = chunks.get(id) else {
            continue;
        };

        let Ok(bytes) = value.try_to::<PackedByteArray>() else {
            continue;
        };

        if let Some(slot) = chunk_slot(&mut city, id) {
            slot.present = true;
            slot.data = bytes.to_vec();
        }
    }

    city
}

fn chunk_slot<'a>(city: &'a mut City, id: &str) -> Option<&'a mut crate::sim::city::Chunk> {
    let slot = match id {
        "CNAM" => &mut city.cnam,
        "MISC" => &mut city.misc,
        "ALTM" => &mut city.altm,
        "XTER" => &mut city.xter,
        "XBLD" => &mut city.xbld,
        "XZON" => &mut city.xzon,
        "XUND" => &mut city.xund,
        "XTXT" => &mut city.xtxt,
        "XLAB" => &mut city.xlab,
        "XMIC" => &mut city.xmic,
        "XTHG" => &mut city.xthg,
        "XBIT" => &mut city.xbit,
        "XTRF" => &mut city.xtrf,
        "XPLT" => &mut city.xplt,
        "XVAL" => &mut city.xval,
        "XCRM" => &mut city.xcrm,
        "XPLC" => &mut city.xplc,
        "XFIR" => &mut city.xfir,
        "XPOP" => &mut city.xpop,
        "XROG" => &mut city.xrog,
        "XGRP" => &mut city.xgrp,
        "SCEN" => &mut city.scen,
        "TEXT" => &mut city.text,
        "PICT" => &mut city.pict,
        "TMPL" => &mut city.tmpl,
        _ => return None,
    };

    Some(slot)
}

/// The written chunks as `{id: bytes}`, in document chunk-id order.
pub fn written_chunks(city: &City) -> VarDictionary {
    let mut result = VarDictionary::new();

    for id in city.written_ids() {
        if let Some(chunk) = city.chunk(id) {
            result.set(id, &PackedByteArray::from(chunk.data.as_slice()));
        }
    }

    result
}

/// A GDScript random generator subclass. Each draw calls the object's method.
struct ScriptedRandom(Gd<Object>);

impl ScriptedRandom {
    fn draw(&mut self, method: &str, args: &[Variant]) -> i64 {
        self.0.call(method, args).try_to::<i64>().unwrap_or(0)
    }
}

impl SimRandomScript for ScriptedRandom {
    fn next_u15(&mut self) -> i64 {
        self.draw("next_u15", &[])
    }
}

impl LfsrRandomScript for ScriptedRandom {
    fn next_word(&mut self) -> i64 {
        self.draw("next_word", &[])
    }

    fn next_mask(&mut self, mask: i64) -> i64 {
        self.draw("next_mask", &[mask.to_variant()])
    }

    fn next_mod(&mut self, divisor: i64) -> i64 {
        self.draw("next_mod", &[divisor.to_variant()])
    }
}

impl GameRandomScript for ScriptedRandom {
    fn next_mod(&mut self, divisor: i64) -> i64 {
        self.draw("next_mod", &[divisor.to_variant()])
    }
}

/// The generator states, and the scripted generators that replace them.
pub fn randoms(request: &VarDictionary) -> Randoms {
    let values = match request.get("randoms").and_then(|value| value.try_to::<PackedInt64Array>().ok()) {
        Some(values) => values.to_vec(),
        None => Vec::new(),
    };
    let at = |index: usize| values.get(index).copied().unwrap_or(1);
    let mut randoms = Randoms::new(at(0), at(1), at(2));
    let scripts = match request.get("scripts").and_then(|value| value.try_to::<VarArray>().ok()) {
        Some(scripts) => scripts,
        None => return randoms,
    };
    let script = |index: usize| scripts.get(index).and_then(|value| value.try_to::<Gd<Object>>().ok());

    if let Some(object) = script(0) {
        randoms.random.script = Some(Box::new(ScriptedRandom(object)));
    }

    if let Some(object) = script(1) {
        randoms.lfsr.script = Some(Box::new(ScriptedRandom(object)));
    }

    if let Some(object) = script(2) {
        randoms.game.script = Some(Box::new(ScriptedRandom(object)));
    }

    randoms
}

pub fn randoms_value(randoms: &Randoms) -> PackedInt64Array {
    PackedInt64Array::from(&[randoms.random.state, randoms.lfsr.state, randoms.game.state])
}

pub fn vector2i(point: Vec2i) -> Vector2i {
    Vector2i::new(point.x as i32, point.y as i32)
}

pub fn variant(value: &Value) -> Variant {
    match value {
        Value::Nil => Variant::nil(),
        Value::Bool(value) => value.to_variant(),
        Value::Int(value) => value.to_variant(),
        Value::Float(value) => value.to_variant(),
        Value::Str(value) => GString::from(value.as_str()).to_variant(),
        Value::Vec2i(value) => vector2i(*value).to_variant(),
        Value::Rect2i(value) => Rect2i::new(vector2i(value.position), vector2i(value.size)).to_variant(),
        Value::Bytes(value) => PackedByteArray::from(value.as_slice()).to_variant(),
        Value::Ints32(value) => PackedInt32Array::from(value.as_slice()).to_variant(),
        Value::Ints64(value) => PackedInt64Array::from(value.as_slice()).to_variant(),
        Value::Strings(value) => value
            .iter()
            .map(|text| GString::from(text.as_str()))
            .collect::<PackedStringArray>()
            .to_variant(),
        Value::Array(items) => {
            let mut array = VarArray::new();

            for item in items {
                array.push(&variant(item));
            }

            array.to_variant()
        }
        Value::Dict(entries) => {
            let mut result = VarDictionary::new();

            for (key, item) in entries {
                result.set(&variant(key), &variant(item));
            }

            result.to_variant()
        }
        Value::Object(class, fields) => {
            let mut result = VarDictionary::new();
            result.set("__class", *class);

            for (name, item) in fields {
                result.set(*name, &variant(item));
            }

            result.to_variant()
        }
    }
}

/// A SimulationTiming sent as `{work_usec, steps}`.
pub fn timing(dictionary: &VarDictionary, key: &str) -> crate::sim::events::Timing {
    let source = self::dictionary(dictionary, key);
    let mut steps = crate::sim::value::OrderedMap::new();

    for (name, value) in self::dictionary(&source, "steps").iter_shared() {
        steps.set(&name.to_string(), value.try_to::<i64>().unwrap_or(0));
    }

    let total = if boolean(&source, "has_total", false) {
        int(&source, "work_usec", 0)
    } else {
        -1
    };

    crate::sim::events::Timing::new(total, steps)
}

/// ScenarioState fields, or None when the dictionary is missing or empty.
pub fn scenario(dictionary: &VarDictionary, key: &str) -> Option<crate::sim::civic::scenario::Scenario> {
    let source = self::dictionary(dictionary, key);

    if source.is_empty() {
        return None;
    }

    let field = |name: &str| int(&source, name, 0);

    Some(crate::sim::civic::scenario::Scenario {
        format_size: field("format_size") as usize,
        disaster_type: field("disaster_type"),
        disaster_x: field("disaster_x"),
        disaster_y: field("disaster_y"),
        time_limit_months: field("time_limit_months"),
        city_size_goal: field("city_size_goal"),
        residential_goal: field("residential_goal"),
        commercial_goal: field("commercial_goal"),
        industrial_goal: field("industrial_goal"),
        cash_goal: field("cash_goal"),
        land_value_goal: field("land_value_goal"),
        life_expectancy_goal: field("life_expectancy_goal"),
        education_goal: field("education_goal"),
        pollution_limit: field("pollution_limit"),
        crime_limit: field("crime_limit"),
        traffic_limit: field("traffic_limit"),
        first_building_id: field("first_building_id"),
        second_building_id: field("second_building_id"),
        first_building_tile_count: field("first_building_tile_count"),
        second_building_tile_count: field("second_building_tile_count"),
    })
}

pub fn schedule(dictionary: &VarDictionary, key: &str) -> crate::sim::engine::day::Schedule {
    let fields = self::dictionary(dictionary, key);

    crate::sim::engine::day::Schedule {
        city_days: int(&fields, "city_days", 0),
        month_day: int(&fields, "month_day", 0),
        season: int(&fields, "season", 0),
        actions: strings(&fields, "actions"),
        growth_step: int(&fields, "growth_step", -1),
        growth_substep: int(&fields, "growth_substep", -1),
    }
}

pub fn engine_state(dictionary: &VarDictionary, key: &str) -> crate::sim::engine::day::EngineState {
    let fields = self::dictionary(dictionary, key);

    crate::sim::engine::day::EngineState {
        developed_tiles: int(&fields, "developed_tiles", -1),
        power_usage_percent: int(&fields, "power_usage_percent", -1),
        water_usage_percent: int(&fields, "water_usage_percent", -1),
        bus_passengers: int(&fields, "bus_passengers", 0),
        rail_passengers: int(&fields, "rail_passengers", 0),
        subway_passengers: int(&fields, "subway_passengers", 0),
        ship_home: point(&fields, "ship_home", Vec2i::NONE),
        city_status_resource_id: int(&fields, "city_status_resource_id", -1),
        commerce_connections: int(&fields, "commerce_connections", 0),
        industry_connections: int(&fields, "industry_connections", 0),
        mayor_approval: int(&fields, "mayor_approval", 0),
        midi_playback_active: boolean(&fields, "midi_playback_active", false),
        pending_disaster_type: int(&fields, "pending_disaster_type", 0),
        pending_disaster_point: point(&fields, "pending_disaster_point", Vec2i::ZERO),
        terminal_state: boolean(&fields, "terminal_state", false),
        traffic_news_deadline_msec: int(&fields, "traffic_news_deadline_msec", 0),
    }
}

pub fn points(dictionary: &VarDictionary, key: &str) -> Vec<Vec2i> {
    let value = dictionary.get(key);

    if let Some(typed) = value.as_ref().and_then(|value| value.try_to::<Array<Vector2i>>().ok()) {
        return typed
            .iter_shared()
            .map(|point| Vec2i::new(point.x as i64, point.y as i64))
            .collect();
    }

    match value.and_then(|value| value.try_to::<VarArray>().ok()) {
        Some(values) => values
            .iter_shared()
            .filter_map(|value| value.try_to::<Vector2i>().ok())
            .map(|value| Vec2i::new(value.x as i64, value.y as i64))
            .collect(),
        None => Vec::new(),
    }
}

pub fn ints64(dictionary: &VarDictionary, key: &str) -> Vec<i64> {
    match dictionary.get(key).and_then(|value| value.try_to::<PackedInt64Array>().ok()) {
        Some(values) => values.to_vec(),
        None => Vec::new(),
    }
}
