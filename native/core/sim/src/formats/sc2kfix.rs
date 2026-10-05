//! The SC2X save format of the sc2kfix plugin (version 1), internally called
//! "sc2kfix". It is not the OpenSC2K SC2X version 4 format.
//!
//! A ZIP archive holds `META.json`, `current/MISC.json`, `current/XFIX.json`,
//! and the runtime arrays of an original 128-tile city under `current/`.
//! Runtime arrays are little-endian: ALTM words, XGRP values and the three
//! words of each XMIC record are byte-swapped from the SC2 file layout. XLAB
//! holds C strings instead of Pascal strings. The other arrays match the
//! decoded SC2 chunks.
//!
//! MISC.json omits some MISC words and the scenario chunks. A save also writes
//! `opensc2k/MISC` and `opensc2k/chunks/<ID>` entries, so a file that OpenSC2K
//! writes and reads again keeps all its data. sc2kfix ignores them.

use super::document::Document;
use super::sc2;
use crate::sim::ids::{sc2microsim_layout, sc2misc_layout};
use sc2k_formats::json::{self, Object, Value};
use sc2k_formats::zip;

pub const MAGIC: &str = "d77bc72e0a78e3f47700f3a2efc04bb2f49e75908547c7bcd495e5518831a0e7";
pub const VERSION: i64 = 1;
pub const EDGE: i64 = 128;
pub const SOURCE_FORMAT: &str = "sc2kfix";

const META: &str = "META.json";
const MISC: &str = "current/MISC.json";
const XFIX: &str = "current/XFIX.json";
const PRESERVED_MISC: &str = "opensc2k/MISC";
const PRESERVED_PREFIX: &str = "opensc2k/chunks/";
const PRESERVED_ORDER: &str = "opensc2k/chunk_order";
const MAX_ARCHIVE_BYTES: i64 = 64 * 1024 * 1024;
const MAX_DATA_BYTES: i64 = 64 * 1024 * 1024;
const MISC_VERSION: u32 = 290;

/// The chunks of a city in the order of an original save. CNAM comes from META.json.
const MAP_CHUNKS: [&str; 19] = [
    "ALTM", "XTER", "XBLD", "XZON", "XUND", "XTXT", "XLAB", "XMIC", "XTHG", "XBIT", "XTRF", "XPLT", "XVAL", "XCRM", "XPLC", "XFIR", "XPOP",
    "XROG", "XGRP",
];

const BUDGET_NAMES: [&str; 16] = [
    "residential",
    "commercial",
    "industrial",
    "ordinances",
    "bonds",
    "police",
    "fire",
    "health",
    "schools",
    "colleges",
    "raods",
    "highways",
    "bridges",
    "rail",
    "subways",
    "tunnels",
];
const NEIGHBOR_NAMES: [&str; 4] = ["north", "east", "south", "west"];
const NEIGHBOR_KEYS: [&str; 4] = ["name", "population", "value", "fame"];
const BUDGET_KEYS: [&str; 3] = ["current_costs", "funding_percent", "year_to_date_cost"];
const MONTH_KEYS: [&str; 2] = ["count_month", "fund_month"];
const LABEL_SIZE: usize = 25;
const LABEL_TEXT: usize = 24;

/// The runtime type of a MISC word in sc2kfix.
#[derive(Clone, Copy)]
enum Kind {
    U8,
    I16,
    U16,
    I32,
    U32,
}

