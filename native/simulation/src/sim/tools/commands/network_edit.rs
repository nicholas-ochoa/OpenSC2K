//! One segment of a network drag, as NetworkEdit and NetworkTiles.

use super::network_bridge::{self as bridges, BRIDGE_CANCELLED, BRIDGE_COSTS, BRIDGE_RAIL, BRIDGE_UNSELECTED, BRIDGE_WIRE, Plan};
use super::network_route::{self as routes, RouteMaps, reuses_surface, reuses_underground};
use super::route::RouteResult;
use super::{DIRECTIONS, EditBase, ToolArgs, scaled};
use crate::sim::city::City;
use crate::sim::geom::Vec2i;
use crate::sim::ids::building_tile_ids as tiles;
use crate::sim::ids::sc2overlay_layout::CONNECTION_MARKER;
use crate::sim::ids::sc2tile_flags as flag_bits;
use crate::sim::ids::sc2zone_layout as zone;
use crate::sim::ids::terrain_tile_ids as terrain_ids;
use crate::sim::ids::underground_tile_ids as under;
use crate::sim::overlay;
use crate::sim::tools::Maps;
use crate::sim::tools::network::{
    MODE_PIPE, MODE_POWER, MODE_RAIL, MODE_ROAD, MODE_SUBWAY, TERRAIN_REQUIRES_GRADING, grade_surface_terrain, replace_building,
    retile_surface_neighborhood,
};
use crate::sim::tools::underground::{replace_underground, retile_neighborhood};

pub const CONNECTION_UNSELECTED: i64 = -1;
pub const CONNECTION_CANCELLED: i64 = 0;
pub const CONNECTION_CONFIRMED: i64 = 1;

const ROAD_CONNECTION_COST: i64 = 1000;
const RAIL_CONNECTION_COST: i64 = 1500;

/// Grading one tile of a network route costs this much.
const GRADING_COST: i64 = 25;

/// The chunks that NetworkState.city_payloads checks.
pub const PAYLOAD_IDS: [&str; 8] = ["ALTM", "XBLD", "XTER", "XZON", "XUND", "XBIT", "XTXT", "MISC"];

/// NetworkConstants.NETWORK_TOOLS: the network mode of each tool slot.
pub fn tool_mode(group: i64, subtool: i64) -> Option<i64> {
    match (group, subtool) {
        (3, 0) => Some(MODE_POWER),
        (4, 0) => Some(MODE_PIPE),
        (6, 0) => Some(MODE_ROAD),
        (7, 0) => Some(MODE_RAIL),
        (7, 1) => Some(MODE_SUBWAY),
        _ => None,
    }
}

fn connection_cost(mode: i64) -> i64 {
    match mode {
        MODE_ROAD => ROAD_CONNECTION_COST,
        MODE_RAIL => RAIL_CONNECTION_COST,
        _ => 0,
    }
}

/// The plan of one segment, as NetworkEdit.SegmentPlan.
struct SegmentPlan {
    start: Vec2i,
    finish: Vec2i,
    mode: i64,
    surface_mode: bool,
    free_mode: bool,
    planned: Vec<Vec2i>,
    planned_directions: Vec<i64>,
    bridge_plan: Option<Plan>,
    graded_tiles: i64,
    listed_dry_cost: i64,
    dry_cost: i64,
    selected_bridge: i64,
    listed_bridge_cost: i64,
    bridge_cost: i64,
    bridge_built: bool,
    bridge_error: String,
    bridge_points: Vec<Vec2i>,
    connection_choice: i64,
    connection_anchor: Vec2i,
    listed_connection_cost: i64,
    connection_cost: i64,
    connection_available: bool,
    connection_affordable: bool,
    connection_built: bool,
    connection_error: String,
    cost: i64,
}

impl SegmentPlan {
    fn has_bridge(&self) -> bool {
        self.bridge_plan.as_ref().is_some_and(|plan| plan.ok)
    }

    fn span_length(&self) -> i64 {
        self.bridge_plan.as_ref().map_or(0, |plan| plan.span_length)
    }
}

