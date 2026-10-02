class_name NewspaperFonts
extends RefCounted
## The newspaper typefaces. The headline and masthead fonts are bundled. Story
## copy uses a serif system font, and the default theme font is the fallback.

const HEADLINE_PATH := "res://assets/fonts/anton/Anton-Regular.ttf"
# each paper keeps its own masthead. the first paper uses Chomsky
const MASTHEAD_PATHS: Array[String] = [
	"res://assets/fonts/chomsky/Chomsky.otf",
	"res://assets/fonts/grenzegotisch/GrenzeGotisch[wght].ttf",
	"res://assets/fonts/unifrakturmaguntia/UnifrakturMaguntia-Book.ttf",
]
const MASTHEAD_NAMES: Array[String] = ["Chomsky", "Grenze Gotisch", "UnifrakturMaguntia"]
const SERIF_NAMES: Array[String] = ["Georgia", "Times New Roman", "serif"]
const INTERFACE_NAMES: Array[String] = ["sans-serif"]
const REGULAR_WEIGHT := 400
const BOLD_WEIGHT := 700

static var _cache: Dictionary = {}


static func headline() -> Font:
	return _cached("headline", func() -> Font:
		return load(HEADLINE_PATH) as Font
	)


static func masthead(paper_index: int) -> Font:
	var index := posmod(paper_index, MASTHEAD_PATHS.size())

	return _cached("masthead%d" % index, func() -> Font:
		var variation := FontVariation.new()
		variation.base_font = load(MASTHEAD_PATHS[index]) as Font
		# the variable masthead otherwise starts at its thinnest weight
		variation.variation_opentype = { TextServerManager.get_primary_interface().name_to_tag("wght"): REGULAR_WEIGHT }

		return variation
	)


static func masthead_name(paper_index: int) -> String:
	return MASTHEAD_NAMES[posmod(paper_index, MASTHEAD_NAMES.size())]


static func body() -> Font:
	return _cached("body", func() -> Font:
		return _system_font(SERIF_NAMES, REGULAR_WEIGHT, false)
	)


static func body_bold() -> Font:
	return _cached("body_bold", func() -> Font:
		return _system_font(SERIF_NAMES, BOLD_WEIGHT, false)
	)


static func body_italic() -> Font:
	return _cached("body_italic", func() -> Font:
		return _system_font(SERIF_NAMES, REGULAR_WEIGHT, true)
	)


static func interface() -> Font:
	return _cached("interface", func() -> Font:
		return _system_font(INTERFACE_NAMES, REGULAR_WEIGHT, false)
	)


static func _system_font(names: Array[String], weight: int, italic: bool) -> SystemFont:
	var font := SystemFont.new()
	font.font_names = PackedStringArray(names)
	font.font_weight = weight
	font.font_italic = italic

	return font


static func _cached(key: String, create: Callable) -> Font:
	if not _cache.has(key):
		_cache[key] = create.call()

	return _cache[key] as Font
