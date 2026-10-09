//! The text and newspaper record converters of the game importer. Records
//! cross as parallel `ids` and `payloads` arrays in their order.

use godot::prelude::*;
use sc2k_assets::import::newspaper::{self, Records, SourceRecord};
use sc2k_assets::text_usa;

fn records_from(ids: &PackedInt64Array, payloads: &VarArray) -> Records {
    Records(
        ids.as_slice()
            .iter()
            .zip(payloads.iter_shared())
            .map(|(&id, payload)| {
                (
                    id,
                    payload.try_to::<PackedByteArray>().map(|bytes| bytes.to_vec()).unwrap_or_default(),
                )
            })
            .collect(),
    )
}

fn records_value(records: &Records, prefix: &str) -> VarDictionary {
    let mut payloads = VarArray::new();

    for (_, bytes) in &records.0 {
        payloads.push(&PackedByteArray::from(bytes.as_slice()).to_variant());
    }

    let mut result = VarDictionary::new();
    result.set(
        format!("{prefix}ids").as_str(),
        &records.0.iter().map(|(id, _)| *id).collect::<PackedInt64Array>(),
    );
    result.set(format!("{prefix}payloads").as_str(), &payloads);
    result
}

/// The text and newspaper record converters of the game importer.
#[derive(GodotClass)]
#[class(base=Object, no_init)]
pub struct NativeDataImport {}

#[godot_api]
impl NativeDataImport {
    /// `{text_ids, text_payloads, newspaper_ids, newspaper_payloads}` of the
    /// source records, given as parallel arrays.
    #[func]
    fn find_records(
        names: PackedStringArray,
        kinds: PackedStringArray,
        ids: PackedInt64Array,
        sources: PackedStringArray,
        payloads: VarArray,
    ) -> VarDictionary {
        let records: Vec<SourceRecord> = (0..names.len())
            .map(|index| SourceRecord {
                name: names.as_slice()[index].to_string(),
                kind: kinds.as_slice()[index].to_string(),
                id: ids.as_slice()[index],
                source: sources.as_slice()[index].to_string(),
                bytes: payloads
                    .get(index)
                    .and_then(|payload| payload.try_to::<PackedByteArray>().ok())
                    .map(|bytes| bytes.to_vec())
                    .unwrap_or_default(),
            })
            .collect();
        let (text, paper) = newspaper::find_records(&records);
        let mut result = records_value(&text, "text_");
        result.extend_dictionary(&records_value(&paper, "newspaper_"), true);
        result
    }

    /// `{ids, payloads}` of a Windows index file pair.
    #[func]
    fn indexed_records(data: PackedByteArray, index: PackedByteArray) -> VarDictionary {
        records_value(&newspaper::indexed_records(data.as_slice(), index.as_slice()), "")
    }

    #[func]
    fn uses_shifted_tokens(ids: PackedInt64Array, payloads: VarArray) -> bool {
        newspaper::uses_shifted_tokens(&records_from(&ids, &payloads))
    }

    #[func]
    fn has_headline_ends(ids: PackedInt64Array, payloads: VarArray) -> bool {
        newspaper::has_headline_ends(&records_from(&ids, &payloads))
    }

    /// `{ids, payloads}` of the newspaper records in the Windows layout, or none.
    #[func]
    fn windows_newspaper(ids: PackedInt64Array, payloads: VarArray) -> VarDictionary {
        records_value(&newspaper::windows_newspaper(&records_from(&ids, &payloads)), "")
    }

    /// The Windows .DAT and .IDX files of the records.
    #[func]
    fn resource_files(ids: PackedInt64Array, payloads: VarArray) -> VarArray {
        let (data, index) = newspaper::resource_files(&records_from(&ids, &payloads));

        let mut files = VarArray::new();
        files.push(&PackedByteArray::from(data.as_slice()).to_variant());
        files.push(&PackedByteArray::from(index.as_slice()).to_variant());
        files
    }

    /// `{ok, error, ids, texts}` of the requested TEXT_USA resources.
    #[func]
    fn text_resources(data: PackedByteArray, index: PackedByteArray, ids: PackedInt64Array) -> VarDictionary {
        match text_usa::load_ids(data.as_slice(), index.as_slice(), ids.as_slice()) {
            Ok(texts) => {
                let mut result = super::success();
                result.set("ids", &texts.iter().map(|(id, _)| *id).collect::<PackedInt64Array>());
                result.set(
                    "texts",
                    &texts
                        .iter()
                        .map(|(_, text)| GString::from(text.as_str()))
                        .collect::<PackedStringArray>(),
                );
                result
            }
            Err(error) => super::failure(&error),
        }
    }
}
