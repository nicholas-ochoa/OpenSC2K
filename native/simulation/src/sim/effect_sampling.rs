//! The tile effects that a view shows. A large demolition makes an effect for
//! each tile, but the view shows only the effects of an even spread of tiles
//! near it. The edit makes every effect first, so its random draws stay the same.

use std::collections::HashSet;

use super::events::EffectEvent;
use super::geom::{Rect2i, Vec2i};

/// The tile effects in `window`, from an even spread of at most `tile_limit`
/// tiles, in their order. Effects without a tile, such as an earthquake or a
/// launch, stay. A limit of zero keeps every effect.
pub fn sample(events: Vec<EffectEvent>, window: Rect2i, tile_limit: usize) -> Vec<EffectEvent> {
    if tile_limit == 0 || events.len() <= tile_limit {
        return events;
    }

    let mut seen = HashSet::new();
    let mut tiles = Vec::new();

    for event in &events {
        if is_tile_effect(event) && window.has_point(event.point) && seen.insert(event.point) {
            tiles.push(event.point);
        }
    }

    let stride = tiles.len().div_ceil(tile_limit).max(1);
    let kept: HashSet<Vec2i> = tiles.into_iter().step_by(stride).collect();

    events
        .into_iter()
        .filter(|event| !is_tile_effect(event) || kept.contains(&event.point))
        .collect()
}

fn is_tile_effect(event: &EffectEvent) -> bool {
    event.type_.is_empty() && event.point != Vec2i::NONE
}

#[cfg(test)]
mod tests {
    use super::*;

    fn dust(x: i64, y: i64) -> EffectEvent {
        EffectEvent::new(Vec2i::new(x, y), 1392, Vec2i::ZERO, false, 0, -1)
    }

    #[test]
    fn large_lists_keep_a_spread_of_tiles_in_the_window() {
        let mut events = vec![EffectEvent::earthquake()];

        for x in 0..100 {
            for y in 0..10 {
                // two frames for each tile
                events.push(dust(x, y));
                events.push(dust(x, y));
            }
        }

        let sampled = sample(events, Rect2i::new(0, 0, 50, 10), 100);
        let tiles: HashSet<Vec2i> = sampled
            .iter()
            .filter(|event| is_tile_effect(event))
            .map(|event| event.point)
            .collect();

        assert_eq!(sampled[0], EffectEvent::earthquake());
        assert_eq!(tiles.len(), 100);
        assert!(tiles.iter().all(|point| point.x < 50));
        assert_eq!(sampled.len(), 1 + 2 * tiles.len());
    }

    #[test]
    fn small_lists_and_a_zero_limit_keep_every_effect() {
        let events: Vec<EffectEvent> = (0..10).map(|x| dust(x, 0)).collect();

        assert_eq!(sample(events.clone(), Rect2i::new(0, 0, 1, 1), 10), events);
        assert_eq!(sample(events.clone(), Rect2i::new(0, 0, 1, 1), 0), events);
    }
}
