//! A small General MIDI SoundFont for tests. OpenSC2K generates every sample, so
//! the file has no third-party content. Bank 0 program 0 plays a sine wave,
//! program 80 a square wave, and the bank 128 drum kit plays a noise burst.
//! The Godot tests use the committed copy in `game/tests/fixtures/soundfonts`.

pub const SAMPLE_RATE: u32 = 44_100;

/// One waveform period: 100 frames is 441 Hz at the sample rate.
const PERIOD: usize = 100;
const LOOPED_FRAMES: usize = 20 * PERIOD;
const NOISE_FRAMES: usize = 4_000;

/// The SoundFont specification wants 46 zero samples after each sample.
const SAMPLE_GUARD: usize = 46;
const AMPLITUDE: f64 = 20_000.0;
const ROOT_KEY: u8 = 69;

// Generator operators of the SoundFont 2.01 specification.
const GEN_KEY_RANGE: u16 = 43;
const GEN_INSTRUMENT: u16 = 41;
const GEN_SAMPLE_MODES: u16 = 54;
const GEN_SAMPLE_ID: u16 = 53;
const GEN_RELEASE_VOL_ENV: u16 = 38;

const LOOP_CONTINUOUSLY: u16 = 1;
const MONO_SAMPLE: u16 = 1;

/// A quick release in timecents: about 0.1 seconds.
const SHORT_RELEASE: i16 = -3986;
const PERCUSSION_BANK: u16 = 128;
const SQUARE_PROGRAM: u16 = 80;

/// The General MIDI drum notes, from bass drum 2 to open triangle.
const DRUM_KEYS: (u8, u8) = (35, 81);

struct Sample {
    name: &'static str,
    frames: Vec<i16>,
    looped: bool,
}

/// An instrument plays one sample over a key range.
struct Instrument {
    name: &'static str,
    sample: u16,
    keys: (u8, u8),
}

struct Preset {
    name: &'static str,
    program: u16,
    bank: u16,
    instrument: u16,
}

/// The complete SoundFont file.
pub fn bytes() -> Vec<u8> {
    let samples = [
        Sample {
            name: "Sine",
            frames: waveform(|phase| (phase * std::f64::consts::TAU).sin()),
            looped: true,
        },
        Sample {
            name: "Square",
            frames: waveform(|phase| if phase < 0.5 { 0.6 } else { -0.6 }),
            looped: true,
        },
        Sample {
            name: "Noise",
            frames: noise(),
            looped: false,
        },
    ];
    let instruments = [
        Instrument {
            name: "Sine",
            sample: 0,
            keys: (0, 127),
        },
        Instrument {
            name: "Square",
            sample: 1,
            keys: (0, 127),
        },
        Instrument {
            name: "Noise Kit",
            sample: 2,
            keys: DRUM_KEYS,
        },
    ];
    let presets = [
        Preset {
            name: "Sine",
            program: 0,
            bank: 0,
            instrument: 0,
        },
        Preset {
            name: "Square",
            program: SQUARE_PROGRAM,
            bank: 0,
            instrument: 1,
        },
        Preset {
            name: "Noise Kit",
            program: 0,
            bank: PERCUSSION_BANK,
            instrument: 2,
        },
    ];

    let info = list(
        b"INFO",
        &[
            chunk(b"ifil", &[2, 0, 1, 0]),
            chunk(b"isng", b"EMU8000\0"),
            chunk(b"INAM", b"OpenSC2K Test GM\0\0"),
        ],
    );
    let (sample_data, headers) = sample_chunks(&samples);
    let sdta = list(b"sdta", &[chunk(b"smpl", &sample_data)]);
    let pdta = list(b"pdta", &hydra(&presets, &instruments, &headers));

    riff(&[info, sdta, pdta])
}

fn waveform(shape: impl Fn(f64) -> f64) -> Vec<i16> {
    (0..LOOPED_FRAMES)
        .map(|frame| (shape((frame % PERIOD) as f64 / PERIOD as f64) * AMPLITUDE) as i16)
        .collect()
}

/// A decaying burst from a fixed linear congruential generator.
fn noise() -> Vec<i16> {
    let mut state: u32 = 12_345;

    (0..NOISE_FRAMES)
        .map(|frame| {
            state = state.wrapping_mul(1_103_515_245).wrapping_add(12_345);
            let value = f64::from((state >> 16) & 0x7fff) / 16_384.0 - 1.0;
            let decay = 1.0 - frame as f64 / NOISE_FRAMES as f64;

            (value * decay * AMPLITUDE) as i16
        })
        .collect()
}

