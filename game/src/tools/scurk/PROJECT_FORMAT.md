# SCURK project format

SCURK projects use the `.scurk` extension. They retain editor data that the
original game's MIF format cannot store. Export a flattened MIF to use the
artwork in the game. Project saves do not write to a MIF file.

## Version 2

Projects use a ZIP container with the `.scurk` extension. Standard ZIP tools can
list and extract its members. This is the only supported project format.

The archive separates editor metadata from artwork bytes:

```text
project.json
palette.json
original.mif
current/current.mif
current/documents/0000/original.png
current/documents/0000/layers/0000.png
current/stamps/0000.png
current/resources/0000.bin
checkpoints/0000/current.mif
checkpoints/0000/documents/0000/...
```

The reader rejects unreferenced archive members and unsupported fields in the
manifest envelope, palette record, or pixel descriptors. It does not silently
discard those records. Unknown fields in the logical project, documents, layers,
stamps, and checkpoints retain the preservation rules below.

Document, layer, stamp, resource, and checkpoint numbers identify archive members.
They do not replace the logical names in JSON. A logical name can contain slashes,
Unicode, or `..`. The writer never uses that name as an archive path.

### JSON metadata

`project.json` has an envelope with `format`, `version`, `palette`, and `project`.
The format identifier is `opensc2k-scurk`. The version is `2`. The palette field
names `palette.json`. The project object contains the logical project record:
revision, original/current MIF references, metadata, resources, documents, stamps,
and checkpoints. Unknown logical project fields remain inside this object. This
keeps project fields named `format` or `palette` separate from the archive envelope.

Layer order, active layer, names, visibility, lock flags, dimensions, stamp
spacing, checkpoint names/times, and other metadata remain JSON values. Binary
resource fields name separate archive members. MIF references point to exact
binary MIF bytes. They preserve original data that a flattened PNG cannot retain.

A pixel field is an object with an `image` member path and an optional
`transparency_mask` member path. Current documents retain both their original
pixels and their separate layers. Checkpoints contain separate snapshot members.
An external editor can change one layer PNG without changing a checkpoint image.

### Palette and indexed pixels

`palette.json` contains a `kind` and 256 ordered RGB triples in `colors`.
`kind: "rgb"` identifies the actual project palette. The editor uses these colors
when it loads the project, even if the configured asset palette differs.
`metadata.palette` still contains navigation preferences, such as favorites and
recent colors. It is not the RGB palette.

Standalone projects can lack actual palette colors. Such files
use `kind: "index-encoding"` and a grayscale palette that displays each index as
its gray value. This is an explicit fallback, not an estimate of the artwork's
colors. The editor uses its configured asset palette when no actual RGB palette
is embedded. A later save embeds those configured colors if they are available.

Embedded colors apply to the Paint editor and its image exports. MIF files carry
indices, not this project palette. The game and Place & Print use the configured
game palette. A project with different embedded RGB colors can look different
when exported to MIF or used in those views.

Artwork PNGs use eight-bit indexed color and all 256 ordered palette entries.
Duplicate RGB colors keep their separate indices. Ordinary transparent images
use a PNG transparency entry at an unused index.

A layer can contain all 256 opaque indices and transparent pixels. One indexed
PNG cannot represent those 257 states. In that case, the image PNG stores the
opaque indices and a second indexed PNG stores a grayscale mask. Mask value `0`
means transparent. Mask value `255` means opaque. Both images have the same
size. The image value at a transparent mask pixel has no meaning. The reader
restores that pixel to `-1`.

When editing members externally, retain indexed mode, ordered palette entries,
image dimensions, referenced paths, and mask values. Converting an image to RGB
or reordering its palette can change its meaning and is rejected. PNG artwork
and MIF state must remain consistent for normal editor operations. A project
archive is not a replacement for the editor's MIF export command.

## Project records

The logical `project` object contains the following fields. The reader does not
load scripts, Godot resources, objects, or filesystem paths from these records.

| Field | Content |
| --- | --- |
| `revision` | Nonnegative change counter. |
| `original_mif` | Archive path to the unchanged starting MIF bytes. |
| `current_mif` | Archive path to the current flattened MIF bytes. |
| `metadata` | JSON object for author, license, editor preferences, and other metadata. |
| `resources` | Map from resource names to archive member paths. Names are identifiers, not file paths. |
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

Pixel fields contain the PNG descriptors described above. In memory, `-1` means
transparent. Values `0` through `255` select an SC2K palette index. All other
values are invalid. Each image must contain exactly `width * height` pixels.
The editor uses 128 by 256 workspaces; smaller documents and stamps are also
supported.

A stamp contains `name`, `width`, `height`, `pixels`, and integer `spacing` from
1 through 256. A checkpoint contains `name`, UTC `created` text, `revision`, and
`snapshot`. A snapshot contains the current MIF, documents, metadata, resources,
and stamps. It does not contain the checkpoint list or another original MIF.
Restoring a checkpoint keeps the original MIF and advances the change counter.

Unknown logical project fields and unknown document, layer, stamp, and checkpoint
fields survive a load-save cycle. Metadata and named resource bytes also
survive. JSON numeric values retain their value; integer and floating-point
storage types are not distinct metadata types. The two MIF fields preserve
their bytes exactly. The MIF parser validates both fields before use.

## Model limits and storage

The reader accepts files up to 128 MiB and up to 64 MiB of decoded binary data,
including checkpoint data. Each MIF or resource can contain up to 16 MiB.
Documents and stamps must be between 1 and 128 pixels wide and between 1 and
256 pixels high. A project can have up to 1,500 documents, 32 layers per
document, 256 stamps, 1,024 resources, and 24 checkpoints. JSON nesting is
limited to 32 levels. The total size limit can be reached before these counts.

The sum of uncompressed ZIP member bytes is limited to 128 MiB.
The separate 64 MiB model limit counts each pixel as two bytes.
PNG compression does not bypass that model limit. The reader checks image
dimensions and archive size declarations before decoding image or ZIP data.

ZIP members use stored or DEFLATE compression. ZIP64 entry counts are supported
within the same size limits. Encryption and multi-disk archives are not supported.
Output ordering and timestamps are fixed, so unchanged project data produces the
same bytes. The reader does not extract member paths to the filesystem.

PNG palettes and archive headers add storage overhead. A project with many small
images can exceed the archive limit even when its decoded pixel data fits.
A failed save leaves the destination unchanged. The writer does not drop layers
or checkpoints to fit.

Writes use a new temporary file in the destination folder. The writer flushes
and verifies that file before renaming it over the destination. A failed
serialization or write leaves the destination unchanged. A partial temporary
file is never treated as a recovery project.

Autosave uses the same format and atomic write method. The editor supplies a
separate recovery path. Loading recovery data is read-only; the editor must
ask the user before replacing the open document. Saving a project does not
delete its source MIF or imported resources.
