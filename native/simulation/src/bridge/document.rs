//! `NativeCityDocument`: the city document codecs for `Sc2File`,
//! `Sc2xDocument`, `Sc2xMetadata` and `Sc2kfixArchive`.
//!
//! GDScript keeps the chunks of a document as `Sc2Chunk` objects. A call
//! receives the document as a dictionary and returns the document, or the
//! parts of it that the call changed, in the same form:
//!
//! `{map_size, large_version, source_format, repaired_form_length, source_bytes,
//! chunks: [{chunk_id, source_offset, stored, decoded, expected_size, compressed, dirty}],
//! sc2x}`. `sc2x` is empty for an original city; see `sc2x_value`.

use godot::prelude::*;

use super::convert;
use super::json_value;
use sc2k_formats::json::Object as JsonObject;
use sc2k_sim::formats::document::{Chunk, Document, Preserved, Sc2xState};
use sc2k_sim::formats::sc2x::document as sc2x_document;
use sc2k_sim::formats::sc2x::document::Entries;
use sc2k_sim::formats::sc2x::metadata::{self, Metadata, TEAM_COUNT};
use sc2k_sim::formats::{sc2, sc2kfix, store};

#[derive(GodotClass)]
#[class(no_init, base = Object)]
pub struct NativeCityDocument {}

fn failure(error: &str) -> VarDictionary {
    let mut result = VarDictionary::new();
    result.set("ok", false);
    result.set("error", error);
    result
}

fn success() -> VarDictionary {
    let mut result = VarDictionary::new();
    result.set("ok", true);
    result.set("error", "");
    result
}

fn strings(values: &[String]) -> PackedStringArray {
    values.iter().map(GString::from).collect()
}

fn packed(bytes: &[u8]) -> PackedByteArray {
    PackedByteArray::from(bytes)
}

fn object_of(dictionary: &VarDictionary, key: &str) -> JsonObject {
    json_value::object_from(&convert::dictionary(dictionary, key))
}

pub fn metadata_value(metadata: &Metadata) -> VarDictionary {
    let mut result = VarDictionary::new();
    result.set("map_size", metadata.map_size);
    result.set("city_name", metadata.city_name.as_str());
    result.set("mayor_name", metadata.mayor_name.as_str());
    result.set("stadium_teams", &strings(&metadata.stadium_teams));
    result.set("next_sign_id", metadata.next_sign_id);
    result.set("next_object_id", metadata.next_object_id);
    result.set("process_random", metadata.process_random);
    result.set("lfsr_random", metadata.lfsr_random);
    result.set("game_random", metadata.game_random);
    result.set("phase_state", &json_value::dictionary_from(&metadata.phase_state));
    result.set("required_features", &strings(&metadata.required_features));
    result.set("legacy", &json_value::dictionary_from(&metadata.legacy));
    result.set("extensions", &json_value::dictionary_from(&metadata.extensions));
    result
}

pub fn metadata_from(fields: &VarDictionary) -> Metadata {
    let mut teams: [String; TEAM_COUNT] = Default::default();

    for (index, team) in convert::strings(fields, "stadium_teams").into_iter().take(TEAM_COUNT).enumerate() {
        teams[index] = team;
    }

    Metadata {
        map_size: convert::int(fields, "map_size", 128),
        city_name: convert::string(fields, "city_name"),
        mayor_name: convert::string(fields, "mayor_name"),
        stadium_teams: teams,
        next_sign_id: convert::int(fields, "next_sign_id", 1),
        next_object_id: convert::int(fields, "next_object_id", 1),
        process_random: convert::int(fields, "process_random", 1),
        lfsr_random: convert::int(fields, "lfsr_random", 1),
        game_random: convert::int(fields, "game_random", 1),
        phase_state: object_of(fields, "phase_state"),
        required_features: convert::strings(fields, "required_features"),
        legacy: object_of(fields, "legacy"),
        extensions: object_of(fields, "extensions"),
    }
}

