//! Screen areas that changed between two revisions of the region source chunks,
//! as ApplicationStaticRender.changed_source_rects. The caller checks that each
//! chunk is present in both revisions with the same size.
use super::Rect;

/// Above this share of changed tiles, a full redraw is cheaper than patches.
const MAX_CHANGED_SHARE: f64 = 0.25;
const ROAD_THRESHOLDS: (u8, u8) = (85, 170);
const HIGHWAY_THRESHOLDS: (u8, u8) = (28, 56);
/// Traffic sprite variant of each XBLD tile from ROAD_STRAIGHT_1. Zero draws no traffic.
const TRAFFIC_TILE_FIRST: i32 = 0x1d;
const THING_FIRST: i32 = 201;
const THING_LAST: i32 = 240;
const EXTRA_THING: i32 = 8192;
const DEVELOPED_FIRST: i32 = 0x70;

/// One revision of the chunks that the static regions draw.
#[derive(Clone, Copy, Default)]
pub struct Chunks<'a> {
    pub altitude: &'a [u8],
    pub buildings: &'a [u8],
    pub terrain: &'a [u8],
    pub zones: &'a [u8],
    pub flags: &'a [u8],
    pub underground: &'a [u8],
    pub overlays: &'a [u8],
    pub traffic: &'a [u8],
}

impl<'a> Chunks<'a> {
    /// ALTM, XBLD, XTER, XZON, XBIT, XUND, XTXT, and XTRF, in that order.
    pub fn from_planes(data: [&'a [u8]; 8]) -> Self {
        Self {
            altitude: data[0],
            buildings: data[1],
            terrain: data[2],
            zones: data[3],
            flags: data[4],
            underground: data[5],
            overlays: data[6],
            traffic: data[7],
        }
    }
}

/// CityViewConfiguration fields.
#[derive(Clone, Copy, Default)]
pub struct View {
    pub tile_width: i32,
    pub tile_height: i32,
    pub half_width: i32,
    pub half_height: i32,
    pub altitude_step: i32,
    pub side_margin: i32,
    pub top_margin: i32,
}

pub struct Request<'a> {
    pub edge: usize,
    pub visible: i32,
    pub rotation: usize,
    pub view: View,
    pub output: Rect,
    /// The largest sprite width and height of the view.
    pub sprite_limit: (i32, i32),
    /// Width and height of each building sprite of the view, or -1 when missing.
    pub building_sprites: &'a [i32],
    /// Display-only object altitudes. Negative or absent means none.
    pub object_overrides: &'a [i32],
    pub before: Chunks<'a>,
    pub after: Chunks<'a>,
}

/// Changed screen rectangles, or `None` when a full redraw is better.
pub fn changed_rects(request: &Request) -> Option<Vec<Rect>> {
    let edge = request.edge;
    let cells = edge * edge;
    let mut dirty = vec![false; cells];
    let mut indices = Vec::new();
    let surface_only = request.visible >= 32;
    let (before, after) = (&request.before, &request.after);
    let mut planes = vec![
        (before.altitude, after.altitude, 2, 0xff),
        (before.buildings, after.buildings, 1, 0xff),
        (before.terrain, after.terrain, 1, 0xff),
        (before.zones, after.zones, 1, 0xff),
        (before.flags, after.flags, 1, if surface_only { 0xc6 } else { 0xff }),
    ];
    if !surface_only {
        planes.push((before.underground, after.underground, 1, 0xff));
    }
    for (old, new, stride, mask) in planes {
        if old.len() == new.len() && old.len() == cells * stride {
            changed_tiles(old, new, stride, 0, mask, &mut dirty, &mut indices);
        }
    }
    static_overlay_changes(before.overlays, after.overlays, cells, &mut dirty, &mut indices);
    if indices.len() as f64 > cells as f64 * MAX_CHANGED_SHARE {
        return None;
    }
    let view = request.view;
    let mut rects = Vec::with_capacity(indices.len());
    for index in indices {
        // some tile artwork depends on its neighbors. a neighbor is one half tile away
        let bounds = potential_tile_bounds(
            &view,
            request.sprite_limit,
            (index / edge) as i32,
            (index % edge) as i32,
            edge as i32,
        );
        let grown = Rect::new(
            bounds.x - view.half_width,
            bounds.y - view.half_height,
            bounds.w + view.half_width * 2,
            bounds.h + view.half_height * 2,
        );
        push_clipped(&mut rects, grown, request.output);
    }
    traffic_rects(request, &mut rects);
    Some(rects)
}

