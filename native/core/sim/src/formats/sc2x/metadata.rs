//! metadata.json of an SC2X version 4 archive: the file contract, the map edge,
//! the shared names, the identity counters, and the simulation state that no
//! binary structure saves. MISC stays authoritative for the values it holds.
//! The application checks these rules itself, selected by `format` and
//! `file_version`. The published schema is a reference for tools. A file can
//! still name it with `$schema`, but it cannot relax the rules.

use sc2k_formats::json::{self, Object, Value};

pub const FORMAT: &str = "OpenSC2K.SC2X";
pub const FILE_VERSION: i64 = 4;
pub const SCHEMA_REFERENCE: &str = "metadata.schema.json";
pub const MAX_NAME_CODE_POINTS: usize = 64;
pub const MAX_NAME_BYTES: usize = 256;
pub const TEAM_COUNT: usize = 5;

const U32_MAX: f64 = 4_294_967_295.0;
const MAP_EDGE_MAX: f64 = 65535.0;
const LFSR_MAX: i64 = 0xffff;

const TOP_LEVEL_KEYS: [&str; 10] = [
    "$schema",
    "format",
    "file_version",
    "map",
    "city",
    "identity_counters",
    "simulation",
    "required_features",
    "legacy",
    "extensions",
];
const REQUIRED_KEYS: [&str; 6] = ["format", "file_version", "map", "city", "identity_counters", "simulation"];
const RNG_KEYS: [&str; 3] = ["process_random", "lfsr_random", "game_random"];

/// simulation.phase_state keys; see Sc2xCheckpoint.
const PHASE_KEYS: [&str; 20] = [
    "ship_home",
    "commerce_connections",
    "industry_connections",
    "bus_passengers",
    "rail_passengers",
    "subway_passengers",
    "mayor_approval",
    "pending_disaster_type",
    "pending_disaster_point",
    "active_disaster_type",
    "unsupported_disaster_type",
    "disaster_map_counter",
    "disaster_hurricane_counter",
    "terminal_state",
    "subtick_counter",
    "simulation_ready",
    "developed_tiles",
    "power_usage_percent",
    "water_usage_percent",
    "city_status_resource_id",
];
const PHASE_INTEGER_KEYS: [&str; 16] = [
    "commerce_connections",
    "industry_connections",
    "bus_passengers",
    "rail_passengers",
    "subway_passengers",
    "mayor_approval",
    "pending_disaster_type",
    "active_disaster_type",
    "unsupported_disaster_type",
    "disaster_map_counter",
    "disaster_hurricane_counter",
    "subtick_counter",
    "developed_tiles",
    "power_usage_percent",
    "water_usage_percent",
    "city_status_resource_id",
];

/// Optional phase_state key: milliseconds of the fire timer, 0 through 1000.
/// Files without it resume with a new timer.
pub const FIRE_TIMER_KEY: &str = "fire_elapsed_msec";
const FIRE_TIMER_MAX: i64 = 1000;

/// Optional phase_state key: true while a staged arcology launch has batches
/// left. Files without it have no launch in progress.
pub const LAUNCH_ACTIVE_KEY: &str = "arcology_launch_active";

/// Additional capabilities that this version supports. File version 4 itself needs none.
pub const SUPPORTED_FEATURES: [&str; 0] = [];

#[derive(Clone, Debug, PartialEq)]
pub struct Metadata {
    pub map_size: i64,
    pub city_name: String,
    pub mayor_name: String,
    pub stadium_teams: [String; TEAM_COUNT],
    pub next_sign_id: i64,
    pub next_object_id: i64,
    pub process_random: i64,
    pub lfsr_random: i64,
    pub game_random: i64,
    pub phase_state: Object,
    pub required_features: Vec<String>,
    pub legacy: Object,
    pub extensions: Object,
}

impl Default for Metadata {
    fn default() -> Self {
        Self {
            map_size: 128,
            city_name: String::new(),
            mayor_name: String::new(),
            stadium_teams: Default::default(),
            next_sign_id: 1,
            next_object_id: 1,
            process_random: 1,
            lfsr_random: 1,
            game_random: 1,
            phase_state: Object::new(),
            required_features: Vec::new(),
            legacy: Object::new(),
            extensions: Object::new(),
        }
    }
}

