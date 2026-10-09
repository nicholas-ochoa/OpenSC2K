class_name AppLocalization
extends RefCounted
## The interface language. Source text and message keys stay English; a
## translation changes only what the interface shows. Saved settings, cities,
## tool IDs, and report IDs do not change.
##
## Pretendard (SIL OFL 1.1, https://github.com/orioncactus/pretendard) supplies
## the Hangul glyphs. It is a fallback of the interface fonts, so Latin text
## keeps its usual font.

const DEFAULT := "en"
# language code -> name in that language. Each code other than English has a
# translation in res://assets/localization
const LANGUAGES: Dictionary[String, String] = { "en": "English", "de": "Deutsch", "ko": "한국어" }
const TRANSLATIONS: Dictionary[String, String] = {
	"de": "res://assets/localization/de.po",
	"ko": "res://assets/localization/ko.po",
}
const REGULAR_FONT = preload("res://assets/fonts/pretendard/Pretendard-Regular.otf")
const BOLD_FONT = preload("res://assets/fonts/pretendard/Pretendard-Bold.otf")

static var _loaded := false


static func normalize(value: Variant) -> String:
	return str(value) if LANGUAGES.has(str(value)) else DEFAULT


# The language codes in the order of the Settings list.
static func codes() -> Array[String]:
	return LANGUAGES.keys()


static func select(value: String) -> void:
	if not _loaded:
		for code: String in TRANSLATIONS:
			TranslationServer.add_translation(load(TRANSLATIONS[code]) as Translation)

		_loaded = true

	TranslationServer.set_locale(normalize(value))


# `font` with the Hangul fallback font. `bold` selects the bold fallback.
static func with_fallback(font: Font, bold := false) -> Font:
	if font == null:
		return null

	var fallback: Font = BOLD_FONT if bold else REGULAR_FONT

	if not fallback in font.fallbacks:
		font.fallbacks = font.fallbacks + [fallback]

	return font
