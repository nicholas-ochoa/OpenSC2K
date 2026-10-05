//! The newspaper grammar and story text. GDScript keeps the parsed grammar
//! in DataUsaResource and sends it with each story.

use godot::prelude::*;

use sc2k_assets::data_usa::{self, DataUsa};
use sc2k_game::newspaper::{self, Names, Story};

fn packed_ints(values: &[i32]) -> PackedInt32Array {
    PackedInt32Array::from(values)
}

fn ints(fields: &VarDictionary, key: &str) -> Vec<i32> {
    fields
        .get(key)
        .and_then(|value| value.try_to::<PackedInt32Array>().ok())
        .map(|values| values.to_vec())
        .unwrap_or_default()
}

fn grammar_from(fields: &VarDictionary) -> DataUsa {
    DataUsa {
        bases: ints(fields, "bases"),
        counts: ints(fields, "counts"),
        offsets: ints(fields, "offsets").into_iter().map(i64::from).collect(),
        grammar: fields
            .get("grammar")
            .and_then(|value| value.try_to::<PackedByteArray>().ok())
            .map(|bytes| bytes.to_vec())
            .unwrap_or_default(),
        is_johab: fields
            .get("is_johab")
            .and_then(|value| value.try_to::<bool>().ok())
            .unwrap_or(false),
    }
}

/// The newspaper grammar and story text.
#[derive(GodotClass)]
#[class(no_init, base = Object)]
pub struct NativeNewspaper {}

#[godot_api]
impl NativeNewspaper {
    /// `{ok, error, bases, counts, offsets, grammar, is_johab}` of the
    /// DATA_USA data file and its index.
    #[func]
    fn parse_data_usa(data: PackedByteArray, index: PackedByteArray) -> VarDictionary {
        let mut result = VarDictionary::new();

        match data_usa::parse(data.as_slice(), index.as_slice()) {
            Ok(grammar) => {
                let offsets: Vec<i32> = grammar.offsets.iter().map(|&offset| offset as i32).collect();
                result.set("ok", true);
                result.set("error", "");
                result.set("bases", &packed_ints(&grammar.bases));
                result.set("counts", &packed_ints(&grammar.counts));
                result.set("offsets", &packed_ints(&offsets));
                result.set("grammar", &PackedByteArray::from(grammar.grammar.as_slice()));
                result.set("is_johab", grammar.is_johab);
            }
            Err(error) => {
                result.set("ok", false);
                result.set("error", error.as_str());
            }
        }

        result
    }

    /// `{ok, error, headline, article, argument, auxiliary, random_state}` of
    /// one story. `story` has `type`, `argument` and `auxiliary`; `names` has
    /// `city`, `mayor` and `teams`. A headline-only render leaves the article empty.
    #[func]
    fn render(grammar: VarDictionary, story: VarDictionary, seed: i64, names: VarDictionary, headline_only: bool) -> VarDictionary {
        let data = grammar_from(&grammar);
        let story = Story {
            story_type: story.get("type").and_then(|value| value.try_to::<i64>().ok()).unwrap_or(-1),
            argument: story.get("argument").and_then(|value| value.try_to::<i64>().ok()).unwrap_or(0),
            auxiliary: story
                .get("auxiliary")
                .and_then(|value| value.try_to::<PackedByteArray>().ok())
                .map(|bytes| bytes.to_vec())
                .unwrap_or_default(),
        };
        let text = |key: &str| {
            names
                .get(key)
                .and_then(|value| value.try_to::<GString>().ok())
                .map(|text| text.to_string())
                .unwrap_or_default()
        };
        let names = Names {
            city: text("city"),
            mayor: text("mayor"),
            teams: names
                .get("teams")
                .and_then(|value| value.try_to::<PackedStringArray>().ok())
                .map(|teams| teams.as_slice().iter().map(GString::to_string).collect())
                .unwrap_or_default(),
        };
        let rendered = if headline_only {
            newspaper::render_headline(&data, &story, seed, &names)
        } else {
            newspaper::render_story(&data, &story, seed, &names)
        };
        let mut result = VarDictionary::new();

        match rendered {
            Ok(rendered) => {
                result.set("ok", true);
                result.set("error", "");
                result.set("headline", rendered.headline.as_str());
                result.set("article", rendered.article.as_str());
                result.set("argument", rendered.argument);
                result.set("auxiliary", &PackedByteArray::from(rendered.auxiliary.as_slice()));
                result.set("random_state", rendered.random_state);
            }
            Err(error) => {
                result.set("ok", false);
                result.set("error", error.as_str());
            }
        }

        result
    }

    /// The seed of a published story, or -1.
    #[func]
    fn published_seed(session_seed: i64, city_days: i64, paper_index: i64, story_slot: i64) -> i64 {
        newspaper::published_seed(session_seed, city_days, paper_index, story_slot)
    }

    #[func]
    fn published_seed_offsets() -> PackedInt64Array {
        PackedInt64Array::from(newspaper::PUBLISHED_SEED_OFFSETS.as_slice())
    }

    /// The phrase that a grammar token byte expands, or 0 for a literal byte.
    #[func]
    fn token_phrase_id(value: i64) -> i64 {
        newspaper::token_phrase_id(value) as i64
    }

    /// The token bytes of phrases 32 and up.
    #[func]
    fn extended_token_bytes() -> PackedByteArray {
        PackedByteArray::from(newspaper::EXTENDED_TOKEN_BYTES.as_slice())
    }
}