impl Metadata {
    /// The features that a document requires but this version does not support.
    /// Such a document can be inspected but not edited or simulated.
    pub fn unsupported_features(&self) -> Vec<String> {
        self.required_features
            .iter()
            .filter(|feature| !SUPPORTED_FEATURES.contains(&feature.as_str()))
            .cloned()
            .collect()
    }

    pub fn to_value(&self) -> Value {
        let mut root = Object::new();
        root.insert("format", Value::String(FORMAT.into()));
        root.insert("file_version", Value::Int(FILE_VERSION));
        root.insert("map", object(&[("size", Value::Int(self.map_size))]));

        let teams = self.stadium_teams.iter().map(|team| Value::String(team.clone())).collect();
        root.insert(
            "city",
            object(&[
                ("name", Value::String(self.city_name.clone())),
                ("mayor_name", Value::String(self.mayor_name.clone())),
                ("stadium_teams", Value::Array(teams)),
            ]),
        );

        root.insert(
            "identity_counters",
            object(&[
                ("next_sign_id", Value::Int(self.next_sign_id)),
                ("next_object_id", Value::Int(self.next_object_id)),
            ]),
        );

        let states = object(&[
            ("process_random", Value::Int(self.process_random)),
            ("lfsr_random", Value::Int(self.lfsr_random)),
            ("game_random", Value::Int(self.game_random)),
        ]);
        root.insert(
            "simulation",
            object(&[
                ("rng_states", states),
                ("phase_state", Value::Object(self.phase_state.clone()).integral()),
            ]),
        );

        if !self.required_features.is_empty() {
            let features = self
                .required_features
                .iter()
                .map(|feature| Value::String(feature.clone()))
                .collect();
            root.insert("required_features", Value::Array(features));
        }

        if !self.legacy.is_empty() {
            root.insert("legacy", Value::Object(self.legacy.clone()).integral());
        }

        if !self.extensions.is_empty() {
            root.insert("extensions", Value::Object(self.extensions.clone()).integral());
        }

        Value::Object(root)
    }

    /// UTF-8 JSON with a fixed key order and tab indentation.
    pub fn to_json(&self) -> String {
        json::stringify(&self.to_value(), "\t", false) + "\n"
    }

    pub fn to_bytes(&self) -> Vec<u8> {
        self.to_json().into_bytes()
    }

    pub fn parse_bytes(bytes: &[u8]) -> Result<Self, String> {
        // a byte order mark or a NUL does not survive the text round trip of the game
        let text = std::str::from_utf8(bytes)
            .ok()
            .filter(|text| !text.starts_with('\u{feff}') && !text.contains('\0'))
            .ok_or("metadata.json is not valid UTF-8 text")?;

        Self::parse(text)
    }

    pub fn parse(text: &str) -> Result<Self, String> {
        let value =
            json::parse(text).map_err(|error| format!("metadata.json is not valid JSON: {} at line {}", error.message, error.line))?;

        Self::from_value(&value)
    }

