//! Whole-city renders of a supplied city with the imported graphics pack. The
//! hashes are of index-path renders that matched the Godot CPU painter pixel for
//! pixel. The test skips when the pack or the city is not present.

use sc2k_assets::packs::graphics::GraphicsPack;
use sc2k_sim::formats::document::Document;
use sc2k_view::art::CityArt;
use sc2k_view::moving::{marker_cells, moving_draws};
use sc2k_view::present::{cycled_colors, whole_city};
use sc2k_view::regions::{Options, Regions};
use sc2k_view::snapshot::painter_city;
use std::path::Path;

const EXPORT_BACKGROUND: u32 = 0x0018242c;
const UNDERGROUND_INDEX: usize = 0xff;
/// (view, underground, sha256 of "w h\n" and the RGBA bytes)
const EXPECTED: [(usize, bool, &str); 6] = [
    (
        0,
        false,
        "628495de12db2b151cea873424088b2e8dad8169b4ec9222f50fcb2f878049e5",
    ),
    (
        1,
        false,
        "acba97149affe5d8167928ed7d2c282156dd117268c5b829fec9df725940c05a",
    ),
    (
        2,
        false,
        "c32867176ce7299fba0bd5d61543a1cc576674daaf8a0d7d5d9e4662bfb5cb00",
    ),
    (
        0,
        true,
        "12ad81b0635369f13f4da86a46b16a811cec5108aafbc978d667d647548edd98",
    ),
    (
        1,
        true,
        "5855401b27f4e7794ee40e55519174f0c34d7d0508bc642db18ec7baaa06a56d",
    ),
    (
        2,
        true,
        "36a2d8f0929ac1d2f2e603b06454973c597cafabe34323819fb57debf0402213",
    ),
];

fn hex(bytes: &[u8]) -> String {
    bytes.iter().map(|byte| format!("{byte:02x}")).collect()
}

#[test]
fn renders_match_the_godot_painter() {
    let root = Path::new(env!("CARGO_MANIFEST_DIR")).join("../../..");
    let Ok(pack) = GraphicsPack::load(&root.join("ext/graphics").to_string_lossy()) else {
        return;
    };
    let Ok(bytes) = std::fs::read(root.join("references/SIMCITY2000/CITIES/BAYVIEW.SC2")) else {
        return;
    };

    let document = Document::parse(&bytes).unwrap();
    let city = sc2k_sim::sim::new_city::city_of(&document);
    let art = CityArt::new(&pack);
    let identity: Vec<i32> = (0..256).collect();
    let colors = cycled_colors(&art.palette, &identity);
    let mut failures = Vec::new();

    for (view, underground, expected) in EXPECTED {
        let options = Options {
            underground,
            ..Options::default()
        };
        let mut regions = Regions::new(painter_city(&city, 32), &art, view, options).unwrap();

        if !underground {
            regions.set_moving(moving_draws(
                &city,
                &art.views[view],
                &marker_cells(&city),
                view,
                0,
                32,
                true,
            ));
        }

        let background = if underground {
            colors[UNDERGROUND_INDEX]
        } else {
            EXPORT_BACKGROUND
        };
        let (width, height, rgba) = whole_city(&mut regions, &colors, background);
        let mut stream = format!("{width} {height}\n").into_bytes();
        stream.extend(rgba);
        let actual = hex(&sc2k_formats::sha256::digest(&stream));

        if actual != expected {
            failures.push(format!("view {view} underground {underground}: {actual}"));
        }
    }

    assert!(failures.is_empty(), "{failures:#?}");
}
