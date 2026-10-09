//! The music SoundFont choices: the General MIDI sound set of the operating
//! system, or a SoundFont file that the player selects. Only the Linux package
//! includes a SoundFont, as the last system choice.

use std::path::Path;

/// The preference values.
pub const SYSTEM: &str = "system";
pub const CUSTOM: &str = "custom";
pub const DEFAULT: &str = SYSTEM;
pub const CHOICES: [&str; 2] = [SYSTEM, CUSTOM];

pub const EXTENSIONS: [&str; 3] = ["sf2", "sf3", "dls"];

/// macOS and Windows include a Roland GS set licensed for their own MIDI
/// synthesizers; Linux distributions can install a SoundFont package.
pub const MACOS_SOUND_SET: &str = "/System/Library/Components/CoreAudio.component/Contents/Resources/gs_instruments.dls";
pub const WINDOWS_SOUND_SET: &str = "System32/drivers/gm.dls";
pub const WINDOWS_FOLDER: &str = "C:/Windows";
pub const LINUX_SOUND_SETS: [&str; 5] = [
    "/usr/share/sounds/sf2/default-GM.sf2",
    "/usr/share/sounds/sf3/default-GM.sf3",
    "/usr/share/soundfonts/default.sf2",
    "/usr/share/sounds/sf2/FluidR3_GM.sf2",
    "/usr/share/soundfonts/FluidR3_GM.sf2",
];

/// The MIT SoundFont beside the executable of the Linux package. An installed
/// distribution SoundFont comes first.
pub const BUNDLED_SOUND_SET: &str = "FluidR3Mono_GM.sf3";

const UNIX_SYSTEMS: [&str; 5] = ["Linux", "FreeBSD", "NetBSD", "OpenBSD", "BSD"];

fn join(folder: &str, name: &str) -> String {
    if folder.is_empty() || folder.ends_with('/') {
        format!("{folder}{name}")
    } else {
        format!("{folder}/{name}")
    }
}

/// The sound sets to try on an operating system, in order. `windows_folder`
/// is the SystemRoot variable, which can be empty.
pub fn sound_set_paths(os_name: &str, executable_folder: &str, windows_folder: &str) -> Vec<String> {
    match os_name {
        "macOS" => vec![MACOS_SOUND_SET.to_string()],
        "Windows" => {
            let folder = if windows_folder.is_empty() {
                WINDOWS_FOLDER
            } else {
                windows_folder
            };

            vec![join(folder, WINDOWS_SOUND_SET)]
        }
        name if UNIX_SYSTEMS.contains(&name) => {
            let mut paths: Vec<String> = LINUX_SOUND_SETS.iter().map(|path| path.to_string()).collect();
            paths.push(join(executable_folder, BUNDLED_SOUND_SET));
            paths
        }
        _ => Vec::new(),
    }
}

/// The first sound set that exists, or an empty string.
pub fn first_existing(paths: &[String]) -> String {
    paths.iter().find(|path| Path::new(path).is_file()).cloned().unwrap_or_default()
}

pub fn is_bundled(path: &str) -> bool {
    path.rsplit(['/', '\\']).next() == Some(BUNDLED_SOUND_SET)
}

/// The menu text of a choice. `system_path` is the sound set that exists.
pub fn label(choice: &str, os_name: &str, system_path: &str) -> String {
    if choice == CUSTOM {
        return "Custom SoundFont".into();
    }

    match os_name {
        "macOS" => return "macOS GS Sound Set".into(),
        "Windows" => return "Microsoft GS Wavetable Sound Set".into(),
        _ => {}
    }

    if is_bundled(system_path) {
        "Bundled SoundFont (FluidR3 Mono)".into()
    } else if system_path.is_empty() {
        "System SoundFont (not installed)".into()
    } else {
        format!(
            "System SoundFont ({})",
            system_path.rsplit(['/', '\\']).next().unwrap_or(system_path)
        )
    }
}

/// A stored preference, or the default when the stored value is unknown, such
/// as a choice that earlier versions offered.
pub fn normalize(choice: &str) -> &'static str {
    CHOICES.into_iter().find(|known| *known == choice).unwrap_or(DEFAULT)
}

/// The SoundFont paths to try, in order. A custom SoundFont that fails falls
/// back to the system sound set. An empty list means that no SoundFont exists.
pub fn candidates(choice: &str, custom_path: &str, system_path: &str) -> Vec<String> {
    let mut result = Vec::new();
    let custom = custom_path.trim();

    if normalize(choice) == CUSTOM && !custom.is_empty() {
        result.push(custom.to_string());
    }

    if !system_path.is_empty() && !result.iter().any(|path| path == system_path) {
        result.push(system_path.to_string());
    }

    result
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn the_package_soundfont_comes_last_on_linux() {
        let linux = sound_set_paths("Linux", "/opt/opensc2k", "");
        assert_eq!(linux.len(), 6);
        assert_eq!(linux[5], "/opt/opensc2k/FluidR3Mono_GM.sf3");
        assert!(is_bundled(&linux[5]) && !is_bundled(&linux[0]));
        assert_eq!(sound_set_paths("Windows", "", ""), ["C:/Windows/System32/drivers/gm.dls"]);
        assert_eq!(sound_set_paths("Windows", "", "D:/WIN"), ["D:/WIN/System32/drivers/gm.dls"]);
        assert!(sound_set_paths("Web", "", "").is_empty());
    }

    #[test]
    fn a_custom_soundfont_falls_back_to_the_system_set() {
        assert_eq!(candidates(CUSTOM, " /music/a.sf2 ", "/sys.dls"), ["/music/a.sf2", "/sys.dls"]);
        assert_eq!(candidates(SYSTEM, "/music/a.sf2", "/sys.dls"), ["/sys.dls"]);
        assert_eq!(candidates(CUSTOM, "/sys.dls", "/sys.dls"), ["/sys.dls"]);
        assert!(candidates(CUSTOM, "", "").is_empty());
        assert_eq!(normalize("fluidr3mono"), SYSTEM);
        assert_eq!(label(SYSTEM, "Linux", "/x/FluidR3Mono_GM.sf3"), "Bundled SoundFont (FluidR3 Mono)");
        assert_eq!(
            label(SYSTEM, "Linux", "/usr/share/soundfonts/default.sf2"),
            "System SoundFont (default.sf2)"
        );
    }
}