    pub fn from_value(data: &Value) -> Result<Self, String> {
        let root = data.as_object().ok_or("metadata.json is not a JSON object")?;

        if let Some(key) = root.keys().find(|key| !TOP_LEVEL_KEYS.contains(key)) {
            return Err(format!("metadata.json has unknown field {key}"));
        }

        if let Some(key) = REQUIRED_KEYS.iter().find(|key| !root.contains(key)) {
            return Err(format!("metadata.json has no {key}"));
        }

        if root.get("$schema").is_some_and(|schema| schema.as_str() != Some(SCHEMA_REFERENCE)) {
            return Err(format!("metadata.json $schema must be {SCHEMA_REFERENCE}"));
        }

        if root.get("format").and_then(Value::as_str) != Some(FORMAT) {
            return Err(format!("metadata.json format is not {FORMAT}"));
        }

        let version = &root.get("file_version").expect("required");

        if !is_integer(version, 0.0, U32_MAX) {
            return Err("metadata.json file_version is not an integer".into());
        }

        if version.to_int() != FILE_VERSION {
            return Err(format!(
                "This version reads SC2X file version {FILE_VERSION}; the file uses version {}",
                version.to_int()
            ));
        }

        let mut metadata = Metadata::default();

        let map = member_object(root, "map", &["size"], &["size"])
            .filter(|map| is_integer(map.get("size").expect("required"), 1.0, MAP_EDGE_MAX))
            .ok_or("metadata.json map.size must be an integer from 1 through 65535")?;

        metadata.map_size = map.get("size").expect("required").to_int();

        let city_keys = ["name", "mayor_name", "stadium_teams"];
        let city = member_object(root, "city", &city_keys, &city_keys)
            .ok_or("metadata.json city must have name, mayor_name, and stadium_teams")?;

        for key in ["name", "mayor_name"] {
            if let Err(error) = name_error(city.get(key).expect("required")) {
                return Err(format!("metadata.json city.{key}: {error}"));
            }
        }

        metadata.city_name = city.get("name").and_then(Value::as_str).unwrap_or_default().to_string();
        metadata.mayor_name = city.get("mayor_name").and_then(Value::as_str).unwrap_or_default().to_string();

        if metadata.city_name.is_empty() {
            return Err("metadata.json city.name is empty".into());
        }

        let teams = city
            .get("stadium_teams")
            .and_then(Value::as_array)
            .filter(|teams| teams.len() == TEAM_COUNT)
            .ok_or("metadata.json city.stadium_teams must list five names")?;

        for (index, team) in teams.iter().enumerate() {
            if let Err(error) = name_error(team) {
                return Err(format!("metadata.json stadium team {}: {error}", index + 1));
            }

            metadata.stadium_teams[index] = team.as_str().unwrap_or_default().to_string();
        }

        let counter_keys = ["next_sign_id", "next_object_id"];
        let counters = member_object(root, "identity_counters", &counter_keys, &counter_keys)
            .filter(|counters| {
                counter_keys
                    .iter()
                    .all(|key| is_integer(counters.get(key).expect("required"), 1.0, U32_MAX))
            })
            .ok_or("metadata.json identity counters must be integers from 1 through 4294967295")?;

        metadata.next_sign_id = counters.get("next_sign_id").expect("required").to_int();
        metadata.next_object_id = counters.get("next_object_id").expect("required").to_int();

        let simulation_keys = ["rng_states", "phase_state"];
        let simulation = member_object(root, "simulation", &simulation_keys, &simulation_keys)
            .ok_or("metadata.json simulation must have rng_states and phase_state")?;

        let states = simulation
            .get("rng_states")
            .and_then(|states| object_with(states, &RNG_KEYS, &RNG_KEYS))
            .ok_or("metadata.json simulation.rng_states must have process_random, lfsr_random, and game_random")?;

        for key in RNG_KEYS {
            if !is_integer(states.get(key).expect("required"), 0.0, U32_MAX) {
                return Err(format!("metadata.json random state {key} is not a 32-bit unsigned integer"));
            }
        }

        // the LFSR has 16 bits, and zero never changes
        let lfsr = states.get("lfsr_random").expect("required").to_int();

        if !(1..=LFSR_MAX).contains(&lfsr) {
            return Err("metadata.json lfsr_random must be from 1 through 65535".into());
        }

        metadata.process_random = states.get("process_random").expect("required").to_int();
        metadata.lfsr_random = lfsr;
        metadata.game_random = states.get("game_random").expect("required").to_int();

        let Some(Value::Object(phase_state)) = simulation.get("phase_state").map(Value::integral) else {
            return Err("metadata.json simulation.phase_state is not an object".into());
        };

        metadata.phase_state = phase_state;

        if let Some(features) = root.get("required_features") {
            let features = features.as_array().ok_or("metadata.json required_features is not an array")?;

            for feature in features {
                match feature.as_str() {
                    Some(name) if !name.is_empty() && !metadata.required_features.iter().any(|known| known == name) => {
                        metadata.required_features.push(name.to_string());
                    }
                    _ => return Err("metadata.json required_features must hold unique nonempty strings".into()),
                }
            }
        }

        for key in ["legacy", "extensions"] {
            if root.get(key).is_some_and(|value| value.as_object().is_none()) {
                return Err(format!("metadata.json {key} is not an object"));
            }
        }

        metadata.legacy = integral_object(root.get("legacy"));
        metadata.extensions = integral_object(root.get("extensions"));

        Ok(metadata)
    }
}

