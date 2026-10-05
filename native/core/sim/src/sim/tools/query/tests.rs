use super::*;
use crate::sim::testing::empty_city;

#[test]
fn names_follow_the_executable_tables() {
    assert_eq!(strings::tile_name(tiles::EMPTY), strings::CLEAR_TERRAIN);
    assert_eq!(strings::tile_name(tiles::RUBBLE_FIRST), "Rubble");
    assert_eq!(strings::tile_name(tiles::LLAMA_DOME), "Braun Llama-dome");
    assert_eq!(strings::tile_name(tiles::LLAMA_DOME + 1), "");
    assert_eq!(
        [0, 1, 59, 60, 119, 120, 179, 180].map(level_name),
        ["None", "Low", "Low", "Medium", "Medium", "High", "High", "Very High"]
    );
}

#[test]
fn an_empty_tile_shows_its_altitude_and_raw_data() {
    let city = empty_city(128);
    let info = inspect(&city, Vec2i::new(3, 4)).expect("a valid query");
    assert_eq!(info.kind, "general");
    assert_eq!(info.title, strings::CLEAR_TERRAIN);
    assert!(!info.shows_traffic && !info.shows_utilities && info.shows_land_value);

    let text = text::format_text(&info);
    assert!(text.starts_with("Clear terrain\nTile: 3, 4\nAltitude: "), "{text}");
    assert!(text.contains("\nAdvanced tile data\nTile ID: 0 / 0x00\n"), "{text}");
    assert!(text.ends_with("Microsim ID: None"), "{text}");
    assert_eq!(inspect(&city, Vec2i::new(128, 0)), Err("query position is outside the city".into()));
}

#[test]
fn a_half_resolution_road_averages_its_neighbors() {
    let mut city = empty_city(128);
    let mut values = city.xtrf.data.clone();
    values.fill(16);
    city.xtrf.replace(values);
    let traffic_at = |building| traffic(city.map_size, &city.xtrf.data, Vec2i::new(0, 0), building);
    assert_eq!(traffic_at(tiles::ROAD_STRAIGHT_1), 4, "two map neighbors of 16 over 8");
    assert_eq!(traffic_at(tiles::HIGHWAY_STRAIGHT_1), 8, "a highway doubles the sum");
    assert_eq!(traffic_at(tiles::EMPTY), 0);
}

#[test]
fn facility_lines_expand_their_codes() {
    let city = empty_city(128);
    let stadium = Microsim {
        tile_id: tiles::STADIUM,
        stat_0: 25,
        stat_1: 900,
        stat_2: 1,
        stat_3: 0,
    };
    assert_eq!(text::expand_specific_template(&city, &stadium, "#S #W #G"), "Baseball 25-15 25");
    assert_eq!(text::expand_specific_template(&city, &stadium, "#1000"), "900000");
    assert_eq!(text::specific_sound_events(tiles::DARCO_ARCOLOGY, 10), vec![526, 513]);
}

#[test]
fn the_analysis_counts_each_land_use() {
    let mut city = empty_city(128);
    assert!(city.set_misc_i32(misc::TILE_COUNTS + tiles::SMALL_PARK * 4, 30));
    assert!(city.set_misc_i32(misc::TILE_COUNTS + tiles::POWER_LINE_FIRST * 4, 10));
    let analysis = actions::city_analysis(&city).unwrap();
    assert_eq!((analysis.counts[10], analysis.counts[2], analysis.total), (30, 10, 40));
    assert_eq!(analysis.percent(10), 75);
    assert!(analysis.text().starts_with(actions::HEADER));
}
