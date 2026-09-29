//! Integer spatial filters for the SC2X per-tile simulation, as NativeGridMath.

/// Box-filter average over a (2 * radius + 1) square, clipped at the map edge.
/// Values are stored as i32, as in a PackedInt32Array.
fn neighborhood_values(values: &[i32], edge: usize, radius: i64, scale: i64) -> Vec<i64> {
    let stride = edge + 1;
    let mut integral = vec![0i64; stride * stride];

    for x in 0..edge {
        crate::sim::budget::checkpoint();
        let mut row_sum = 0i64;
        let row = x * edge;
        let above = x * stride;
        let below = above + stride;

        for y in 0..edge {
            row_sum += values[row + y] as i64;
            integral[below + y + 1] = integral[above + y + 1] + row_sum;
        }
    }

    let edge_i = edge as i64;
    let tops: Vec<usize> = (0..edge_i).map(|y| (y - radius).max(0) as usize).collect();
    let bottoms: Vec<usize> = (0..edge_i).map(|y| (y + radius + 1).min(edge_i) as usize).collect();
    let mut result = vec![0i64; values.len()];

    for x in 0..edge_i {
        crate::sim::budget::checkpoint();
        let left = (x - radius).max(0) as usize;
        let right = (x + radius + 1).min(edge_i) as usize;
        let row = x as usize * edge;
        let left_row = left * stride;
        let right_row = right * stride;
        let height = (right - left) as i64;

        for y in 0..edge {
            let top = tops[y];
            let bottom = bottoms[y];
            let mut total = integral[right_row + bottom] - integral[left_row + bottom];
            total -= integral[right_row + top] - integral[left_row + top];
            result[row + y] = total * scale / (height * (bottom - top) as i64);
        }
    }

    result
}

pub fn neighborhood(values: &[i32], edge: usize, radius: i64, scale: i64) -> Vec<i32> {
    neighborhood_values(values, edge, radius, scale).into_iter().map(|value| value as i32).collect()
}

pub fn neighborhood_bytes(values: &[i32], edge: usize, radius: i64, scale: i64) -> Vec<u8> {
    neighborhood_values(values, edge, radius, scale).into_iter().map(|value| value.clamp(0, 255) as u8).collect()
}

fn smooth_edge_value(values: &[i32], edge: i64, x: i64, y: i64, center_weight: i64, base_divisor: i64, step: i64, rings: i64) -> i64 {
    let index = x * edge + y;
    let mut total = values[index as usize] as i64 * center_weight;
    let mut divisor = base_divisor;

    for ring in 1..=rings {
        let distance = ring * step;

        if x >= distance {
            total += values[(index - distance * edge) as usize] as i64;
            divisor += 1;
        }

        if x + distance < edge {
            total += values[(index + distance * edge) as usize] as i64;
            divisor += 1;
        }

        if y >= distance {
            total += values[(index - distance) as usize] as i64;
            divisor += 1;
        }

        if y + distance < edge {
            total += values[(index + distance) as usize] as i64;
            divisor += 1;
        }
    }

    total / divisor
}

/// Weighted cross smoothing. `store` receives each value and its index.
fn smooth_into(
    values: &[i32],
    edge: i64,
    center_weight: i64,
    base_divisor: i64,
    step: i64,
    rings: i64,
    mut store: impl FnMut(usize, i64),
) {
    let margin = step * rings;
    let near_row = step * edge;
    let far_row = 2 * near_row;
    let far_column = 2 * step;
    let interior_divisor = base_divisor + 4 * rings;
    let has_interior = step > 0 && (rings == 1 || rings == 2) && edge > 2 * margin;
    let at = |index: i64| values[index as usize] as i64;

    for x in 0..edge {
        crate::sim::budget::checkpoint();
        let row = x * edge;
        let interior_row = has_interior && x >= margin && x < edge - margin;
        let rim_width = if interior_row { margin } else { edge };
        let rim_count = if interior_row { 2 * rim_width } else { rim_width };

        // Visit only the clipped rim here. Interior cells use fixed offsets below.
        for rim_index in 0..rim_count {
            let y = if rim_index < rim_width { rim_index } else { edge - 2 * rim_width + rim_index };
            let value = smooth_edge_value(values, edge, x, y, center_weight, base_divisor, step, rings);
            store((row + y) as usize, value);
        }

        if !interior_row {
            continue;
        }

        for index in (row + margin)..(row + edge - margin) {
            let mut total = at(index) * center_weight;
            total += at(index - near_row) + at(index + near_row);
            total += at(index - step) + at(index + step);

            if rings != 1 {
                total += at(index - far_row) + at(index + far_row);
                total += at(index - far_column) + at(index + far_column);
            }

            store(index as usize, total / interior_divisor);
        }
    }
}

pub fn smooth(values: &[i32], edge: usize, center_weight: i64, base_divisor: i64, step: i64, rings: i64) -> Vec<i32> {
    let mut result = vec![0i32; values.len()];
    smooth_into(values, edge as i64, center_weight, base_divisor, step, rings, |index, value| {
        result[index] = value as i32;
    });
    result
}

/// Smoothed bytes and the sum of the stored bytes.
pub fn smooth_bytes(values: &[i32], edge: usize, center_weight: i64, base_divisor: i64, step: i64, rings: i64) -> (Vec<u8>, i64) {
    let mut result = vec![0u8; values.len()];
    let mut sum = 0;
    smooth_into(values, edge as i64, center_weight, base_divisor, step, rings, |index, value| {
        let value = value.clamp(0, 255);
        result[index] = value as u8;
        sum += value;
    });
    (result, sum)
}

fn sample(kernel: &[u8], x: i64, y: i64) -> i64 {
    if (0..7).contains(&x) && (0..7).contains(&y) { kernel[(x * 7 + y) as usize] as i64 } else { 0 }
}

/// The 31 by 31 per-tile coverage pattern of one station strength.
pub fn service_pattern(strength: i64) -> Vec<i64> {
    let mut kernel = vec![0u8; 49];
    super::coarse::add_service(&mut kernel, 3, 3, strength, 28);
    let mut pattern = vec![0i64; 31 * 31];

    for dx in -15i64..16 {
        let kx = dx.div_euclid(4) + 3;
        let fx = dx.rem_euclid(4);

        for dy in -15i64..16 {
            let ky = dy.div_euclid(4) + 3;
            let fy = dy.rem_euclid(4);
            let mut weighted = sample(&kernel, kx, ky) * (4 - fx) * (4 - fy);
            weighted += sample(&kernel, kx + 1, ky) * fx * (4 - fy);
            weighted += sample(&kernel, kx, ky + 1) * (4 - fx) * fy;
            weighted += sample(&kernel, kx + 1, ky + 1) * fx * fy;
            pattern[((dx + 15) * 31 + dy + 15) as usize] = weighted / 16;
        }
    }

    pattern
}

pub fn apply_service_pattern(values: &mut [u8], edge: i64, origin_x: i64, origin_y: i64, pattern: &[i64]) {
    for dx in (-15i64).max(-origin_x)..16i64.min(edge - origin_x) {
        let row = (origin_x + dx) * edge;
        let source_row = (dx + 15) * 31;

        for dy in (-15i64).max(-origin_y)..16i64.min(edge - origin_y) {
            let index = (row + origin_y + dy) as usize;
            values[index] = (values[index] as i64 + pattern[(source_row + dy + 15) as usize]).clamp(0, 255) as u8;
        }
    }
}
