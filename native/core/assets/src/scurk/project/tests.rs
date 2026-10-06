use super::archive::{decode, encode};
use super::{Node, index_palette, integer_in};
use sc2k_formats::zip;

fn object(entries: Vec<(&str, Node)>) -> Node {
    Node::Object(
        entries
            .into_iter()
            .map(|(key, value)| (key.to_string(), value))
            .collect(),
    )
}

fn state(pixels: Vec<i32>) -> Node {
    let layer = object(vec![
        ("name", Node::Str("Layer".into())),
        ("visible", Node::Bool(true)),
        ("locked", Node::Bool(false)),
        ("pixels", Node::Pixels(pixels.clone())),
    ]);
    let document = object(vec![
        ("width", Node::Int(2)),
        ("height", Node::Int(1)),
        ("active", Node::Int(0)),
        ("original_pixels", Node::Pixels(pixels)),
        ("layers", Node::Array(vec![layer])),
    ]);

    object(vec![
        ("current_mif", Node::Bytes(vec![1, 2, 3])),
        ("documents", object(vec![("1001", document)])),
        ("metadata", object(vec![("scale", Node::Float(1.5))])),
        (
            "resources",
            object(vec![
                ("notes.TXT", Node::Bytes(b"hello".to_vec())),
                ("odd", Node::Bytes(vec![9])),
            ]),
        ),
        ("stamps", Node::Array(Vec::new())),
    ])
}

fn record(pixels: Vec<i32>) -> Node {
    let mut record = state(pixels.clone());
    record.set("original_mif", Node::Bytes(vec![7]));
    record.set("revision", Node::Int(3));
    let checkpoint = object(vec![
        ("name", Node::Str("First".into())),
        ("revision", Node::Int(1)),
        ("snapshot", state(pixels)),
    ]);
    record.set("checkpoints", Node::Array(vec![checkpoint]));

    record
}

fn layer_pixels(record: &Node) -> &[i32] {
    match record
        .get("documents")
        .and_then(|documents| documents.get("1001"))
        .and_then(|document| document.get("layers"))
    {
        Some(Node::Array(layers)) => layers[0]
            .get("pixels")
            .map(Node::as_pixels)
            .unwrap_or_default(),
        _ => &[],
    }
}

#[test]
fn archives_round_trip_with_an_rgb_palette() {
    let palette: Vec<u8> = (0..768).map(|index| (index * 7 % 256) as u8).collect();
    let bytes = encode(&record(vec![5, -1]), &palette).unwrap();
    let decoded = decode(&bytes).unwrap();
    assert_eq!(decoded.palette_rgb, palette);
    assert_eq!(layer_pixels(&decoded.record), [5, -1]);
    assert_eq!(
        decoded.record.get("original_mif"),
        Some(&Node::Bytes(vec![7]))
    );
    assert_eq!(decoded.record.get("revision"), Some(&Node::Float(3.0)));
    let resources = decoded.record.get("resources").unwrap();
    assert_eq!(
        resources.get("notes.TXT"),
        Some(&Node::Bytes(b"hello".to_vec()))
    );

    let archive = zip::decode(&bytes, 1 << 27, 1 << 27).unwrap();
    let names: Vec<&str> = archive
        .members
        .iter()
        .map(|(name, _)| name.as_str())
        .collect();
    assert!(
        names.contains(&"current/resources/0000.txt")
            && names.contains(&"current/resources/0001.bin")
    );
    assert!(names.contains(&"checkpoints/0000/documents/0000/layers/0000.png"));
}

#[test]
fn an_image_with_every_index_keeps_a_mask() {
    let mut record = record(vec![0, 0]);
    let pixels: Vec<i32> = (-1..256).chain([0]).collect();
    let stamp = Node::Object(vec![
        ("name".into(), Node::Str("All".into())),
        ("width".into(), Node::Int(2)),
        ("height".into(), Node::Int(129)),
        ("spacing".into(), Node::Int(1)),
        ("pixels".into(), Node::Pixels(pixels.clone())),
    ]);
    record.set("stamps", Node::Array(vec![stamp]));
    let decoded = decode(&encode(&record, &[]).unwrap()).unwrap();
    assert!(decoded.palette_rgb.is_empty());
    let Some(Node::Array(stamps)) = decoded.record.get("stamps") else {
        panic!("stamps")
    };
    assert_eq!(stamps[0].get("pixels"), Some(&Node::Pixels(pixels)));
}

#[test]
fn damaged_archives_fail() {
    let bytes = encode(&record(vec![1, 2]), &[]).unwrap();
    let mut archive = zip::decode(&bytes, 1 << 27, 1 << 27).unwrap().members;
    archive.push(("extra.bin".into(), vec![1]));
    let borrowed: Vec<(String, &[u8])> = archive
        .iter()
        .map(|(name, data)| (name.clone(), data.as_slice()))
        .collect();
    let extra = zip::encode(&borrowed, 1 << 27, 1 << 27, false).unwrap();
    assert_eq!(
        decode(&extra).err().unwrap(),
        "The project archive contains an unreferenced member: extra.bin"
    );

    let missing: Vec<(String, &[u8])> = borrowed
        .iter()
        .filter(|(name, _)| name != "palette.json")
        .cloned()
        .collect();
    let missing = zip::encode(&missing, 1 << 27, 1 << 27, false).unwrap();
    assert_eq!(
        decode(&missing).err().unwrap(),
        "The project palette is invalid."
    );
    assert!(encode(&record(vec![1, 2]), &[0; 5]).is_err());
}

#[test]
fn integers_accept_whole_floats() {
    assert!(integer_in(Some(&Node::Float(2.0)), 2, 2));
    assert!(!integer_in(Some(&Node::Float(2.5)), 0, 3));
    assert!(!integer_in(Some(&Node::Str("2".into())), 0, 3));
    assert_eq!(index_palette()[3 * 9..3 * 10], [9, 9, 9]);
}