/// MISC word, JSON section, key, and the runtime type of sc2kfix.
const FIELDS: &[(usize, &str, &str, Kind)] = &[
    (1, "city", "mode", Kind::I16),
    (2, "city", "view_rotation", Kind::I16),
    (3, "city", "start_year", Kind::I16),
    (4, "city", "days", Kind::I32),
    (5, "city", "funds", Kind::I32),
    (6, "city", "bonds", Kind::I32),
    (7, "city", "difficulty", Kind::I16),
    (8, "city", "progression", Kind::I16),
    (9, "city", "value", Kind::I32),
    (10, "city", "land_value", Kind::I32),
    (11, "city", "crime", Kind::I32),
    (12, "city", "traffic_count", Kind::I32),
    (13, "city", "pollution", Kind::I32),
    (14, "city", "fame", Kind::I32),
    (15, "city", "advertising", Kind::I32),
    (16, "city", "garbage", Kind::U32),
    (17, "city", "workforce_percent", Kind::I32),
    (18, "city", "workforce_le", Kind::I32),
    (19, "city", "workforce_eq", Kind::I32),
    (20, "nation", "population", Kind::I32),
    (21, "nation", "value", Kind::I32),
    (22, "nation", "fed_rate", Kind::I16),
    (23, "nation", "economy_trend", Kind::I16),
    (24, "city", "weather_heat", Kind::U8),
    (25, "city", "weather_wind", Kind::U8),
    (26, "city", "weather_rain", Kind::U8),
    (27, "city", "weather_trend", Kind::U8),
    (29, "city", "old_res_pop", Kind::I32),
    (30, "city", "granted_rewards", Kind::I16),
    (911, "city", "year_end_flag", Kind::U8),
    (912, "city", "water_level", Kind::I16),
    (913, "city", "has_ocean", Kind::U8),
    (914, "city", "has_river", Kind::U8),
    (915, "city", "military_base_type", Kind::U8),
    (1000, "city", "ordinances", Kind::U32),
    (1001, "city", "unemployment", Kind::I32),
    (1018, "city", "xund_count", Kind::U16),
    (1019, "options", "speed", Kind::I16),
    (1020, "options", "auto_budget", Kind::I32),
    (1021, "options", "auto_goto", Kind::I32),
    (1022, "options", "sound", Kind::I32),
    (1023, "options", "music", Kind::I32),
    (1024, "options", "no_disasters", Kind::I32),
    (1025, "city", "newspaper_subscription", Kind::I32),
    (1026, "city", "newspaper_extra", Kind::I32),
    (1027, "city", "newspaper_choice", Kind::I16),
    (1028, "city", "screen_point", Kind::I32),
    (1029, "city", "screen_zoom", Kind::U16),
    (1030, "city", "center_x", Kind::I16),
    (1031, "city", "center_y", Kind::I16),
    (1032, "city", "arcology_population", Kind::I32),
    (1033, "city", "connection_tiles", Kind::I16),
    (1034, "city", "sports_teams", Kind::I16),
    (1035, "city", "population", Kind::U32),
    (1036, "city", "industrial_mix_bonus", Kind::I16),
    (1037, "city", "industrial_mix_pollution_bonus", Kind::I16),
    (1038, "city", "old_arrests", Kind::I16),
    (1039, "city", "prison_bonus", Kind::I16),
    (1040, "city", "disaster_object", Kind::I16),
    (1041, "city", "disaster_type", Kind::I16),
    (1042, "city", "disaster_active", Kind::I32),
    (1043, "city", "sewer_bonus", Kind::I16),
];

/// MISC word, key, count, type of the city arrays.
const ARRAYS: [(usize, &str, usize, Kind); 6] = [
    (124, "tile_count", 256, Kind::U16),
    (380, "zone_pops", 8, Kind::U32),
    (388, "bond_data", 50, Kind::U16),
    (454, "demands", 8, Kind::I16),
    (462, "invention_years", 17, Kind::I16),
    (1002, "military_tile_count", 16, Kind::U16),
];

const RATIO_TABLES_WORD: usize = 31;
const RATIO_TABLES: [&str; 3] = ["pop_ratio_table", "eq_ratio_table", "le_ratio_table"];
const RATIO_VALUES: usize = 20;
const NEIGHBORS_WORD: usize = 438;
const BUDGETS_WORD: usize = 479;
const BUDGET_WORDS: usize = 27;
const MONTHS: usize = 12;
const PAPERS_WORD: usize = 916;
const PAPER_BYTES: usize = 30;
const NEWS_WORD: usize = 946;
const NEWS_COUNT: usize = 9;
const NEWS_WORDS: usize = 6;
const NEWS_BYTES: usize = 8;

