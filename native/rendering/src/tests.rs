use super::ids::building_tile_ids as tiles;
use super::painter::TRAFFIC;
use super::*;

#[test]
fn forests_keep_density_clearings_and_local_cache_invalidation() {
    for view in 0..3 {
        let mut b = fixture(16, view);
        b.config.natural_forests = true;
        for id in 6..=12 {
            let original = b.sprites.images[&((view * 500 + id) as u64 * 2)].clone();
            for variant in 0..128 {
                b.sprites.images.insert(
                    ((nature::FIRST + variant * nature::SPAN + view * 500 + id) * 2) as u64,
                    original.clone(),
                );
            }
        }
        for x in 4..10 {
            for y in 4..10 {
                let i = b.city.index(x, y);
                b.city.buildings[i] = tiles::TREES_7;
            }
        }
        let clearing = b.city.index(7, 7);
        b.city.buildings[clearing] = 0;
        let before = b.city.clone();
        assert_eq!(b.paint(7, 7).unwrap().len(), 1, "empty clearing acquired trees");
        for density in 6..=12 {
            b.city.buildings[clearing] = density;
            let id = b.paint(7, 7).unwrap()[1].sprite;
            assert_eq!(nature::original(id), view * 500 + i32::from(density));
            assert_eq!((id - nature::FIRST) / nature::SPAN / 8, 15);
        }
        b.city.buildings[clearing] = 0;
        let full = Rect::new(0, 0, 4096, 4096);
        let original = b.region(full).unwrap();
        let total = b.builds;
        let atlas_revision = b.atlas.revision;
        let again = b.region(full).unwrap();
        assert_eq!(b.builds, total);
        assert_eq!(b.atlas.revision, atlas_revision);
        assert_eq!(original.vertices, again.vertices);
        assert_eq!(original.uvs, again.uvs);
        let old_neighbor = b.forest_sprite(6, 6, view * 500 + 12);
        let far = b.forest_sprite(9, 9, view * 500 + 12);
        let mut edited = b.city.clone();
        let cut = edited.index(6, 5);
        edited.buildings[cut] = 0;
        b.update(edited);
        b.region(full).unwrap();
        assert_eq!(b.builds - total, 9);
        assert_ne!(b.forest_sprite(6, 6, view * 500 + 12), old_neighbor);
        assert_eq!(b.forest_sprite(9, 9, view * 500 + 12), far);
        assert_eq!(b.city.terrain, before.terrain);
        assert_eq!(b.city.altitude, before.altitude);
        assert_eq!(b.city.zones, before.zones);
        assert_eq!(b.city.flags, before.flags);
        b.config.natural_forests = false;
        assert_eq!(b.paint(6, 6).unwrap()[1].sprite, view * 500 + 12);
        b.config.natural_forests = true;
        for (x, y) in [(0, 0), (15, 0), (0, 15), (15, 15)] {
            let i = b.city.index(x, y);
            b.city.buildings[i] = tiles::TREES_7;
            assert_eq!((b.forest_sprite(x, y, view * 500 + 12) - nature::FIRST) / nature::SPAN / 8, 0);
        }
    }
}

#[test]
fn individual_traffic_replaces_supported_patterns_without_changing_the_city() {
    let mut original = fixture(8, 2);
    original.city.traffic = vec![255; 16];
    original.city.buildings[3 * 8 + 3] = 0x1d;
    original.city.buildings[3 * 8 + 4] = 0x57;
    let before = original.city.clone();
    let classic = original.paint(3, 3).unwrap();
    original.config.individual_traffic = true;
    let enhanced = original.paint(3, 3).unwrap();
    assert!(classic.iter().any(|draw| draw.image >= 1_u64 << 32));
    assert!(!enhanced.iter().any(|draw| draw.image >= 1_u64 << 32));
    assert!(!original.paint(3, 4).unwrap().iter().any(|draw| draw.image >= 1_u64 << 32));
    for tile in
        (tiles::ROAD_STRAIGHT_1..=tiles::REINFORCED_HIGHWAY_BRIDGE).filter(|tile| TRAFFIC[usize::from(tile - tiles::ROAD_STRAIGHT_1)] != 0)
    {
        original.city.buildings[3 * 8 + 3] = tile;
        original.city.zones[3 * 8 + 3] = 0x80;
        original.config.individual_traffic = false;
        let classic = original.paint(3, 3).unwrap();
        original.config.individual_traffic = true;
        let enhanced = original.paint(3, 3).unwrap();
        assert!(classic.iter().any(|draw| draw.image >= 1_u64 << 32), "classic tile {tile:#x}");
        assert!(!enhanced.iter().any(|draw| draw.image >= 1_u64 << 32), "enhanced tile {tile:#x}");
    }
    original.city.buildings = before.buildings.clone();
    original.city.zones = before.zones.clone();
    assert_eq!(before.traffic, original.city.traffic);
    assert_eq!(before.buildings, original.city.buildings);
}