/// NetworkEdit.apply_segment.
pub fn apply_segment(
    city: &mut City,
    args: &ToolArgs,
    start: Vec2i,
    finish: Vec2i,
    bridge_type: i64,
    connection_choice: i64,
) -> RouteResult {
    let Some(mode) = tool_mode(args.group, args.subtool) else {
        return RouteResult::rejected("tool is not a linear network tool", 0);
    };

    if city.index_of(start.x, start.y) < 0 || city.index_of(finish.x, finish.y) < 0 {
        return RouteResult::rejected("network path is outside the city", 0);
    }

    if city.missing_or_resized(&PAYLOAD_IDS).is_some() {
        return RouteResult::rejected("required city data is missing or invalid", 0);
    }

    let mut plan = SegmentPlan {
        start,
        finish,
        mode,
        surface_mode: mode == MODE_ROAD || mode == MODE_RAIL || mode == MODE_POWER,
        free_mode: args.free_mode,
        planned: Vec::new(),
        planned_directions: Vec::new(),
        bridge_plan: None,
        graded_tiles: 0,
        listed_dry_cost: 0,
        dry_cost: 0,
        selected_bridge: bridge_type,
        listed_bridge_cost: 0,
        bridge_cost: 0,
        bridge_built: false,
        bridge_error: String::new(),
        bridge_points: Vec::new(),
        connection_choice,
        connection_anchor: Vec2i::ZERO,
        listed_connection_cost: 0,
        connection_cost: 0,
        connection_available: false,
        connection_affordable: false,
        connection_built: false,
        connection_error: String::new(),
        cost: 0,
    };

    let rejection = plan_route(city, &mut plan)
        .or_else(|| validate_dry_cost(city, args, &mut plan))
        .or_else(|| validate_bridge_choice(city, &mut plan))
        .or_else(|| validate_connection_choice(city, &mut plan));

    if let Some(rejection) = rejection {
        return rejection;
    }

    apply_plan(city, &mut plan);

    undo_record(args, plan)
}

/// Plan the dry route, and a bridge where a surface route starts on or
/// reaches water. Returns a rejection when neither exists.
fn plan_route(city: &City, plan: &mut SegmentPlan) -> Option<RouteResult> {
    let edge = city.map_size;
    let maps = RouteMaps {
        buildings: &city.xbld.data,
        terrain: &city.xter.data,
        zones: &city.xzon.data,
        underground: &city.xund.data,
        flags: &city.xbit.data,
        altitude: &city.altm.data,
        map_edge: edge,
    };
    let (planned, directions) = routes::plan_route(&maps, plan.start, plan.finish, plan.mode);
    plan.planned = planned;
    plan.planned_directions = directions;

    if plan.surface_mode {
        if plan.planned.is_empty() && bridges::is_bridge_wrapper_tile(maps.terrain, maps.flags, plan.start, edge) {
            plan.bridge_plan = Some(bridges::plan_bridge_from_start(
                maps.buildings,
                maps.terrain,
                plan.start,
                city.compass_rotation(),
                edge,
            ));
        } else if let Some(&last) = plan.planned.last() {
            let exit = routes::route_exit_direction(&plan.planned, plan.start, plan.finish);
            let bridge_start = last + DIRECTIONS[exit as usize];

            if bridges::is_bridge_wrapper_tile(maps.terrain, maps.flags, bridge_start, edge) {
                plan.bridge_plan = Some(bridges::scan_bridge(maps.buildings, maps.terrain, bridge_start, exit, false, edge));
            }
        }
    }

    if plan.planned.is_empty() && !plan.has_bridge() {
        let message = plan
            .bridge_plan
            .as_ref()
            .map_or("network cannot start on this tile", |bridge| bridge.error.as_str());

        return Some(RouteResult::rejected(message, 0));
    }

    None
}

/// Price the new dry tiles and the grading they need. Reused tiles are free.
fn validate_dry_cost(city: &City, args: &ToolArgs, plan: &mut SegmentPlan) -> Option<RouteResult> {
    let edge = city.map_size;
    let mut new_tiles = plan.planned.len() as i64;

    for point in &plan.planned {
        let index = (point.x * edge + point.y) as usize;
        let reused = if plan.surface_mode {
            reuses_surface(city.xbld.data[index] as i64, plan.mode)
        } else {
            reuses_underground(city.xund.data[index] as i64, plan.mode)
        };

        if reused {
            new_tiles -= 1;
            continue;
        }

        let terrain_id = city.xter.data[index] as i64;

        if terrain_id < terrain_ids::SURFACE_WATER_FIRST && TERRAIN_REQUIRES_GRADING[(terrain_id & terrain_ids::SHAPE_MASK) as usize] {
            plan.graded_tiles += 1;
        }
    }

    plan.listed_dry_cost = new_tiles * args.cost + plan.graded_tiles * GRADING_COST;
    plan.dry_cost = if plan.free_mode { 0 } else { plan.listed_dry_cost };

    if city.funds() < plan.dry_cost {
        return Some(RouteResult::rejected("insufficient funds", plan.dry_cost));
    }

    None
}

