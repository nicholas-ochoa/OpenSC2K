class_name SoundFontCatalog
extends RefCounted
## The music SoundFont choices. The bundled SoundFonts are in a folder beside
## the game, not in the Godot pack, because FluidSynth reads operating system paths.
## tools/fetch_soundfonts.py downloads them; docs/fluidsynth.md has their licenses.

## The preference values. A bundled SoundFont uses its id.
const DEFAULT := "default"
const BUILTIN := "builtin"
const CUSTOM := "custom"
const SYSTEM := "system"

const DEFAULT_ID := "fluidr3mono"
const FOLDER_NAME := "soundfonts"

## id: [label, file name]. Keep in sync with tools/fetch_soundfonts.py.
const BUNDLED := {
	"fluidr3mono": ["FluidR3Mono GM", "FluidR3Mono_GM.sf3"],
	"musescore_general": ["MuseScore General", "MuseScore_General.sf3"],
}
const EXTENSIONS := ["sf2", "sf3", "dls"]

## The General MIDI sound set of the operating system. OpenSC2K reads it in place
## and never copies it. macOS and Windows include a Roland GS set licensed for
## their own MIDI synthesizers; Linux distributions can install a SoundFont package.
const MACOS_SOUND_SET := "/System/Library/Components/CoreAudio.component/Contents/Resources/gs_instruments.dls"
const WINDOWS_SOUND_SET := "System32/drivers/gm.dls"
const LINUX_SOUND_SETS := [
	"/usr/share/sounds/sf2/default-GM.sf2", "/usr/share/sounds/sf3/default-GM.sf3",
	"/usr/share/soundfonts/default.sf2", "/usr/share/sounds/sf2/FluidR3_GM.sf2",
	"/usr/share/soundfonts/FluidR3_GM.sf2",
]


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


## The sound set of this operating system, or an empty string when it has none.
static func system_path() -> String:
	var paths := PackedStringArray()

	match OS.get_name():
		"macOS":
			paths.append(MACOS_SOUND_SET)
		"Windows":
			var windows_folder := OS.get_environment("SystemRoot")
			paths.append((windows_folder if not windows_folder.is_empty() else "C:/Windows").path_join(WINDOWS_SOUND_SET))
		"Linux", "FreeBSD", "NetBSD", "OpenBSD", "BSD":
			paths.append_array(LINUX_SOUND_SETS)

	for path in paths:
		if FileAccess.file_exists(path):
			return path

	return ""


static func label(choice: String) -> String:
	match choice:
		DEFAULT:
			return "OpenSC2K Default (%s)" % str(BUNDLED[DEFAULT_ID][0])
		BUILTIN:
			return "Built-in synthesizer"
		CUSTOM:
			return "Custom SoundFont"
		SYSTEM:
			match OS.get_name():
				"macOS":
					return "macOS GS Sound Set"
				"Windows":
					return "Microsoft GS Wavetable Sound Set"

			return "System SoundFont (%s)" % system_path().get_file()

	return str(BUNDLED[choice][0]) if BUNDLED.has(choice) else choice


## Every choice of this computer, in menu order. The system sound set is listed
## only where the operating system has one.
static func choices() -> PackedStringArray:
	var result := PackedStringArray([DEFAULT])
	result.append_array(PackedStringArray(BUNDLED.keys()))

	if not system_path().is_empty():
		result.append(SYSTEM)

	result.append_array([CUSTOM, BUILTIN])

	return result


## A stored preference, or the default when the stored value is unknown. The
## system choice stays, so settings copied to a computer without it keep it;
## there it plays the default SoundFont.
static func normalize(choice: String) -> String:
	if choice == SYSTEM or choice in choices():
		return choice

	return DEFAULT


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
		SYSTEM:
			if not system_path().is_empty():
				result.append(system_path())
		DEFAULT:
			pass
		var id:
			result.append(bundled_path(id))

	var fallback := bundled_path(DEFAULT_ID)

	if fallback not in result:
		result.append(fallback)

	return result