fn fixture(edge: i32, view: i32) -> Builder {
    let cells = (edge * edge) as usize;
    let city = City {
        edge,
        visible: 32,
        rotation: 0,
        altitude: vec![0; cells],
        terrain: vec![0; cells],
        buildings: vec![0; cells],
        zones: vec![0; cells],
        flags: vec![0; cells],
        overlays: vec![0; cells],
        underground: vec![0; cells],
        ..Default::default()
    };

    let mut images = HashMap::new();

    for id in view * 500..view * 500 + 500 {
        images.insert(
            id as u64 * 2,
            Sprite {
                w: 2,
                h: 2,
                rgba: vec![161, 161, 161, 255, 20, 20, 20, 255, 30, 30, 30, 255, 40, 40, 40, 255],
                la: vec![161, 255, 20, 255, 30, 255, 40, 255],
            },
        );
    }

    Builder::new(
        city,
        Config {
            view,
            underground: false,
            pipes: true,
            subways: true,
            tunnels: true,
            mains: true,
            redraw_ground: false,
            specials: false,
            individual_traffic: false,
            natural_forests: false,
            natural_terrain: false,
            phase: 0,
        },
        images,
        [161, 161, 161, 255],
        2048,
        true,
    )
    .unwrap()
}

#[test]
fn clipping_keeps_edge_contact_empty() {
    let a = Rect::new(-5, -2, 10, 4);
    assert_eq!(a.clip(Rect::new(0, 0, 10, 10)), Rect::new(0, 0, 5, 2));
    assert!(!a.clip(Rect::new(5, 0, 1, 1)).area());
}

#[test]
fn sprite_flip_and_traffic_mask_preserve_hidden_colors() {
    let mut b = fixture(4, 2);
    let original = b.sprites.get(1256, false).unwrap();
    let flipped = b.sprites.get(1256, true).unwrap();
    assert_eq!(b.sprites.images[&flipped].la, [20, 255, 161, 255, 40, 255, 30, 255]);
    let masked = b.sprites.traffic(flipped, original);
    assert_eq!(b.sprites.images[&masked].la, [20, 255, 161, 0, 40, 0, 30, 0]);
    assert_eq!(b.sprites.images[&flipped].la[3], 255);
}

#[test]
fn atlas_growth_keeps_existing_slots_and_pixels() {
    let mut atlas = sprites::Atlas::new(2048);
    let sprite = Sprite {
        w: 2046,
        h: 2046,
        rgba: vec![],
        la: vec![77; 2046 * 2046 * 2],
    };

    let first = atlas.slot(1, &sprite).unwrap();
    atlas.slot(2, &sprite).unwrap();
    assert_eq!(atlas.edge, 4096);
    assert_eq!(atlas.slots[&1], first);
    assert_eq!(atlas.data[((first.y * atlas.edge + first.x) * 2) as usize], 77);
    let revision = atlas.revision;
    assert_eq!(atlas.slot(1, &sprite).unwrap(), first);
    assert_eq!(revision, atlas.revision);
}

