//! New-city terrain against the golden new-city corpus of the scripts
//! (game/tests/fixtures/corpus/golden-new-cities.json).

use super::{Options, Preview, preview};
use sc2k_formats::json::{self, Value};
use sc2k_formats::sha256::{Sha256, hex};
use std::path::Path;

/// The settings of golden_new_city_test.gd: layout, features, ocean, river,
/// smooth slopes.
const COMBINATIONS: [(&str, &[&str], bool, bool, bool); 21] = [
    ("classic", &[], false, true, false),
    ("classic", &[], true, false, false),
    ("classic", &[], true, true, true),
    ("meander", &[], false, true, false),
    ("delta", &[], false, true, false),
    ("peninsula", &["bay"], false, true, false),
    ("crossing", &[], false, true, false),
    ("branch", &[], false, true, false),
    ("rejoin", &["delta"], false, true, false),
    ("bay", &[], true, false, false),
    ("island", &["bay"], false, false, false),
    ("islands", &["bay"], false, false, false),
    ("plateau", &[], false, true, false),
    ("ridge", &["lake"], false, false, false),
    ("valley", &[], false, true, false),
    ("rolling", &["lakes"], false, false, false),
    ("basin", &[], false, false, false),
    ("canyon", &["meander"], false, true, false),
    ("cliffs", &[], true, false, false),
    ("lake", &["meander"], false, true, false),
    ("lakes", &["plateau"], true, true, true),
];

const SEEDS: [(i64, i64); 2] = [(123, 456), (98765, 4321)];

fn chunks_hash(document: &crate::formats::document::Document) -> String {
    let mut hash = Sha256::new();

    for chunk in &document.chunks {
        hash.update(format!("{}{}\n", chunk.id, chunk.decoded.len()).as_bytes());
        hash.update(&chunk.decoded);
    }

    hex(&hash.finish())
}

#[test]
fn every_layout_matches_the_terrain_of_the_scripts() {
    let path = Path::new(env!("CARGO_MANIFEST_DIR")).join("../../../game/tests/fixtures/corpus/golden-new-cities.json");
    let corpus = json::parse(&std::fs::read_to_string(path).unwrap()).unwrap();
    let cases = corpus.as_object().unwrap().get("cases").unwrap().as_object().unwrap();
    let mut checked = 0;

    for (layout, features, ocean, river, smooth) in COMBINATIONS {
        for (process, game) in SEEDS {
            for native_maps in [false, true] {
                let features: Vec<String> = features.iter().map(|name| name.to_string()).collect();
                let settings = Preview {
                    size: 128,
                    native_maps,
                    terrain: Options {
                        ocean,
                        river,
                        hills: 5 + process % 30,
                        water: game % 40,
                        trees: 20,
                        layout: layout.to_string(),
                        features: features.clone(),
                        smooth_slopes: smooth,
                    },
                    process_start: process,
                    game_start: game,
                };

                let key = format!(
                    "{layout}+{}-{}{}{}-{process}-{}",
                    features.join(","),
                    if ocean { "o" } else { "" },
                    if river { "r" } else { "" },
                    if smooth { "s" } else { "" },
                    if native_maps { "native" } else { "original" }
                );

                let (document, _, _, _) = preview(&settings).unwrap();
                assert_eq!(Some(&Value::String(chunks_hash(&document))), cases.get(&key), "{key}");
                checked += 1;
            }
        }
    }

    assert_eq!(checked, 84);
}

mod rules {
    use super::super::elevation::{self, water_distances};
    use super::super::features::{self, Carve};
    use super::super::gd::Vector2;
    use super::super::heights::EDGE;
    use super::super::noise::Noise;
    use crate::sim::random::GameLcgRandom;

    fn landform(height: i32) -> Vec<i32> {
        vec![height; (EDGE * EDGE) as usize]
    }

    fn at(x: i64, y: i64) -> usize {
        (x * EDGE + y) as usize
    }

    fn strings(names: &[&str]) -> Vec<String> {
        names.iter().map(|name| name.to_string()).collect()
    }

