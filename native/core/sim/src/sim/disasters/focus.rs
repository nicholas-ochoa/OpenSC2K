//! The tile that the Go To Disaster button centers, as DisasterFocus: an
//! active disaster object, else the marker nearest the middle of the markers.

use super::{FIRE_OVERLAY, FLOOD_OVERLAY, RIOT_OVERLAY_FORWARD, RIOT_OVERLAY_REVERSE, TOXIC_OVERLAY};
use crate::sim::city::City;
use crate::sim::geom::Vec2i;
use crate::sim::overlay;
use crate::sim::things;

/// An airplane in this state is crashing.
const CRASHING_AIRPLANE_STATE: i64 = 7;
const MARKER_OVERLAYS: [i64; 5] = [
    FIRE_OVERLAY,
    TOXIC_OVERLAY,
    FLOOD_OVERLAY,
    RIOT_OVERLAY_FORWARD,
    RIOT_OVERLAY_REVERSE,
];

/// The disaster tile, or `None` when no object or marker shows a disaster.
pub fn find_point(city: &City) -> Option<Vec2i> {
    thing_point(city).or_else(|| marker_point(city))
}

fn thing_point(city: &City) -> Option<Vec2i> {
    let data = &city.xthg.data;

    if city.chunk("XTHG").is_none() || data.len() as i64 != city.decoded_size("XTHG") {
        return None;
    }

    (1..things::count(data)).find_map(|record| {
        let kind = things::field(data, record, things::FIELD_TYPE);
        let crashing = kind == things::TYPE_AIRPLANE && things::field(data, record, things::FIELD_STATE) == CRASHING_AIRPLANE_STATE;
        let active = kind == things::TYPE_MONSTER || kind == things::TYPE_TORNADO || kind == things::TYPE_EXPLOSION || crashing;

        active.then(|| {
            Vec2i::new(
                things::field(data, record, things::FIELD_X),
                things::field(data, record, things::FIELD_Y),
            )
        })
    })
}

/// Scattered markers average to a quiet tile, so the average snaps back to
/// the nearest marker. Equal distances choose the first tile in map order.
fn marker_point(city: &City) -> Option<Vec2i> {
    let edge = city.map_size;
    let text = &city.xtxt.data;
    let mut markers = Vec::new();

    // a search of the overlay bytes costs much less than a check of each tile
    for value in MARKER_OVERLAYS {
        let mut found = overlay::find(text, value, 0);

        while found >= 0 {
            markers.push(found);
            found = overlay::find(text, value, found + 1);
        }
    }

    if markers.is_empty() {
        return None;
    }

    markers.sort_unstable();
    let point = |index: i64| Vec2i::new(index / edge, index % edge);
    let count = markers.len() as i64;
    let (sum_x, sum_y) = markers.iter().fold((0, 0), |(x, y), &index| (x + index / edge, y + index % edge));
    let average = Vec2i::new(sum_x / count, sum_y / count);
    let mut nearest = None;
    let mut nearest_distance = edge * 2;

    for &index in &markers {
        let marker = point(index);
        let distance = (marker.x - average.x).abs() + (marker.y - average.y).abs();

        if distance < nearest_distance {
            nearest = Some(marker);
            nearest_distance = distance;
        }
    }

    nearest
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::sim::testing::empty_city;

    #[test]
    fn objects_come_before_markers_and_markers_snap_to_the_nearest() {
        let mut city = empty_city(128);
        assert_eq!(find_point(&city), None);

        let mut text = city.xtxt.data.clone();
        overlay::set_marker_at(&mut text, 10 * 128 + 10, FIRE_OVERLAY);
        overlay::set_marker_at(&mut text, 10 * 128 + 14, FIRE_OVERLAY);
        overlay::set_marker_at(&mut text, 30 * 128 + 30, FLOOD_OVERLAY);
        city.xtxt.replace(text);
        assert_eq!(
            find_point(&city),
            Some(Vec2i::new(10, 14)),
            "the average (16, 18) is nearest to (10, 14)"
        );

        let mut data = city.xthg.data.clone();
        things::set_field(&mut data, 3, things::FIELD_TYPE, things::TYPE_MONSTER);
        things::set_field(&mut data, 3, things::FIELD_X, 50);
        things::set_field(&mut data, 3, things::FIELD_Y, 60);
        city.xthg.replace(data);
        assert_eq!(find_point(&city), Some(Vec2i::new(50, 60)));
    }
}
