class_name SoundFontCatalog
extends RefCounted
## The music SoundFont choices. The bundled SoundFonts are in a folder beside
## the game, not in the Godot pack, because FluidSynth reads operating system paths.
## tools/fetch_soundfonts.py downloads them; docs/fluidsynth.md has their licenses.

## The preference values. A bundled SoundFont uses its id.
const DEFAULT := "default"
const BUILTIN := "builtin"
const CUSTOM := "custom"

const DEFAULT_ID := "fluidr3mono"
const FOLDER_NAME := "soundfonts"

## id: [label, file name]. Keep in sync with tools/fetch_soundfonts.py.
const BUNDLED := {
	"fluidr3mono": ["FluidR3Mono GM", "FluidR3Mono_GM.sf3"],
	"musescore_general": ["MuseScore General", "MuseScore_General.sf3"],
}
const EXTENSIONS := ["sf2", "sf3", "dls"]


## The folder of the bundled SoundFonts. A source checkout keeps them in
## res://bin/soundfonts; an export copies them beside the executable, or into
## Contents/Resources on macOS.
static func folder() -> String:
	if not OS.has_feature("template"):
		return ProjectSettings.globalize_path("res://bin").path_join(FOLDER_NAME)

	var executable_folder := OS.get_executable_path().get_base_dir()

	if OS.get_name() == "macOS":
		return executable_folder.path_join("../Resources").path_join(FOLDER_NAME).simplify_path()

	return executable_folder.path_join(FOLDER_NAME)


static func bundled_path(id: String) -> String:
	if not BUNDLED.has(id):
		return ""

	return folder().path_join(str(BUNDLED[id][1]))


static func label(choice: String) -> String:
	match choice:
		DEFAULT:
			return "OpenSC2K Default (%s)" % str(BUNDLED[DEFAULT_ID][0])
		BUILTIN:
			return "Built-in synthesizer"
		CUSTOM:
			return "Custom SoundFont"

	return str(BUNDLED[choice][0]) if BUNDLED.has(choice) else choice


## Every choice, in menu order.
static func choices() -> PackedStringArray:
	var result := PackedStringArray([DEFAULT])
	result.append_array(PackedStringArray(BUNDLED.keys()))
	result.append_array([CUSTOM, BUILTIN])

	return result


## A stored preference, or the default when the stored value is unknown.
static func normalize(choice: String) -> String:
	return choice if choice in choices() else DEFAULT


## The SoundFont paths to try, in order. A choice that fails falls back to the
## bundled default. An empty list selects the built-in synthesizer.
static func candidates(choice: String, custom_path: String) -> PackedStringArray:
	var result := PackedStringArray()

	match normalize(choice):
		BUILTIN:
			return result
		CUSTOM:
			if not custom_path.strip_edges().is_empty():
				result.append(custom_path.strip_edges())
		DEFAULT:
			pass
		var id:
			result.append(bundled_path(id))

	var fallback := bundled_path(DEFAULT_ID)

	if fallback not in result:
		result.append(fallback)

	return result