#[test]
fn region_reuse_and_neighbor_edits_do_not_retain_stale_draws() {
    let mut b = fixture(8, 2);
    let i = b.city.index(3, 3);
    b.city.terrain[i] = 0x30;
    b.city.flags[i] = 4;
    let bounds = Rect::new(0, 0, 600, 700);
    let first = b.region(bounds).unwrap();
    let builds = b.builds;
    assert!(!first.draws.is_empty());
    assert_eq!(b.region(bounds).unwrap().vertices, first.vertices);
    assert_eq!(b.builds, builds);
    b.update(b.city.clone());
    assert_eq!(b.reuses, 0);
    b.region(bounds).unwrap();
    assert_eq!(b.reuses, builds);
    b.region(bounds).unwrap();
    assert_eq!(b.reuses, builds);
    let mut changed = b.city.clone();
    let near = changed.index(4, 3);
    changed.altitude[near] = 4;
    b.update(changed);
    b.region(bounds).unwrap();
    assert!(b.builds > builds);
    assert!(b.tiles[&i].draws.iter().any(|d| d.sprite == 1284));
}

#[test]
fn power_crossing_keeps_train_fields_and_painter_order() {
    let mut b = fixture(4, 2);
    let i = b.city.index(1, 1);
    b.city.buildings[i] = 0x4f;
    let draws = b.paint(1, 1).unwrap();
    let crossing = draws.iter().find(|d| d.sprite == 1079).unwrap();
    assert_eq!(crossing.reference, 1073);
    assert_eq!(crossing.deck, 1073);
    assert_eq!(crossing.thickness, 3);
    assert!(crossing.requires_depth);
    assert_eq!(crossing.depth, 9);
    assert_eq!(crossing.order, (9 << 16) | 1);
}

#[test]
fn underground_tunnel_and_hidden_subway_are_separate_depths() {
    let mut b = fixture(4, 2);
    b.config.underground = true;
    b.city.visible = 4;
    let i = b.city.index(1, 1);
    b.city.altitude[i] = 5 | (3 << 10);
    b.city.underground[i] = 1;
    let draws = b.paint(1, 1).unwrap();
    assert_eq!(draws.len(), 1);
    assert_eq!(draws[0].image, 1352 * 2);
    b.city.visible = 5;
    let draws = b.paint(1, 1).unwrap();
    assert_eq!(draws.len(), 2);
    assert!(draws.iter().all(|d| d.depth == -1));
}

#[test]
fn hidden_tunnels_leave_the_underground_tile() {
    let mut b = fixture(4, 2);
    b.config.underground = true;
    b.city.visible = 5;
    let i = b.city.index(1, 1);
    b.city.altitude[i] = 5 | (3 << 10);
    b.city.underground[i] = 1;
    let shown = b.paint(1, 1).unwrap();
    b.config.tunnels = false;
    let hidden = b.paint(1, 1).unwrap();
    assert_eq!(hidden.len(), shown.len() - 1);
    assert!(hidden.iter().all(|d| d.sprite != b.config.base() + 0x160));
}

#[test]
fn object_overrides_expand_the_region_candidate_span() {
    let mut b = fixture(128, 2);
    let i = b.city.index(64, 64);
    b.city.buildings[i] = 6;
    let mut city = b.city.clone();
    city.objects = vec![-1; 128 * 128];
    city.objects[i] = 31;
    b.update(city);
    assert_eq!(b.maximum_altitude, 31);
    let draws = b.paint(64, 64).unwrap();
    let tree = draws.iter().find(|d| d.sprite == 1006).unwrap();
    let region = b.region(tree.rect).unwrap();
    assert!(region.draws.iter().any(|d| d.sprite == 1006 && d.rect == tree.rect));
}

#[test]
fn original_dispatch_requires_matching_overlay_and_skips_record_zero() {
    let mut city = fixture(128, 2).city;
    let mut things = vec![0; 480];

    for (record, kind, x, y, sprite) in [(0, 7, 1, 1, 382), (1, 7, 2, 3, 382), (2, 8, 4, 5, 383), (39, 14, 6, 7, 384)] {
        things[record * 12] = kind;
        things[record * 12 + 3] = x;
        things[record * 12 + 4] = y;
        let index = city.index(i32::from(x), i32::from(y));
        city.overlays[index] = 201 + record as u8;
        city.set_dispatch(&things);
        assert_eq!(city.dispatch.get(&index), (record != 0).then_some(&sprite));
    }

    assert_eq!(city.dispatch.len(), 3);
    let index = city.index(2, 3);
    city.overlays[index] = 203;
    city.set_dispatch(&things);
    assert!(!city.dispatch.contains_key(&index));

    // Coordinates outside this map must not alias a valid map cell.
    things[2 * 12 + 3] = 128;
    city.set_dispatch(&things);
    assert_eq!(city.dispatch.len(), 1);
    things.fill(0);
    city.set_dispatch(&things);
    assert!(city.dispatch.is_empty());
}

