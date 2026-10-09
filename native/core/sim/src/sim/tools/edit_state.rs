//! What a selected tool does in the current view, as ToolEditState.normal:
//! whether it works, how the cursor selects, and the status bar text.

use super::catalog;
use super::ids::{group, landscape};
use super::kinds::{Kind, kind};

/// The forest brush covers a square of this edge.
const FOREST_BRUSH: i64 = 7;

/// The views of the map.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum View {
    City,
    Underground,
    /// A data map such as crime or pollution.
    Data,
    Other,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct EditState {
    pub available: bool,
    pub enabled: bool,
    /// "point", "rectangle", or "path".
    pub selection: &'static str,
    pub area: i64,
    pub landscape: bool,
    /// True when a held cursor runs the click again on each new tile.
    pub repeat_placement: bool,
    pub show_status: bool,
    pub status_text: String,
    pub status_detail: String,
}

/// The state of a catalog tool. `available` follows the city and the debug
/// options; `dispatch_units` is the unit count of a dispatch tool.
pub fn normal(has_city: bool, available: bool, view: View, group_index: i64, subtool: i64, dispatch_units: i64) -> EditState {
    let kind = kind(group_index, subtool);
    let forest = group_index == group::LANDSCAPE && subtool == landscape::FOREST;
    let underground_network =
        (group_index == group::WATER || group_index == group::RAIL) && subtool == if group_index == group::WATER { 0 } else { 1 };
    let in_view = match view {
        View::City => true,
        View::Data => matches!(kind, Some(Kind::Query | Kind::Center)),
        View::Underground => underground_network || matches!(kind, Some(Kind::Demolish | Kind::Query | Kind::Center)),
        View::Other => false,
    };
    let selection = match kind {
        _ if forest => "point",
        Some(Kind::Zone | Kind::Demolish) => "rectangle",
        Some(Kind::Landscape | Kind::Network | Kind::Highway | Kind::Terrain) => "path",
        _ => "point",
    };
    let tool = catalog::tool(group_index, subtool);
    let area = match kind {
        _ if forest => FOREST_BRUSH,
        Some(Kind::Building) => tool.map_or(1, |entry| entry.area),
        _ => 1,
    };

    EditState {
        available,
        enabled: available && in_view && kind.is_some(),
        selection,
        area,
        landscape: kind == Some(Kind::Landscape),
        repeat_placement: matches!(
            kind,
            Some(Kind::Building | Kind::Hydro | Kind::SubwayToRail | Kind::Onramp | Kind::Tunnel | Kind::Dispatch)
        ),
        show_status: has_city,
        status_text: tool.map_or("Tool", |entry| entry.name).to_string(),
        status_detail: if has_city {
            status_detail(
                tool.map_or("Tool", |entry| entry.name),
                available,
                group_index,
                subtool,
                dispatch_units,
            )
        } else {
            String::new()
        },
    }
}

fn status_detail(name: &str, available: bool, group_index: i64, subtool: i64, dispatch_units: i64) -> String {
    if !available {
        return format!("{name} is not available in this city.");
    }

    if group_index == group::LANDSCAPE && subtool == landscape::FOREST {
        return "Place Forest selected. Hold to scatter trees in a seven-tile brush. Each tree placement costs $3. Hold Shift to Query."
            .into();
    }

    match kind(group_index, subtool) {
        Some(Kind::Zone) => {
            format!("{name} selected. Drag on the city map to zone. Use the mouse wheel to zoom and the right or middle button to pan.")
        }
        Some(Kind::Landscape) => format!("{name} selected. Drag to fill an area. Hold Shift to draw a line."),
        Some(Kind::Building) => format!("{name} selected. Click a clear city site to build it. Drag to build more."),
        Some(Kind::Network) => format!("{name} selected. Drag between city tiles to build a route."),
        Some(Kind::Hydro) => "Hydroelectric Power Plant selected. Click an unused waterfall tile.".into(),
        Some(Kind::SubwayToRail) => "Subway-to-Rail Connection selected. Click beside a rail or subway.".into(),
        Some(Kind::Onramp) => "On-ramp selected. Click on clear terrain between a highway and a perpendicular road.".into(),
        Some(Kind::Tunnel) => "Tunnel selected. Click a cardinal slope that faces through a hill.".into(),
        Some(Kind::Highway) => "Highway selected. Drag between city tiles to build a two-tile-wide route.".into(),
        Some(Kind::Demolish) => "Demolish selected. Drag to paint. Hold Shift before dragging to demolish a box.".into(),
        Some(Kind::Terrain) => format!("{name} selected. Click or drag across terrain."),
        Some(Kind::Dispatch) => {
            format!("{name} selected. Click dry, unlabeled terrain to deploy one of {dispatch_units} available units.")
        }
        Some(Kind::Sign) => "Place Sign selected. Click a city tile to add, edit, or remove a user sign.".into(),
        Some(Kind::Query) if subtool == 1 => {
            "Trip Query selected. Click a zone or network tile to show potential routes, trip cost, and growth access.".into()
        }
        Some(Kind::Query) if subtool == 2 => {
            "Tile Inspector selected. Point at a tile to read its stored values. Click to keep the panel on that tile.".into()
        }
        Some(Kind::Query) => "Query selected. Click a city tile to inspect it.".into(),
        Some(Kind::Center) => "Center View selected. Click a city tile to center the map on it.".into(),
        None => format!("{name} is in the original tool catalog. Its command is not implemented yet."),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn each_family_selects_its_own_way() {
        let state = |group_index, subtool, view| normal(true, true, view, group_index, subtool, 3);
        assert_eq!(state(group::RESIDENTIAL, 0, View::City).selection, "rectangle");
        assert_eq!(state(group::ROADS, 0, View::City).selection, "path");
        assert_eq!(
            (
                state(group::LANDSCAPE, landscape::FOREST, View::City).selection,
                state(group::LANDSCAPE, 3, View::City).area
            ),
            ("point", 7)
        );
        assert_eq!(state(group::SERVICES, 3, View::City).area, 4, "a building uses its catalog area");
        assert!(state(group::SERVICES, 3, View::City).repeat_placement);
        assert!(state(group::WATER, 0, View::Underground).enabled && !state(group::WATER, 1, View::Underground).enabled);
        assert!(state(group::QUERY, 0, View::Data).enabled && !state(group::ROADS, 0, View::Data).enabled);
        assert!(
            state(group::DISPATCH, 1, View::City)
                .status_detail
                .contains("one of 3 available units")
        );
        assert!(!state(group::DISPATCH, 3, View::City).enabled, "Cancel Dispatch has no command");
        assert!(normal(false, false, View::City, group::ROADS, 0, 0).status_detail.is_empty());
    }
}