/// Ask for a road bridge type, fix the rail and power bridge types, check the
/// chosen type, and decide whether the funds cover it. A bridge that the city
/// cannot afford is skipped unless it is the whole segment.
fn validate_bridge_choice(city: &City, plan: &mut SegmentPlan) -> Option<RouteResult> {
    let mode = plan.mode;

    if plan.has_bridge() {
        let choices = bridges::bridge_choices(plan.span_length(), mode);

        if mode == MODE_ROAD && plan.selected_bridge == BRIDGE_UNSELECTED {
            let mut choice = RouteResult::rejected("bridge type selection is required", 0);
            choice.bridge_selection_required = true;
            choice.bridge_choices = choices;
            choice.bridge_span_length = plan.span_length();
            choice.dry_cost = plan.dry_cost;
            choice.listed_dry_cost = plan.listed_dry_cost;
            choice.base.free_mode = plan.free_mode;
            choice.dry_points = plan.planned.clone();

            return Some(choice);
        }

        if mode == MODE_RAIL {
            plan.selected_bridge = BRIDGE_RAIL;
        } else if mode == MODE_POWER {
            plan.selected_bridge = BRIDGE_WIRE;
        }

        if plan.selected_bridge >= 0 && !choices.iter().any(|choice| choice.type_ == plan.selected_bridge) {
            return Some(RouteResult::rejected("selected bridge type is not available", 0));
        }
    }

    if plan.has_bridge() && plan.selected_bridge == BRIDGE_CANCELLED && plan.planned.is_empty() {
        let mut cancelled = RouteResult::rejected("bridge selection canceled", 0);
        cancelled.cancelled = true;

        return Some(cancelled);
    }

    if plan.has_bridge() && plan.selected_bridge >= 0 {
        plan.listed_bridge_cost = plan.span_length() * BRIDGE_COSTS[plan.selected_bridge as usize];
        plan.bridge_cost = if plan.free_mode { 0 } else { plan.listed_bridge_cost };

        if !plan.free_mode && city.funds() - plan.dry_cost < plan.bridge_cost {
            plan.bridge_error = "insufficient funds for the bridge".to_string();

            if plan.planned.is_empty() {
                return Some(RouteResult::rejected("insufficient funds", plan.bridge_cost));
            }
        } else {
            plan.bridge_built = true;
        }
    }

    None
}

/// Offer a neighbor connection when the route leaves the map edge, and check
/// a confirmed connection. Then total the segment cost.
fn validate_connection_choice(city: &City, plan: &mut SegmentPlan) -> Option<RouteResult> {
    let edge = city.map_size;
    plan.cost = plan.dry_cost + if plan.bridge_built { plan.bridge_cost } else { 0 };
    plan.connection_anchor = plan.planned.last().copied().unwrap_or(plan.start);
    plan.listed_connection_cost = connection_cost(plan.mode);
    plan.connection_cost = if plan.free_mode { 0 } else { plan.listed_connection_cost };

    let anchor_index = plan.connection_anchor.x * edge + plan.connection_anchor.y;
    plan.connection_available = !plan.has_bridge()
        && !plan.planned.is_empty()
        && plan.listed_connection_cost > 0
        && routes::is_connection_exit(&plan.planned, plan.start, plan.finish, edge)
        && overlay::marker_at(&city.xtxt.data, anchor_index) != CONNECTION_MARKER;
    plan.connection_affordable = plan.free_mode || city.funds() - plan.dry_cost >= plan.connection_cost;

    if plan.connection_available && plan.connection_affordable && plan.connection_choice == CONNECTION_UNSELECTED {
        let mut confirmation = RouteResult::rejected("neighbor connection confirmation is required", 0);
        confirmation.connection_selection_required = true;
        confirmation.connection_anchor = plan.connection_anchor;
        confirmation.connection_cost = plan.connection_cost;
        confirmation.listed_connection_cost = plan.listed_connection_cost;
        confirmation.dry_cost = plan.dry_cost;
        confirmation.listed_dry_cost = plan.listed_dry_cost;
        confirmation.base.free_mode = plan.free_mode;
        confirmation.dry_points = plan.planned.clone();

        return Some(confirmation);
    }

    if plan.connection_choice == CONNECTION_CONFIRMED {
        if !plan.connection_available {
            return Some(RouteResult::rejected("neighbor connection is not available", 0));
        }

        if !plan.connection_affordable {
            return Some(RouteResult::rejected("insufficient funds", plan.dry_cost + plan.connection_cost));
        }
    }

    plan.connection_built = plan.connection_choice == CONNECTION_CONFIRMED;

    if plan.connection_available && !plan.connection_affordable {
        plan.connection_error = "insufficient funds for the neighbor connection".to_string();
    }

    if plan.connection_built {
        plan.cost += plan.connection_cost;
    }

    None
}