/// MISC word 28 is the triggered disaster. sc2kfix writes it and word 1041 to one
/// key, so the key holds word 1041.
const TRIGGERED_DISASTER_WORD: usize = 28;
const DISASTER_TYPE_WORD: usize = 1041;

/// The first member of an sc2kfix archive is META.json. An OpenSC2K SC2X
/// version 4 archive starts with metadata.json.
pub fn is_archive(bytes: &[u8]) -> bool {
    if !super::sc2x::document::is_archive(bytes) || bytes.len() < 30 + META.len() {
        return false;
    }

    let name_size = usize::from(u16::from_le_bytes([bytes[26], bytes[27]]));

    name_size == META.len() && &bytes[30..30 + name_size] == META.as_bytes()
}

/// The original city of an sc2kfix archive.
pub fn load(bytes: &[u8]) -> Result<Document, String> {
    let archive =
        zip::decode(bytes, MAX_ARCHIVE_BYTES, MAX_DATA_BYTES).map_err(|error| format!("The sc2kfix city archive is invalid: {error}"))?;

    let member = |path: &str| archive.get(path);
    let meta = parse_json(member(META))
        .and_then(object_value)
        .ok_or("The sc2kfix city has no valid META.json.")?;

    let header = meta
        .get("sc2x")
        .and_then(Value::as_object)
        .filter(|header| header.get("magic").and_then(Value::as_str) == Some(MAGIC))
        .ok_or("The sc2kfix city has no valid META.json.")?;

    let version = header.get("version");

    if version.map_or(0, script_int) != VERSION {
        return Err(format!("The sc2kfix city version {} is not supported.", display(version)));
    }

    let empty = Object::new();
    let game = meta.get("game").and_then(Value::as_object).unwrap_or(&empty);

    if game.get("dimensions").map_or(EDGE, script_int) != EDGE {
        return Err("An sc2kfix city must use a 128 × 128 map.".into());
    }

    let misc_json = parse_json(member(MISC))
        .and_then(object_value)
        .ok_or("The sc2kfix city has no valid current/MISC.json.")?;

    let mut document = Document {
        map_size: EDGE,
        large_version: sc2::ORIGINAL_LARGE_VERSION,
        ..Document::default()
    };

    let name = game.get("city_name").map_or(String::new(), |value| display(Some(value)));
    let preserved_name = member(&format!("{PRESERVED_PREFIX}CNAM")).unwrap_or_default();

    if preserved_name.len() as i64 == decoded_size("CNAM") {
        let chunk = document.original_chunk("CNAM", preserved_name.to_vec());
        document.chunks.push(chunk);
    }

    if document.city_name() != name && !name.is_empty() {
        document.add_city_name_chunk();
        document.set_city_name(&name);
    }

    let misc = misc_from_json(&misc_json, member(PRESERVED_MISC).unwrap_or_default());
    let chunk = document.original_chunk("MISC", misc);
    document.chunks.push(chunk);

    for id in MAP_CHUNKS {
        let expected = decoded_size(id) as usize;

        let runtime = member(&format!("current/{id}"))
            .filter(|data| data.len() == expected)
            .ok_or_else(|| format!("The sc2kfix city {id} array is missing or has the wrong size."))?;

        // a chunk that OpenSC2K kept is exact while sc2kfix did not change it
        let preserved = member(&format!("{PRESERVED_PREFIX}{id}")).filter(|data| data.len() == expected && to_runtime(id, data) == runtime);

        let decoded = match preserved {
            Some(data) => data.to_vec(),
            None => from_runtime(id, runtime),
        };

        let chunk = document.original_chunk(id, decoded);
        document.chunks.push(chunk);
    }

    // a save adds the XFIX that sc2kfix requires. A city that had none keeps none
    let order = member(PRESERVED_ORDER).map(latin1).unwrap_or_default();
    let added_xfix = !order.is_empty() && !order.split(',').any(|id| id == "XFIX");

    if let Some(data) = member(XFIX)
        && !added_xfix
    {
        let chunk = document.original_chunk("XFIX", data.to_vec());
        document.chunks.push(chunk);
    }

    for (path, data) in &archive.members {
        let Some(id) = path.strip_prefix(PRESERVED_PREFIX) else {
            continue;
        };

        if !MAP_CHUNKS.contains(&id) && id != "CNAM" {
            let chunk = document.original_chunk(id, data.clone());
            document.chunks.push(chunk);
        }
    }

    restore_order(&mut document, &order);
    document.source_format = SOURCE_FORMAT.into();

    Ok(document)
}

