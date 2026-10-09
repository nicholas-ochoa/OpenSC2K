//! The music SoundFont choices for GDScript.

use godot::prelude::*;
use sc2k_audio::soundfont;

fn strings(values: &[String]) -> PackedStringArray {
    values.iter().map(GString::from).collect()
}

/// The music SoundFont choices. See `soundfont.rs`.
#[derive(GodotClass)]
#[class(no_init, base = Object)]
pub struct NativeSoundFonts {}

#[godot_api]
impl NativeSoundFonts {
    #[func]
    fn sound_set_paths(os_name: GString, executable_folder: GString, windows_folder: GString) -> PackedStringArray {
        strings(&soundfont::sound_set_paths(
            &os_name.to_string(),
            &executable_folder.to_string(),
            &windows_folder.to_string(),
        ))
    }

    #[func]
    fn first_existing(paths: PackedStringArray) -> GString {
        let paths: Vec<String> = paths.as_slice().iter().map(GString::to_string).collect();

        GString::from(&soundfont::first_existing(&paths))
    }

    #[func]
    fn is_bundled(path: GString) -> bool {
        soundfont::is_bundled(&path.to_string())
    }

    #[func]
    fn label(choice: GString, os_name: GString, system_path: GString) -> GString {
        GString::from(&soundfont::label(
            &choice.to_string(),
            &os_name.to_string(),
            &system_path.to_string(),
        ))
    }

    #[func]
    fn normalize(choice: GString) -> GString {
        soundfont::normalize(&choice.to_string()).into()
    }

    #[func]
    fn candidates(choice: GString, custom_path: GString, system_path: GString) -> PackedStringArray {
        strings(&soundfont::candidates(
            &choice.to_string(),
            &custom_path.to_string(),
            &system_path.to_string(),
        ))
    }
}