    /// Each relief feature gives its profile. Ported from terrain_elevation_test.gd.
    #[test]
    fn relief_features_shape_the_landform() {
        let noise = Noise::new(71, 7.0, 5);

        for feature in ["plateau", "ridge", "rolling", "basin", "valley", "canyon", "cliffs"] {
            let mut heights = landform(6);

            if ["valley", "canyon", "cliffs"].contains(&feature) {
                for y in 0..EDGE {
                    heights[at(64, y)] = 2;
                }
            }

            elevation::apply(&mut heights, 4, &strings(&[feature]), 0.0, 1.0, &noise, 12);

            match feature {
                "plateau" => {
                    assert_eq!(heights[0], heights[at(6, 6)]);
                    assert!(heights[0] > heights[at(64, 64)] + 4);
                }
                "ridge" => assert!(heights[at(64, 64)] > heights[at(8, 64)] + 4),
                "rolling" => assert!(heights.iter().max().unwrap() - heights.iter().min().unwrap() >= 4),
                "basin" => assert!(heights[at(64, 64)] + 4 < heights[at(8, 64)]),
                "valley" => {
                    for x in 66..73 {
                        assert_eq!(heights[at(x, 64)], 5, "keep a flat dry strip beside the river");
                    }

                    assert!(heights[at(66, 64)] < heights[at(96, 64)]);
                    assert_eq!(heights[at(64, 64)], 2, "preserve river water");
                }
                "canyon" => {
                    assert!(heights[at(78, 64)] <= 6, "the dry floor follows its own winding path");
                    assert!(heights[at(110, 64)] >= 13, "retain steep canyon walls");
                }
                _ => {
                    assert!(heights[at(110, 64)] >= 13, "keep inland terrain high");
                    assert!((heights[at(66, 64)] - heights[at(110, 64)]).abs() <= 1);
                    assert_eq!(heights[at(64, 64)], 2, "preserve coastal water");
                }
            }

            assert!(*heights.iter().max().unwrap() <= 31);
        }

        for feature in ["rolling", "basin"] {
            let outputs: Vec<Vec<i32>> = [71, 912]
                .iter()
                .map(|seed| {
                    let mut heights = landform(6);
                    elevation::apply(&mut heights, 4, &strings(&[feature]), 0.0, 1.0, &Noise::new(*seed, 7.0, 5), 12);
                    heights
                })
                .collect();

            let changed = outputs[0].iter().zip(&outputs[1]).filter(|(a, b)| a != b).count();
            assert!(changed > 500, "seeded noise left the {feature} landform unchanged");
        }
    }

    #[test]
    fn water_distances_count_steps_to_water() {
        let mut heights = landform(6);
        heights[at(10, 10)] = 2;
        let distances = water_distances(&heights, 4);

        assert_eq!(distances[at(10, 10)], 0);
        assert_eq!(distances[at(12, 11)], 3);
        assert_eq!(distances[at(127, 127)], 117 + 117);
    }

    /// The flood fills of the water and the land of a carved landform.
    fn components(heights: &[i32], sea: i64, water: bool) -> usize {
        let mut seen = vec![false; heights.len()];
        let mut count = 0;

        for start in 0..heights.len() {
            if seen[start] || (i64::from(heights[start]) <= sea) != water {
                continue;
            }

            count += 1;
            let mut queue = vec![start];
            seen[start] = true;

            while let Some(current) = queue.pop() {
                let (x, y) = (current as i64 / EDGE, current as i64 % EDGE);

                for (dx, dy) in features::NEIGHBORS {
                    let (nx, ny) = (x + dx, y + dy);

                    if nx < 0 || ny < 0 || nx >= EDGE || ny >= EDGE {
                        continue;
                    }

                    let next = at(nx, ny);

                    if !seen[next] && (i64::from(heights[next]) <= sea) == water {
                        seen[next] = true;
                        queue.push(next);
                    }
                }
            }
        }

        count
    }

    fn carved(names: &[&str], ocean: bool, seed: i64) -> Vec<i32> {
        let mut heights = landform(6);
        let mut flags = vec![0_u8; heights.len()];
        let selected = strings(names);
        let options = Carve {
            sea: 4,
            features: &selected,
            ocean,
            river: names.contains(&"delta"),
            water: 10,
            hills: 30,
        };

        features::carve(&mut heights, &mut flags, &options, &mut GameLcgRandom::new(seed));

        heights
    }

    /// Ported from terrain_layout_test.gd: shared outlets keep one body of water.
    #[test]
    fn feature_outlets_reach_the_ocean() {
        for names in [
            &["delta", "peninsula", "bay"][..],
            &["bay", "islands"],
            &["bay", "branch"],
            &["branch", "crossing", "rejoin"],
        ] {
            let city = carved(names, true, 29);
            assert_eq!(components(&city, 4, true), 1, "disconnected water: {names:?}");

            if names.contains(&"islands") {
                assert_eq!(components(&city, 4, false), 2);
            }

            let inland = carved(names, false, 29);

            for (index, height) in inland.iter().enumerate() {
                if *height <= 4 {
                    assert!(city[index] <= 4, "a feature outlet is disconnected from the ocean: {names:?}");
                }
            }
        }
    }