/// An sc2kfix archive of an original city. `timestamp` is the META.json time.
pub fn encode(document: &Document, timestamp: i64) -> Result<Vec<u8>, String> {
    if document.is_extended() || document.map_size != EDGE {
        return Err("Only an original 128 × 128 city can use the sc2kfix format.".into());
    }

    let misc = document
        .find("MISC")
        .map(|chunk| chunk.decoded.as_slice())
        .filter(|data| data.len() as i64 == sc2misc_layout::SIZE)
        .ok_or("The city has no valid MISC data.")?;

    let mut members: Vec<(String, Vec<u8>)> = Vec::new();

    let mut add = |path: &str, bytes: Vec<u8>| {
        if !members.iter().any(|(name, _)| name == path) {
            members.push((path.to_string(), bytes));
        }
    };

    let meta = object(vec![
        (
            "sc2x",
            object(vec![
                ("magic", Value::String(MAGIC.into())),
                ("creator", Value::String("OpenSC2K".into())),
                ("timestamp", Value::Int(timestamp)),
                ("version", Value::Int(VERSION)),
            ]),
        ),
        (
            "game",
            object(vec![
                ("dimensions", Value::Int(EDGE)),
                ("city_name", Value::String(document.city_name())),
            ]),
        ),
    ]);

    add(META, json_bytes(&meta));
    add(MISC, json_bytes(&misc_to_json(misc)));

    for id in MAP_CHUNKS {
        let data = document
            .find(id)
            .map(|chunk| chunk.decoded.as_slice())
            .filter(|data| data.len() as i64 == decoded_size(id))
            .ok_or_else(|| format!("The city has no valid {id} data."))?;

        add(&format!("current/{id}"), to_runtime(id, data));
    }

    let xfix = match document.find("XFIX") {
        Some(chunk) => chunk.decoded.clone(),
        None => json_bytes(&default_xfix(timestamp)),
    };

    add(XFIX, xfix);
    add(PRESERVED_MISC, misc.to_vec());

    let mut order = Vec::new();

    for chunk in &document.chunks {
        let id = chunk.id.as_str();
        order.push(id.to_string());
        let exact = MAP_CHUNKS.contains(&id) && from_runtime(id, &to_runtime(id, &chunk.decoded)) == chunk.decoded;

        if id != "MISC" && id != "XFIX" && !exact {
            add(&format!("{PRESERVED_PREFIX}{id}"), chunk.decoded.clone());
        }
    }

    add(PRESERVED_ORDER, order.join(",").chars().map(super::document::ascii_byte).collect());

    let borrowed: Vec<(String, &[u8])> = members.iter().map(|(name, data)| (name.clone(), data.as_slice())).collect();

    zip::encode(&borrowed, MAX_ARCHIVE_BYTES, MAX_DATA_BYTES, true)
}

fn decoded_size(id: &str) -> i64 {
    sc2::decoded_size(id, EDGE, sc2::ORIGINAL_LARGE_VERSION)
}

