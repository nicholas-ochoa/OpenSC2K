//! The document codecs against the golden corpus of the game (see
//! docs/golden-corpus.md). The committed generated cities always run. The
//! supplied cities and scenarios run when `references/SIMCITY2000` exists.

use super::document::Document;
use super::sc2x::document as sc2x_document;
use sc2k_formats::json::{self, Object, Value};
use sc2k_formats::sha256::{Sha256, hex};
use sc2k_formats::zip;
use std::path::{Path, PathBuf};

fn repository() -> PathBuf {
    Path::new(env!("CARGO_MANIFEST_DIR")).join("../../..")
}

fn golden() -> Object {
    let path = repository().join("game/tests/fixtures/corpus/golden.json");
    let text = std::fs::read_to_string(&path).expect("the golden corpus is committed");

    match json::parse(&text).expect("valid JSON") {
        Value::Object(object) => object,
        _ => panic!("the corpus is an object"),
    }
}

fn expected<'a>(corpus: &'a Object, section: &str, name: &str, key: &str) -> Option<&'a str> {
    corpus.get(section)?.as_object()?.get(name)?.as_object()?.get(key)?.as_str()
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
    let archive = zip::decode(bytes, sc2x_document::MAX_ARCHIVE_BYTES, sc2x_document::MAX_DATA_BYTES).expect("a valid archive");
    let mut hash = Sha256::new();

    for (name, data) in &archive.members {
        hash.update(format!("{name}\n{}\n", data.len()).as_bytes());
        hash.update(data);
    }

    hex(&hash.finish())
}

fn saved_hash(document: &Document, bytes: &[u8]) -> String {
    if document.is_sc2x() {
        zip_hash(bytes)
    } else {
        hex(&sc2k_formats::sha256::digest(bytes))
    }
}

/// Load, save and convert one file, and compare each value with the corpus.
fn check_file(corpus: &Object, path: &Path) {
    let name = path.file_name().unwrap().to_string_lossy().into_owned();
    let bytes = std::fs::read(path).unwrap();
    let mut document = Document::parse(&bytes).unwrap_or_else(|error| panic!("{name}: {error}"));

    assert_eq!(
        Some(chunks_hash(&document).as_str()),
        expected(corpus, "files", &name, "chunks"),
        "{name} chunks"
    );

    let saved = document.serialize(true).unwrap();
    assert_eq!(
        Some(saved_hash(&document, &saved.bytes).as_str()),
        expected(corpus, "files", &name, "saved"),
        "{name} save"
    );

    if !document.is_sc2x() {
        let stem = name.rsplit_once('.').map_or(name.as_str(), |(stem, _)| stem);
        let (mut converted, _) = sc2x_document::from_legacy(&document, stem, false).unwrap();
        let encoded = converted.serialize(true).unwrap();
        assert_eq!(
            Some(zip_hash(&encoded.bytes).as_str()),
            expected(corpus, "files", &name, "sc2x"),
            "{name} SC2X"
        );
    }
}

#[test]
fn generated_cities_match_the_corpus() {
    let corpus = golden();
    let folder = repository().join("game/tests/fixtures/cities");

    for name in [
        "generated-128.SC2",
        "generated-256.sc2x",
        "generated-384.sc2x",
        "generated-512.sc2x",
    ] {
        check_file(&corpus, &folder.join(name));
    }
}

#[test]
fn supplied_cities_and_scenarios_match_the_corpus() {
    let reference = repository().join("references/SIMCITY2000");

    if !reference.join("SIMCITY.EXE").exists() {
        return;
    }

    let corpus = golden();
    let mut paths = vec![reference.join("DEFAULT.SC2")];

    for folder in ["CITIES", "SCENARIO"] {
        let mut names: Vec<PathBuf> = std::fs::read_dir(reference.join(folder))
            .unwrap()
            .flatten()
            .map(|entry| entry.path())
            .filter(|path| {
                path.extension()
                    .is_some_and(|extension| ["SC2", "SCN"].contains(&extension.to_string_lossy().to_uppercase().as_str()))
            })
            .collect();
        names.sort();
        paths.extend(names);
    }

    for path in paths {
        check_file(&corpus, &path);
    }
}
