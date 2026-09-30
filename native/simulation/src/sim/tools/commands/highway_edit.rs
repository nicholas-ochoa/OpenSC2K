//! One segment of a highway drag, as HighwayEdit.

use super::highway_bridge::{self as bridges, BridgeMaps, Plan};
use super::highway_route::{self as routes, HighwayMaps, section_direction, section_has_water, section_is_existing_highway};
use super::network_bridge::{BRIDGE_CANCELLED, BRIDGE_UNSELECTED};
use super::network_edit::{CONNECTION_CANCELLED, CONNECTION_CONFIRMED, CONNECTION_UNSELECTED};
use super::route::RouteResult;
use super::{DIRECTIONS, EditBase, ToolArgs, scaled};
use crate::sim::city::City;
use crate::sim::geom::Vec2i;
use crate::sim::ids::sc2overlay_layout::CONNECTION_MARKER;
use crate::sim::overlay;
use crate::sim::tools::highway::{SECTION_OFFSETS, anchor_is_in_bounds, place_section, retile_route_sections, snap_anchor};
use crate::sim::value::Ints32;

/// A highway connection to a neighbor city costs this much.
pub const CONNECTION_COST: i64 = 1500;

/// The funds that the preview asks for one new section.
const PREVIEW_SECTION_FUNDS: i64 = 100;

/// The chunks that HighwayEdit checks: NetworkState.city_payloads.
pub const PAYLOAD_IDS: [&str; 8] = ["ALTM", "XBLD", "XTER", "XZON", "XUND", "XBIT", "XTXT", "MISC"];

/// The plan of one segment, as HighwayEdit.SegmentPlan.
#[derive(Default)]
struct SegmentPlan {
    start: Vec2i,
    finish: Vec2i,
    free_mode: bool,
    sections: Vec<Vec2i>,
    bridge_plan: Option<Plan>,
    bridge_attempted: bool,
    listed_route_cost: i64,
    route_cost: i64,
    selected_bridge: i64,
    listed_bridge_cost: i64,
    bridge_cost: i64,
    bridge_built: bool,
    bridge_error: String,
    connection_choice: i64,
    connection_anchor: Vec2i,
    connection_available: bool,
    connection_affordable: bool,
    connection_cost: i64,
    connection_built: bool,
    cost: i64,
    graded_sections: i64,
    bridge_sections: Vec<Vec2i>,
    bridge_endpoint_sections: Vec<Vec2i>,
}

impl SegmentPlan {
    fn has_bridge(&self) -> bool {
        self.bridge_plan.as_ref().is_some_and(|plan| plan.ok)
    }

    fn span_length(&self) -> i64 {
        self.bridge_plan.as_ref().map_or(0, |plan| plan.span_length)
    }
}

/// HighwayEdit.apply_segment.
pub fn apply_segment(
    city: &mut City,
    args: &ToolArgs,
    selected_start: Vec2i,
    selected_finish: Vec2i,
    connection_choice: i64,
    bridge_type: i64,
) -> RouteResult {
    let edge = city.map_size;
    let mut plan = SegmentPlan {
        start: snap_anchor(selected_start),
        finish: snap_anchor(selected_finish),
        free_mode: args.free_mode,
        selected_bridge: bridge_type,
        connection_choice,
        ..Default::default()
    };

    if !anchor_is_in_bounds(plan.start, edge) || !anchor_is_in_bounds(plan.finish, edge) {
        return RouteResult::rejected("highway is outside the city", 0);
    }

    let rejection = plan_route(city, &mut plan)
        .or_else(|| validate_route_cost(city, args, &mut plan))
        .or_else(|| validate_bridge_choice(city, &mut plan))
        .or_else(|| validate_connection_choice(city, &mut plan))
        .or_else(|| apply_plan(city, &mut plan));

    if let Some(rejection) = rejection {
        return rejection;
    }

    undo_record(args, plan, edge)
}

fn highway_maps(city: &City) -> HighwayMaps<'_> {
    HighwayMaps {
        buildings: &city.xbld.data,
        terrain: &city.xter.data,
        flags: &city.xbit.data,
        altitude: &city.altm.data,
        map_edge: city.map_size,
    }
}