/// The chunk order of the file that OpenSC2K wrote, when it lists the same chunks.
fn restore_order(document: &mut Document, order: &str) {
    let ids: Vec<&str> = order.split(',').filter(|id| !id.is_empty()).collect();

    if ids.len() != document.chunks.len() {
        return;
    }

    let mut unique: Vec<&str> = document.chunks.iter().map(|chunk| chunk.id.as_str()).collect();
    unique.sort_unstable();
    unique.dedup();

    if unique.len() != ids.len() {
        return;
    }

    let mut ordered = Vec::with_capacity(ids.len());

    for id in ids {
        // the last chunk of an ID wins, as a dictionary keeps it
        match document.chunks.iter().rev().find(|chunk| chunk.id == id) {
            Some(chunk) => ordered.push(chunk.clone()),
            None => return,
        }
    }

    document.chunks = ordered;
}

/// sc2kfix writes each JSON file with a terminating null byte.
fn parse_json(bytes: Option<&[u8]>) -> Option<Value> {
    let bytes = bytes?;
    let end = bytes.iter().rposition(|byte| *byte != 0).map_or(0, |index| index + 1);
    let text = String::from_utf8_lossy(&bytes[..end]);

    json::parse(&text).ok()
}

fn object_value(value: Value) -> Option<Object> {
    match value {
        Value::Object(object) => Some(object),
        _ => None,
    }
}

/// The text of a value as GDScript `str()` makes it.
fn display(value: Option<&Value>) -> String {
    match value {
        None | Some(Value::Null) => "<null>".into(),
        Some(Value::String(text)) => text.clone(),
        Some(Value::Bool(value)) => value.to_string(),
        Some(Value::Int(value)) => value.to_string(),
        Some(Value::Float(value)) if *value == value.floor() && value.abs() < 1e15 => format!("{value:.1}"),
        Some(other) => json::stringify(other, "", true),
    }
}

/// GDScript `int()` of a JSON value. Text counts by its leading integer.
fn script_int(value: &Value) -> i64 {
    match value {
        Value::String(text) => {
            let digits: String = text
                .trim_start()
                .chars()
                .enumerate()
                .take_while(|(index, character)| character.is_ascii_digit() || (*index == 0 && *character == '-'))
                .map(|(_, character)| character)
                .collect();

            digits.parse().unwrap_or(0)
        }
        other => other.to_int(),
    }
}

fn latin1(bytes: &[u8]) -> String {
    bytes.iter().map(|byte| char::from(*byte)).collect()
}

fn json_bytes(value: &Value) -> Vec<u8> {
    let mut bytes = json::stringify(value, "", true).into_bytes();
    bytes.push(0);

    bytes
}

fn object(entries: Vec<(&str, Value)>) -> Value {
    let mut result = Object::new();

    for (key, value) in entries {
        result.insert(key, value);
    }

    Value::Object(result)
}

fn default_xfix(timestamp: i64) -> Value {
    object(vec![
        (
            "meta",
            object(vec![
                ("creator", Value::String("OpenSC2K".into())),
                ("timestamp", Value::Int(timestamp)),
                ("porntipsguzzardo", Value::Bool(false)),
            ]),
        ),
        (
            "map",
            object(vec![
                ("terrain_cosmetic_mode", Value::Int(0)),
                ("tilesets", Value::Array(Vec::new())),
            ]),
        ),
    ])
}

/// The value of a MISC word as sc2kfix holds it at run time.
fn typed(word: i64, kind: Kind) -> i64 {
    match kind {
        Kind::U8 => word & 0xff,
        Kind::I16 => i64::from((word & 0xffff) as u16 as i16),
        Kind::U16 => word & 0xffff,
        Kind::I32 => i64::from((word & 0xffff_ffff) as u32 as i32),
        Kind::U32 => word & 0xffff_ffff,
    }
}

/// GDScript `int()` of a JSON value: booleans count as 0 and 1, other values as 0.
fn number(value: &Value) -> i64 {
    match value {
        Value::Bool(value) => i64::from(*value),
        Value::Int(value) => *value,
        Value::Float(value) => *value as i64,
        _ => 0,
    }
}

fn word(misc: &[u8], index: usize) -> i64 {
    i64::from(u32::from_be_bytes(misc[index * 4..index * 4 + 4].try_into().expect("four bytes")))
}