/// Place the dry tiles, the bridge, and the connection label, and charge the funds.
fn apply_plan(city: &mut City, plan: &mut SegmentPlan) {
    let funds = city.funds();
    let mut maps = city.maps();

    for (point, direction) in plan.planned.iter().zip(&plan.planned_directions) {
        match plan.mode {
            MODE_ROAD | MODE_RAIL | MODE_POWER => place_surface(&mut maps, *point, plan.mode, *direction, true),
            _ => place_underground(&mut maps, *point, plan.mode == MODE_PIPE, *direction),
        }
    }

    if plan.bridge_built
        && let Some(bridge_plan) = &plan.bridge_plan
    {
        plan.bridge_points = bridges::place_bridge(&mut maps, bridge_plan, plan.selected_bridge);
    }

    if plan.connection_built {
        let anchor = plan.connection_anchor;
        overlay::write(maps.text_overlays, anchor.x * maps.map_edge + anchor.y, CONNECTION_MARKER);
        retile_surface_neighborhood(
            maps.buildings,
            maps.terrain,
            maps.zones,
            maps.flags,
            maps.misc,
            anchor,
            plan.mode,
            maps.text_overlays,
            maps.map_edge,
        );
    }

    city.set_funds(funds - plan.cost);
}

/// Describe the stored segment.
fn undo_record(args: &ToolArgs, plan: SegmentPlan) -> RouteResult {
    let bridge_built = plan.bridge_built;
    let connection_built = plan.connection_built;
    let span_length = plan.span_length();
    let bridge_cancelled = plan.has_bridge() && plan.selected_bridge == BRIDGE_CANCELLED;
    let mut points = plan.planned.clone();
    points.extend_from_slice(&plan.bridge_points);

    let mut result = RouteResult {
        base: EditBase::accepted("network", args.group, args.subtool),
        mode: plan.mode,
        dry_points: plan.planned.clone(),
        bridge_points: plan.bridge_points.clone(),
        bridge_built,
        bridge_cancelled,
        bridge_span_length: span_length,
        bridge_error: plan.bridge_error.clone(),
        connection_anchor: plan.connection_anchor,
        connection_built,
        connection_cancelled: plan.connection_available && plan.connection_choice == CONNECTION_CANCELLED,
        connection_error: plan.connection_error.clone(),
        dry_cost: plan.dry_cost,
        listed_dry_cost: plan.listed_dry_cost,
        graded_tiles: plan.graded_tiles,
        stopped_early: !bridge_built && plan.planned.last() != Some(&plan.finish),
        ..Default::default()
    };

    if bridge_built {
        if let Some(bridge_plan) = &plan.bridge_plan {
            result.bridge_exit = bridge_plan.start + scaled(DIRECTIONS[bridge_plan.direction as usize], bridge_plan.span_length);
        }

        result.bridge_type = plan.selected_bridge;
        result.bridge_name = bridges::bridge_type_name(plan.selected_bridge);
        result.bridge_cost = plan.bridge_cost;
        result.listed_bridge_cost = plan.listed_bridge_cost;
    }

    if connection_built {
        result.connection_cost = plan.connection_cost;
        result.listed_connection_cost = plan.listed_connection_cost;
    }

    result.base.points = points;
    result.base.cost = plan.cost;
    result.base.listed_cost = plan.listed_dry_cost
        + if bridge_built { plan.listed_bridge_cost } else { 0 }
        + if connection_built { plan.listed_connection_cost } else { 0 };
    result.base.free_mode = plan.free_mode;

    result
}

