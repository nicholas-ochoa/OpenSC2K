//! The FluidSynth 2 C functions that OpenSC2K calls, found at run time.
//! These declarations follow the public FluidSynth API documentation; no
//! FluidSynth source or header is copied here.
use std::ffi::{c_char, c_double, c_float, c_int, c_void};
use std::path::{Path, PathBuf};
use std::sync::OnceLock;

use super::platform::{self, SharedLibrary};

/// Opaque FluidSynth objects.
pub enum Settings {}

pub enum Synth {}

pub const FLUID_OK: c_int = 0;
pub const FLUID_FAILED: c_int = -1;

/// The supported FluidSynth API generation (library file version 3).
pub const SUPPORTED_MAJOR_VERSION: c_int = 2;

/// Log levels of `fluid_set_log_function`.
pub const LOG_PANIC: c_int = 0;
pub const LOG_ERROR: c_int = 1;
pub const LOG_WARNING: c_int = 2;
pub const LOG_INFO: c_int = 3;
pub const LOG_DEBUG: c_int = 4;

/// Overrides the library search, for development and tests.
pub const LIBRARY_ENVIRONMENT_VARIABLE: &str = "OPENSC2K_FLUIDSYNTH";

#[cfg(target_os = "macos")]
const LIBRARY_NAMES: &[&str] = &["libfluidsynth.3.dylib", "libfluidsynth.dylib"];

#[cfg(all(unix, not(target_os = "macos")))]
const LIBRARY_NAMES: &[&str] = &["libfluidsynth.so.3", "libfluidsynth.so"];

#[cfg(windows)]
const LIBRARY_NAMES: &[&str] = &["libfluidsynth-3.dll", "fluidsynth-3.dll"];

/// Development installs that the macOS loader does not search by default.
#[cfg(target_os = "macos")]
const DEVELOPMENT_FOLDERS: &[&str] = &["/opt/homebrew/lib", "/usr/local/lib"];

#[cfg(not(target_os = "macos"))]
const DEVELOPMENT_FOLDERS: &[&str] = &[];

pub type LogFunction = Option<unsafe extern "C" fn(level: c_int, message: *const c_char, data: *mut c_void)>;

/// The function table. Each field is a C function of the loaded library.
pub struct Api {
    _library: SharedLibrary,
    pub path: PathBuf,
    pub version: (c_int, c_int, c_int),
    pub new_settings: unsafe extern "C" fn() -> *mut Settings,
    pub delete_settings: unsafe extern "C" fn(*mut Settings),
    pub settings_setnum: unsafe extern "C" fn(*mut Settings, *const c_char, c_double) -> c_int,
    pub settings_setint: unsafe extern "C" fn(*mut Settings, *const c_char, c_int) -> c_int,
    pub new_synth: unsafe extern "C" fn(*mut Settings) -> *mut Synth,
    pub delete_synth: unsafe extern "C" fn(*mut Synth),
    pub is_soundfont: unsafe extern "C" fn(*const c_char) -> c_int,
    pub sfload: unsafe extern "C" fn(*mut Synth, *const c_char, c_int) -> c_int,
    pub sfunload: unsafe extern "C" fn(*mut Synth, c_int, c_int) -> c_int,
    pub noteon: unsafe extern "C" fn(*mut Synth, c_int, c_int, c_int) -> c_int,
    pub noteoff: unsafe extern "C" fn(*mut Synth, c_int, c_int) -> c_int,
    pub cc: unsafe extern "C" fn(*mut Synth, c_int, c_int, c_int) -> c_int,
    pub program_change: unsafe extern "C" fn(*mut Synth, c_int, c_int) -> c_int,
    pub pitch_bend: unsafe extern "C" fn(*mut Synth, c_int, c_int) -> c_int,
    pub channel_pressure: unsafe extern "C" fn(*mut Synth, c_int, c_int) -> c_int,
    pub key_pressure: unsafe extern "C" fn(*mut Synth, c_int, c_int, c_int) -> c_int,
    pub system_reset: unsafe extern "C" fn(*mut Synth) -> c_int,
    pub all_notes_off: unsafe extern "C" fn(*mut Synth, c_int) -> c_int,
    pub set_gain: unsafe extern "C" fn(*mut Synth, c_float),
    pub active_voice_count: unsafe extern "C" fn(*mut Synth) -> c_int,
    #[allow(clippy::type_complexity)]
    pub write_float: unsafe extern "C" fn(*mut Synth, c_int, *mut c_void, c_int, c_int, *mut c_void, c_int, c_int) -> c_int,
    pub set_log_function: unsafe extern "C" fn(c_int, LogFunction, *mut c_void) -> LogFunction,
}