fn bridge_maps(city: &City) -> BridgeMaps<'_> {
    BridgeMaps {
        buildings: &city.xbld.data,
        terrain: &city.xter.data,
        altitude: &city.altm.data,
        map_edge: city.map_size,
    }
}

/// Plan the flat sections, and a bridge where the route starts on or
/// reaches water. Returns a rejection when neither exists.
fn plan_route(city: &City, plan: &mut SegmentPlan) -> Option<RouteResult> {
    if city.missing_or_resized(&PAYLOAD_IDS).is_some() {
        return Some(RouteResult::rejected("required city data is missing or invalid", 0));
    }

    let edge = city.map_size;
    plan.sections = routes::plan_flat_route(&highway_maps(city), plan.start, plan.finish);

    if plan.sections.is_empty() && section_has_water(&city.xbit.data, plan.start, edge) {
        plan.bridge_attempted = true;
        plan.bridge_plan = Some(bridges::plan_bridge_from_start(
            &bridge_maps(city),
            plan.start,
            city.compass_rotation(),
        ));
    } else if let Some(&last) = plan.sections.last() {
        let exit = section_direction(&plan.sections, plan.sections.len() - 1, plan.finish);
        let bridge_start = last + scaled(DIRECTIONS[exit as usize], 2);

        if section_has_water(&city.xbit.data, bridge_start, edge) {
            plan.bridge_attempted = true;
            plan.bridge_plan = Some(bridges::scan_bridge(&bridge_maps(city), bridge_start, exit));
        }
    }

    if plan.sections.is_empty() && !plan.has_bridge() {
        if plan.bridge_attempted {
            let error = plan.bridge_plan.as_ref().map_or("", |bridge| bridge.error.as_str());

            return Some(RouteResult::rejected(error, 0));
        }

        return Some(RouteResult::rejected("highway cannot start on this section", 0));
    }

    None
}

/// Price the new sections. Existing highway sections are free.
fn validate_route_cost(city: &City, args: &ToolArgs, plan: &mut SegmentPlan) -> Option<RouteResult> {
    let new_sections = plan
        .sections
        .iter()
        .filter(|section| !section_is_existing_highway(&city.xbld.data, **section, city.map_size))
        .count() as i64;

    plan.listed_route_cost = new_sections * args.cost;
    plan.route_cost = if plan.free_mode { 0 } else { plan.listed_route_cost };

    if city.funds() < plan.route_cost {
        return Some(RouteResult::rejected("insufficient funds", plan.route_cost));
    }

    None
}