#[test]
fn extended_dispatch_reads_coordinate_planes_and_extended_overlay_ids() {
    let mut city = fixture(512, 2).city;
    let cells = (city.edge * city.edge) as usize;
    city.overlays.resize(cells * 2, 0);
    let mut things = vec![0; 640 * 24];
    let high = things.len() / 2;

    for (record, kind, x, y, overlay, sprite) in [
        (39, 7, 300, 400, 240, 382),
        (40, 8, 301, 401, 8192, 383),
        (511, 14, 511, 300, 8663, 384),
    ] {
        things[record * 12] = kind;
        things[record * 12 + 3] = x as u8;
        things[record * 12 + 4] = y as u8;
        things[high + record * 12 + 3] = (x >> 8) as u8;
        things[high + record * 12 + 4] = (y >> 8) as u8;
        let index = city.index(x, y);
        city.overlays[index] = overlay as u8;
        city.overlays[cells + index] = (overlay >> 8) as u8;
        city.set_dispatch(&things);
        assert_eq!(city.dispatch.get(&index), Some(&sprite));
    }

    assert_eq!(city.dispatch.len(), 3);
    let index = city.index(301, 401);
    city.overlays[cells + index] = 0;
    city.set_dispatch(&things);
    assert!(!city.dispatch.contains_key(&index));
    things[511 * 12] = 1;
    city.set_dispatch(&things);
    assert_eq!(city.dispatch.len(), 1);
    city.set_dispatch(&[]);
    assert!(city.dispatch.is_empty());
}

#[test]
fn artwork_is_packed_before_the_first_region() {
    let mut b = fixture(8, 2);
    let revision = b.atlas.revision;
    assert_eq!(b.atlas.slots.len(), 500);
    b.region(Rect::new(0, 0, 600, 700)).unwrap();
    assert_eq!(b.atlas.revision, revision, "unflipped artwork must not change the atlas");
}

#[test]
fn known_bounds_skip_outside_tiles_and_eviction_keeps_recent_tiles() {
    let mut b = fixture(128, 2);
    let bounds = Rect::new(1900, 1000, 256, 256);
    b.region(bounds).unwrap();
    let painted = b.builds;
    let cached = b.cached_tiles();
    assert!(
        cached > 0 && (cached as i64) < painted,
        "tiles outside the region must not be cached"
    );

    // Evict every cached tile. Known bounds still skip the outside candidates.
    b.tiles.clear();
    b.region(bounds).unwrap();
    assert_eq!(b.builds - painted, cached as i64);

    // The least recently used tiles leave first.
    b.tiles.clear();

    for i in 0..region::TILE_LIMIT {
        b.tiles.insert(
            1_000_000 + i,
            region::Tile {
                draws: Vec::new(),
                revision: 0,
                used: i as u64,
            },
        );
    }

    b.stamp = region::TILE_LIMIT as u64;
    b.region(bounds).unwrap();
    assert!(b.cached_tiles() <= region::TILE_LIMIT);
    assert!(!b.tiles.contains_key(&1_000_000));
    assert!(b.tiles.contains_key(&(1_000_000 + region::TILE_LIMIT - 1)));
}