fn set_word(misc: &mut [u8], index: usize, value: i64) {
    misc[index * 4..index * 4 + 4].copy_from_slice(&(value as u32).to_be_bytes());
}

fn misc_to_json(misc: &[u8]) -> Value {
    let mut city = Object::new();
    let mut nation = Object::new();
    let mut options = Object::new();
    let mut neighbors = Object::new();

    for (index, section, key, kind) in FIELDS {
        let value = Value::Int(typed(word(misc, *index), *kind));

        match *section {
            "nation" => nation.insert(key, value),
            "options" => options.insert(key, value),
            _ => city.insert(key, value),
        }
    }

    for (first, key, count, kind) in ARRAYS {
        let values = (0..count).map(|index| Value::Int(typed(word(misc, first + index), kind))).collect();
        city.insert(key, Value::Array(values));
    }

    for (table, key) in RATIO_TABLES.iter().enumerate() {
        let values = (0..RATIO_VALUES)
            .map(|index| Value::Int(typed(word(misc, RATIO_TABLES_WORD + index * 3 + table), Kind::U32)))
            .collect();
        city.insert(key, Value::Array(values));
    }

    for (neighbor, key) in NEIGHBOR_NAMES.iter().enumerate() {
        let first = NEIGHBORS_WORD + neighbor * 4;
        let mut values = Object::new();
        values.insert("name", Value::Int(typed(word(misc, first), Kind::I16)));
        values.insert("population", Value::Int(typed(word(misc, first + 1), Kind::I32)));
        values.insert("value", Value::Int(typed(word(misc, first + 2), Kind::I32)));
        values.insert("fame", Value::Int(typed(word(misc, first + 3), Kind::I32)));
        neighbors.insert(key, Value::Object(values));
    }

    let mut budgets = Object::new();

    for (budget, key) in BUDGET_NAMES.iter().enumerate() {
        let first = BUDGETS_WORD + budget * BUDGET_WORDS;
        let month = |list: usize| -> Value {
            Value::Array(
                (0..MONTHS)
                    .map(|month| Value::Int(typed(word(misc, first + 3 + month * 2 + list), Kind::I32)))
                    .collect(),
            )
        };

        let mut values = Object::new();
        values.insert("current_costs", Value::Int(typed(word(misc, first), Kind::I32)));
        values.insert("funding_percent", Value::Int(typed(word(misc, first + 1), Kind::I32)));
        values.insert("year_to_date_cost", Value::Int(typed(word(misc, first + 2), Kind::I32)));
        values.insert("count_month", month(0));
        values.insert("fund_month", month(1));
        budgets.insert(key, Value::Object(values));
    }

    city.insert("budget", Value::Object(budgets));

    let papers = (0..PAPER_BYTES)
        .map(|index| Value::Int(typed(word(misc, PAPERS_WORD + index), Kind::U8)))
        .collect();
    city.insert("newspaper_papers_array", Value::Array(papers));

    let news = news_to_runtime(misc).into_iter().map(|byte| Value::Int(i64::from(byte))).collect();
    city.insert("newspaper_news_array", Value::Array(news));

    object(vec![
        ("city", Value::Object(city)),
        ("nation", Value::Object(nation)),
        ("options", Value::Object(options)),
        ("neighbors", Value::Object(neighbors)),
    ])
}

/// Each runtime news record has two little-endian words and four bytes.
fn news_to_runtime(misc: &[u8]) -> Vec<u8> {
    let mut bytes = vec![0_u8; NEWS_COUNT * NEWS_BYTES];

    for record in 0..NEWS_COUNT {
        let first = NEWS_WORD + record * NEWS_WORDS;
        let at = record * NEWS_BYTES;
        bytes[at..at + 2].copy_from_slice(&((word(misc, first) & 0xffff) as u16).to_le_bytes());
        bytes[at + 2..at + 4].copy_from_slice(&((word(misc, first + 1) & 0xffff) as u16).to_le_bytes());

        for index in 0..4 {
            bytes[at + 4 + index] = (word(misc, first + 2 + index) & 0xff) as u8;
        }
    }

    bytes
}

