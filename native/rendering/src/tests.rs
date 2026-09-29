use super::*;

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
                rgba: vec![
                    161, 161, 161, 255, 20, 20, 20, 255, 30, 30, 30, 255, 40, 40, 40, 255,
                ],
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
            mains: true,
            redraw_ground: false,
        },
        images,
        [161, 161, 161, 255],
    )
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
    assert_eq!(
        b.sprites.images[&flipped].la,
        [20, 255, 161, 255, 40, 255, 30, 255]
    );
    let masked = b.sprites.traffic(flipped, original);
    assert_eq!(
        b.sprites.images[&masked].la,
        [20, 255, 161, 0, 40, 0, 30, 0]
    );
    assert_eq!(b.sprites.images[&flipped].la[3], 255);
}
#[test]
fn atlas_growth_keeps_existing_slots_and_pixels() {
    let mut atlas = sprites::Atlas::new();
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
    assert_eq!(
        atlas.data[((first.y * atlas.edge + first.x) * 2) as usize],
        77
    );
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
    assert!(
        region
            .draws
            .iter()
            .any(|d| d.sprite == 1006 && d.rect == tree.rect)
    );
}

#[test]
fn original_dispatch_requires_matching_overlay_and_skips_record_zero() {
    let mut city = fixture(128, 2).city;
    let mut things = vec![0; 480];
    for (record, kind, x, y, sprite) in [
        (0, 7, 1, 1, 382),
        (1, 7, 2, 3, 382),
        (2, 8, 4, 5, 383),
        (39, 14, 6, 7, 384),
    ] {
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
