use super::dos_ui::{self, HEADER_SIZE, STRIP_WIDTH};
use super::palette::{mac_color_table, mac_palette, text_mode_bytes, windows_layout_index, windows_layout_palette};
use super::{Resource, export};
use sc2k_formats::png;

fn file(name: &str, bytes: Vec<u8>) -> Resource {
    Resource {
        name: name.into(),
        bytes,
        source: "SC2000.DAT".into(),
        id: -1,
        ..Resource::default()
    }
}

#[test]
fn macintosh_palettes_use_the_high_channel_bytes() {
    let mut mac = vec![0; 4112];
    mac[0] = 1;
    mac[16] = 255;
    mac[20] = 77;
    assert_eq!(mac_palette(&mac).unwrap()[0], [255, 0, 77]);
    assert!(mac_palette(&mac[..4111]).is_none());

    let table = [
        0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0x12, 0x34, 0x56, 0x78, 0x9a, 0xbc, 0, 1, 1, 0, 2, 0, 3, 0,
    ];
    assert_eq!(mac_color_table(&table), [[0x12, 0x56, 0x9a], [1, 2, 3]]);
    assert!(mac_color_table(&table[..23]).is_empty());
    assert_eq!(text_mode_bytes(&[1, 13, 10, 13, 2, 13]), [1, 10, 13, 2, 13]);
}

#[test]
fn shifted_palettes_move_to_the_windows_layout() {
    assert_eq!(windows_layout_index(-1), -1);
    assert_eq!(windows_layout_index(0), 16);
    assert_eq!(windows_layout_index(203), 219);
    assert_eq!(windows_layout_index(204), 0);
    assert_eq!((windows_layout_index(224), windows_layout_index(239)), (224, 239));
    assert_eq!((windows_layout_index(240), windows_layout_index(255)), (0, 0));

    // without cycle colors, the filler entries stay at their moved indices
    let source: Vec<[u8; 3]> = (0..=255).map(|index| [index, 0, 0]).collect();
    let moved = windows_layout_palette(&source, &[], &[]);
    assert_eq!((moved[0], moved[15], moved[16], moved[170]), ([0; 3], [0; 3], [0; 3], [154, 0, 0]));
    assert_eq!((moved[219], moved[224], moved[255]), ([203, 0, 0], [224, 0, 0], [0; 3]));
}

fn dos_toolbar() -> Vec<u8> {
    let mut toolbar = vec![0; HEADER_SIZE + 72 * 312];
    toolbar[..4].copy_from_slice(&[0x38, 1, 72, 0]);
    toolbar[HEADER_SIZE + 3 * 72 + 3] = 7;
    toolbar[HEADER_SIZE + 127 * 72 + 8] = 9;
    toolbar
}

#[test]
fn the_dos_toolbar_fills_the_windows_strip() {
    let palette = vec![1; 768];
    let strip = dos_ui::toolbar(&dos_toolbar(), &palette).unwrap();
    assert_eq!(strip.pixels[2 * STRIP_WIDTH + 2], 7);
    assert_eq!(strip.pixels[2 * STRIP_WIDTH + 350], 9);
    assert_eq!(strip.pixels[0], 145);
    assert!(dos_ui::toolbar(&dos_toolbar()[1..], &palette).is_err());
    assert!(dos_ui::toolbar(&dos_toolbar(), &palette[1..]).is_err());
}

#[test]
fn dos_sources_make_a_partial_pack() {
    let mut header = vec![255; 24];
    header[8..12].copy_from_slice(&[0; 4]);
    header[12] = 2;
    header[13] = 4;
    let pixels = vec![16, 7, 4, 1, 12, 2, 7, 9, 16, 1, 0];
    let palette: Vec<u8> = (0..256_u32)
        .flat_map(|index| [index as u8, 255 - index as u8, (index / 2) as u8])
        .collect();
    let resources = [
        file("LARGE.HED", header.clone()),
        file("LARGE.DAT", pixels.clone()),
        file("SMALL.HED", header),
        file("SMALL.DAT", pixels),
        file("MINE.PAL", palette),
        file("CULT1.RAW", vec![40; 49 * 3]),
        file("CULT2.RAW", vec![80; 16 * 3]),
        file("TOOL.RAW", dos_toolbar()),
    ];
    let mut files: Vec<(String, Vec<u8>)> = Vec::new();
    let outcome = export(&resources, "DOS", "Test", &mut files);
    assert!(outcome.error.is_empty(), "{}", outcome.error);
    assert_eq!(outcome.count, 3);
    assert!(!outcome.warnings.iter().any(|warning| warning.contains("cycle colors")));

    let names: Vec<&str> = files.iter().map(|(name, _)| name.as_str()).collect();
    assert_eq!(
        names,
        [
            "palette.png",
            "large_sprites/0000-1.png",
            "small_medium_sprites/0000-1.png",
            "ui/toolbar_art.png",
            "pack.json"
        ]
    );
    let sprite = png::decode_indexed(&files[1].1, true).unwrap();
    assert_eq!(sprite.pixels, [-1, 23, 25, -1, -1, -1, -1, -1]);
    assert_eq!(&sprite.palette[25 * 3..26 * 3], [9, 246, 4]);
    let manifest = String::from_utf8(files[4].1.clone()).unwrap();
    assert!(manifest.contains("\"import_revision\": 3") && manifest.contains("\"source_platform\": \"DOS\""));
}

#[test]
fn sources_without_a_palette_fail() {
    let mut files: Vec<(String, Vec<u8>)> = Vec::new();
    let outcome = export(&[file("README.TXT", vec![1])], "Windows", "Test", &mut files);
    assert_eq!(outcome.error, "No readable city palette or interface bitmap was found.");
    assert!(files.is_empty());
}