fn misc_from_json(json: &Object, preserved: &[u8]) -> Vec<u8> {
    let size = sc2misc_layout::SIZE as usize;
    let has_base = preserved.len() == size;
    let mut misc = if has_base { preserved.to_vec() } else { vec![0; size] };

    if !has_base {
        set_word(&mut misc, 0, i64::from(MISC_VERSION));
    }

    let mut triggered_disaster = word(&misc, TRIGGERED_DISASTER_WORD);
    let preserved_disaster = typed(word(&misc, DISASTER_TYPE_WORD), Kind::I16);
    let empty = Object::new();
    let section = |name: &str| json.get(name).and_then(Value::as_object).unwrap_or(&empty);

    for (index, section_name, key, kind) in FIELDS {
        if let Some(value) = section(section_name).get(key) {
            store(&mut misc, *index, value, *kind, has_base);
        }
    }

    // sc2kfix loads one disaster type into both words. A file that OpenSC2K wrote
    // keeps its triggered disaster while the current disaster is unchanged
    if !has_base || typed(word(&misc, DISASTER_TYPE_WORD), Kind::I16) != preserved_disaster {
        triggered_disaster = word(&misc, DISASTER_TYPE_WORD);
    }

    set_word(&mut misc, TRIGGERED_DISASTER_WORD, triggered_disaster);
    let city = section("city");

    for (first, key, count, kind) in ARRAYS {
        if let Some(values) = city.get(key).and_then(Value::as_array) {
            for (index, value) in values.iter().take(count).enumerate() {
                store(&mut misc, first + index, value, kind, has_base);
            }
        }
    }

    for (table, key) in RATIO_TABLES.iter().enumerate() {
        if let Some(values) = city.get(key).and_then(Value::as_array) {
            for (index, value) in values.iter().take(RATIO_VALUES).enumerate() {
                store(&mut misc, RATIO_TABLES_WORD + index * 3 + table, value, Kind::U32, has_base);
            }
        }
    }

    for (neighbor, name) in NEIGHBOR_NAMES.iter().enumerate() {
        let Some(values) = section("neighbors").get(name).and_then(Value::as_object) else {
            continue;
        };

        let first = NEIGHBORS_WORD + neighbor * 4;

        for (key_index, key) in NEIGHBOR_KEYS.iter().enumerate() {
            if let Some(value) = values.get(key) {
                let kind = if key_index == 0 { Kind::I16 } else { Kind::I32 };
                store(&mut misc, first + key_index, value, kind, has_base);
            }
        }
    }

    let budgets = city.get("budget").and_then(Value::as_object).unwrap_or(&empty);

    for (budget, name) in BUDGET_NAMES.iter().enumerate() {
        let Some(values) = budgets.get(name).and_then(Value::as_object) else {
            continue;
        };

        let first = BUDGETS_WORD + budget * BUDGET_WORDS;

        for (key_index, key) in BUDGET_KEYS.iter().enumerate() {
            if let Some(value) = values.get(key) {
                store(&mut misc, first + key_index, value, Kind::I32, has_base);
            }
        }

        for (list, key) in MONTH_KEYS.iter().enumerate() {
            if let Some(months) = values.get(key).and_then(Value::as_array) {
                for (month, value) in months.iter().take(MONTHS).enumerate() {
                    store(&mut misc, first + 3 + month * 2 + list, value, Kind::I32, has_base);
                }
            }
        }
    }

    if let Some(papers) = city.get("newspaper_papers_array").and_then(Value::as_array) {
        for (index, value) in papers.iter().take(PAPER_BYTES).enumerate() {
            store(
                &mut misc,
                PAPERS_WORD + index,
                &Value::Int(number(value) & 0xff),
                Kind::U8,
                has_base,
            );
        }
    }

    if let Some(news) = city.get("newspaper_news_array").and_then(Value::as_array)
        && news.len() >= NEWS_COUNT * NEWS_BYTES
    {
        let bytes: Vec<u8> = news
            .iter()
            .take(NEWS_COUNT * NEWS_BYTES)
            .map(|value| (number(value) & 0xff) as u8)
            .collect();

        for record in 0..NEWS_COUNT {
            let first = NEWS_WORD + record * NEWS_WORDS;
            let at = record * NEWS_BYTES;
            let low = typed(i64::from(u16::from_le_bytes([bytes[at], bytes[at + 1]])), Kind::I16);
            let high = typed(i64::from(u16::from_le_bytes([bytes[at + 2], bytes[at + 3]])), Kind::I16);
            store(&mut misc, first, &Value::Int(low), Kind::U16, has_base);
            store(&mut misc, first + 1, &Value::Int(high), Kind::U16, has_base);

            for index in 0..4 {
                store(
                    &mut misc,
                    first + 2 + index,
                    &Value::Int(i64::from(bytes[at + 4 + index])),
                    Kind::U8,
                    has_base,
                );
            }
        }
    }

    misc
}