/// Mark each tile whose masked bytes differ. `plane_cells` folds the planes of
/// a wide XTXT into one tile index.
fn changed_tiles(before: &[u8], after: &[u8], stride: usize, plane_cells: usize, mask: u8, dirty: &mut [bool], indices: &mut Vec<usize>) {
    if before == after {
        return;
    }
    let shift = if stride == 2 { 1 } else { 0 };
    let size = before.len().min(after.len());
    let word_mask = u64::from_ne_bytes([mask; 8]);
    let mut offset = 0;
    while offset < size {
        // skip unchanged words; most bytes stay the same from day to day
        if offset + 8 <= size {
            let old = u64::from_ne_bytes(before[offset..offset + 8].try_into().expect("eight bytes"));
            let new = u64::from_ne_bytes(after[offset..offset + 8].try_into().expect("eight bytes"));
            if (old ^ new) & word_mask == 0 {
                offset += 8;
                continue;
            }
        }
        let end = (offset + 8).min(size);
        for byte in offset..end {
            if (before[byte] ^ after[byte]) & mask == 0 {
                continue;
            }
            let mut index = byte >> shift;
            if plane_cells > 0 {
                index %= plane_cells;
            }
            mark(index, dirty, indices);
        }
        offset = end;
    }
}

fn mark(index: usize, dirty: &mut [bool], indices: &mut Vec<usize>) {
    if index < dirty.len() && !dirty[index] {
        dirty[index] = true;
        indices.push(index);
    }
}

/// OverlayData.cells_for: a wide SC2X map stores a low and a high plane.
fn overlay_cells(bytes: usize) -> usize {
    if [131072, 294912, 524288, 819200, 2097152].contains(&bytes) {
        bytes / 2
    } else {
        bytes
    }
}

fn overlay(data: &[u8], index: usize) -> i32 {
    let cells = overlay_cells(data.len());
    i32::from(data[index])
        | if cells != data.len() {
            i32::from(data[cells + index]) << 8
        } else {
            0
        }
}

/// Moving objects and special overlays are not static region art.
fn dynamic_overlay(id: i32) -> bool {
    id == 0 || (THING_FIRST..=THING_LAST).contains(&id) || id >= EXTRA_THING || (0xfb..=0xff).contains(&id)
}

fn static_overlay_changes(before: &[u8], after: &[u8], cells: usize, dirty: &mut [bool], indices: &mut Vec<usize>) {
    if before == after || overlay_cells(after.len()) != cells || before.len() != after.len() {
        return;
    }
    let mut changed_flags = vec![false; cells];
    let mut changed = Vec::new();
    changed_tiles(before, after, 1, cells, 0xff, &mut changed_flags, &mut changed);
    for index in changed {
        if !dynamic_overlay(overlay(before, index)) || !dynamic_overlay(overlay(after, index)) {
            mark(index, dirty, indices);
        }
    }
}

/// IsometricGeometry.potential_tile_bounds: every sprite of one tile at any altitude.
fn potential_tile_bounds(view: &View, limit: (i32, i32), x: i32, y: i32, edge: i32) -> Rect {
    let screen_x = view.side_margin + edge * view.half_width + (x - y) * view.half_width;
    let flat_base_y = view.top_margin + (x + y) * view.half_height;
    let top = flat_base_y - 31 * view.altitude_step - view.altitude_step - limit.1;
    let bottom = flat_base_y + view.tile_height + limit.0 / 4 + 1;
    Rect::new(screen_x - limit.0, top, view.tile_width + limit.0 * 2 + 1, bottom - top)
}

fn push_clipped(rects: &mut Vec<Rect>, rect: Rect, output: Rect) {
    let clipped = rect.clip(output);
    if clipped.area() {
        rects.push(clipped);
    }
}

fn is_highway(tile: i32) -> bool {
    (0x49..=0x50).contains(&tile) || (0x61..=0x6b).contains(&tile)
}

/// Traffic level count of a road and of a highway, as ApplicationStaticRender._traffic_levels.
fn traffic_levels(density: u8) -> (u8, u8) {
    let level = |(low, high): (u8, u8)| u8::from(density > low) + u8::from(density > high);
    (level(ROAD_THRESHOLDS), level(HIGHWAY_THRESHOLDS))
}

/// IsometricStaticVisuals.traffic_level.
fn traffic_level(tile: i32, density: u8) -> u8 {
    let index = tile - TRAFFIC_TILE_FIRST;
    if index < 0 || index as usize >= super::painter::TRAFFIC.len() || super::painter::TRAFFIC[index as usize] == 0 {
        return 0;
    }
    let (low, high) = if is_highway(tile) { HIGHWAY_THRESHOLDS } else { ROAD_THRESHOLDS };
    u8::from(density > low) + u8::from(density > high)
}