/// NetworkTiles._surface_replacement: the tile that a new network makes of an
/// existing one, or -1 when it cannot cross it.
fn surface_replacement(old_tile: i64, mode: i64) -> i64 {
    use tiles::*;

    if old_tile < POWER_LINE_FIRST {
        return match mode {
            MODE_ROAD => FIRST_ROAD,
            MODE_RAIL => RAIL_FIRST,
            _ => POWER_LINE_FIRST,
        };
    }

    match (mode, old_tile) {
        (MODE_ROAD, POWER_LINE_FIRST) => ROAD_POWER_CROSSING_2,
        (MODE_ROAD, POWER_LINE_STRAIGHT_2) => ROAD_POWER_CROSSING_1,
        (MODE_ROAD, RAIL_FIRST) => ROAD_RAIL_CROSSING_2,
        (MODE_ROAD, RAIL_STRAIGHT_2) => ROAD_RAIL_CROSSING_1,
        (MODE_ROAD, HIGHWAY_STRAIGHT_1) => HIGHWAY_ROAD_CROSSING_1,
        (MODE_ROAD, HIGHWAY_STRAIGHT_2) => HIGHWAY_ROAD_CROSSING_2,
        (MODE_RAIL, POWER_LINE_FIRST) => RAIL_POWER_CROSSING_2,
        (MODE_RAIL, POWER_LINE_STRAIGHT_2) => RAIL_POWER_CROSSING_1,
        (MODE_RAIL, FIRST_ROAD) => ROAD_RAIL_CROSSING_1,
        (MODE_RAIL, ROAD_STRAIGHT_2) => ROAD_RAIL_CROSSING_2,
        (MODE_RAIL, HIGHWAY_STRAIGHT_1) => HIGHWAY_RAIL_CROSSING_1,
        (MODE_RAIL, HIGHWAY_STRAIGHT_2) => HIGHWAY_RAIL_CROSSING_2,
        (MODE_POWER, FIRST_ROAD) => ROAD_POWER_CROSSING_1,
        (MODE_POWER, ROAD_STRAIGHT_2) => ROAD_POWER_CROSSING_2,
        (MODE_POWER, RAIL_FIRST) => RAIL_POWER_CROSSING_1,
        (MODE_POWER, RAIL_STRAIGHT_2) => RAIL_POWER_CROSSING_2,
        (MODE_POWER, HIGHWAY_STRAIGHT_1) => HIGHWAY_POWER_CROSSING_1,
        (MODE_POWER, HIGHWAY_STRAIGHT_2) => HIGHWAY_POWER_CROSSING_2,
        _ => -1,
    }
}

/// NetworkTiles._place_surface: grade the ground, place the network tile, and
/// retile the tile and its neighbors. A bridge bank retiles without the
/// connection labels.
pub fn place_surface(maps: &mut Maps, point: Vec2i, mode: i64, direction: i64, with_labels: bool) {
    let edge = maps.map_edge;
    let index = point.x * edge + point.y;
    let i = index as usize;

    if reuses_surface(maps.buildings[i] as i64, mode) {
        return;
    }

    grade_surface_terrain(maps.terrain, maps.flags, point, direction, edge);
    let new_tile = surface_replacement(maps.buildings[i] as i64, mode);

    if new_tile < 0 {
        return;
    }

    replace_building(maps.buildings, maps.zones, maps.misc, index, new_tile);

    if mode == MODE_POWER {
        maps.flags[i] |= flag_bits::POWERABLE as u8;
    } else {
        maps.zones[i] &= zone::CORNERS_MASK as u8;
    }

    let labels: &[u8] = if with_labels { maps.text_overlays } else { &[] };
    retile_surface_neighborhood(
        maps.buildings,
        maps.terrain,
        maps.zones,
        maps.flags,
        maps.misc,
        point,
        mode,
        labels,
        edge,
    );
}

