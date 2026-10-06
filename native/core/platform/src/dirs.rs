//! The folder of the user files. The native game uses the folder of the Godot
//! build, so both share settings, packs, and cities. A "data" folder beside the
//! executable selects portable mode; see `paths`.

use std::env;
use std::path::PathBuf;

/// The project name of the Godot build. It names the user folder.
pub const PROJECT_NAME: &str = "OpenSC2K";

/// The Godot user folder of the project on this system.
pub fn godot_user_folder() -> PathBuf {
    let home = env::var_os("HOME").map(PathBuf::from).unwrap_or_default();

    if cfg!(target_os = "macos") {
        return home
            .join("Library/Application Support/Godot/app_userdata")
            .join(PROJECT_NAME);
    }

    if cfg!(target_os = "windows") {
        let roaming = env::var_os("APPDATA")
            .map(PathBuf::from)
            .unwrap_or_else(|| home.join("AppData/Roaming"));

        return roaming.join("Godot/app_userdata").join(PROJECT_NAME);
    }

    let data = env::var_os("XDG_DATA_HOME")
        .map(PathBuf::from)
        .unwrap_or_else(|| home.join(".local/share"));

    data.join("godot/app_userdata").join(PROJECT_NAME)
}

/// The folder of user files: the portable folder beside the executable, or
/// the Godot user folder. The macOS app bundle is signed, thus it always uses
/// the user folder.
pub fn user_root() -> super::paths::Root {
    let executable_folder = env::current_exe()
        .ok()
        .and_then(|path| {
            path.parent()
                .map(|folder| folder.to_string_lossy().into_owned())
        })
        .unwrap_or_default();
    let allow_portable = !cfg!(target_os = "macos");

    super::paths::select(
        &executable_folder,
        allow_portable,
        &godot_user_folder().to_string_lossy(),
    )
}
