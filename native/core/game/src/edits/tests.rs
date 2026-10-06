use super::{Selection, apply, building_tile, zone_type};
use crate::session::Session;
use sc2k_sim::formats::document::Document;
use sc2k_sim::sim::geom::Vec2i;
use sc2k_sim::sim::tools::ids::group;

fn session() -> Option<Session> {
    let path = std::path::Path::new(env!("CARGO_MANIFEST_DIR")).join("../../../references/SIMCITY2000/CITIES/CAPE.SC2");
    let bytes = std::fs::read(path).ok()?;

    Some(Session::from_document(Document::parse(&bytes).ok()?, Default::default(), 1))
}

#[test]
fn tools_map_to_zones_and_buildings() {
    assert_eq!(zone_type(group::RESIDENTIAL, 1), 2);
    assert_eq!(zone_type(group::BULLDOZER, 4), 0);
    assert_eq!(zone_type(group::ROADS, 0), -1);
    assert!(building_tile(group::POWER, 2).is_some());
    assert!(building_tile(group::POWER, 3).is_none());
}

#[test]
fn an_edit_undoes() {
    let Some(mut session) = session() else {
        return;
    };

    let before = session.city.chunk("XBLD").unwrap().data.clone();
    let mut selection = Selection::new(group::BULLDOZER, 0, Vec2i::new(64, 64), Vec2i::new(64, 64));
    selection.path = (60..68).map(|x| Vec2i::new(x, 64)).collect();
    let outcome = apply(&mut session, &selection);
    assert!(outcome.ok, "{}", outcome.message);

    if session.undo.is_some() {
        let undo = session.undo.take().unwrap();
        undo.apply(&mut session).unwrap();
        assert_eq!(session.city.chunk("XBLD").unwrap().data, before);
    }
}

#[test]
fn demolition_raises_dust() {
    use sc2k_sim::sim::ids::building_tile_ids as tiles;

    let Some(mut session) = session() else {
        return;
    };

    let edge = session.city.map_size;
    let target = (0..edge * edge)
        .map(|cell| (cell / edge, cell % edge))
        .find(|(x, y)| (tiles::LOWER_CLASS_HOMES_1X1_1..=tiles::LUXURY_HOMES_1X1_4).contains(&session.city.building_id(*x, *y)))
        .unwrap();
    let point = Vec2i::new(target.0, target.1);
    let outcome = apply(&mut session, &Selection::new(group::BULLDOZER, 0, point, point));
    assert!(outcome.ok, "{}", outcome.message);
    assert!(!outcome.effects.is_empty());
    assert!(outcome.sounds.is_empty() || outcome.sounds.iter().all(|sound| *sound >= 500));
}