/// Ask for a bridge type when one is needed, check the chosen type, and decide
/// whether the funds cover it. A bridge that the city cannot afford is skipped
/// unless it is the whole segment.
fn validate_bridge_choice(city: &City, plan: &mut SegmentPlan) -> Option<RouteResult> {
    let selected = plan.selected_bridge;

    if let Some(bridge_plan) = plan.bridge_plan.as_ref().filter(|bridge| bridge.ok) {
        let choices = bridges::bridge_choices(bridge_plan);

        if selected == BRIDGE_UNSELECTED {
            let mut choice = RouteResult::rejected("highway bridge type selection is required", 0);
            choice.bridge_selection_required = true;
            choice.bridge_choices = choices;
            choice.bridge_span_length = bridge_plan.span_length;
            choice.route_cost = plan.route_cost;
            choice.listed_route_cost = plan.listed_route_cost;
            choice.base.free_mode = plan.free_mode;
            choice.sections = plan.sections.clone();

            return Some(choice);
        }

        if selected >= 0 && !choices.iter().any(|choice| choice.type_ == selected) {
            return Some(RouteResult::rejected("selected highway bridge is not available", 0));
        }
    } else if selected >= 0 {
        return Some(RouteResult::rejected("highway bridge is not available", 0));
    }

    if plan.has_bridge() && selected == BRIDGE_CANCELLED && plan.sections.is_empty() {
        let mut cancelled = RouteResult::rejected("bridge selection canceled", 0);
        cancelled.cancelled = true;

        return Some(cancelled);
    }

    if plan.has_bridge() && selected >= 0 {
        plan.listed_bridge_cost = plan.span_length() * bridges::bridge_cost(selected);
        plan.bridge_cost = if plan.free_mode { 0 } else { plan.listed_bridge_cost };

        if !plan.free_mode && city.funds() - plan.route_cost < plan.bridge_cost {
            plan.bridge_error = "insufficient funds for the highway bridge".to_string();

            if plan.sections.is_empty() {
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
    let start_index = plan.start.x * edge + plan.start.y;
    plan.connection_anchor = plan.sections.last().copied().unwrap_or(plan.start);
    plan.connection_available = !plan.bridge_attempted
        && !plan.sections.is_empty()
        && routes::is_connection_exit(&plan.sections, plan.finish, edge)
        && overlay::marker_at(&city.xtxt.data, start_index) != CONNECTION_MARKER;
    plan.connection_affordable = plan.free_mode || city.funds() - plan.route_cost >= CONNECTION_COST;
    plan.connection_cost = if plan.free_mode { 0 } else { CONNECTION_COST };

    if plan.connection_available && plan.connection_affordable && plan.connection_choice == CONNECTION_UNSELECTED {
        let mut confirmation = RouteResult::rejected("neighbor connection confirmation is required", 0);
        confirmation.connection_selection_required = true;
        confirmation.connection_anchor = plan.connection_anchor;
        confirmation.connection_cost = plan.connection_cost;
        confirmation.listed_connection_cost = CONNECTION_COST;
        confirmation.route_cost = plan.route_cost;
        confirmation.listed_route_cost = plan.listed_route_cost;
        confirmation.base.free_mode = plan.free_mode;
        confirmation.sections = plan.sections.clone();

        return Some(confirmation);
    }

    if plan.connection_choice == CONNECTION_CONFIRMED {
        if !plan.connection_available {
            return Some(RouteResult::rejected("neighbor connection is not available", 0));
        }

        if !plan.connection_affordable {
            return Some(RouteResult::rejected("insufficient funds", plan.route_cost + CONNECTION_COST));
        }
    }

    plan.connection_built = plan.connection_choice == CONNECTION_CONFIRMED;
    plan.cost = plan.route_cost
        + if plan.bridge_built { plan.bridge_cost } else { 0 }
        + if plan.connection_built { plan.connection_cost } else { 0 };

    None
}

/// Place the sections, the connection label, and the bridge, and charge the
/// funds. A section that cannot hold its grade rejects the segment.
fn apply_plan(city: &mut City, plan: &mut SegmentPlan) -> Option<RouteResult> {
    let edge = city.map_size;
    let rotation = city.compass_rotation();
    let funds = city.funds();
    let mut directions = Vec::with_capacity(plan.sections.len());
    let mut maps = city.maps();

    for index in 0..plan.sections.len() {
        let direction = section_direction(&plan.sections, index, plan.finish);
        let section = plan.sections[index];

        directions.push((section, direction));

        if section_is_existing_highway(maps.buildings, section, edge) {
            continue;
        }

        let placement = place_section(&mut maps, section, direction, rotation);

        if !placement.ok {
            return Some(RouteResult::rejected(placement.error, 0));
        }

        if placement.graded {
            plan.graded_sections += 1;
        }
    }

    if plan.connection_built {
        let anchor = plan.connection_anchor;
        overlay::write(maps.text_overlays, anchor.x * edge + anchor.y, CONNECTION_MARKER);
    }

    retile_route_sections(&mut maps, &plan.sections, rotation, &directions);

    if plan.bridge_built
        && let Some(bridge_plan) = &plan.bridge_plan
    {
        let placed = bridges::place_bridge(&mut maps, bridge_plan, plan.selected_bridge, rotation);
        plan.bridge_sections = placed.sections;
        plan.bridge_endpoint_sections = placed.endpoint_sections;
    }

    city.set_funds(funds - plan.cost);

    None
}

/// Describe the stored segment.
fn undo_record(args: &ToolArgs, plan: SegmentPlan, edge: i64) -> RouteResult {
    let bridge_built = plan.bridge_built;
    let connection_built = plan.connection_built;
    let mut affected = plan.sections.clone();

    for anchor in plan.bridge_sections.iter().chain(&plan.bridge_endpoint_sections) {
        if !affected.contains(anchor) {
            affected.push(*anchor);
        }
    }

    let tile_indices = affected
        .iter()
        .flat_map(|anchor| SECTION_OFFSETS.map(|offset| ((anchor.x + offset.x) * edge + anchor.y + offset.y) as i32))
        .collect();

    let mut result = RouteResult {
        base: EditBase::accepted("highway", args.group, args.subtool),
        start: plan.start,
        finish: plan.finish,
        sections: plan.sections.clone(),
        route_cost: plan.route_cost,
        listed_route_cost: plan.listed_route_cost,
        bridge_built,
        bridge_cancelled: plan.has_bridge() && plan.selected_bridge == BRIDGE_CANCELLED,
        bridge_sections: plan.bridge_sections.clone(),
        bridge_endpoint_sections: plan.bridge_endpoint_sections.clone(),
        bridge_span_length: plan.span_length(),
        bridge_error: if plan.bridge_attempted {
            plan.bridge_error.clone()
        } else {
            String::new()
        },
        connection_built,
        connection_cancelled: plan.connection_available && plan.connection_choice == CONNECTION_CANCELLED,
        connection_anchor: plan.connection_anchor,
        graded_sections: plan.graded_sections,
        connection_error: if plan.connection_available && !plan.connection_affordable {
            "insufficient funds for the neighbor connection".to_string()
        } else {
            String::new()
        },
        stopped_early: !bridge_built && plan.sections.last() != Some(&plan.finish),
        ..Default::default()
    };

    if bridge_built {
        if let Some(bridge_plan) = &plan.bridge_plan {
            result.bridge_exit = bridge_plan.start + scaled(DIRECTIONS[bridge_plan.direction as usize], bridge_plan.span_length * 2);
        }

        result.bridge_type = plan.selected_bridge;
        result.bridge_name = bridges::bridge_type_name(plan.selected_bridge);
        result.bridge_cost = plan.bridge_cost;
        result.listed_bridge_cost = plan.listed_bridge_cost;
    }

    if connection_built {
        result.connection_cost = plan.connection_cost;
        result.listed_connection_cost = CONNECTION_COST;
    }

    result.base.tile_indices = Ints32(tile_indices);
    result.base.cost = plan.cost;
    result.base.listed_cost = plan.listed_route_cost
        + if bridge_built { plan.listed_bridge_cost } else { 0 }
        + if connection_built { CONNECTION_COST } else { 0 };
    result.base.free_mode = plan.free_mode;

    result
}

/// HighwayEdit.preview_error: empty when a click can start a highway at `selected`.
pub fn preview_error(city: &City, selected: Vec2i) -> String {
    let edge = city.map_size;
    let anchor = snap_anchor(selected);

    if !anchor_is_in_bounds(anchor, edge) {
        return "The 2 by 2 highway section extends outside the map.".to_string();
    }

    let sections = routes::plan_flat_route(&highway_maps(city), anchor, anchor);

    if !sections.is_empty() {
        if section_is_existing_highway(&city.xbld.data, anchor, edge) || city.funds() >= PREVIEW_SECTION_FUNDS {
            return String::new();
        }
    } else if section_has_water(&city.xbit.data, anchor, edge) {
        let bridge = bridges::plan_bridge_from_start(&bridge_maps(city), anchor, city.compass_rotation());

        if bridge.ok && bridges::bridge_choices(&bridge).iter().any(|choice| city.funds() >= choice.cost) {
            return String::new();
        }
    }

    if section_has_water(&city.xbit.data, anchor, edge) {
        let bridge = bridges::plan_bridge_from_start(&bridge_maps(city), anchor, city.compass_rotation());

        if !bridge.ok {
            return bridge.error;
        }

        return "Insufficient funds for this highway bridge.".to_string();
    }

    if city.funds() < PREVIEW_SECTION_FUNDS {
        return "Insufficient funds for this highway section.".to_string();
    }

    routes::blocked_section_error(&city.xbld.data, anchor, edge).to_string()
}
