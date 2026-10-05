//! Terrain editor actions, as LandscapeEditorCommand: stretch, sea level,
//! forest, and stream. Each action is one undo unit.

use crate::sim::city::{CHUNK_IDS, City};
use crate::sim::geom::Vec2i;
use crate::sim::ids::sc2misc_layout as misc_layout;
use crate::sim::random::SimRandom;
use crate::sim::tools::commands::landscape::terrain::{self, SUBTOOL_LOWER, SUBTOOL_RAISE, TerrainPath, TerrainResult};
use crate::sim::tools::commands::landscape::{self, SUBTOOL_TREES};
use crate::sim::tools::commands::{EditBase, ToolArgs};
use crate::sim::tools::new_terrain::editor_stream;
use crate::sim::tools::terrain::retile_region;
use crate::sim::value::Ints32;

/// CityToolIds.Group and the editor subtools.
const GROUP_BULLDOZER: i64 = 0;
const GROUP_LANDSCAPE: i64 = 1;
const SUBTOOL_STRETCH: i64 = 5;
const SUBTOOL_RAISE_SEA: i64 = 6;
const SUBTOOL_FOREST: i64 = 3;

/// A stretch moves the ground at most this many levels.
const MAX_STRETCH: i64 = 31;

/// The highest sea level.
const MAX_SEA_LEVEL: i64 = 31;

/// A forest action plants trees in three passes.
const FOREST_PASSES: usize = 3;

/// An editor stream runs this many steps.
const STREAM_LENGTH: i64 = 128;

/// LandscapeEditorCommand.apply. The edit runs on a copy; the city takes the
/// changed chunks only when one changed.
pub fn apply(city: &mut City, group: i64, subtool: i64, point: Vec2i, random: &mut SimRandom, stretch_levels: i64) -> TerrainResult {
    let edge = city.map_size;

    if city.index_of(point.x, point.y) < 0 {
        return TerrainResult::rejected("invalid landscape edit", 0);
    }

    let mut staged = city.clone();
    let mut staged_random = SimRandom::new(random.state);
    let before = random.state;

    if group == GROUP_BULLDOZER && subtool == SUBTOOL_STRETCH {
        let step_tool = ToolArgs {
            group: GROUP_BULLDOZER,
            subtool: if stretch_levels > 0 { SUBTOOL_RAISE } else { SUBTOOL_LOWER },
            cost: 0,
            free_mode: true,
        };

        let points = [point];
        let path = TerrainPath {
            start: point,
            points: &points,
            target_override: -1,
        };

        for _ in 0..MAX_STRETCH.min(stretch_levels.abs()) {
            if !terrain::apply(&mut staged, &step_tool, &path, Some(&mut staged_random)).base.ok {
                break;
            }
        }
    } else if group == GROUP_LANDSCAPE && subtool == SUBTOOL_FOREST {
        let trees = ToolArgs {
            group: GROUP_LANDSCAPE,
            subtool: SUBTOOL_TREES,
            cost: 0,
            free_mode: true,
        };

        let mut points = Vec::new();

        for x in -3..4 {
            for y in -3..4 {
                if x * x + y * y <= 10 {
                    points.push(point + Vec2i::new(x + 3, y + 3));
                }
            }
        }

        for _ in 0..FOREST_PASSES {
            landscape::apply(&mut staged, &trees, &points, &mut staged_random, false);
        }
    } else if group == GROUP_LANDSCAPE {
        // The generator stream and its waterfall repair.
        if stream_data_valid(&staged) {
            editor_stream(&mut staged, point, STREAM_LENGTH, &mut staged_random);
        }
    } else {
        let step = if subtool == SUBTOOL_RAISE_SEA { 1 } else { -1 };
        let sea = (staged.misc_u32(misc_layout::WATER_LEVEL) + step).clamp(0, MAX_SEA_LEVEL);
        staged.set_misc_u32(misc_layout::WATER_LEVEL, sea);

        let indices: Vec<i64> = (0..edge * edge).collect();
        let maps = staged.maps();
        retile_region(
            maps.altitude,
            maps.buildings,
            maps.terrain,
            maps.zones,
            maps.flags,
            maps.misc,
            &indices,
            sea,
            edge,
        );
    }

    let changed = CHUNK_IDS.iter().any(|id| {
        let old = city.chunk(id);
        let new = staged.chunk(id);

        matches!((old, new), (Some(old), Some(new)) if old.present && new.present && old.data != new.data)
    });

    if !changed {
        return TerrainResult::rejected("no eligible terrain changed", 0);
    }

    // Keep the written flags of the city: the bridge compares every chunk with
    // its original payload.
    for id in CHUNK_IDS {
        if let (Some(target), Some(source)) = (city.chunk_mut(id), staged.chunk(id))
            && source.present
        {
            target.data.clone_from(&source.data);
        }
    }

    random.state = staged_random.state;

    let mut result = TerrainResult {
        base: EditBase::accepted("terrain", group, subtool),
        action_count: 1,
        random_used: before != random.state,
        ..Default::default()
    };

    result.base.tile_indices = Ints32((0..(edge * edge) as i32).collect());
    result.base.free_mode = true;
    result.base.tracks_random = true;
    result.base.random_state_before = before;
    result.base.random_state_after = random.state;

    result
}

/// The map chunks that a stream reads, at the map size.
fn stream_data_valid(city: &City) -> bool {
    let cells = (city.map_size * city.map_size) as usize;

    city.altm.data.len() == cells * 2
        && [&city.xter, &city.xbld, &city.xzon, &city.xbit]
            .iter()
            .all(|chunk| chunk.data.len() == cells)
        && city.xtxt.data.len() >= cells
}
