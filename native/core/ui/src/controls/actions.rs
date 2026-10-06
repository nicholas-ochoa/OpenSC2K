//! The action catalog with its default bindings. The ids are stored in the
//! settings file.

use std::sync::OnceLock;

/// Where an action works.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Scope {
    /// The city view with no dialog or text field in use.
    Map,
    /// Also while a text field has focus.
    Global,
    /// The SCURK editor only.
    Scurk,
    /// Every screen, as the media keys.
    Anywhere,
    /// Read-only help rows.
    Fixed,
}

/// How an action starts.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Kind {
    Press,
    Hold,
    Click,
    Drag,
    /// Changes another action while its key is down; several can share a key.
    Modifier,
}

#[derive(Clone, Debug)]
pub struct Action {
    pub id: String,
    pub label: String,
    pub category: &'static str,
    pub scope: Scope,
    pub kind: Kind,
    pub defaults: Vec<String>,
    /// The text of a fixed row, which has no binding.
    pub fixed_text: &'static str,
}

pub const TOOL_IDS: [&str; 18] = [
    "tool_bulldozer",
    "tool_landscape",
    "tool_dispatch",
    "tool_power",
    "tool_water",
    "tool_rewards",
    "tool_roads",
    "tool_rail",
    "tool_ports",
    "tool_residential",
    "tool_commercial",
    "tool_industrial",
    "tool_education",
    "tool_services",
    "tool_recreation",
    "tool_signs",
    "tool_query",
    "tool_center",
];
const TOOL_LABELS: [&str; 18] = [
    "Bulldozer",
    "Landscape",
    "Emergency dispatch",
    "Power",
    "Water",
    "Rewards",
    "Roads",
    "Rail",
    "Ports",
    "Residential zones",
    "Commercial zones",
    "Industrial zones",
    "Education",
    "City services",
    "Recreation",
    "Signs",
    "Query",
    "Center",
];
pub const SPEED_IDS: [&str; 5] = [
    "speed_pause",
    "speed_turtle",
    "speed_llama",
    "speed_cheetah",
    "speed_african_swallow",
];
pub const DATA_VIEW_IDS: [&str; 11] = [
    "view_density",
    "view_growth",
    "view_traffic",
    "view_pollution",
    "view_crime",
    "view_police_power",
    "view_fire_power",
    "view_land_value",
    "view_water_supply",
    "view_power_supply",
    "view_height",
];
const DATA_VIEW_TITLES: [&str; 11] = [
    "Density",
    "Rate of Growth",
    "Traffic",
    "Pollution",
    "Crime",
    "Police Power",
    "Fire Power",
    "Land Value",
    "Water Supply",
    "Power Supply",
    "Heightmap",
];
pub const SURFACE_LAYERS: [(&str, &str, &str); 11] = [
    ("view_show_buildings", "Show buildings", "buildings"),
    ("view_show_networks", "Show networks", "networks"),
    ("view_show_water", "Show water", "water"),
    ("view_show_trees", "Show trees", "trees"),
    ("view_show_zones", "Zones view", "zones"),
    ("view_show_signs", "Show signs", "signs"),
    ("view_show_pipes", "Show pipes", "pipes"),
    ("view_show_water_mains", "Show water mains", "water_mains"),
    ("view_show_vehicles", "Show vehicles", "vehicles"),
    ("view_show_subways", "Show subways", "subways"),
    ("view_show_tunnels", "Show tunnels", "tunnels"),
];
/// The Windows menu actions: id, label, menu id, and default bindings.
pub const WINDOW_ACTIONS: [(&str, &str, i64, &[&str]); 9] = [
    ("window_budget", "Budget", 0, &["key:B"]),
    ("window_ordinances", "Ordinances", 1, &[]),
    ("window_population", "Population", 2, &[]),
    ("window_industry", "Industry", 3, &[]),
    ("window_graphs", "Graphs", 4, &["key:G"]),
    ("window_neighbors", "Neighbors", 5, &[]),
    ("window_map", "Map", 6, &["key:M"]),
    ("window_scenario_goals", "Scenario goals", 8, &[]),
    ("window_debug", "Debug window", 7, &["key:F12"]),
];