/// Whether `value` is a valid shared or record name: a string of at most 64
/// code points and 256 UTF-8 bytes, with no NUL.
pub fn name_error(value: &Value) -> Result<(), String> {
    let text = value.as_str().ok_or("the name is not a string")?;
    let length = text.chars().count();

    if length > MAX_NAME_CODE_POINTS {
        return Err(format!("the name has {length} characters; the limit is {MAX_NAME_CODE_POINTS}"));
    }

    if text.len() > MAX_NAME_BYTES {
        return Err(format!("the name has more than {MAX_NAME_BYTES} UTF-8 bytes"));
    }

    if text.contains('\0') {
        return Err("the name contains a NUL character".into());
    }

    Ok(())
}

/// The first 64 code points of `text` without NUL characters, within 256 UTF-8 bytes.
pub fn limit_name(text: &str) -> String {
    let mut result: String = text
        .chars()
        .filter(|character| *character != '\0')
        .take(MAX_NAME_CODE_POINTS)
        .collect();

    while result.len() > MAX_NAME_BYTES {
        result.pop();
    }

    result
}

/// Empty phase state is valid: a converted city starts with the load defaults.
/// Otherwise every key must be present with its type.
pub fn phase_state_error(state: &Object) -> Result<(), String> {
    if state.is_empty() {
        return Ok(());
    }

    if let Some(key) = PHASE_KEYS.iter().find(|key| !state.contains(key)) {
        return Err(format!("metadata.json phase_state has no {key}"));
    }

    for key in PHASE_INTEGER_KEYS {
        if !state.get(key).expect("checked").is_integral() {
            return Err(format!("metadata.json phase_state.{key} is not an integer"));
        }
    }

    for key in ["terminal_state", "simulation_ready"] {
        if state.get(key).and_then(Value::as_bool).is_none() {
            return Err(format!("metadata.json phase_state.{key} is not true or false"));
        }
    }

    for key in ["ship_home", "pending_disaster_point"] {
        let pair = state
            .get(key)
            .and_then(Value::as_array)
            .is_some_and(|pair| pair.len() == 2 && pair.iter().all(Value::is_integral));

        if !pair {
            return Err(format!("metadata.json phase_state.{key} is not a pair of integers"));
        }
    }

    if let Some(timer) = state.get(FIRE_TIMER_KEY)
        && (!timer.is_integral() || !(0..=FIRE_TIMER_MAX).contains(&timer.to_int()))
    {
        return Err(format!(
            "metadata.json phase_state.{FIRE_TIMER_KEY} is not 0 through {FIRE_TIMER_MAX}"
        ));
    }

    if state.get(LAUNCH_ACTIVE_KEY).is_some_and(|value| value.as_bool().is_none()) {
        return Err(format!("metadata.json phase_state.{LAUNCH_ACTIVE_KEY} is not true or false"));
    }

    Ok(())
}

fn object(entries: &[(&str, Value)]) -> Value {
    let mut result = Object::new();

    for (key, value) in entries {
        result.insert(key, value.clone());
    }

    Value::Object(result)
}

fn integral_object(value: Option<&Value>) -> Object {
    match value.map(Value::integral) {
        Some(Value::Object(object)) => object,
        _ => Object::new(),
    }
}

/// The object of `value` when it has only `allowed` keys and every `required` key.
fn object_with<'a>(value: &'a Value, allowed: &[&str], required: &[&str]) -> Option<&'a Object> {
    let object = value.as_object()?;

    if object.keys().any(|key| !allowed.contains(&key)) || required.iter().any(|key| !object.contains(key)) {
        return None;
    }

    Some(object)
}

fn member_object<'a>(root: &'a Object, key: &str, allowed: &[&str], required: &[&str]) -> Option<&'a Object> {
    object_with(root.get(key)?, allowed, required)
}

