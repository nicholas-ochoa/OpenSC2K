use super::*;

const LIMIT: i64 = 64 * 1024 * 1024;

fn members<'a>(items: &'a [(&str, &'a [u8])]) -> Vec<(String, &'a [u8])> {
    items.iter().map(|(name, data)| (name.to_string(), *data)).collect()
}

fn round_trip(items: &[(&str, &[u8])], always_deflate: bool) -> Archive {
    let bytes = encode(&members(items), LIMIT, LIMIT, always_deflate).expect("encode");

    decode(&bytes, LIMIT, LIMIT).expect("decode")
}

#[test]
fn members_keep_their_order_and_bytes() {
    let repeated = vec![7_u8; 5000];
    let items: [(&str, &[u8]); 4] = [("b.bin", &repeated), ("a/x.json", b"{}"), ("empty", b""), ("z", b"1")];
    let archive = round_trip(&items, false);
    let names: Vec<&str> = archive.members.iter().map(|(name, _)| name.as_str()).collect();

    assert_eq!(names, ["b.bin", "a/x.json", "empty", "z"]);
    assert_eq!(archive.get("b.bin"), Some(repeated.as_slice()));
    assert_eq!(archive.get("empty"), Some(&b""[..]));
    assert_eq!(archive.get("missing"), None);
}

#[test]
fn small_members_stay_stored_unless_deflate_is_required() {
    let bytes = encode(&members(&[("a", b"x")]), LIMIT, LIMIT, false).unwrap();
    assert_eq!(u16::from_le_bytes([bytes[8], bytes[9]]), STORED);

    let bytes = encode(&members(&[("a", b"x"), ("e", b"")]), LIMIT, LIMIT, true).unwrap();
    assert_eq!(u16::from_le_bytes([bytes[8], bytes[9]]), DEFLATE);
    assert_eq!(decode(&bytes, LIMIT, LIMIT).unwrap().get("e"), Some(&b""[..]));
}

#[test]
fn the_output_is_deterministic() {
    let data: Vec<u8> = (0..20000).map(|i| (i * 7 % 251) as u8).collect();
    let first = encode(&members(&[("m", &data)]), LIMIT, LIMIT, false).unwrap();
    let second = encode(&members(&[("m", &data)]), LIMIT, LIMIT, false).unwrap();

    assert_eq!(first, second);
}

#[test]
fn unsafe_paths_and_limits_are_refused() {
    for path in ["", "/a", "a//b", "./a", "a/../b", "c:a", "a\\b", "a\0b"] {
        assert!(!valid_path(path), "{path:?}");
        assert_eq!(
            encode(&members(&[(path, b"1")]), LIMIT, LIMIT, false),
            Err("The ZIP member path is invalid.".into())
        );
    }

    assert!(valid_path("folder/file.bin"));
    assert_eq!(encode(&[], -1, LIMIT, false), Err("The ZIP size limit is invalid.".into()));
    assert_eq!(
        encode(&members(&[("a", b"12345")]), LIMIT, 4, false),
        Err("The ZIP exceeds the size limit.".into())
    );
    assert_eq!(
        encode(&members(&[("a", b"1")]), 99, LIMIT, false),
        Err("The ZIP exceeds the size limit.".into())
    );
    assert_eq!(
        encode(&members(&[("a", b"1")]), 100, LIMIT, false),
        Err("The encoded ZIP exceeds the file size limit.".into())
    );

    let bytes = encode(&members(&[("a", b"12345")]), LIMIT, LIMIT, false).unwrap();
    assert_eq!(decode(&bytes, LIMIT, 4), Err("The decoded ZIP exceeds the size limit.".into()));
    assert_eq!(decode(&bytes, 10, LIMIT), Err("The ZIP size is invalid.".into()));
    assert_eq!(decode(b"", LIMIT, LIMIT), Err("The ZIP size is invalid.".into()));
}

#[test]
fn damaged_archives_are_refused() {
    let data = vec![3_u8; 4000];
    let bytes = encode(&members(&[("a", &data), ("b", b"stored")]), LIMIT, LIMIT, false).unwrap();

    // the stored member's CRC
    let mut damaged = bytes.clone();
    let stored_data = damaged.len() - 22 - 2 * (CENTRAL_SIZE as usize + 1) - 6;
    damaged[stored_data] ^= 1;
    assert_eq!(decode(&damaged, LIMIT, LIMIT), Err("The ZIP member checksum is invalid.".into()));

    // the compressed member's data
    let mut damaged = bytes.clone();
    damaged[LOCAL_SIZE as usize + 1 + 3] ^= 0x55;
    assert!(decode(&damaged, LIMIT, LIMIT).is_err());

    // no end record
    let truncated = &bytes[..bytes.len() - 1];
    assert_eq!(decode(truncated, LIMIT, LIMIT), Err("The ZIP directory is missing.".into()));

    // a directory entry that names another local header
    let mut damaged = bytes.clone();
    let directory = damaged.len() - 22 - 2 * (CENTRAL_SIZE as usize + 1);
    damaged[directory + 42] = 1;
    assert_eq!(
        decode(&damaged, LIMIT, LIMIT),
        Err("The ZIP local header does not match its directory.".into())
    );
}

#[test]
fn repeated_paths_are_refused() {
    let bytes = encode(&members(&[("a", b"1"), ("b", b"2")]), LIMIT, LIMIT, false).unwrap();
    let mut damaged = bytes.clone();

    // rename "b" to "a" in its local and central headers
    let second_local = LOCAL_SIZE as usize + 1 + 1;
    damaged[second_local + LOCAL_SIZE as usize] = b'a';
    let second_central = damaged.len() - 22 - (CENTRAL_SIZE as usize + 1);
    damaged[second_central + CENTRAL_SIZE as usize] = b'a';

    assert_eq!(
        decode(&damaged, LIMIT, LIMIT),
        Err("The ZIP member path is invalid or repeated.".into())
    );
}

#[test]
fn data_descriptors_are_read_with_and_without_a_signature() {
    let data = b"descriptor data";

    for signature in [true, false] {
        let mut bytes = Vec::new();
        let crc = crc32::calculate(data);
        let mut local = vec![0_u8; LOCAL_SIZE as usize];
        put_u32(&mut local, 0, LOCAL_SIGNATURE);
        put_u16(&mut local, 4, 20);
        put_u16(&mut local, 6, DESCRIPTOR_FLAG);
        put_u16(&mut local, 26, 1);
        bytes.extend_from_slice(&local);
        bytes.push(b'd');
        bytes.extend_from_slice(data);

        if signature {
            bytes.extend_from_slice(&DESCRIPTOR_SIGNATURE.to_le_bytes());
        }

        bytes.extend_from_slice(&crc.to_le_bytes());
        bytes.extend_from_slice(&(data.len() as u32).to_le_bytes());
        bytes.extend_from_slice(&(data.len() as u32).to_le_bytes());

        let directory_offset = bytes.len();
        let entry = Entry {
            name: b"d".to_vec(),
            flags: DESCRIPTOR_FLAG,
            crc,
            compressed_size: data.len() as i64,
            size: data.len() as i64,
            ..Entry::default()
        };
        let mut central = central_header(&entry);
        central.push(b'd');
        bytes.extend_from_slice(&central);

        let mut end = vec![0_u8; END_SIZE as usize];
        put_u32(&mut end, 0, END_SIGNATURE);
        put_u16(&mut end, 8, 1);
        put_u16(&mut end, 10, 1);
        put_u32(&mut end, 12, central.len() as u32);
        put_u32(&mut end, 16, directory_offset as u32);
        bytes.extend_from_slice(&end);

        assert_eq!(decode(&bytes, LIMIT, LIMIT).unwrap().get("d"), Some(&data[..]));
    }
}

#[test]
fn many_members_use_zip64_records() {
    let count = ZIP16_MAX as usize + 2;
    let names: Vec<String> = (0..count).map(|index| format!("m{index}")).collect();
    let items: Vec<(String, &[u8])> = names.iter().map(|name| (name.clone(), &b""[..])).collect();
    let bytes = encode(&items, LIMIT, LIMIT, false).unwrap();
    let archive = decode(&bytes, LIMIT, LIMIT).unwrap();

    assert_eq!(archive.members.len(), count);
    assert_eq!(archive.members[count - 1].0, names[count - 1]);
}