fn preserved_value(record: &Preserved) -> VarDictionary {
    let mut result = VarDictionary::new();
    result.set("chunk_id", record.chunk_id.as_str());
    result.set("occurrence", i64::from(record.occurrence));
    result.set("source_order", i64::from(record.source_order));
    result.set("flags", i64::from(record.flags));
    result.set("payload", &packed(&record.payload));
    result.set("entry", record.entry.as_str());
    result
}

fn preserved_from(fields: &VarDictionary) -> Preserved {
    let u32_of = |key: &str| u32::try_from(convert::int(fields, key, 0)).unwrap_or(0);

    Preserved {
        chunk_id: convert::string(fields, "chunk_id"),
        occurrence: u32_of("occurrence"),
        source_order: u32_of("source_order"),
        flags: u32_of("flags"),
        payload: convert::bytes(fields, "payload"),
        entry: convert::string(fields, "entry"),
    }
}

/// `{metadata, compat_labels, object_ids, object_kinds, object_names,
/// xmic_extension, xthg_extension, text_orders, preserved, extra_names,
/// extra_payloads, unsupported_features, converted_from}`.
pub fn sc2x_value(state: &Sc2xState) -> VarDictionary {
    let mut result = VarDictionary::new();
    result.set("metadata", &metadata_value(&state.metadata));
    result.set("compat_labels", &packed(&state.compat_labels));
    result.set("object_ids", &PackedInt64Array::from(state.object_ids.as_slice()));
    result.set("object_kinds", &packed(&state.object_kinds));
    result.set("object_names", &strings(&state.object_names));
    result.set("xmic_extension", &packed(&state.xmic_extension));
    result.set("xthg_extension", &packed(&state.xthg_extension));
    result.set("text_orders", &PackedInt64Array::from(state.text_orders.as_slice()));

    let mut preserved = VarArray::new();

    for record in &state.preserved {
        preserved.push(&preserved_value(record).to_variant());
    }

    result.set("preserved", &preserved);

    let names: Vec<String> = state.extra_entries.iter().map(|(name, _)| name.clone()).collect();
    let mut payloads = VarArray::new();

    for (_, data) in &state.extra_entries {
        payloads.push(&packed(data).to_variant());
    }

    result.set("extra_names", &strings(&names));
    result.set("extra_payloads", &payloads);
    result.set("unsupported_features", &strings(&state.unsupported_features));
    result.set("converted_from", state.converted_from.as_str());
    result
}

fn sc2x_from(fields: &VarDictionary) -> Sc2xState {
    let preserved = convert::array(fields, "preserved")
        .iter_shared()
        .filter_map(|item| item.try_to::<VarDictionary>().ok())
        .map(|record| preserved_from(&record))
        .collect();

    let names = convert::strings(fields, "extra_names");
    let payloads: Vec<Vec<u8>> = convert::array(fields, "extra_payloads")
        .iter_shared()
        .map(|item| item.try_to::<PackedByteArray>().map(|data| data.to_vec()).unwrap_or_default())
        .collect();

    Sc2xState {
        metadata: metadata_from(&convert::dictionary(fields, "metadata")),
        compat_labels: convert::bytes(fields, "compat_labels"),
        object_ids: convert::ints64(fields, "object_ids"),
        object_kinds: convert::bytes(fields, "object_kinds"),
        object_names: convert::strings(fields, "object_names"),
        xmic_extension: convert::bytes(fields, "xmic_extension"),
        xthg_extension: convert::bytes(fields, "xthg_extension"),
        text_orders: convert::ints64(fields, "text_orders"),
        preserved,
        extra_entries: names.into_iter().zip(payloads).collect(),
        unsupported_features: convert::strings(fields, "unsupported_features"),
        converted_from: convert::string(fields, "converted_from"),
    }
}

fn chunk_value(chunk: &Chunk) -> VarDictionary {
    let mut result = VarDictionary::new();
    result.set("chunk_id", chunk.id.as_str());
    result.set("source_offset", chunk.source_offset as i64);
    result.set("stored", &packed(&chunk.stored));
    result.set("decoded", &packed(&chunk.decoded));
    result.set("expected_size", chunk.expected_size);
    result.set("compressed", chunk.compressed);
    result.set("dirty", chunk.dirty);
    result
}

