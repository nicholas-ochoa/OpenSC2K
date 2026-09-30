//! Network and highway drags, as NetworkDragCommand and RouteEditResult.
//!
//! A drag can cross water. Each bridge ends one segment; the next segment
//! starts at the far bank. The segments become one result and one undo.

use std::collections::HashSet;

use super::network_bridge::BridgeChoice;
use super::{ToolArgs, highway_edit, network_edit};
use crate::gd_edit_result;
use crate::sim::city::City;
use crate::sim::geom::{Rect2i, Vec2i};
use crate::sim::tools::highway::snap_anchor;

gd_edit_result! {
    /// A road, rail, power line, subway, pipe, or highway route. Network routes
    /// use the tile fields; highways use the 2 by 2 section fields.
    pub struct RouteResult as "RouteEditResult" {
        pub mode: i64 = -1,
        pub start: Vec2i = Vec2i::NONE,
        pub finish: Vec2i = Vec2i::NONE,
        pub dry_points: Vec<Vec2i> = Vec::new(),
        pub sections: Vec<Vec2i> = Vec::new(),
        pub bridge_points: Vec<Vec2i> = Vec::new(),
        pub bridge_sections: Vec<Vec2i> = Vec::new(),
        pub bridge_endpoint_sections: Vec<Vec2i> = Vec::new(),
        pub dry_cost: i64 = 0,
        pub listed_dry_cost: i64 = 0,
        pub route_cost: i64 = 0,
        pub listed_route_cost: i64 = 0,
        pub graded_tiles: i64 = 0,
        pub graded_sections: i64 = 0,
        pub bridge_built: bool = false,
        pub bridge_count: i64 = 0,
        pub bridge_exit: Vec2i = Vec2i::NONE,
        pub bridge_type: i64 = -1,
        pub bridge_name: String = String::new(),
        pub bridge_cancelled: bool = false,
        pub bridge_span_length: i64 = 0,
        pub bridge_cost: i64 = 0,
        pub listed_bridge_cost: i64 = 0,
        pub bridge_error: String = String::new(),
        pub connection_anchor: Vec2i = Vec2i::NONE,
        pub connection_built: bool = false,
        pub connection_cancelled: bool = false,
        pub connection_cost: i64 = 0,
        pub listed_connection_cost: i64 = 0,
        pub connection_error: String = String::new(),
        pub stopped_early: bool = false,
        pub continuation_error: String = String::new(),
        pub bridge_selection_required: bool = false,
        pub bridge_choices: Vec<BridgeChoice> = Vec::new(),
        pub connection_selection_required: bool = false,
        pub cancelled: bool = false,
    }
}

impl RouteResult {
    /// RouteEditResult.merge_segment: add the next bridge-separated segment.
    fn merge_segment(&mut self, segment: RouteResult) {
        self.base.cost += segment.base.cost;
        self.base.listed_cost += segment.base.listed_cost;
        self.dry_cost += segment.dry_cost;
        self.listed_dry_cost += segment.listed_dry_cost;
        self.route_cost += segment.route_cost;
        self.listed_route_cost += segment.listed_route_cost;
        self.bridge_cost += segment.bridge_cost;
        self.listed_bridge_cost += segment.listed_bridge_cost;
        self.bridge_span_length += segment.bridge_span_length;
        self.graded_tiles += segment.graded_tiles;
        self.graded_sections += segment.graded_sections;
        self.connection_cost += segment.connection_cost;
        self.listed_connection_cost += segment.listed_connection_cost;

        merge_points(&mut self.base.points, &segment.base.points);
        merge_points(&mut self.dry_points, &segment.dry_points);
        merge_points(&mut self.bridge_points, &segment.bridge_points);
        merge_points(&mut self.sections, &segment.sections);
        merge_points(&mut self.bridge_sections, &segment.bridge_sections);
        merge_points(&mut self.bridge_endpoint_sections, &segment.bridge_endpoint_sections);

        let mut indices: HashSet<i32> = self.base.tile_indices.0.iter().copied().collect();

        for &index in &segment.base.tile_indices.0 {
            if indices.insert(index) {
                self.base.tile_indices.0.push(index);
            }
        }

        self.bridge_built |= segment.bridge_built;
        self.bridge_cancelled |= segment.bridge_cancelled;
        self.connection_built |= segment.connection_built;
        self.connection_cancelled |= segment.connection_cancelled;
        self.connection_anchor = segment.connection_anchor;
        self.connection_error = segment.connection_error;
        self.stopped_early = segment.stopped_early;

        if !segment.bridge_error.is_empty() {
            self.continuation_error = segment.bridge_error;
        }

        self.bridge_count += segment.bridge_built as i64;
    }
}