    /// Ported from terrain_layout_test.gd: a headland with ocean on three sides.
    #[test]
    fn a_peninsula_keeps_its_headland() {
        for seed in [1, 29, 719, 5000] {
            for names in [&["peninsula"][..], &["peninsula", "bay"]] {
                let mut heights = landform(6);
                let mut flags = vec![0_u8; heights.len()];
                let selected = strings(names);
                let options = Carve {
                    sea: 5,
                    features: &selected,
                    ocean: true,
                    river: false,
                    water: 5,
                    hills: 12,
                };

                features::carve(&mut heights, &mut flags, &options, &mut GameLcgRandom::new(seed));
                let angle = GameLcgRandom::new(seed).next_mod(6283) as f64 / 1000.0;

                let height = |x: f64, y: f64| {
                    let point = Vector2::new(x, y).rotated(angle);
                    let tile_x = ((point.fx() + 0.5) * 127.0).round() as i64;
                    let tile_y = ((point.fy() + 0.5) * 127.0).round() as i64;
                    heights[at(tile_x, tile_y)]
                };

                for (x, y) in [(0.08, -0.18), (0.08, 0.0), (0.08, 0.25)] {
                    assert!(height(x, y) >= 5, "the neck and the tip stay on the map");
                }

                for (x, y) in [(-0.20, 0.15), (0.35, 0.15), (0.08, 0.46)] {
                    assert!(height(x, y) < 5, "the headland is missing ocean on one of three sides");
                }
            }
        }
    }

    /// Ported from meandering_terrain_test.gd: shared bend displacement and broad bends.
    #[test]
    fn meanders_keep_joins_and_broad_bends() {
        let mut paths = vec![
            vec![Vector2::new(0.0, -0.9), Vector2::ZERO],
            vec![Vector2::ZERO, Vector2::new(0.0, 0.9)],
        ];
        features::meander_channels(&mut paths, 0.03, 0.0, 1.0, &mut GameLcgRandom::new(3));
        assert_eq!(paths[0][1], paths[1][0], "branch endpoints move together");

        let reach: Vec<Vector2> = (0..257).map(|index| Vector2::new(0.0, -0.5 + index as f64 / 256.0)).collect();
        let mut smooth = vec![reach];
        features::meander_channels(&mut smooth, 0.03, 0.0, 1.0, &mut GameLcgRandom::new(3));
        let path = &smooth[0];
        let mut turns = 0;

        for index in 1..256 {
            let before = path[index] - path[index - 1];
            let after = path[index + 1] - path[index];
            let turn = (before.fx() * after.fy() - before.fy() * after.fx()).atan2(before.fx() * after.fx() + before.fy() * after.fy());
            assert!(turn.abs() < 0.15, "a sharp bend in the channel");

            if before.x * after.x < 0.0 {
                turns += 1;
            }
        }

        assert!((3..=4).contains(&turns), "keep bends broad: {turns} turns");
    }
}

/// Found the cities of the `new_cities` section of golden.json, as
/// NewCityTerrainSession.create_city does after its preview.
#[test]
fn founded_cities_match_the_corpus() {
    use super::setup::{self, Founding};
    use crate::sim::random::{GameLcgRandom, SimRandom};

    let path = Path::new(env!("CARGO_MANIFEST_DIR")).join("../../../game/tests/fixtures/corpus/golden.json");
    let corpus = json::parse(&std::fs::read_to_string(path).unwrap()).unwrap();
    let cities = corpus.as_object().unwrap().get("new_cities").unwrap().as_object().unwrap();

    let cases: [(&str, i64, &str, &[&str], bool); 5] = [
        ("classic-128", 128, "classic", &[], false),
        ("island-128", 128, "island", &[], false),
        ("canyon-native-128", 128, "classic", &["canyon"], true),
        ("classic-256", 256, "classic", &[], false),
        ("bay-native-256", 256, "classic", &["bay", "meander"], true),
    ];

    for (key, size, layout, features, native_maps) in cases {
        let terrain = Options {
            ocean: false,
            river: true,
            hills: 12,
            water: 5,
            trees: 15,
            layout: layout.into(),
            features: features.iter().map(|name| name.to_string()).collect(),
            smooth_slopes: false,
        };

        let settings = Preview {
            size,
            native_maps,
            terrain: terrain.clone(),
            process_start: 123 + key.len() as i64,
            game_start: 456,
        };

        let (preview_document, _, process, game) = preview(&settings).unwrap();
        let expected = cities.get(key).unwrap().as_object().unwrap();
        assert_eq!(
            Some(&Value::String(chunks_hash(&preview_document))),
            expected.get("preview"),
            "{key} preview"
        );

        let founding = Founding {
            city_name: "Corpus".into(),
            mayor_name: "Mayor".into(),
            difficulty: 2,
            starting_year: 1950,
            terrain: None,
            newspaper_session: Vec::new(),
            island: super::is_island(layout, &terrain.features),
        };

        let founded = setup::create(
            &preview_document,
            &founding,
            &mut SimRandom::new(process),
            Some(&mut GameLcgRandom::new(game)),
        )
        .unwrap();
        assert_eq!(
            Some(&Value::String(chunks_hash(&founded.document))),
            expected.get("city"),
            "{key} city"
        );
    }
}