fn chunk_from(fields: &VarDictionary) -> Chunk {
    Chunk {
        id: convert::string(fields, "chunk_id"),
        source_offset: usize::try_from(convert::int(fields, "source_offset", 0)).unwrap_or(0),
        stored: convert::bytes(fields, "stored"),
        decoded: convert::bytes(fields, "decoded"),
        expected_size: convert::int(fields, "expected_size", -1),
        compressed: convert::boolean(fields, "compressed", false),
        dirty: convert::boolean(fields, "dirty", false),
    }
}

pub fn document_value(document: &Document) -> VarDictionary {
    let mut result = VarDictionary::new();
    result.set("map_size", document.map_size);
    result.set("large_version", document.large_version);
    result.set("source_format", document.source_format.as_str());
    result.set("repaired_form_length", document.repaired_form_length);
    result.set("source_bytes", &packed(&document.source_bytes));

    let mut chunks = VarArray::new();

    for chunk in &document.chunks {
        chunks.push(&chunk_value(chunk).to_variant());
    }

    result.set("chunks", &chunks);
    result.set("sc2x", &document.sc2x.as_ref().map(sc2x_value).unwrap_or_default());
    result
}

pub fn document_from(fields: &VarDictionary) -> Document {
    let chunks = convert::array(fields, "chunks")
        .iter_shared()
        .filter_map(|item| item.try_to::<VarDictionary>().ok())
        .map(|chunk| chunk_from(&chunk))
        .collect();

    let sc2x = convert::dictionary(fields, "sc2x");

    Document {
        map_size: convert::int(fields, "map_size", sc2::ORIGINAL_EDGE),
        large_version: convert::int(fields, "large_version", sc2::ORIGINAL_LARGE_VERSION),
        chunks,
        source_bytes: convert::bytes(fields, "source_bytes"),
        repaired_form_length: convert::boolean(fields, "repaired_form_length", false),
        source_format: convert::string(fields, "source_format"),
        sc2x: if sc2x.is_empty() { None } else { Some(sc2x_from(&sc2x)) },
    }
}

/// New City terrain options from `{ocean, river, hills, water, trees, layout, features, smooth_slopes}`.
pub fn terrain_options(fields: &VarDictionary) -> sc2k_sim::sim::new_city::Options {
    sc2k_sim::sim::new_city::Options {
        ocean: convert::boolean(fields, "ocean", false),
        river: convert::boolean(fields, "river", false),
        hills: convert::int(fields, "hills", 0),
        water: convert::int(fields, "water", 0),
        trees: convert::int(fields, "trees", 0),
        layout: convert::string(fields, "layout"),
        features: convert::strings(fields, "features"),
        smooth_slopes: convert::boolean(fields, "smooth_slopes", false),
    }
}

/// The settings and counts of generated terrain.
pub fn generated_value(generated: &sc2k_sim::sim::new_city::Generated) -> VarDictionary {
    let summary = &generated.summary;
    let mut result = VarDictionary::new();
    result.set("has_ocean", generated.has_ocean);
    result.set("has_river", generated.has_river);
    result.set("water_level", generated.water_level);
    result.set("water_tiles", summary.water_tiles);
    result.set("salt_water_tiles", summary.salt_water_tiles);
    result.set("tree_tiles", summary.tree_tiles);
    result.set("minimum_altitude", summary.minimum_altitude);
    result.set("maximum_altitude", summary.maximum_altitude);
    result
}

/// The SC2X state after a call that may change it, or an empty dictionary.
fn sc2x_of(document: &Document) -> VarDictionary {
    document.sc2x.as_ref().map(sc2x_value).unwrap_or_default()
}