/// One exported function as a typed pointer.
///
/// # Safety
///
/// `T` must be the C function pointer type that the FluidSynth 2 API documents
/// for `name`. The library stays loaded for the process.
unsafe fn function<T: Copy>(library: &SharedLibrary, name: &str) -> Result<T, String> {
    let address = library.symbol(name)?;
    assert_eq!(size_of::<T>(), size_of::<*mut c_void>(), "{name} is a function pointer");

    // SAFETY: the caller names the documented signature; both types are one pointer wide.
    Ok(unsafe { std::mem::transmute_copy::<*mut c_void, T>(&address) })
}

impl Api {
    /// Opens the library at `path` and finds every function.
    pub fn open(path: &Path) -> Result<Self, String> {
        let library = SharedLibrary::open(path).map_err(|error| format!("{}: {error}", path.display()))?;
        let mut version = (0, 0, 0);

        // SAFETY: fluid_version has this documented signature and writes three integers.
        unsafe {
            let fluid_version: unsafe extern "C" fn(*mut c_int, *mut c_int, *mut c_int) = function(&library, "fluid_version")?;
            fluid_version(&mut version.0, &mut version.1, &mut version.2);
        }

        if version.0 != SUPPORTED_MAJOR_VERSION {
            return Err(format!(
                "{} is FluidSynth {}.{}.{}; OpenSC2K needs FluidSynth {SUPPORTED_MAJOR_VERSION}",
                path.display(),
                version.0,
                version.1,
                version.2
            ));
        }

        // SAFETY: each field type is the documented signature of its FluidSynth 2 function.
        let api = unsafe {
            Self {
                path: path.to_path_buf(),
                version,
                new_settings: function(&library, "new_fluid_settings")?,
                delete_settings: function(&library, "delete_fluid_settings")?,
                settings_setnum: function(&library, "fluid_settings_setnum")?,
                settings_setint: function(&library, "fluid_settings_setint")?,
                new_synth: function(&library, "new_fluid_synth")?,
                delete_synth: function(&library, "delete_fluid_synth")?,
                is_soundfont: function(&library, "fluid_is_soundfont")?,
                sfload: function(&library, "fluid_synth_sfload")?,
                sfunload: function(&library, "fluid_synth_sfunload")?,
                noteon: function(&library, "fluid_synth_noteon")?,
                noteoff: function(&library, "fluid_synth_noteoff")?,
                cc: function(&library, "fluid_synth_cc")?,
                program_change: function(&library, "fluid_synth_program_change")?,
                pitch_bend: function(&library, "fluid_synth_pitch_bend")?,
                channel_pressure: function(&library, "fluid_synth_channel_pressure")?,
                key_pressure: function(&library, "fluid_synth_key_pressure")?,
                system_reset: function(&library, "fluid_synth_system_reset")?,
                all_notes_off: function(&library, "fluid_synth_all_notes_off")?,
                set_gain: function(&library, "fluid_synth_set_gain")?,
                active_voice_count: function(&library, "fluid_synth_get_active_voice_count")?,
                write_float: function(&library, "fluid_synth_write_float")?,
                set_log_function: function(&library, "fluid_set_log_function")?,
                _library: library,
            }
        };

        Ok(api)
    }

    pub fn version_text(&self) -> String {
        format!("{}.{}.{}", self.version.0, self.version.1, self.version.2)
    }
}

/// The library paths to try, in order: the environment override, the folder of
/// the OpenSC2K audio extension, the system search path, then development installs.
pub fn library_candidates(override_path: Option<PathBuf>, own_folder: Option<PathBuf>) -> Vec<PathBuf> {
    if let Some(path) = override_path {
        return vec![path];
    }

    let mut candidates = Vec::new();

    if let Some(folder) = own_folder {
        candidates.extend(LIBRARY_NAMES.iter().map(|name| folder.join(name)));
    }

    candidates.extend(LIBRARY_NAMES.iter().map(PathBuf::from));

    for folder in DEVELOPMENT_FOLDERS {
        candidates.extend(LIBRARY_NAMES.iter().map(|name| Path::new(folder).join(name)));
    }

    candidates
}

/// Tries each candidate. The error names every failed attempt.
pub fn open_first(candidates: &[PathBuf]) -> Result<Api, String> {
    let mut failures = Vec::new();

    for path in candidates {
        match Api::open(path) {
            Ok(api) => return Ok(api),
            Err(error) => failures.push(error),
        }
    }

    Err(format!(
        "The FluidSynth shared library could not be loaded. {}",
        failures.join("; ")
    ))
}

/// The process-wide FluidSynth library. The first call opens it; later calls
/// return the same result, so a missing library is reported, not retried.
pub fn shared() -> Result<&'static Api, &'static str> {
    static API: OnceLock<Result<Api, String>> = OnceLock::new();

    let api = API.get_or_init(|| {
        let override_path = std::env::var_os(LIBRARY_ENVIRONMENT_VARIABLE).map(PathBuf::from);
        let api = open_first(&library_candidates(override_path, platform::own_library_folder()))?;
        super::log::install(&api);

        Ok(api)
    });

    api.as_ref().map_err(String::as_str)
}
