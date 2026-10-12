# Localization sources and coverage

Original wording from the supplied SimCity 2000 editions takes precedence.
Missing text and new OpenSC2K functions use supplementary translations with the
original terminology. Catalog comments identify the source or supplementary
origin. The `original` message context selects game text; it does not mean that
every supplementary entry was published by Maxis.

Only text catalogs and newspaper phrase-selection tables are included. Original
disc images, executables, graphics, audio, cities and binary data packs remain
outside Git. No language-specific asset pack is needed for language selection.
Normal gameplay still requires the supported original assets.

## Coverage

| Language | UI entries | Game-text entries | Supplied source |
| --- | ---: | ---: | --- |
| German (`de`) | 1,486 | 1,942 | German CD Collection (1994), supplied DOS installation |
| Spanish (`es`) | 1,486 | 2,236 | Spanish DOS `Disk1.img` and `Disk2.img` |
| Italian (`it`) | 1,486 | 1,747 | `dos_simcity_2000_ita/SC2000` installation |
| French (`fr`) | 1,486 | 2,165 | `SIMCITY2K_CD_COL_FR.mdf`, Windows 95 edition |
| Brazilian Portuguese (`pt_BR`) | 1,486 | 2,150 | Brazilian `Sc2ksepc.iso`, mixed Windows editions |
| Korean (`ko`) | 963, upstream catalog | Imported game text | Existing upstream translation, retained |

English remains the source language. Counts are catalog entries, not words or
complete sentences: newspaper entries include words, grammar fragments and
articles. No entry in the five added language catalogs is empty or fuzzy.
Coverage refers to this standalone OpenSC2K 0.3.0 branch and its localization
changes. Separate Visual Enhancements and Multiplayer features may add messages
outside this branch. The German catalog retains previously contributed Visual
Enhancements labels. No original Korean edition was supplied for this work.

## Original resources and supplements

**German:** The supplied `SimCity2` installation provides executable terminology,
165 text resources, 1,735 newspaper phrases and 38 scenario text chunks.
Four missing library texts were translated separately. The English scenario
reference set matches 36 chunks; the two Tokyo texts are retained without
guessing a match to another scenario. Custom scenario descriptions stay intact.

**Spanish:** The FAT12 disk images contain a compressed installer archive.
`SC2000.DAT` and `SC2000.EXE` provide 165 text resources, 2,029 newspaper
phrases and original UI wording. The five supplied scenarios contain English.
There are 42 supplementary scenario/library entries, including two Tokyo texts
translated from German. DOS newspaper compression tokens are decoded into
named text markers.

**Italian:** The installed `SC2000.EXE`, `SC2000.DAT` and scenarios provide
165 text resources, 1,540 newspaper phrases and ten text chunks from five
translated scenarios. Another 32 scenario/library entries are supplementary.
The alternative executable in `SCITALY.DAT` was unpacked for local comparison;
the installed executable remains the primary source. Text resources use CP850,
while newspaper literals and scenarios use MacRoman. The executable's distinct
newspaper compression-token mapping is decoded before display compilation.

**French:** The raw MDF image provides `WIN95/SC2K/TEXT_FRE`, `DATA_FRE`,
`SIMCITY.EXE` and scenarios: 169 text resources, 1,958 newspaper phrases and
36 scenario text chunks. Two Tokyo entries are translated from German.
Main-game string tables, menus and dialogs supply interface wording. Windows
SCURK on this CD is English, so its missing French labels are supplementary.
Original newspaper quirks, including unusually short headlines, are retained.

**Brazilian Portuguese:** The supplied CD has 904 files, size 181,313,536 bytes,
and SHA-256
`8bf6b149140b63a4a4b449600717183b72e61c73f75b2939f0ad95e5de688172`.
The [archive item sc-2ksepc](https://archive.org/details/sc-2ksepc) uses “Edição
Limitada” in its title and “Edição Especial” in its description. These labels
are not an independently authenticated release history.

- `WIN95/SC2K/SIMCITY.EXE` provides 1,045 nonempty string-table entries, plus
  menus and dialogs. Windows SCURK resources also supply original UI wording.
- `WIN31/SC2USA.DLL` provides 1,045 string-table entries for comparison.
- `WIN31/DATA/TEXT_USA.DAT` and IDX provide 169 Portuguese help, adviser and
  library resources in Windows-1252. The Windows 95 equivalent is English.
- `WIN31/SCENARIO` provides 34 text chunks from 17 Portuguese scenarios.
  Las Vegas and Tokyo require four supplementary chunks.
- All three newspaper DAT files, including `DATA_BR.DAT`, match the English
  reference byte for byte. They are not a Portuguese original newspaper.

The Portuguese newspaper is therefore supplementary: 1,697 translated prose
entries, 136 retained personal names and 110 grammar-only indirections. All
1,943 entries are accounted for. Compression fragments are expanded first and
substitution markers are preserved. The 203 original resources/scenario chunks,
four supplements and newspaper entries total 2,150 game-text entries.

Original spelling is generally retained. Existing translated alternatives take
precedence over inconsistent source menus. A reversed Undo label (`Refazer`)
is not copied into the Undo action; the partially English `Reverter o Name`
receives a complete translation.

## Extraction boundary and validation

Relevant in-game resources, newspaper grammar, scenarios, executable string
tables and menu/dialog labels were inspected. Full original WinHelp topic
bodies, PDF manuals, installer instructions and unrelated legacy-program text
are not reproduced. This is not a transcription of every document on the discs.
Inventories and extraction scripts remain local, outside the repository.

Newspaper localization changes displayed prose only. Imported grammar still
determines saved arguments, auxiliary choices and random state. Tests cover all
80 newspaper table types with three seeds per language, operation without
language assets, placeholders, Unicode glyphs, scenario matching, library
fallbacks and byte-identical city data. Toolbar checks cover all language
choices, both themes, available UI scales and power/water/reward palettes.
Multiline tooltips and translated save prompts also have regression coverage.

Technical checks do not replace native-speaker editorial review of every random
phrase combination. Supplementary wording is identified for direct review.
AI-assisted using Codex for extraction, supplementary translation,
implementation and validation.