#[test]
fn edits_invalidate_neighbors_and_traffic_bands_only() {
    let mut b = fixture(128, 2);
    b.city.traffic = vec![0; 32 * 32];
    let bounds = Rect::new(1900, 1000, 256, 256);
    b.region(bounds).unwrap();
    let cached: Vec<usize> = b.tiles.keys().copied().collect();
    let center = cached[cached.len() / 2];
    let (x, y) = (center as i32 / 128, center as i32 % 128);
    let mut city = b.city.clone();
    city.terrain[center] = 1;

    // A density change inside one traffic band draws the same sprites.
    city.traffic[((x / 4) * 32 + (y / 4)) as usize] = 20;
    b.update(city);

    for &i in &cached {
        let (ix, iy) = (i as i32 / 128, i as i32 % 128);
        let near = (ix - x).abs() <= 1 && (iy - y).abs() <= 1;
        assert_eq!(b.tiles.contains_key(&i), !near, "cell {ix},{iy}");
    }

    let mut city = b.city.clone();
    city.traffic[((x / 4) * 32 + (y / 4)) as usize] = 100;
    b.update(city);
    let block = |i: &usize| (*i as i32 / 128) / 4 == x / 4 && (*i as i32 % 128) / 4 == y / 4;
    assert!(b.tiles.keys().all(|i| !block(i)));
    assert!(cached.iter().any(|i| !block(i) && b.tiles.contains_key(i)));
}

#[test]
fn draw_index_returns_painter_order_and_changed_commands() {
    let mut draws = Vec::new();

    for (at, rect) in [Rect::new(0, 0, 10, 10), Rect::new(60, 0, 10, 10), Rect::new(5, 5, 100, 100)]
        .into_iter()
        .enumerate()
    {
        let mut d = Draw::new(2, rect);
        d.depth = at as i64;
        d.order = (at as i64) << 16;
        draws.push(d);
    }

    draws[1].depth = -1;
    let index = index::RegionDraws::new(draws.clone());
    assert_eq!(index.candidates(Rect::new(0, 0, 200, 200), 1, false), [0, 1, 2]);
    assert_eq!(index.candidates(Rect::new(0, 0, 200, 200), 1, true), [0, 2]);
    assert_eq!(index.candidates(Rect::new(130, 130, 10, 10), 2, false), [2]);
    assert!(index.candidates(Rect::new(220, 220, 10, 10), 2, false).is_empty());
    let mut after = draws.clone();
    after[2].rect.x += 1;
    after.remove(0);
    let changed = index::RegionDraws::new(after).changed(&index);
    assert_eq!(
        changed,
        [Rect::new(5, 5, 100, 100), Rect::new(6, 5, 100, 100), Rect::new(0, 0, 10, 10)]
    );
}

#[test]
fn raster_composites_opaque_pixels_over_the_background() {
    let mut sprites = sprites::Sprites::new(HashMap::new(), [0; 4]);
    sprites.images.insert(
        2,
        Sprite {
            w: 2,
            h: 1,
            rgba: vec![9, 9, 9, 255, 7, 7, 7, 0],
            la: vec![9, 255, 7, 0],
        },
    );
    let mut draw = Draw::new(2, Rect::new(1, 0, 2, 1));
    draw.sprite = 1;
    let ground = floating::Ground {
        edge: 8,
        config: fixture(1, 2).config,
    };
    let pixels = raster::composite(
        &[draw.clone()],
        &sprites,
        &HashMap::new(),
        Rect::new(0, 0, 3, 1),
        [1, 2, 3, 4],
        ground,
    );

    // the hidden sprite pixel keeps the background
    assert_eq!(pixels, vec![1, 2, 3, 4, 9, 9, 9, 255, 1, 2, 3, 4]);

    // a shadow darkens a known color and leaves others
    draw.shadow = true;
    draw.rect = Rect::new(0, 0, 2, 1);
    let shadows = HashMap::from([([1, 2, 3, 4], [5, 5, 5, 255])]);
    let pixels = raster::composite(&[draw], &sprites, &shadows, Rect::new(0, 0, 3, 1), [1, 2, 3, 4], ground);
    assert_eq!(pixels, vec![5, 5, 5, 255, 1, 2, 3, 4, 1, 2, 3, 4]);
}