fn is_integer(value: &Value, minimum: f64, maximum: f64) -> bool {
    value.as_whole().is_some_and(|number| number >= minimum && number <= maximum)
}

#[cfg(test)]
mod tests {
    use super::*;

    fn minimal() -> String {
        r#"{"format": "OpenSC2K.SC2X", "file_version": 4, "map": {"size": 256},
            "city": {"name": "Town", "mayor_name": "", "stadium_teams": ["", "", "", "", ""]},
            "identity_counters": {"next_sign_id": 1, "next_object_id": 3},
            "simulation": {"rng_states": {"process_random": 5, "lfsr_random": 7, "game_random": 9}, "phase_state": {}}}"#
            .into()
    }

    #[test]
    fn a_minimal_file_round_trips() {
        let metadata = Metadata::parse(&minimal()).unwrap();
        assert_eq!(metadata.map_size, 256);
        assert_eq!(metadata.city_name, "Town");
        assert_eq!(metadata.next_object_id, 3);
        assert_eq!((metadata.process_random, metadata.lfsr_random, metadata.game_random), (5, 7, 9));

        let written = metadata.to_json();
        assert!(written.starts_with("{\n\t\"format\": \"OpenSC2K.SC2X\",\n\t\"file_version\": 4,\n"));
        assert!(written.ends_with("}\n"));
        assert_eq!(Metadata::parse(&written).unwrap(), metadata);
    }

    #[test]
    fn rule_violations_name_the_field() {
        let cases = [
            (
                r#""format": "OpenSC2K.SC2X""#,
                r#""format": "Other""#,
                "metadata.json format is not OpenSC2K.SC2X",
            ),
            (
                r#""file_version": 4"#,
                r#""file_version": 5"#,
                "This version reads SC2X file version 4; the file uses version 5",
            ),
            (
                r#""file_version": 4"#,
                r#""file_version": 4.5"#,
                "metadata.json file_version is not an integer",
            ),
            (
                r#""size": 256"#,
                r#""size": 0"#,
                "metadata.json map.size must be an integer from 1 through 65535",
            ),
            (r#""name": "Town""#, r#""name": """#, "metadata.json city.name is empty"),
            (
                r#""name": "Town""#,
                r#""name": 3"#,
                "metadata.json city.name: the name is not a string",
            ),
            (
                r#""lfsr_random": 7"#,
                r#""lfsr_random": 0"#,
                "metadata.json lfsr_random must be from 1 through 65535",
            ),
            (
                r#""next_sign_id": 1"#,
                r#""next_sign_id": 0"#,
                "metadata.json identity counters must be integers from 1 through 4294967295",
            ),
            (
                r#""phase_state": {}"#,
                r#""phase_state": []"#,
                "metadata.json simulation.phase_state is not an object",
            ),
            (r#""format""#, r#""extra": 1, "format""#, "metadata.json has unknown field extra"),
        ];

        for (from, to, message) in cases {
            let text = minimal().replacen(from, to, 1);
            assert_eq!(Metadata::parse(&text), Err(message.to_string()), "{to}");
        }

        assert_eq!(Metadata::parse_bytes(&[0xff]), Err("metadata.json is not valid UTF-8 text".into()));
        assert!(Metadata::parse("{").unwrap_err().starts_with("metadata.json is not valid JSON: "));
    }

    #[test]
    fn names_are_limited_to_64_code_points_and_256_bytes() {
        assert_eq!(limit_name("a\0b"), "ab");
        assert_eq!(limit_name(&"x".repeat(70)).len(), 64);
        assert_eq!(limit_name(&"😀".repeat(64)).len(), 256);
        assert!(name_error(&Value::String("😀".repeat(65))).is_err());
        assert!(name_error(&Value::String("ok".into())).is_ok());
    }

    #[test]
    fn phase_state_needs_every_key_once_it_has_one() {
        let mut state = Object::new();
        assert!(phase_state_error(&state).is_ok());

        state.insert("ship_home", Value::Array(vec![Value::Int(1), Value::Int(2)]));
        assert_eq!(
            phase_state_error(&state),
            Err("metadata.json phase_state has no commerce_connections".into())
        );
    }
}