/// Traffic is masked to its road sprite. Only that sprite's bounds can change.
fn traffic_rects(request: &Request, rects: &mut Vec<Rect>) {
    let (before, after) = (request.before.traffic, request.after.traffic);
    let edge = request.edge;
    let side = after.len().isqrt();
    let grid_edge = [edge, edge / 2, edge / 4]
        .into_iter()
        .find(|&grid| grid > 0 && grid * grid == after.len())
        .unwrap_or(0);
    if grid_edge == 0 || side != grid_edge || before == after || before.len() != after.len() {
        return;
    }
    let scale = edge / grid_edge;
    let view = request.view;
    let city = &request.after;
    for cell in 0..after.len() {
        if before[cell] == after[cell] || traffic_levels(before[cell]) == traffic_levels(after[cell]) {
            continue;
        }
        let (first_x, first_y) = ((cell / grid_edge) * scale, (cell % grid_edge) * scale);
        for x in first_x..first_x + scale {
            for y in first_y..first_y + scale {
                let i = x * edge + y;
                let building = i32::from(city.buildings[i]);
                if traffic_level(building, before[cell]) == traffic_level(building, after[cell])
                    || !visible(request, i)
                    || !should_draw_building(request, i, building)
                {
                    continue;
                }
                let (x, y) = (x as i32, y as i32);
                let width = request.building_sprites.get(building as usize * 2).copied().unwrap_or(-1);
                let height = request.building_sprites.get(building as usize * 2 + 1).copied().unwrap_or(-1);
                let bounds = if width < 0 {
                    potential_tile_bounds(&view, request.sprite_limit, x, y, edge as i32)
                } else {
                    let base_y = view.top_margin + (x + y) * view.half_height + view.tile_height
                        - object_altitude(request, i) * view.altitude_step
                        + baseline_offset(&view, building, surface_terrain(request, x, y), width);
                    Rect::new(
                        view.side_margin + (edge as i32 + x - y) * view.half_width,
                        base_y - height,
                        width,
                        height,
                    )
                };
                push_clipped(rects, bounds, request.output);
            }
        }
    }
}

fn word(request: &Request, i: usize) -> i32 {
    (i32::from(request.after.altitude[i * 2]) << 8) | i32::from(request.after.altitude[i * 2 + 1])
}

fn land(request: &Request, i: usize) -> i32 {
    word(request, i) & 31
}

fn water(request: &Request, i: usize) -> i32 {
    (word(request, i) >> 5) & 31
}

fn wet(request: &Request, i: usize) -> bool {
    request.after.flags[i] & 4 != 0
}

/// CityState.tile_is_visible.
fn visible(request: &Request, i: usize) -> bool {
    request.visible >= 32 || (if wet(request, i) { water(request, i) } else { land(request, i) }) < request.visible
}

/// IsometricStaticVisuals._should_draw_building: a building draws at its anchor corner.
fn should_draw_building(request: &Request, i: usize, building: i32) -> bool {
    if building <= 0x60 || (0x6c..=0x6f).contains(&building) {
        return true;
    }
    let anchor = [0x80, 0x10, 0x20, 0x40][request.rotation & 3];
    request.after.zones[i] & 0xf0 & anchor != 0
}

/// CityState.object_altitude.
fn object_altitude(request: &Request, i: usize) -> i32 {
    let cells = request.edge * request.edge;
    if request.object_overrides.len() == cells && request.object_overrides[i] >= 0 {
        return request.object_overrides[i];
    }
    if wet(request, i) { water(request, i) } else { land(request, i) }
}

/// IsometricGeometry.surface_terrain_id: level surface water below a higher bank is a waterfall.
fn surface_terrain(request: &Request, x: i32, y: i32) -> i32 {
    let edge = request.edge as i32;
    let i = (x * edge + y) as usize;
    let terrain = i32::from(request.after.terrain[i]);
    if !(0x30..=0x45).contains(&terrain) || terrain == 0x3e || water(request, i) != land(request, i) {
        return terrain;
    }
    for (dx, dy) in [(0, -1), (1, 0), (0, 1), (-1, 0)] {
        let (near_x, near_y) = (x + dx, y + dy);
        if near_x >= 0
            && near_y >= 0
            && near_x < edge
            && near_y < edge
            && land(request, (near_x * edge + near_y) as usize) > land(request, i)
        {
            return 0x3e;
        }
    }
    terrain
}

