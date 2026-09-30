//! Which screen regions a viewport shows, and which it paints ahead. Regions
//! are squares of `edge` native pixels, keyed by column and row.

use super::Rect;

/// The visible regions from the viewport center outward, and the nearby regions
/// in the order the view paints them ahead.
pub struct Plan {
    pub visible: Vec<(i32, i32)>,
    pub nearby: Vec<(i32, i32)>,
}

/// A viewport and the way it moves.
pub struct Viewport {
    /// The viewport in native pixels, inside the city image.
    pub rect: Rect,
    /// The size of the city image in native pixels.
    pub size: (i32, i32),
    pub edge: i32,
    /// GPU views paint a wider ring ahead, most of it in the direction of travel.
    pub gpu: bool,
    pub movement: (f32, f32),
}

// The most rings of regions that a GPU view paints ahead.
const MAXIMUM_MARGIN: i32 = 4;

pub fn plan(view: &Viewport) -> Plan {
    let edge = view.edge.max(1);
    let rect = view.rect;
    let first = (rect.x / edge, rect.y / edge);
    let last = ((rect.x + rect.w - 1) / edge, (rect.y + rect.h - 1) / edge);

    // A GPU view paints up to four rings ahead, fewer on a small viewport.
    let margin = if view.gpu {
        ((f64::from(rect.w.min(rect.h)) / (3.0 * f64::from(edge))).ceil() as i32).clamp(1, MAXIMUM_MARGIN)
    } else {
        1
    };

    let mut side = margin;
    let mut top = if view.gpu { ((margin as f32) / 2.0).ceil() as i32 } else { 1 };
    let mut bottom = top;

    // Vertical travel moves the look-ahead from the sides to the leading edge.
    if view.gpu && view.movement.1.abs() > view.movement.0.abs() {
        side = top;

        if view.movement.1 < 0.0 {
            top = margin;
        } else {
            bottom = margin;
        }
    }

    let columns = (view.size.0 + edge - 1) / edge;
    let rows = (view.size.1 + edge - 1) / edge;
    let mut visible = Vec::new();
    let mut nearby = Vec::new();

    for y in (first.1 - top).max(0)..rows.min(last.1 + bottom + 1) {
        for x in (first.0 - side).max(0)..columns.min(last.0 + side + 1) {
            if x >= first.0 && x <= last.0 && y >= first.1 && y <= last.1 {
                visible.push((x, y));
            } else {
                nearby.push((x, y));
            }
        }
    }

    // The center in region units, as Rect2i.get_center, and the look-ahead
    // point in the direction of travel.
    let center = (
        (rect.x + rect.w / 2) as f32 / edge as f32 - 0.5,
        (rect.y + rect.h / 2) as f32 / edge as f32 - 0.5,
    );
    let ahead = if view.gpu {
        look_ahead(center, view.movement, edge, margin)
    } else {
        center
    };

    sort(&mut visible, center, first, last, false);
    sort(&mut nearby, ahead, first, last, view.gpu);

    Plan { visible, nearby }
}

// The center moved by the travel, limited to the look-ahead margin as
// Vector2.limit_length does.
fn look_ahead(center: (f32, f32), movement: (f32, f32), edge: i32, margin: i32) -> (f32, f32) {
    let length = (movement.0 * movement.0 + movement.1 * movement.1).sqrt();
    let limit = (edge * margin) as f32;
    let mut travel = movement;

    if length > 0.0 && limit < length {
        travel = (travel.0 / length * limit, travel.1 / length * limit);
    }

    (center.0 + travel.0 / edge as f32, center.1 + travel.1 / edge as f32)
}

// Rings first when `rings` is set, then the distance to `center`, then the key.
fn sort(keys: &mut [(i32, i32)], center: (f32, f32), first: (i32, i32), last: (i32, i32), rings: bool) {
    keys.sort_by_key(|&(x, y)| {
        let ring = if rings {
            (first.0 - x).max(x - last.0).max((first.1 - y).max(y - last.1))
        } else {
            0
        };

        let (dx, dy) = (x as f32 - center.0, y as f32 - center.1);
        let distance = ((dx * dx + dy * dy) * 1024.0).round() as i64;

        (ring, distance, (x << 16) | y)
    });
}

/// The keys of the regions that the rectangles touch. Parts left of or above
/// the image count as its first column or row.
pub fn keys_for(rects: &[Rect], edge: i32) -> Vec<(i32, i32)> {
    let edge = edge.max(1);
    let mut keys = Vec::new();

    for rect in rects.iter().filter(|r| r.area()) {
        let first = (rect.x.max(0) / edge, rect.y.max(0) / edge);
        let last = ((rect.x + rect.w - 1).max(0) / edge, (rect.y + rect.h - 1).max(0) / edge);

        for y in first.1..=last.1 {
            for x in first.0..=last.0 {
                if !keys.contains(&(x, y)) {
                    keys.push((x, y));
                }
            }
        }
    }

    keys
}

#[cfg(test)]
mod tests {
    use super::*;

    fn view(rect: Rect, gpu: bool, movement: (f32, f32)) -> Viewport {
        Viewport {
            rect,
            size: (2048, 2048),
            edge: 256,
            gpu,
            movement,
        }
    }

    #[test]
    fn visible_regions_start_at_the_center() {
        let plan = plan(&view(Rect::new(256, 256, 768, 512), false, (0.0, 0.0)));

        assert_eq!(plan.visible.len(), 3 * 2);
        assert!(plan.visible[..2].contains(&(2, 1)) && plan.visible[..2].contains(&(2, 2)));

        // one ring of nearby regions around a CPU view
        assert_eq!(plan.nearby.len(), 5 * 4 - 6);
    }

    #[test]
    fn gpu_views_look_ahead_in_the_direction_of_travel() {
        let plan = plan(&view(Rect::new(512, 512, 512, 512), true, (0.0, 200.0)));

        // the first nearby region is the next row down
        assert_eq!(plan.nearby[0].1, 4);
        assert!(plan.nearby.iter().all(|key| key.1 >= 1));
    }

    #[test]
    fn keys_cover_each_rectangle_once() {
        let keys = keys_for(&[Rect::new(0, 0, 300, 10), Rect::new(250, 5, 10, 10), Rect::new(0, 0, 0, 0)], 256);

        assert_eq!(keys, vec![(0, 0), (1, 0)]);
    }
}