/// The entries `{order, members}` of a prepared save.
fn entries_from(order: &PackedStringArray, members: &VarDictionary) -> Entries {
    let members = order
        .as_slice()
        .iter()
        .map(|name| {
            let data = members
                .get(&name.to_variant())
                .and_then(|value| value.try_to::<PackedByteArray>().ok())
                .map(|data| data.to_vec())
                .unwrap_or_default();

            (name.to_string(), data)
        })
        .collect();

    Entries {
        members,
        issues: Vec::new(),
    }
}

fn written(result: Result<(), String>) -> VarDictionary {
    match result {
        Ok(()) => success(),
        Err(error) => failure(&error),
    }
}

fn converted(result: Result<(Document, Vec<String>), String>) -> VarDictionary {
    match result {
        Ok((document, issues)) => {
            let mut value = success();
            value.set("document", &document_value(&document));
            value.set("issues", &strings(&issues));
            value
        }
        Err(error) => failure(&error),
    }
}

#[godot_api]
impl NativeCityDocument {
    /// `{ok, error, document}` from the bytes of an SC2, SCN, SCLG, sc2kfix or SC2X file.
    #[func]
    fn parse(bytes: PackedByteArray) -> VarDictionary {
        match Document::parse(bytes.as_slice()) {
            Ok(document) => {
                let mut result = success();
                result.set("document", &document_value(&document));
                result
            }
            Err(error) => failure(&error),
        }
    }

    /// `{ok, error, bytes, sc2x}`: the file bytes. A working document also
    /// returns its state with the new identity counters.
    #[func]
    fn serialize(document: VarDictionary, force_rebuild: bool) -> VarDictionary {
        let mut native = document_from(&document);

        match native.serialize(force_rebuild) {
            Ok(saved) => {
                let mut result = success();
                result.set("bytes", &packed(&saved.bytes));
                result.set("sc2x", &sc2x_of(&native));
                result
            }
            Err(error) => failure(&error),
        }
    }

    /// `{snapshot, sc2x}`: equal snapshots mean that a save would write the same city.
    #[func]
    fn content_snapshot(document: VarDictionary) -> VarDictionary {
        let mut native = document_from(&document);
        let mut result = VarDictionary::new();
        result.set("snapshot", &packed(&native.content_snapshot()));
        result.set("sc2x", &sc2x_of(&native));
        result
    }

    /// `{ok, error, order, members, issues, sc2x}`: the raw entries of a working document.
    #[func]
    fn sc2x_entries(document: VarDictionary) -> VarDictionary {
        let mut native = document_from(&document);

        match sc2x_document::entries(&mut native) {
            Ok(entries) => {
                let mut order = PackedStringArray::new();
                let mut members = VarDictionary::new();

                for (name, data) in &entries.members {
                    order.push(name.as_str());
                    members.set(name.as_str(), &packed(data));
                }

                let mut result = success();
                result.set("order", &order);
                result.set("members", &members);
                result.set("issues", &strings(&entries.issues));
                result.set("digest", &packed(&sc2x_document::digest_entries(&entries)));
                result.set("sc2x", &sc2x_of(&native));
                result
            }
            Err(error) => failure(&error),
        }
    }

    /// `{ok, error, document, issues}`: a working document from an original document.
    #[func]
    fn from_legacy(document: VarDictionary, fallback_name: GString, fresh: bool) -> VarDictionary {
        let source = document_from(&document);

        converted(sc2x_document::from_legacy(&source, &fallback_name.to_string(), fresh))
    }

    /// `{ok, error, document, issues}`: a working document from a city that the
    /// new-city tools made in the legacy layout.
    #[func]
    fn from_new_city(document: VarDictionary, city_name: GString, mayor_name: GString) -> VarDictionary {
        let source = document_from(&document);

        converted(sc2x_document::from_new_city(
            &source,
            &city_name.to_string(),
            &mayor_name.to_string(),
        ))
    }

    /// `{ok, error, bytes}`: an sc2kfix archive of an original city.
    #[func]
    fn encode_sc2kfix(document: VarDictionary, timestamp: i64) -> VarDictionary {
        match sc2kfix::encode(&document_from(&document), timestamp) {
            Ok(bytes) => {
                let mut result = success();
                result.set("bytes", &packed(&bytes));
                result
            }
            Err(error) => failure(&error),
        }
    }