#[test]
fn floating_draws_hide_under_bridges_and_stay_over_water() {
    // In the large view of an 8-tile map, tile (3, 3) at altitude 0 has its top
    // corner at (176, 560). The floating column meets the water at (176, 572),
    // inside that tile.
    let edge = 8;
    let ground = floating::Ground {
        edge,
        config: fixture(1, 2).config,
    };
    let depth = |x: i64, y: i64| (x + y) * i64::from(edge) + y;
    let pixel = |key: u64, value: u8| {
        (
            key,
            Sprite {
                w: 1,
                h: 1,
                rgba: vec![value, value, value, 255],
                la: vec![value, 255],
            },
        )
    };
    let mut sprites = sprites::Sprites::new(HashMap::new(), [0; 4]);
    sprites.images.extend([pixel(2, 10), pixel(4, 20), pixel(6, 30)]);
    sprites.images.insert(
        8,
        Sprite {
            w: 1,
            h: 2,
            rgba: vec![90, 90, 90, 255, 90, 90, 90, 255],
            la: vec![90, 255, 90, 255],
        },
    );

    let static_draw = |key: u64, sprite: i32, tile: (i64, i64)| {
        let mut draw = Draw::new(key, Rect::new(176, 570, 1, 1));
        draw.sprite = sprite;
        draw.depth = depth(tile.0, tile.1);
        draw
    };
    let mut boat = Draw::new(8, Rect::new(176, 570, 1, 2));
    boat.moving = true;
    boat.floating = 0;
    let bounds = Rect::new(176, 570, 1, 1);
    let paint = |draws: &[Draw]| raster::composite(draws, &sprites, &HashMap::new(), bounds, [0; 4], ground)[0];

    // the bridge of the boat's tile and of a tile in front hide it
    assert_eq!(paint(&[static_draw(2, 1000 + 0x57, (3, 3)), boat.clone()]), 10);
    assert_eq!(paint(&[boat.clone(), static_draw(2, 1000 + 0x57, (4, 3))]), 10);

    // a tile behind the boat's column stays under it
    assert_eq!(paint(&[static_draw(4, 1000 + 0x57, (2, 3)), boat.clone()]), 90);
    assert_eq!(paint(&[boat.clone(), static_draw(4, 1000 + 0x57, (2, 4))]), 90);

    // the water of a later tile does not cover it, but other moving draws do
    assert_eq!(paint(&[boat.clone(), static_draw(6, 1000 + 270, (4, 4))]), 90);

    let mut plane = static_draw(6, 1000 + 0x57, (0, 0));
    plane.moving = true;
    assert_eq!(paint(&[boat.clone(), plane]), 30);

    // without the floating altitude, painter order decides
    boat.floating = -1;
    assert_eq!(paint(&[static_draw(2, 1000 + 0x57, (3, 3)), boat.clone()]), 90);
    assert_eq!(paint(&[boat, static_draw(6, 1000 + 270, (4, 4))]), 30);
}

#[test]
fn raster_and_tile_draws_match_regions() {
    let mut b = fixture(8, 2);
    let i = b.city.index(3, 3);
    b.city.buildings[i] = ids::building_tile_ids::LOWER_CLASS_HOMES_1X1_1;

    // the bottom corner of a building anchors its sprite at rotation 0
    b.city.zones[i] = 0x80;
    let bounds = Rect::new(0, 0, 400, 800);
    let (pixels, draws) = b.raster(bounds, [0; 4]).unwrap();
    assert_eq!(pixels.len(), 400 * 800 * 4);
    assert_eq!(draws.len(), b.region(bounds).unwrap().draws.len());
    let tile = b.tile_draws(3, 3).unwrap();
    assert_eq!(tile.len(), 1);
    assert!(b.tile_draws(8, 0).unwrap().is_empty());
}

#[test]
fn special_overlays_only_when_configured() {
    let mut b = fixture(8, 2);
    let i = b.city.index(2, 2);
    b.city.overlays[i] = 0xfc;
    let plain = b.tile_draws(2, 2).unwrap().len();
    b.config.specials = true;
    let marked = b.tile_draws(2, 2).unwrap();
    assert_eq!(marked.len(), plain + 1);
    assert_eq!(marked.last().unwrap().sprite, 1000 + 492);
}

// The sprites, mirrors and rectangles of one tile, in painter order.
fn tile(b: &mut Builder, x: i32, y: i32) -> Vec<(i32, bool, Rect)> {
    b.tile_draws(x, y).unwrap().iter().map(|d| (d.sprite, d.flip, d.rect)).collect()
}

fn place(b: &mut Builder, x: i32, y: i32, building: u8, corners: u8) {
    let i = b.city.index(x, y);
    b.city.buildings[i] = building;
    b.city.zones[i] = corners;
}