struct Catalog(Vec<Action>);

impl Catalog {
    fn add(&mut self, id: &str, label: &str, category: &'static str, scope: Scope, kind: Kind, defaults: &[&str]) {
        self.0.push(Action {
            id: id.into(),
            label: label.into(),
            category,
            scope,
            kind,
            defaults: defaults.iter().map(|text| text.to_string()).collect(),
            fixed_text: "",
        });
    }

    fn fixed(&mut self, id: &str, label: &str, text: &'static str) {
        self.add(id, label, "Fixed", Scope::Fixed, Kind::Press, &[]);
        self.0.last_mut().expect("an action").fixed_text = text;
    }
}

fn build() -> Vec<Action> {
    use Kind::*;
    use Scope::*;

    let mac = cfg!(target_os = "macos");
    let mut c = Catalog(Vec::new());
    c.add("camera_up", "Move up", "Camera", Map, Hold, &["key:W", "key:Up"]);
    c.add("camera_left", "Move left", "Camera", Map, Hold, &["key:A", "key:Left"]);
    c.add("camera_down", "Move down", "Camera", Map, Hold, &["key:S", "key:Down"]);
    c.add("camera_right", "Move right", "Camera", Map, Hold, &["key:D", "key:Right"]);
    c.add("camera_fast", "Fast move (hold)", "Camera", Map, Modifier, &["key:Shift"]);
    c.add(
        "zoom_in",
        "Zoom in",
        "Camera",
        Map,
        Press,
        &["key:E", "key:Equal", "key:Plus", "key:Kp Add", "mouse:WheelUp"],
    );
    c.add(
        "zoom_out",
        "Zoom out",
        "Camera",
        Map,
        Press,
        &["key:Q", "key:Minus", "key:Kp Subtract", "mouse:WheelDown"],
    );
    c.add("zoom_reset", "Reset zoom to 100%", "Camera", Map, Press, &["key:0"]);
    c.add(
        "rotate_clockwise",
        "Rotate clockwise",
        "Camera",
        Map,
        Press,
        &["key:Period", "mouse:Extra2"],
    );
    c.add(
        "rotate_counter_clockwise",
        "Rotate counterclockwise",
        "Camera",
        Map,
        Press,
        &["key:Comma", "mouse:Extra1"],
    );

    c.add("speed_toggle_pause", "Pause or resume", "Speed", Map, Press, &["key:Space"]);
    c.add("speed_pause", "Pause", "Speed", Map, Press, &[]);
    c.add("speed_turtle", "Turtle", "Speed", Map, Press, &["key:1"]);
    c.add("speed_llama", "Llama", "Speed", Map, Press, &["key:2"]);
    c.add("speed_cheetah", "Cheetah", "Speed", Map, Press, &["key:3"]);
    c.add("speed_african_swallow", "African Swallow", "Speed", Map, Press, &["key:4"]);
    c.add("speed_faster", "Faster", "Speed", Map, Press, &[]);
    c.add("speed_slower", "Slower", "Speed", Map, Press, &[]);

    for (id, label) in TOOL_IDS.iter().zip(TOOL_LABELS) {
        let defaults: &[&str] = match *id {
            "tool_bulldozer" => &["key:X"],
            "tool_query" => &["key:Z"],
            "tool_center" => &["key:C"],
            _ => &[],
        };
        c.add(id, label, "Tools", Map, Press, defaults);
    }

    c.add("tool_next_subtool", "Next tool in group", "Tools", Map, Press, &["key:Tab"]);
    c.add(
        "tool_previous_subtool",
        "Previous tool in group",
        "Tools",
        Map,
        Press,
        &["key:Shift+Tab"],
    );
    c.add("brush_larger", "Larger brush", "Tools", Map, Press, &["key:BracketRight"]);
    c.add("brush_smaller", "Smaller brush", "Tools", Map, Press, &["key:BracketLeft"]);
    c.add("tool_previous", "Previous tool", "Tools", Map, Press, &[]);
    c.add("cancel_selection", "Cancel selection", "Tools", Map, Press, &[]);
    c.add(
        "tool_shape_modifier",
        "Line or rectangle (hold)",
        "Tools",
        Map,
        Modifier,
        &["key:Shift"],
    );
    c.add(
        "tool_query_modifier",
        "Query with any tool (hold)",
        "Tools",
        Map,
        Modifier,
        &["key:Shift"],
    );

    c.add("view_city", "City view", "View", Map, Press, &["key:V"]);
    c.add("view_toggle_underground", "Underground view", "View", Map, Press, &["key:U"]);

    for (id, title) in DATA_VIEW_IDS.iter().zip(DATA_VIEW_TITLES) {
        c.add(id, &format!("{title} view"), "View", Map, Press, &[]);
    }

    for (id, label, _) in SURFACE_LAYERS {
        c.add(id, label, "View", Map, Press, &[]);
    }

    c.add(
        "toggle_fullscreen",
        "Full screen",
        "View",
        Global,
        Press,
        if mac { &["key:Command+Ctrl+F"] } else { &["key:F11"] },
    );

    for (id, label, _, defaults) in WINDOW_ACTIONS {
        c.add(
            id,
            label,
            "Windows",
            if id == "window_debug" { Global } else { Map },
            Press,
            defaults,
        );
    }

    c.add("window_newspaper", "Latest newspaper", "Windows", Map, Press, &["key:N"]);
    c.add("window_console", "Console", "Windows", Anywhere, Press, &["key:Command+Shift+J"]);

    c.add(
        "music_play_pause",
        "Play or pause music",
        "Music",
        Anywhere,
        Press,
        &["key:MediaPlay"],
    );
    c.add("music_next", "Next track", "Music", Anywhere, Press, &["key:MediaNext"]);
    c.add("music_previous", "Previous track", "Music", Anywhere, Press, &["key:MediaPrevious"]);
    c.add("music_stop", "Stop music", "Music", Anywhere, Press, &["key:MediaStop"]);

    c.add("option_auto_budget", "Auto-Budget", "Options", Map, Press, &[]);
    c.add("option_auto_goto", "Auto-Goto", "Options", Map, Press, &[]);
    c.add("option_sound_effects", "Sound effects", "Options", Map, Press, &[]);
    c.add("option_music", "Music", "Options", Map, Press, &[]);
    c.add("settings", "Settings", "Options", Global, Press, &["key:Command+Comma"]);

    c.add("undo", "Undo", "File", Global, Press, &["key:Command+Z"]);
    c.add("file_new", "New city", "File", Global, Press, &["key:Command+N"]);
    c.add("file_open", "Open city", "File", Global, Press, &["key:Command+O"]);
    c.add("file_save", "Save city", "File", Global, Press, &["key:Command+S"]);
    c.add("file_save_as", "Save city as", "File", Global, Press, &["key:Command+Shift+S"]);
    c.add("file_rename", "Rename city", "File", Global, Press, &[]);
    c.add("file_export_png", "Export city as PNG", "File", Global, Press, &[]);
    c.add("file_main_menu", "Main menu", "File", Global, Press, &[]);

    c.add("map_use_tool", "Use tool", "Mouse", Fixed, Click, &["mouse:Left"]);
    c.add("map_context_menu", "Context menu", "Mouse", Map, Click, &["mouse:Right"]);
    c.add("map_center_on_tile", "Center on tile", "Mouse", Map, Click, &["mouse:Middle"]);
    c.add("map_pan", "Move map (drag)", "Mouse", Map, Drag, &["mouse:Right", "mouse:Middle"]);

    c.add("scurk_open", "Open tile set", "SCURK", Scurk, Press, &["key:Command+O"]);
    c.add("scurk_save", "Save tile set", "SCURK", Scurk, Press, &["key:Command+S"]);
    c.add("scurk_save_as", "Save tile set as", "SCURK", Scurk, Press, &["key:Command+Shift+S"]);
    c.add("scurk_undo", "Undo", "SCURK", Scurk, Press, &["key:Command+Z"]);
    c.add(
        "scurk_redo",
        "Redo",
        "SCURK",
        Scurk,
        Press,
        if mac {
            &["key:Command+Shift+Z", "key:Command+Y"]
        } else {
            &["key:Command+Y", "key:Command+Shift+Z"]
        },
    );
    c.add("scurk_select_all", "Select all", "SCURK", Scurk, Press, &["key:Command+A"]);
    c.add(
        "scurk_deselect",
        "Cancel selection",
        "SCURK",
        Scurk,
        Press,
        &["key:Command+Shift+A"],
    );
    c.add("scurk_cut", "Cut", "SCURK", Scurk, Press, &["key:Command+X"]);
    c.add("scurk_copy", "Copy", "SCURK", Scurk, Press, &["key:Command+C"]);
    c.add("scurk_paste", "Paste", "SCURK", Scurk, Press, &["key:Command+V"]);
    c.add(
        "scurk_cut_all_layers",
        "Cut from all layers",
        "SCURK",
        Scurk,
        Press,
        &["key:Command+Shift+X"],
    );
    c.add(
        "scurk_copy_all_layers",
        "Copy from all layers",
        "SCURK",
        Scurk,
        Press,
        &["key:Command+Shift+C"],
    );
    c.add(
        "scurk_paste_new_layer",
        "Paste as new layer",
        "SCURK",
        Scurk,
        Press,
        &["key:Command+Shift+V"],
    );
    c.add("scurk_duplicate", "Duplicate selection", "SCURK", Scurk, Press, &["key:Command+D"]);
    c.add(
        "scurk_delete",
        "Delete selection",
        "SCURK",
        Scurk,
        Press,
        &["key:Delete", "key:Backspace"],
    );
    c.add(
        "scurk_apply_paste",
        "Apply paste",
        "SCURK",
        Scurk,
        Press,
        &["key:Enter", "key:Kp Enter"],
    );
    c.add("scurk_brush_smaller", "Smaller brush", "SCURK", Scurk, Press, &["key:BracketLeft"]);
    c.add("scurk_brush_larger", "Larger brush", "SCURK", Scurk, Press, &["key:BracketRight"]);
    c.add(
        "scurk_pan",
        "Move canvas with the left button (hold)",
        "SCURK",
        Scurk,
        Modifier,
        &["key:Space"],
    );
    c.add(
        "scurk_compare",
        "Compare with the original (hold)",
        "SCURK",
        Scurk,
        Modifier,
        &["key:BackSlash"],
    );

    c.fixed("fixed_escape", "Cancel or close", "Esc");
    c.fixed(
        "fixed_shift_detail",
        "Exact data view values, deferred terrain stretch",
        "Hold Shift",
    );
    c.fixed("fixed_scurk", "SCURK nudge and selection modes", "Arrow keys, Shift, Ctrl");

    c.0
}

/// Every action, in menu order.
pub fn actions() -> &'static [Action] {
    static CATALOG: OnceLock<Vec<Action>> = OnceLock::new();

    CATALOG.get_or_init(build)
}

pub fn find(id: &str) -> Option<&'static Action> {
    actions().iter().find(|action| action.id == id)
}

/// The actions that a player can bind, with all but the fixed rows.
pub fn bindable_ids() -> impl Iterator<Item = &'static str> {
    actions()
        .iter()
        .filter(|action| action.scope != Scope::Fixed)
        .map(|action| action.id.as_str())
}