fn merge_points(merged: &mut Vec<Vec2i>, added: &[Vec2i]) {
    for point in added {
        if !merged.contains(point) {
            merged.push(*point);
        }
    }
}

/// The choices that a drag passes to each segment.
pub struct RouteChoices {
    pub bridge: i64,
    pub connection: i64,
    pub highway: bool,
}

/// NetworkDragCommand.apply. The segments edit `city` in place; the bridge
/// keeps the chunks only when the combined result succeeds.
pub fn drag(city: &mut City, args: &ToolArgs, start: Vec2i, finish: Vec2i, choices: &RouteChoices) -> RouteResult {
    let endpoint = if choices.highway { snap_anchor(finish) } else { finish };
    let mut cursor = if choices.highway { snap_anchor(start) } else { start };
    let low = Vec2i::new(cursor.x.min(endpoint.x), cursor.y.min(endpoint.y));
    let bounds = Rect2i::from(
        low,
        Vec2i::new((endpoint.x - cursor.x).abs() + 1, (endpoint.y - cursor.y).abs() + 1),
    );
    let mut visited = HashSet::new();
    let mut combined: Option<RouteResult> = None;

    while visited.insert(cursor) {
        let mut bridge = if combined.is_none() { choices.bridge } else { -1 };
        let mut connection = -1;
        let mut segment = RouteResult::default();

        // A later highway segment can fail after it placed some sections. Keep
        // the city from before it, as the original edits a copy.
        let before = (choices.highway && combined.is_some()).then(|| city.clone());

        // A segment can ask for a bridge type and then for a connection.
        for _ in 0..3 {
            segment = if choices.highway {
                highway_edit::apply_segment(city, args, cursor, endpoint, connection, bridge)
            } else {
                network_edit::apply_segment(city, args, cursor, endpoint, bridge, connection)
            };

            if segment.bridge_selection_required && choices.bridge != -1 {
                bridge = choices.bridge;
            } else if segment.connection_selection_required && choices.connection != -1 {
                connection = choices.connection;
            } else {
                break;
            }
        }

        if !segment.base.ok {
            let Some(mut combined) = combined else {
                return segment;
            };

            if let Some(before) = before {
                *city = before;
            }

            if segment.bridge_selection_required || segment.connection_selection_required {
                // Wait for confirmation before committing any segment, including earlier spans.
                if choices.highway {
                    segment.route_cost += combined.base.cost;
                } else {
                    segment.dry_cost += combined.base.cost;
                }

                return segment;
            }

            combined.continuation_error = segment.base.error;
            combined.stopped_early = true;

            return combined;
        }

        let bridge_built = segment.bridge_built;
        let next = segment.bridge_exit;

        match combined.as_mut() {
            None => {
                if choices.connection == 1 && !segment.bridge_built && !segment.connection_built {
                    return RouteResult::rejected("neighbor connection is not available", 0);
                }

                segment.bridge_count = segment.bridge_built as i64;
                combined = Some(segment);
            }
            Some(combined) => combined.merge_segment(segment),
        }

        if !bridge_built {
            break;
        }

        // A bridge can end past the pointer over water. Stop there instead of routing back.
        if !rect_has_point(bounds, next) || visited.contains(&next) {
            break;
        }

        cursor = next;
    }

    combined.unwrap_or_else(|| RouteResult::rejected("network route is empty", 0))
}

fn rect_has_point(rect: Rect2i, point: Vec2i) -> bool {
    let end = rect.end();

    point.x >= rect.position.x && point.y >= rect.position.y && point.x < end.x && point.y < end.y
}