/// IsometricStaticVisuals.building_baseline_offset.
fn baseline_offset(view: &View, building: i32, terrain: i32, width: i32) -> i32 {
    if (0x61..=0x6b).contains(&building) {
        view.half_height
    } else if building >= DEVELOPED_FIRST {
        width / 4 - view.half_height
    } else if terrain == 0x0d {
        -view.altitude_step
    } else {
        0
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    const LARGE: View = View {
        tile_width: 32,
        tile_height: 17,
        half_width: 16,
        half_height: 8,
        altitude_step: 12,
        side_margin: 32,
        top_margin: 512,
    };

    struct Maps {
        altitude: Vec<u8>,
        cells: Vec<Vec<u8>>,
        overlays: Vec<u8>,
        traffic: Vec<u8>,
    }
    impl Maps {
        fn new(edge: usize) -> Self {
            Self {
                altitude: vec![0; edge * edge * 2],
                cells: vec![vec![0; edge * edge]; 5],
                overlays: vec![0; edge * edge],
                traffic: vec![0; edge * edge / 4],
            }
        }
        fn chunks(&self) -> Chunks<'_> {
            Chunks {
                altitude: &self.altitude,
                buildings: &self.cells[0],
                terrain: &self.cells[1],
                zones: &self.cells[2],
                flags: &self.cells[3],
                underground: &self.cells[4],
                overlays: &self.overlays,
                traffic: &self.traffic,
            }
        }
    }

    fn rects(edge: usize, before: &Maps, after: &Maps, sprites: &[i32]) -> Option<Vec<Rect>> {
        changed_rects(&Request {
            edge,
            visible: 32,
            rotation: 0,
            view: LARGE,
            output: Rect::new(0, 0, 4096 + (edge as i32 - 128) * 32, 2944 + (edge as i32 - 128) * 16),
            sprite_limit: (64, 100),
            building_sprites: sprites,
            object_overrides: &[],
            before: before.chunks(),
            after: after.chunks(),
        })
    }

    #[test]
    fn changed_tiles_report_grown_potential_bounds() {
        let edge = 16;
        let before = Maps::new(edge);
        let mut after = Maps::new(edge);
        after.cells[0][5 * edge + 6] = 0x70;
        let found = rects(edge, &before, &after, &[]).unwrap();
        let expected = potential_tile_bounds(&LARGE, (64, 100), 5, 6, edge as i32);
        assert_eq!(
            found,
            [Rect::new(expected.x - 16, expected.y - 8, expected.w + 32, expected.h + 16)]
        );
    }

    #[test]
    fn surface_views_ignore_underground_flags_and_moving_overlays() {
        let edge = 16;
        let before = Maps::new(edge);
        let mut after = Maps::new(edge);
        after.cells[3][3] = 0x08 | 0x01;
        after.cells[4][4] = 1;
        after.overlays[7] = 210;
        assert_eq!(rects(edge, &before, &after, &[]).unwrap(), []);
        after.overlays[7] = 5;
        assert_eq!(rects(edge, &before, &after, &[]).unwrap().len(), 1);
    }

    #[test]
    fn many_changes_request_a_full_redraw() {
        let edge = 16;
        let before = Maps::new(edge);
        let mut after = Maps::new(edge);
        after.cells[1][..edge * edge / 2].fill(1);
        assert!(rects(edge, &before, &after, &[]).is_none());
    }

    #[test]
    fn traffic_changes_report_road_sprites_at_new_levels() {
        let edge = 16;
        let mut before = Maps::new(edge);
        before.cells[0][2 * edge + 3] = TRAFFIC_TILE_FIRST as u8;
        let mut after = Maps::new(edge);
        after.cells[0][2 * edge + 3] = TRAFFIC_TILE_FIRST as u8;
        let mut sprites = vec![-1; 512];
        sprites[TRAFFIC_TILE_FIRST as usize * 2] = 32;
        sprites[TRAFFIC_TILE_FIRST as usize * 2 + 1] = 20;
        let block = edge / 2 + 1;
        after.traffic[block] = 90;
        let found = rects(edge, &before, &after, &sprites).unwrap();
        let base_y = 512 + 5 * 8 + 17;
        assert_eq!(found, [Rect::new(32 + (16 + 2 - 3) * 16, base_y - 20, 32, 20)]);
        after.traffic[block] = 80;
        before.traffic[block] = 60;
        assert_eq!(rects(edge, &before, &after, &sprites).unwrap(), []);
    }
}