#[test]
fn traffic_follows_the_density_thresholds_of_each_network() {
    use ids::building_tile_ids::*;
    let mut b = fixture(8, 2);

    // a 4 by 4 traffic grid: each cell covers two by two tiles
    b.city.traffic = vec![0; 16];
    place(&mut b, 2, 2, ROAD_STRAIGHT_1, 0);
    let has = |b: &mut Builder, id: i32| tile(b, 2, 2).iter().any(|d| d.0 == id);
    b.city.traffic[5] = 85;
    assert!(!tile(&mut b, 2, 2).iter().any(|d| (1399..1500).contains(&d.0)));
    b.city.traffic[5] = 86;
    assert!(has(&mut b, 1400));
    b.city.traffic[5] = 171;
    assert!(has(&mut b, 1427));
    place(&mut b, 2, 2, POWER_LINE_STRAIGHT_1, 0);
    assert!(!tile(&mut b, 2, 2).iter().any(|d| (1399..1500).contains(&d.0)));

    // highways cross their thresholds lower, with lane sprites
    place(&mut b, 2, 2, HIGHWAY_STRAIGHT_1, 0x80);
    b.city.traffic[5] = 29;
    assert!(has(&mut b, 1410));
    b.city.traffic[5] = 57;
    assert!(has(&mut b, 1437));
    let mut medium = fixture(8, 1);
    medium.city.traffic = vec![0; 16];
    medium.city.traffic[5] = 86;
    place(&mut medium, 2, 2, ROAD_STRAIGHT_1, 0);
    assert!(tile(&mut medium, 2, 2).iter().any(|d| d.0 == 900));

    // the small view has no high-density sprites
    let mut small = fixture(8, 0);
    small.city.traffic = vec![0; 16];
    small.city.traffic[5] = 171;
    place(&mut small, 2, 2, ROAD_STRAIGHT_1, 0);
    assert!(!tile(&mut small, 2, 2).iter().any(|d| (399..500).contains(&d.0)));

    // masked traffic draws are no foreground
    small.city.traffic[5] = 86;
    let draws = small.tile_draws(2, 2).unwrap();
    assert!(draws.iter().any(|d| d.sprite == 400 && d.depth < 0));
}

#[test]
fn anchors_mirrors_and_baselines() {
    use ids::building_tile_ids::*;
    let mut b = fixture(8, 2);
    place(&mut b, 3, 3, HIGHWAY_SLOPE_1, 0);
    assert!(!tile(&mut b, 3, 3).iter().any(|d| d.0 == 1000 + i32::from(HIGHWAY_SLOPE_1)));
    place(&mut b, 3, 3, HIGHWAY_SLOPE_1, 0x80);
    let drawn = tile(&mut b, 3, 3);
    assert!(drawn.iter().any(|d| d.0 == 1000 + i32::from(HIGHWAY_SLOPE_1)));

    // an elevated highway redraws the four-cell ground diamond first
    assert_eq!(drawn.len(), 5);
    assert_eq!((drawn[3].2.x - drawn[0].2.x, drawn[3].2.y - drawn[0].2.y), (16, 8));
    let mut small = fixture(8, 0);
    place(&mut small, 3, 3, HIGHWAY_SLOPE_1, 0x80);
    assert_eq!(tile(&mut small, 3, 3).len(), 1);

    // the map edge clips the diamond to valid cells
    place(&mut b, 7, 0, HIGHWAY_SLOPE_1, 0x80);
    assert_eq!(tile(&mut b, 7, 0).len(), 2);
    place(&mut b, 3, 3, RAIL_SUBWAY_ENTRANCE_1, 0);
    assert!(tile(&mut b, 3, 3).iter().any(|d| d.0 == 1000 + i32::from(RAIL_SUBWAY_ENTRANCE_1)));

    // an odd compass rotation mirrors buildings but not networks
    b.city.rotation = 3;
    place(&mut b, 4, 4, ROAD_STRAIGHT_1, 0);
    assert!(!tile(&mut b, 4, 4).iter().find(|d| d.0 == 1029).unwrap().1);
    place(&mut b, 4, 4, LOWER_CLASS_HOMES_1X1_1, 0x40);
    assert!(tile(&mut b, 4, 4).iter().find(|d| d.0 == 1112).unwrap().1);
    let i = b.city.index(4, 4);
    b.city.flags[i] |= ids::sc2tile_flags::FLIPPED;
    assert!(!tile(&mut b, 4, 4).iter().find(|d| d.0 == 1112).unwrap().1);
    place(&mut b, 4, 4, RAIL_STRAIGHT_1, 0x40);
    assert!(tile(&mut b, 4, 4).iter().find(|d| d.0 == 1044).unwrap().1);

    // a network on terrain shape 0x0d sits one altitude step higher
    b.city.rotation = 0;
    b.city.flags[i] = 0;
    place(&mut b, 4, 4, ROAD_STRAIGHT_1, 0);
    let flat = tile(&mut b, 4, 4).iter().find(|d| d.0 == 1029).unwrap().2.y;
    b.city.terrain[i] = 0x0d;
    let raised = tile(&mut b, 4, 4).iter().find(|d| d.0 == 1029).unwrap().2.y;
    assert_eq!(flat - raised, 12);
}

