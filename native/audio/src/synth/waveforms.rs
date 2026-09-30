//! Waveforms, envelopes, and the Godot float helpers that the mix uses.

use super::*;

struct Tables {
    families: [Vec<f32>; 5],
}

fn tables() -> &'static Tables {
    static TABLES: OnceLock<Tables> = OnceLock::new();
    TABLES.get_or_init(|| {
        // Keep the interpolation endpoint: family 1's 3.01 harmonic does not wrap at phase 1.
        let make =
            |f: &dyn Fn(f64) -> f64| -> Vec<f32> { (0..=WAVETABLE_SIZE).map(|i| f(i as f64 / WAVETABLE_SIZE as f64) as f32).collect() };
        let s = |p: f64| (TAU * p).sin();
        Tables {
            families: [
                make(&|p| s(p) * 0.72 + (TAU * p * 2.0).sin() * 0.20 + (TAU * p * 3.0).sin() * 0.08),
                make(&|p| s(p) * 0.65 + (TAU * p * 3.01).sin() * 0.35),
                make(&|p| s(p) * 0.65 + (TAU * p * 2.0).sin() * 0.25 + (TAU * p * 4.0).sin() * 0.10),
                // family 6 still needs its pitch-dependent saw at runtime
                make(&|p| s(p) * 0.55),
                make(&|p| s(p) * 0.88 + (TAU * p * 2.0).sin() * 0.12),
            ],
        }
    })
}

pub(super) fn family_table(family: i32) -> Option<&'static [f32]> {
    let index = match family {
        0 => 0,
        1 => 1,
        2 => 2,
        6 => 3,
        7 => 4,
        _ => return None,
    };

    Some(&tables().families[index])
}

// Godot's clampf, minf and maxf, including their comparison order.
pub(super) fn clamp(value: f64, low: f64, high: f64) -> f64 {
    if value < low {
        low
    } else if value > high {
        high
    } else {
        value
    }
}

pub(super) fn min(a: f64, b: f64) -> f64 {
    if a < b { a } else { b }
}

pub(super) fn max(a: f64, b: f64) -> f64 {
    if a > b { a } else { b }
}

pub(super) fn lerp(from: f64, to: f64, weight: f64) -> f64 {
    from + (to - from) * weight
}

pub fn note_frequency(note: i32, pitch_bend: i32) -> f64 {
    let center = f64::from(PITCH_BEND_CENTER);
    let bend = (f64::from(pitch_bend.clamp(0, PITCH_BEND_MAX)) - center) / center * PITCH_BEND_RANGE;
    440.0 * 2.0_f64.powf((f64::from(note.clamp(0, 127)) - 69.0 + bend) / 12.0)
}

pub fn waveform_family(program: i32) -> i32 {
    match program.clamp(0, 127) {
        0..8 => 0,
        8..16 => 1,
        16..24 => 2,
        24..32 => 3,
        32..40 => 4,
        40..56 => 5,
        56..72 => 6,
        72..80 => 7,
        80..104 => 8,
        _ => 9,
    }
}

pub(super) fn attack_seconds(program: i32, percussion: bool) -> f64 {
    if percussion {
        return 0.001;
    }

    match waveform_family(program) {
        5 => 0.08,
        6 | 7 => 0.025,
        _ => 0.006,
    }
}

pub(super) fn release_rate(program: i32, percussion: bool) -> f64 {
    if percussion {
        return 10.0;
    }

    match waveform_family(program) {
        2 | 5 => 1.8,
        6 | 7 => 2.6,
        _ => 4.0,
    }
}

pub fn band_limited_saw(phase: f64, step: f64) -> f64 {
    phase * 2.0 - 1.0 - poly_blep(phase, step)
}

pub fn band_limited_square(phase: f64, step: f64) -> f64 {
    let mut value = if phase < 0.5 { 1.0 } else { -1.0 };
    value += poly_blep(phase, step);
    value -= poly_blep((phase + 0.5) % 1.0, step);
    value
}

pub(super) fn triangle(phase: f64) -> f64 {
    1.0 - 4.0 * (phase - 0.5).abs()
}

pub(super) fn poly_blep(phase: f64, step: f64) -> f64 {
    let step = clamp(step, 0.000001, 0.49);

    if phase < step {
        let position = phase / step;

        return position + position - position * position - 1.0;
    }

    if phase > 1.0 - step {
        let position = (phase - 1.0) / step;

        return position * position + position + position + 1.0;
    }

    0.0
}

pub(super) fn wavetable_sample(table: &[f32], phase: f64) -> f64 {
    let scaled = phase * WAVETABLE_SIZE as f64;
    let index = (scaled as i64 as usize) & (WAVETABLE_SIZE - 1);
    lerp(f64::from(table[index]), f64::from(table[index + 1]), scaled - index as f64)
}

pub(super) fn family_sample(family: i32, phase: f64, secondary: f64, step: f64) -> f64 {
    match family {
        0..=2 | 7 => wavetable_sample(family_table(family).unwrap(), phase),
        3 => triangle(phase) * 0.70 + band_limited_saw(phase, step) * 0.30,
        4 => triangle(phase) * 0.80 + band_limited_square(phase, step) * 0.20,
        5 => band_limited_saw(phase, step) * 0.52 + band_limited_saw(secondary, step * 1.006) * 0.48,
        6 => band_limited_saw(phase, step) * 0.45 + wavetable_sample(family_table(6).unwrap(), phase),
        8 => band_limited_square(phase, step) * 0.55 + band_limited_saw(phase, step) * 0.45,
        _ => triangle(phase) * 0.55 + (TAU * phase * 2.0).sin() * 0.45,
    }
}

pub(super) fn percussion_sample(note: i32, phase: f64, age: f64, noise: f64, step: f64) -> f64 {
    if note == BASS_DRUM_2 || note == BASS_DRUM_1 {
        let drop = max(0.35, 1.0 - age * 2.5);

        return (TAU * phase * drop).sin() * 0.85 + noise * 0.15;
    }

    if (CLOSED_HI_HAT..=OPEN_HI_HAT).contains(&note) {
        return noise * 0.82 + band_limited_square(phase, step) * 0.18;
    }

    if note == SNARE_1 || note == SNARE_2 {
        return noise * 0.72 + (TAU * phase).sin() * 0.28;
    }

    noise * 0.55 + (TAU * phase).sin() * 0.45
}
