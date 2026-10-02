class_name SoundFontCatalog
extends RefCounted
## The music SoundFont choices: the General MIDI sound set of the operating
## system, or a SoundFont file that the player selects. OpenSC2K ships no
## SoundFont. FluidSynth reads each file in place; see docs/fluidsynth.md.

## The preference values.
const SYSTEM := "system"
const CUSTOM := "custom"
const DEFAULT := SYSTEM

const EXTENSIONS := ["sf2", "sf3", "dls"]

## macOS and Windows include a Roland GS set licensed for their own MIDI
## synthesizers; Linux distributions can install a SoundFont package.
const MACOS_SOUND_SET := "/System/Library/Components/CoreAudio.component/Contents/Resources/gs_instruments.dls"
const WINDOWS_SOUND_SET := "System32/drivers/gm.dls"
const LINUX_SOUND_SETS := [
	"/usr/share/sounds/sf2/default-GM.sf2", "/usr/share/sounds/sf3/default-GM.sf3",
	"/usr/share/soundfonts/default.sf2", "/usr/share/sounds/sf2/FluidR3_GM.sf2",
	"/usr/share/soundfonts/FluidR3_GM.sf2",
]


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
	if choice == CUSTOM:
		return "Custom SoundFont"

	match OS.get_name():
		"macOS":
			return "macOS GS Sound Set"
		"Windows":
			return "Microsoft GS Wavetable Sound Set"

	var path := system_path()

	return "System SoundFont (%s)" % path.get_file() if not path.is_empty() else "System SoundFont (not installed)"


## Every choice, in menu order.
static func choices() -> PackedStringArray:
	return PackedStringArray([SYSTEM, CUSTOM])


## A stored preference, or the default when the stored value is unknown, such
## as a choice that earlier versions offered.
static func normalize(choice: String) -> String:
	return choice if choice in choices() else DEFAULT


## The SoundFont paths to try, in order. A custom SoundFont that fails falls
## back to the system sound set. An empty list means that no SoundFont exists.
static func candidates(choice: String, custom_path: String) -> PackedStringArray:
	var result := PackedStringArray()

	if normalize(choice) == CUSTOM and not custom_path.strip_edges().is_empty():
		result.append(custom_path.strip_edges())

	var system := system_path()

	if not system.is_empty() and system not in result:
		result.append(system)

	return result