#[test]
fn power_markers_and_map_edges() {
    use ids::building_tile_ids::*;
    let mut b = fixture(8, 2);
    place(&mut b, 3, 3, LOWER_CLASS_HOMES_1X1_1, 0x80);
    let i = b.city.index(3, 3);
    b.city.flags[i] = ids::sc2tile_flags::POWERABLE;
    assert!(tile(&mut b, 3, 3).iter().any(|d| d.0 == 1386));
    b.city.flags[i] |= ids::sc2tile_flags::POWERED;
    assert!(!tile(&mut b, 3, 3).iter().any(|d| d.0 == 1386));

    // map edges repeat the land side sprite, then the water side sprite
    let edge = b.city.index(7, 4);
    b.city.altitude[edge] = 3 | 5 << 5;
    b.city.flags[edge] = ids::sc2tile_flags::WATER;
    let sides: Vec<(i32, bool, Rect)> = tile(&mut b, 7, 4).into_iter().filter(|d| d.0 == 1269 || d.0 == 1284).collect();
    assert_eq!(sides.iter().filter(|d| d.0 == 1269).count(), 3);
    assert_eq!(sides.iter().filter(|d| d.0 == 1284).count(), 2);
    assert_eq!(sides[0].2.y - sides[2].2.y, 24);
    assert!(!tile(&mut b, 6, 4).iter().any(|d| d.0 == 1269));
    let mut small = fixture(8, 0);
    let edge = small.city.index(7, 4);
    small.city.altitude[edge] = 2;
    let small_sides: Vec<Rect> = tile(&mut small, 7, 4).into_iter().filter(|d| d.0 == 269).map(|d| d.2).collect();
    assert_eq!(small_sides[0].y - small_sides[1].y, 3);
}

#[test]
fn missing_sprites_are_listed_once() {
    let mut b = fixture(4, 2);
    b.sprites.images.remove(&(1256_u64 * 2));
    b.sprites.images.remove(&(1269_u64 * 2));
    let i = b.city.index(3, 1);
    b.city.altitude[i] = 1;

    // flat ground and the land side of the map edge
    assert_eq!(b.missing_sprites(), vec![1256, 1269]);

    // painting afterwards reports the first missing sprite again
    assert!(b.tile_draws(0, 0).is_err());
}

#[test]
fn missing_tiles_name_each_tile_and_its_sprite() {
    let mut b = fixture(4, 2);
    b.sprites.images.remove(&(1256_u64 * 2));
    let i = b.city.index(3, 1);
    b.city.altitude[i] = 1;
    let everything = b.missing_sprites();
    let found = b.missing_tiles(Rect::new(0, 0, 4, 4));

    assert_eq!(found.all, everything);
    assert_eq!(found.cells.len(), found.sprites.len());
    assert!(!found.cells.is_empty() && found.sprites.iter().all(|id| *id == 1256));

    // a window that leaves out every tile finds nothing
    assert!(b.missing_tiles(Rect::new(4, 4, 2, 2)).cells.is_empty());

    // painting afterwards reports the missing sprite again
    assert!(b.tile_draws(0, 0).is_err());
}
