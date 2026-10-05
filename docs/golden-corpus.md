# Golden corpus

The golden corpus records hashes of the results of the game for fixed inputs. The
migration of GDScript rules to the native crates must keep each value. The corpus
holds only hashes, never content of the original game.

| File | Test | Inputs |
| --- | --- | --- |
| `game/tests/fixtures/corpus/golden.json` | `golden_corpus_test` | The committed generated cities, `DEFAULT.SC2`, and the supplied cities and scenarios |
| `game/tests/fixtures/corpus/golden-import.json` | `golden_corpus_import_test` | An import of the supplied game: the original packs and the media packs |

## Contents

`golden.json` has these sections:

- `files`: for each input, the hash of the file, of its decoded chunks, of a
  save, and of its SC2X version 4 conversion.
- `days`: fixed-seed days (seeds 123, 456 and 789) on the generated cities and
  on four supplied cities. Each entry has the chunks and the save after the
  days, the three random states, and the phase schedule of each day.
- `new_cities`: the terrain preview and the founded city of five New City
  settings.
- `images`: the City Map image of each mode, and CPU images of the city and
  underground views at each graphics size.

`golden-import.json` has the hash of each file of each pack. A PNG file counts
by its decoded pixels.

## Hashes

Each value is SHA-256 over a byte stream that any language can make again. See
`game/tests/support/golden_corpus.gd`:

- **Files** count by their bytes. An SC2X file counts by its members in archive
  order (name, line feed, decimal length, line feed, bytes), because two ZIP
  compressors can make different bytes from the same members.
- **Chunks** count by the four-letter id, the decimal length of the decoded
  payload, a line feed, and the payload, in document order.
- **Images** count by the width and height as decimal text, a line feed, and
  the RGBA8 pixels.

Keys that start with `gdscript_` hash GDScript text, such as the JSON of result
objects. The test reports a changed `gdscript_` value as a note, not as a failure.

## Update

A test never replaces a corpus file. To record a new corpus, for example after an
intentional change of a rule, delete the file and run the test with
`OPENSC2K_UPDATE_FIXTURES=1`. Explain the change in the commit message.