/// NetworkTiles._place_underground: a pipe or subway, crossing the other network.
fn place_underground(maps: &mut Maps, point: Vec2i, pipes: bool, direction: i64) {
    let edge = maps.map_edge;
    let index = point.x * edge + point.y;
    let i = index as usize;
    let old_tile = maps.underground[i] as i64;

    if reuses_underground(old_tile, if pipes { MODE_PIPE } else { MODE_SUBWAY }) {
        return;
    }

    let new_tile = match (pipes, old_tile) {
        (true, under::EMPTY) => under::PIPE_FIRST,
        (true, under::SUBWAY_FIRST) => under::PIPE_TB_SUBWAY_LR,
        (true, under::SUBWAY_TB) => under::PIPE_LR_SUBWAY_TB,
        (false, under::EMPTY) => under::SUBWAY_FIRST,
        (false, under::PIPE_LR) => under::PIPE_LR_SUBWAY_TB,
        (false, under::PIPE_TB) => under::PIPE_TB_SUBWAY_LR,
        _ => return,
    };

    if pipes {
        maps.flags[i] |= flag_bits::PIPED as u8;
    }

    grade_surface_terrain(maps.terrain, maps.flags, point, direction, edge);
    replace_underground(maps.underground, maps.zones, maps.misc, index, new_tile);
    retile_neighborhood(maps.underground, maps.terrain, point, pipes, edge);
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::sim::city::{Chunk, City};
    use crate::sim::tools::network::retile_surface;

    fn city(edge: i64) -> City {
        let cells = (edge * edge) as usize;
        let mut city = City::new(edge, 2);

        for chunk in [
            &mut city.xbld,
            &mut city.xter,
            &mut city.xzon,
            &mut city.xund,
            &mut city.xbit,
            &mut city.xtxt,
        ] {
            *chunk = Chunk::new(vec![0; cells]);
        }

        city.altm = Chunk::new(vec![0; cells * 2]);
        city.misc = Chunk::new(vec![0; 4800]);
        city
    }

    /// A subway leaves a pipe bend or junction as it is.
    #[test]
    fn subways_keep_pipe_bends() {
        let mut city = city(128);
        let point = Vec2i::new(21, 20);
        let index = (point.x * 128 + point.y) as usize;

        for pipe in 0x12..0x1f {
            for direction in 0..4 {
                city.xund.data[index] = pipe;
                place_underground(&mut city.maps(), point, false, direction);
                assert_eq!(city.xund.data[index], pipe);
            }
        }
    }

    /// A slope beside a straight line does not make a side junction.
    #[test]
    fn slopes_make_no_false_junctions() {
        for edge in [128, 512] {
            let mut city = city(edge);
            let point = Vec2i::new(edge - 12, edge - 12);
            let center = (point.x * edge + point.y) as usize;

            for (mode, base) in [
                (MODE_ROAD, tiles::ROAD_STRAIGHT_1),
                (MODE_RAIL, tiles::RAIL_STRAIGHT_1),
                (MODE_POWER, tiles::POWER_LINE_STRAIGHT_1),
            ] {
                for direction in 0..4usize {
                    let near = point + DIRECTIONS[direction];
                    let cross = DIRECTIONS[(direction + 1) % 4];
                    let cells = [point, near, point + cross, point - cross];

                    for cell in cells {
                        let index = (cell.x * edge + cell.y) as usize;
                        city.xbld.data[index] = base as u8;
                        city.xbit.data[index] |= flag_bits::POWERABLE as u8;
                    }

                    let near_index = (near.x * edge + near.y) as usize;
                    city.xter.data[near_index] = if direction % 2 == 0 { 1 } else { 2 };
                    city.xbld.data[near_index] = (base + if direction % 2 == 0 { 2 } else { 3 }) as u8;

                    let maps = city.maps();
                    retile_surface(
                        maps.buildings,
                        maps.terrain,
                        maps.zones,
                        maps.flags,
                        maps.misc,
                        point,
                        mode,
                        maps.text_overlays,
                        edge,
                    );
                    assert_eq!(
                        city.xbld.data[center] as i64,
                        base + if direction % 2 == 0 { 1 } else { 0 },
                        "mode {mode} direction {direction}"
                    );

                    for cell in cells {
                        let index = (cell.x * edge + cell.y) as usize;
                        city.xbld.data[index] = 0;
                        city.xbit.data[index] = 0;
                    }

                    city.xter.data[near_index] = 0;
                }
            }
        }
    }
}
