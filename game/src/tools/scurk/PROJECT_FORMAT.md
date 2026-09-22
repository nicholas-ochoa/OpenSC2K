# SCURK project format

SCURK projects use the `.scurk` extension. They retain editor data that the
original game's MIF format cannot store. Export a flattened MIF to use the
artwork in the game. Project saves do not write to a MIF file.

## Version 1

A file starts with the UTF-8 bytes `SCURK-PROJECT\n`. A UTF-8 JSON object follows
the header. This is a data format. The reader does not load scripts, Godot
resources, objects, or paths from the record.

| Field | Content |
| --- | --- |
| `version` | Integer `1`. Other versions are rejected. |
| `revision` | Nonnegative change counter. |
| `original_mif` | Base64 of the unchanged starting MIF bytes. |
| `current_mif` | Base64 of the current flattened MIF bytes. |
| `metadata` | JSON object for author, license, editor preferences, and other metadata. |
| `resources` | Map from resource names to base64 byte strings. Names are identifiers, not file paths. |
| `documents` | Map from tile/view keys to layer documents. The editor uses `tile:view` keys. |
| `stamps` | Array of indexed stamp records. |
| `checkpoints` | Array of named project snapshots, oldest first. |

Each document contains `width`, `height`, `active`, `original_pixels`, and
`layers`. `active` is the zero-based active layer index. `original_pixels`
retains the pixels supplied when the document was created. Layers are ordered
from bottom to top. Each layer contains `name`, `visible`, `locked`, and
`pixels`. A visible pixel from a higher layer replaces a lower pixel. A
transparent pixel leaves the lower pixel unchanged. Hidden layers do not
contribute to the flattened result. Locked layers reject painting and deletion.

Pixel fields contain base64 bytes. Each pixel is a signed 16-bit little-endian
integer in row order. `-1` means transparent. Values `0` through `255` select an
SC2K palette index. All other values are invalid. A pixel field must contain
exactly `width * height * 2` bytes. The editor uses 128 by 256 workspaces;
smaller documents and stamps are also supported.

A stamp contains `name`, `width`, `height`, `pixels`, and integer `spacing` from
1 through 256. A checkpoint contains `name`, UTC `created` text, `revision`, and
`snapshot`. A snapshot contains the current MIF, documents, metadata, resources,
and stamps. It does not contain the checkpoint list or another original MIF.
Restoring a checkpoint keeps the original MIF and advances the change counter.

Unknown top-level fields and unknown document, layer, stamp, and checkpoint
fields survive a load-save cycle. Metadata and named resource bytes also
survive. JSON numeric values retain their value; integer and floating-point
storage types are not distinct metadata types. The two MIF fields preserve
their bytes exactly. The MIF parser validates both fields before use.

## Limits and storage

The reader accepts files up to 128 MiB and up to 64 MiB of decoded binary data,
including checkpoint data. Each MIF or resource can contain up to 16 MiB.
Documents and stamps must be between 1 and 128 pixels wide and between 1 and
256 pixels high. A project can have up to 1,500 documents, 32 layers per
document, 256 stamps, 1,024 resources, and 24 checkpoints. JSON nesting is
limited to 32 levels. The total size limit can be reached before these counts.

Writes use a new temporary file in the destination folder. The writer flushes
and verifies that file before renaming it over the destination. A failed
serialization or write leaves the destination unchanged. A partial temporary
file is never treated as a recovery project.

Autosave uses the same format and atomic write method. The editor supplies a
separate recovery path. Loading recovery data is read-only; the editor must
ask the user before replacing the open document. Saving a project does not
delete its source MIF or imported resources.