    /// `{ok, document}`: the document with a new map edge, for an empty map.
    #[func]
    fn resize_empty_map(document: VarDictionary, edge: i64) -> VarDictionary {
        let mut native = document_from(&document);
        let mut result = VarDictionary::new();
        result.set("ok", native.resize_empty_map(edge));
        result.set("document", &document_value(&native));
        result
    }

    /// `{ok, document}`: the document with one data map value per tile.
    #[func]
    fn enable_full_resolution_maps(document: VarDictionary) -> VarDictionary {
        let mut native = document_from(&document);
        let mut result = VarDictionary::new();
        result.set("ok", native.enable_full_resolution_maps());
        result.set("document", &document_value(&native));
        result
    }

    /// The document with the record tables of SCLG version 2.
    #[func]
    fn upgrade_large_limits(document: VarDictionary) -> VarDictionary {
        let mut native = document_from(&document);
        native.upgrade_large_limits();

        document_value(&native)
    }

    /// `{ok, error}`: write `bytes` to `path` through a checked temporary file.
    /// `expected` is empty, or `{order, members}`: the entries that an SC2X file
    /// must load again with.
    #[func]
    fn write_verified(path: GString, bytes: PackedByteArray, expected: VarDictionary) -> VarDictionary {
        let path = std::path::PathBuf::from(path.to_string());

        if expected.is_empty() {
            return written(store::write_verified(&path, bytes.as_slice(), None));
        }

        let order = expected
            .get("order")
            .and_then(|value| value.try_to::<PackedStringArray>().ok())
            .unwrap_or_default();
        let entries = entries_from(&order, &convert::dictionary(&expected, "members"));

        written(store::write_verified(&path, bytes.as_slice(), Some(&entries)))
    }

    /// `{ok, error, bytes}`: compress the entries of a working document and
    /// write them to `path` through a checked temporary file.
    #[func]
    fn write_entries(path: GString, order: PackedStringArray, members: VarDictionary) -> VarDictionary {
        let entries = entries_from(&order, &members);

        match store::write_entries(&std::path::PathBuf::from(path.to_string()), &entries) {
            Ok(bytes) => {
                let mut result = success();
                result.set("bytes", &packed(&bytes));
                result
            }
            Err(error) => failure(&error),
        }
    }

    /// `{ok, error, document, city_name, mayor_name, invention_years, terrain,
    /// random_state, game_state}`: found a new city from `template`. `settings`
    /// has `city_name`, `mayor_name`, `difficulty`, `starting_year`,
    /// `newspaper_session`, `island`, and optional `terrain` options. A negative
    /// `game_state` means no game generator.
    #[func]
    fn found_city(template: VarDictionary, settings: VarDictionary, random_state: i64, game_state: i64) -> VarDictionary {
        use sc2k_sim::sim::new_city::setup::{self, Founding};
        use sc2k_sim::sim::random::{GameLcgRandom, SimRandom};

        let terrain = convert::dictionary(&settings, "terrain");
        let founding = Founding {
            city_name: convert::string(&settings, "city_name"),
            mayor_name: convert::string(&settings, "mayor_name"),
            difficulty: convert::int(&settings, "difficulty", 0),
            starting_year: convert::int(&settings, "starting_year", 0),
            terrain: (!terrain.is_empty()).then(|| terrain_options(&terrain)),
            newspaper_session: convert::bytes(&settings, "newspaper_session"),
            island: convert::boolean(&settings, "island", false),
        };

        let mut random = SimRandom::new(random_state);
        let mut game = (game_state >= 0).then(|| GameLcgRandom::new(game_state));

        match setup::create(&document_from(&template), &founding, &mut random, game.as_mut()) {
            Ok(founded) => {
                let mut result = success();
                result.set("document", &document_value(&founded.document));
                result.set("city_name", founded.city_name.as_str());
                result.set("mayor_name", founded.mayor_name.as_str());
                result.set(
                    "invention_years",
                    &PackedInt32Array::from(
                        founded
                            .invention_years
                            .iter()
                            .map(|year| *year as i32)
                            .collect::<Vec<_>>()
                            .as_slice(),
                    ),
                );
                result.set("terrain", &founded.terrain.as_ref().map(generated_value).unwrap_or_default());
                result.set("random_state", random.state);
                result.set("game_state", game.map_or(-1, |game| game.state));
                result
            }
            Err(error) => failure(&error),
        }
    }

