//! The asset container readers of the game importer.

use godot::prelude::*;
use sc2k_assets::import::container::Container;

/// `{error, names, kinds, ids, payloads}` of a container.
fn container_value(container: &Container) -> VarDictionary {
    let resources = &container.resources;
    let mut payloads = VarArray::new();

    for resource in resources {
        payloads.push(&PackedByteArray::from(resource.bytes.as_slice()).to_variant());
    }

    let mut result = VarDictionary::new();
    result.set("error", container.error.as_str());
    result.set(
        "names",
        &resources
            .iter()
            .map(|resource| GString::from(resource.name.as_str()))
            .collect::<PackedStringArray>(),
    );
    result.set(
        "kinds",
        &resources
            .iter()
            .map(|resource| GString::from(resource.kind.as_str()))
            .collect::<PackedStringArray>(),
    );
    result.set("ids", &resources.iter().map(|resource| resource.id).collect::<PackedInt64Array>());
    result.set("payloads", &payloads);
    result
}

/// The asset container readers of the game importer.
#[derive(GodotClass)]
#[class(base=Object, no_init)]
pub struct NativeAssetContainer {}

#[godot_api]
impl NativeAssetContainer {
    /// The records of a DAT archive.
    #[func]
    fn named_archive(data: PackedByteArray) -> VarDictionary {
        container_value(&Container::named_archive(data.as_slice()))
    }

    /// The resources of a Macintosh resource fork.
    #[func]
    fn macintosh(data: PackedByteArray) -> VarDictionary {
        container_value(&Container::macintosh(data.as_slice()))
    }

    /// The resources of a Windows executable.
    #[func]
    fn windows(data: PackedByteArray) -> VarDictionary {
        container_value(&Container::windows(data.as_slice()))
    }
}