/// The 16-bit sample data and the sample headers.
fn sample_chunks(samples: &[Sample]) -> (Vec<u8>, Vec<u8>) {
    let mut data = Vec::new();
    let mut headers = Vec::new();
    let mut start = 0u32;

    for sample in samples {
        let end = start + sample.frames.len() as u32;
        let (loop_start, loop_end) = if sample.looped {
            (start + PERIOD as u32, end - PERIOD as u32)
        } else {
            (start, end)
        };

        for frame in sample.frames.iter().chain(std::iter::repeat_n(&0, SAMPLE_GUARD)) {
            data.extend_from_slice(&frame.to_le_bytes());
        }

        headers.extend(name20(sample.name));

        for value in [start, end, loop_start, loop_end, SAMPLE_RATE] {
            headers.extend_from_slice(&value.to_le_bytes());
        }

        headers.extend_from_slice(&[ROOT_KEY, 0]);
        headers.extend_from_slice(&0u16.to_le_bytes());
        headers.extend_from_slice(&MONO_SAMPLE.to_le_bytes());
        start = end + SAMPLE_GUARD as u32;
    }

    headers.extend(name20("EOS"));
    headers.extend(std::iter::repeat_n(0, 26));

    (data, headers)
}

/// The preset, instrument and sample header chunks. Each preset and instrument has one zone.
fn hydra(presets: &[Preset], instruments: &[Instrument], sample_headers: &[u8]) -> Vec<Vec<u8>> {
    let mut phdr = Vec::new();
    let mut pbag = Vec::new();
    let mut pgen = Vec::new();

    for (index, preset) in presets.iter().enumerate() {
        phdr.extend(name20(preset.name));
        phdr.extend(words(&[preset.program, preset.bank, index as u16]));
        phdr.extend(std::iter::repeat_n(0, 12));
        pbag.extend(words(&[index as u16, 0]));
        pgen.extend(words(&[GEN_INSTRUMENT, preset.instrument]));
    }

    phdr.extend(name20("EOP"));
    phdr.extend(words(&[0, 0, presets.len() as u16]));
    phdr.extend(std::iter::repeat_n(0, 12));
    pbag.extend(words(&[presets.len() as u16, 0]));
    pgen.extend(words(&[0, 0]));

    let mut inst = Vec::new();
    let mut ibag = Vec::new();
    let mut igen = Vec::new();
    let mut generators = 0u16;

    for (index, instrument) in instruments.iter().enumerate() {
        let looped = instrument.keys == (0, 127);
        inst.extend(name20(instrument.name));
        inst.extend(words(&[index as u16]));
        ibag.extend(words(&[generators, 0]));
        // the key range comes first and the sample last, as the specification requires
        igen.extend(words(&[GEN_KEY_RANGE, u16::from_le_bytes([instrument.keys.0, instrument.keys.1])]));
        igen.extend(words(&[GEN_RELEASE_VOL_ENV, SHORT_RELEASE as u16]));
        igen.extend(words(&[GEN_SAMPLE_MODES, if looped { LOOP_CONTINUOUSLY } else { 0 }]));
        igen.extend(words(&[GEN_SAMPLE_ID, instrument.sample]));
        generators += 4;
    }

    inst.extend(name20("EOI"));
    inst.extend(words(&[instruments.len() as u16]));
    ibag.extend(words(&[generators, 0]));
    igen.extend(words(&[0, 0]));
    let no_modulators = vec![0; 10];

    vec![
        chunk(b"phdr", &phdr),
        chunk(b"pbag", &pbag),
        chunk(b"pmod", &no_modulators),
        chunk(b"pgen", &pgen),
        chunk(b"inst", &inst),
        chunk(b"ibag", &ibag),
        chunk(b"imod", &no_modulators),
        chunk(b"igen", &igen),
        chunk(b"shdr", sample_headers),
    ]
}

fn words(values: &[u16]) -> Vec<u8> {
    values.iter().flat_map(|value| value.to_le_bytes()).collect()
}

fn name20(name: &str) -> Vec<u8> {
    let mut bytes = name.as_bytes().to_vec();
    bytes.resize(20, 0);

    bytes
}

fn chunk(id: &[u8; 4], data: &[u8]) -> Vec<u8> {
    let mut bytes = id.to_vec();
    bytes.extend_from_slice(&(data.len() as u32).to_le_bytes());
    bytes.extend_from_slice(data);

    if data.len() % 2 == 1 {
        bytes.push(0);
    }

    bytes
}

fn list(kind: &[u8; 4], chunks: &[Vec<u8>]) -> Vec<u8> {
    let mut data = kind.to_vec();
    data.extend(chunks.concat());

    chunk(b"LIST", &data)
}

fn riff(lists: &[Vec<u8>]) -> Vec<u8> {
    let mut data = b"sfbk".to_vec();
    data.extend(lists.concat());

    chunk(b"RIFF", &data)
}
