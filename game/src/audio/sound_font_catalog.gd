class_name SoundFontCatalog
extends RefCounted
## The music SoundFont choices: the General MIDI sound set of the operating
## system, or a SoundFont file that the player selects. Only the Linux package
## includes a SoundFont, as the last system choice. FluidSynth reads each file
## in place; see docs/fluidsynth.md.

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

## The MIT SoundFont beside the executable of the Linux package. An installed
## distribution SoundFont comes first.
const BUNDLED_SOUND_SET := "FluidR3Mono_GM.sf3"


## The sound set of this operating system, or an empty string when it has none.
static func system_path() -> String:
	return NativeSoundFonts.first_existing(sound_set_paths(OS.get_name(), OS.get_executable_path().get_base_dir()))


## The sound sets to try on an operating system, in order.
static func sound_set_paths(os_name: String, executable_folder: String) -> PackedStringArray:
	return NativeSoundFonts.sound_set_paths(os_name, executable_folder, OS.get_environment("SystemRoot"))


static func is_bundled(path: String) -> bool:
	return NativeSoundFonts.is_bundled(path)


static func label(choice: String) -> String:
	return NativeSoundFonts.label(choice, OS.get_name(), "" if choice == CUSTOM else system_path())


## Every choice, in menu order.
static func choices() -> PackedStringArray:
	return PackedStringArray([SYSTEM, CUSTOM])


## A stored preference, or the default when the stored value is unknown, such
## as a choice that earlier versions offered.
static func normalize(choice: String) -> String:
	return NativeSoundFonts.normalize(choice)


## The SoundFont paths to try, in order. A custom SoundFont that fails falls
## back to the system sound set. An empty list means that no SoundFont exists.
static func candidates(choice: String, custom_path: String) -> PackedStringArray:
	return NativeSoundFonts.candidates(choice, custom_path, system_path())
