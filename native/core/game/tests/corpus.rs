//! The engine against the `days` section of the golden corpus
//! (game/tests/fixtures/corpus/golden.json): fixed-seed days on the generated
//! cities and on supplied cities, as tools/benchmarks/determinism_probe.gd runs
//! them in the scripts.

use sc2k_formats::json::{self, Object, Value};
use sc2k_formats::sha256::{Sha256, hex};
use sc2k_formats::zip;
use sc2k_game::engine::Engine;
use sc2k_game::state::EngineState;
use sc2k_sim::formats::document::Document;
use sc2k_sim::formats::sc2x::document::{MAX_ARCHIVE_BYTES, MAX_DATA_BYTES};
use sc2k_sim::sim::city::CHUNK_IDS;
use sc2k_sim::sim::economy::budget;
use sc2k_sim::sim::ids::sc2misc_layout as misc;
use sc2k_sim::sim::new_city::city_of;
use sc2k_sim::sim::random::Randoms;
use std::path::{Path, PathBuf};

const SEEDS: (i64, i64, i64) = (123, 456, 789);
const FIXTURE_DAYS: i64 = 60;
const SUPPLIED_DAYS: i64 = 30;
const SUPPLIED_DAY_CITIES: [&str; 4] = ["BAYVIEW.SC2", "CAPE.SC2", "HAWAII.SC2", "LASVEGAS.SC2"];

fn repository() -> PathBuf {
    Path::new(env!("CARGO_MANIFEST_DIR")).join("../../..")
}

fn corpus_days() -> Object {
    let text = std::fs::read_to_string(repository().join("game/tests/fixtures/corpus/golden.json")).unwrap();
    let corpus = json::parse(&text).unwrap();

    corpus.as_object().unwrap().get("days").unwrap().as_object().unwrap().clone()
}

fn sha256(data: &[u8]) -> String {
    hex(&sc2k_formats::sha256::digest(data))
}

fn chunks_hash(document: &Document) -> String {
    let mut hash = Sha256::new();

    for chunk in &document.chunks {
        hash.update(format!("{}{}\n", chunk.id, chunk.decoded.len()).as_bytes());
        hash.update(&chunk.decoded);
    }

    hex(&hash.finish())
}

fn zip_hash(bytes: &[u8]) -> String {
    let archive = zip::decode(bytes, MAX_ARCHIVE_BYTES, MAX_DATA_BYTES).unwrap();
    let mut hash = Sha256::new();

    for (name, data) in &archive.members {
        hash.update(format!("{name}\n{}\n", data.len()).as_bytes());
        hash.update(data);
    }

    hex(&hash.finish())
}

/// Run the days of one city and compare the values with the corpus entry.
fn check_city(path: &Path, days: i64, expected: &Object) {
    let name = path.file_name().unwrap().to_string_lossy().into_owned();
    let mut document = Document::parse(&std::fs::read(path).unwrap()).unwrap();
    let mut city = city_of(&document);
    let mut state = EngineState::for_city(&city);
    let mut randoms = Randoms::new(SEEDS.0, SEEDS.1, SEEDS.2);
    let mut schedules = Vec::new();
    let first_day = city.age_in_days();

    {
        let mut engine = Engine {
            city: &mut city,
            randoms: &mut randoms,
            state: &mut state,
            detailed: false,
        };

        for day in 0..days {
            let result = engine.advance_day();
            assert!(result.ok, "{name} day {day}: {}", result.error);
            schedules.push(result.applied.join(","));

            while !engine.state.pending_interaction.is_empty() {
                let answer = match engine.state.pending_interaction.as_str() {
                    "annual_budget" => {
                        let funding = budget::funding_values(engine.city);
                        let auto_budget = engine.city.misc_u32(misc::AUTO_BUDGET) != 0;
                        engine.resolve_annual_budget(&funding, auto_budget)
                    }
                    "military_proposal" => engine.resolve_military_proposal(false),
                    other => panic!("{name}: unsupported interaction {other}"),
                };

                assert!(answer.ok, "{name} interaction on day {day}: {}", answer.error);
            }
        }
    }

    assert_eq!(city.age_in_days(), first_day + days);

    // the chunks that the days wrote go back to the document
    for id in CHUNK_IDS {
        if let Some(chunk) = city.chunk(id).filter(|chunk| chunk.written) {
            assert!(document.find_mut(id).unwrap().set_decoded(chunk.data.clone()), "{name}: {id} size");
        }
    }

    let field = |key: &str| expected.get(key).cloned().unwrap_or(Value::Null);
    let saved = document.serialize(true).unwrap().bytes;
    let saved_hash = if document.is_sc2x() { zip_hash(&saved) } else { sha256(&saved) };

    assert_eq!(Value::String(chunks_hash(&document)), field("chunks"), "{name} chunks");
    assert_eq!(Value::String(saved_hash), field("saved"), "{name} save");
    assert_eq!(Value::Float(randoms.random.state as f64), field("random"), "{name} random");
    assert_eq!(Value::Float(randoms.lfsr.state as f64), field("lfsr_random"), "{name} LFSR");
    assert_eq!(Value::Float(randoms.game.state as f64), field("game_random"), "{name} game random");
    assert_eq!(
        Value::String(sha256(schedules.join("|").as_bytes())),
        field("schedules"),
        "{name} schedules"
    );
}

#[test]
fn generated_city_days_match_the_corpus() {
    let days = corpus_days();
    let folder = repository().join("game/tests/fixtures/cities");

    for name in [
        "generated-128.SC2",
        "generated-256.sc2x",
        "generated-384.sc2x",
        "generated-512.sc2x",
    ] {
        check_city(&folder.join(name), FIXTURE_DAYS, days.get(name).unwrap().as_object().unwrap());
    }
}

#[test]
fn supplied_city_days_match_the_corpus() {
    let reference = repository().join("references/SIMCITY2000");

    if !reference.join("SIMCITY.EXE").exists() {
        return;
    }

    let days = corpus_days();

    for name in SUPPLIED_DAY_CITIES {
        check_city(
            &reference.join("CITIES").join(name),
            SUPPLIED_DAYS,
            days.get(name).unwrap().as_object().unwrap(),
        );
    }
}