    /// An empty original city of `edge` tiles with the starting values of New City.
    #[func]
    fn empty_city(edge: i64) -> VarDictionary {
        document_value(&sc2k_sim::sim::new_city::template::empty_city(edge))
    }

    /// `{misc, state}`: MISC with four new neighbor cities, and the process
    /// random state after the draws.
    #[func]
    fn draw_neighbors(misc: PackedByteArray, state: i64) -> VarDictionary {
        let mut document = Document::default();
        document
            .chunks
            .push(sc2k_sim::formats::document::Chunk::new("MISC", misc.to_vec(), -1));
        let mut random = sc2k_sim::sim::random::SimRandom::new(state);
        sc2k_sim::sim::new_city::template::draw_neighbors(&mut document, &mut random);

        let mut result = VarDictionary::new();
        result.set("misc", &packed(document.payload("MISC")));
        result.set("state", random.state);
        result
    }

    /// `{ok, error, metadata}` from the bytes of metadata.json.
    #[func]
    fn parse_metadata(bytes: PackedByteArray) -> VarDictionary {
        match Metadata::parse_bytes(bytes.as_slice()) {
            Ok(value) => {
                let mut result = success();
                result.set("metadata", &metadata_value(&value));
                result
            }
            Err(error) => failure(&error),
        }
    }

    /// `{ok, error, metadata}` from a JSON value, as `Sc2xMetadata.from_dictionary`.
    #[func]
    fn metadata_from_value(data: Variant) -> VarDictionary {
        match Metadata::from_value(&json_value::from_variant(&data)) {
            Ok(value) => {
                let mut result = success();
                result.set("metadata", &metadata_value(&value));
                result
            }
            Err(error) => failure(&error),
        }
    }

    /// The JSON text of metadata.json with a final line feed.
    #[func]
    fn metadata_json(fields: VarDictionary) -> GString {
        GString::from(metadata_from(&fields).to_json().as_str())
    }

    /// The dictionary that metadata.json holds.
    #[func]
    fn metadata_dictionary(fields: VarDictionary) -> Variant {
        json_value::to_variant(&metadata_from(&fields).to_value())
    }

    /// The error of a shared or record name, or an empty string.
    #[func]
    fn name_error(value: Variant) -> GString {
        match metadata::name_error(&json_value::from_variant(&value)) {
            Ok(()) => GString::new(),
            Err(error) => GString::from(error.as_str()),
        }
    }

    /// The first 64 code points of `text` without NUL characters.
    #[func]
    fn limit_name(text: GString) -> GString {
        GString::from(metadata::limit_name(&text.to_string()).as_str())
    }

    /// The error of a phase state, or an empty string.
    #[func]
    fn phase_state_error(state: VarDictionary) -> GString {
        match metadata::phase_state_error(&json_value::object_from(&state)) {
            Ok(()) => GString::new(),
            Err(error) => GString::from(error.as_str()),
        }
    }

    /// The decoded size of a chunk in a document, or -1 when it varies.
    #[func]
    fn decoded_size(document: VarDictionary, chunk_id: GString) -> i64 {
        let mut native = document_from(&document);

        // only the SC2X record tables need the chunks
        if !native.is_sc2x() {
            native.chunks.clear();
        }

        native.decoded_size(&chunk_id.to_string())
    }

    /// The text of a JSON value as Godot's `JSON.stringify` writes it.
    #[func]
    fn stringify(value: Variant, indent: GString, sort_keys: bool) -> GString {
        GString::from(sc2k_formats::json::stringify(&json_value::from_variant(&value), &indent.to_string(), sort_keys).as_str())
    }
}