/// Store a JSON value. A word of a file that OpenSC2K wrote keeps its other bits
/// when sc2kfix holds the same value.
fn store(misc: &mut [u8], index: usize, value: &Value, kind: Kind, has_base: bool) {
    let value = number(value);

    if has_base && typed(word(misc, index), kind) == typed(value, kind) {
        return;
    }

    set_word(misc, index, value);
}

/// The SC2 chunk of a runtime array.
fn from_runtime(id: &str, runtime: &[u8]) -> Vec<u8> {
    match id {
        "ALTM" => swapped(runtime, 2, 0, 2),
        "XGRP" => swapped(runtime, 4, 0, 4),
        "XMIC" => swapped(runtime, 2, 2, sc2microsim_layout::RECORD_SIZE as usize),
        "XLAB" => labels_to_pascal(runtime),
        _ => runtime.to_vec(),
    }
}

/// The runtime array of an SC2 chunk.
fn to_runtime(id: &str, decoded: &[u8]) -> Vec<u8> {
    match id {
        "ALTM" | "XGRP" | "XMIC" => from_runtime(id, decoded),
        "XLAB" => labels_to_c(decoded),
        _ => decoded.to_vec(),
    }
}

/// Reverse each `width`-byte value from `first` to the end of every `stride`-byte record.
fn swapped(source: &[u8], width: usize, first: usize, stride: usize) -> Vec<u8> {
    let mut bytes = source.to_vec();

    if bytes.len() < stride {
        return bytes;
    }

    for record in (0..=bytes.len() - stride).step_by(stride) {
        for offset in (record + first..record + stride).step_by(width) {
            bytes[offset..offset + width].reverse();
        }
    }

    bytes
}

fn labels_to_pascal(runtime: &[u8]) -> Vec<u8> {
    let mut bytes = vec![0_u8; runtime.len()];

    if runtime.len() < LABEL_SIZE {
        return bytes;
    }

    for record in (0..=runtime.len() - LABEL_SIZE).step_by(LABEL_SIZE) {
        let length = runtime[record..record + LABEL_TEXT - 1]
            .iter()
            .position(|byte| *byte == 0)
            .unwrap_or(LABEL_TEXT - 1);

        if length == 0 {
            continue;
        }

        bytes[record] = length as u8;
        bytes[record + 1..record + 1 + length].copy_from_slice(&runtime[record..record + length]);
    }

    bytes
}

fn labels_to_c(decoded: &[u8]) -> Vec<u8> {
    let mut bytes = vec![0_u8; decoded.len()];

    if decoded.len() < LABEL_SIZE {
        return bytes;
    }

    for record in (0..=decoded.len() - LABEL_SIZE).step_by(LABEL_SIZE) {
        let length = usize::from(decoded[record]).min(LABEL_TEXT - 1);
        bytes[record..record + length].copy_from_slice(&decoded[record + 1..record + 1 + length]);
    }

    bytes
}
