# SCURK project format

A SCURK project file stores the work of the SCURK editor. It keeps editor data
that the original MIF tile set format cannot store, for example layers, stamps,
and checkpoints. Project files use the `.scurk` extension.

The game cannot use a project file directly. To use the artwork in the game,
use File > Export Tile Set to write a flattened MIF file. File > Save and
File > Save As write only the project file. They do not write a MIF file.

## Container

A project file is a ZIP archive. Standard ZIP tools can list and extract its
members. The archive contains JSON metadata, MIF bytes, indexed PNG images, and
resource bytes:

```text
project.json
palette.json
original.mif
current/current.mif
current/documents/0000/original.png
current/documents/0000/layers/0000.png
current/documents/0000/layers/0001.png
current/documents/0000/layers/0001.mask.png
current/stamps/0000.png
current/resources/0000.bin
checkpoints/0000/current.mif
checkpoints/0000/documents/0000/original.png
checkpoints/0000/documents/0000/layers/0000.png
```

The member paths contain numbers, not names:

- Document folders use the order of the sorted document keys.
- Layer and stamp images use the order of their arrays.
- Resource members use the order of the sorted resource names. A resource
  member keeps the extension of its resource name when that extension has 10
  characters or fewer and is a valid identifier. Otherwise, the extension is
  `.bin`.
- Checkpoint folders use the order of the checkpoint array.

A logical name can contain slashes, Unicode characters, or `..`. The writer
never uses a logical name as a member path.

The reader rejects an archive in these conditions:

- A member is not referenced by the metadata.
- A referenced member is missing.
- The manifest envelope, the palette record, or a pixel descriptor contains an
  unsupported field.

## Manifest

`project.json` contains one JSON object with exactly these fields:

| Field | Value |
| --- | --- |
| `format` | `opensc2k-scurk` |
| `version` | `2` |
| `palette` | `palette.json` |
| `project` | The logical project record. Refer to [Project record](#project-record). |

The envelope keeps project fields separate from archive fields. A project field
with the name `format` or `palette` stays inside `project`.

## Palette

`palette.json` contains one JSON object with exactly these fields:

| Field | Value |
| --- | --- |
| `kind` | `rgb` or `index-encoding` |
| `colors` | Array of 256 ordered colors. Each color is an array of three integers from 0 through 255: red, green, and blue. |

`kind: "rgb"` identifies the actual colors of the project. The editor uses these
colors when it loads the project, also when the configured game palette is
different.

A project without actual colors uses `kind: "index-encoding"`. Its colors must
be a gray scale in which color `n` is `[n, n, n]`. Each index then shows as its
gray value. The editor then uses the configured game palette. The next save
writes those colors with `kind: "rgb"` if they are available.

The project palette applies to the Paint editor and to its image exports. A MIF
file contains palette indices, not colors. The game and Place & Print use the
configured game palette. A project with different colors can look different in
those views.

`metadata.palette` in the project record contains editor preferences, for
example favorite and recent colors. It is not the project palette.

## Indexed images

Each image member is a PNG file with these properties:

- 8-bit indexed color.
- A palette of exactly 256 entries, in the same order as `palette.json`. The
  mask images use the gray-scale palette.
- The width and height of its document or stamp.

The reader checks the dimensions before it decodes the image.

In the project data, pixel value `-1` is transparent. Values `0` through `255`
are palette indices. Other values are not valid. Duplicate colors keep their
separate indices.

A pixel field in the metadata is an object with these fields:

| Field | Value |
| --- | --- |
| `image` | Member path of the indexed PNG image |
| `transparency_mask` | Optional. Member path of the mask image. |

Usually, the writer stores transparent pixels with a transparent palette entry.
It uses the lowest palette index that no pixel of the image uses.

If an image uses all 256 indices and also has transparent pixels, no palette
index is free. The writer then writes a mask image next to the image, with the
name `<image name>.mask.png`. In the mask, value `0` is transparent and value
`255` is opaque. Other mask values are not valid. The image stores index `0`
at each transparent pixel. The reader ignores the image value at a transparent
mask pixel and restores `-1`. When a pixel field has a mask, its image must not
have transparent pixels.

You can change an image member with an external editor. Keep indexed color, the
ordered palette, the dimensions, the member paths, and the mask values. The
reader rejects an image that uses RGB color or a different palette order. A
project file does not replace the Export Tile Set command.

## Project record

The `project` object contains these fields:

| Field | Content |
| --- | --- |
| `revision` | Change counter. An integer from 0 through 9007199254740991. |
| `original_mif` | Member path of the MIF bytes at the start of the project |
| `current_mif` | Member path of the current flattened MIF bytes |
| `metadata` | JSON object for the author, the license, editor preferences, and other data |
| `resources` | Object that maps resource names to member paths |
| `documents` | Object that maps document keys to documents |
| `stamps` | Array of stamps |
| `checkpoints` | Array of checkpoints, from oldest to newest |

The reader loads only JSON values, MIF bytes, PNG images, and resource bytes.
It does not load scripts, Godot resources, objects, or file system paths.

The reader parses each MIF member before it uses it. A MIF member cannot be
empty.

### Documents

A document key is a text of 1 through 128 characters. The editor uses the key
`<large sprite ID>:<view>`, for example `1001:0`.

A document contains these fields:

| Field | Content |
| --- | --- |
| `width` | Width in pixels, from 1 through 128 |
| `height` | Height in pixels, from 1 through 256 |
| `active` | Index of the active layer. It must identify a layer in `layers`. |
| `original_pixels` | Pixel field with the pixels at the start of the document |
| `layers` | Array of 1 through 32 layers, from bottom to top |

A layer contains these fields:

| Field | Content |
| --- | --- |
| `name` | Text of 1 through 256 characters. It must not contain only spaces. |
| `visible` | Boolean |
| `locked` | Boolean |
| `pixels` | Pixel field |

To make the flattened image, the editor puts the visible layers on top of each
other, from bottom to top. An opaque pixel in a higher layer replaces the lower
pixel. A transparent pixel keeps the lower pixel. Hidden layers do not change
the result. The editor does not paint on a locked layer or delete it.

The editor uses 128 by 256 workspace documents. Smaller documents and stamps
are also valid.

### Stamps

A stamp contains these fields:

| Field | Content |
| --- | --- |
| `name` | Text of 1 through 256 characters. It must not contain only spaces. |
| `width` | Width in pixels, from 1 through 128 |
| `height` | Height in pixels, from 1 through 256 |
| `spacing` | Integer from 1 through 256 |
| `pixels` | Pixel field |

### Resources

A resource name is a text of 1 through 256 characters. The name is an
identifier, not a file path. Each resource contains up to 16 MiB of bytes.

### Checkpoints

A checkpoint contains these fields:

| Field | Content |
| --- | --- |
| `name` | Text of 1 through 256 characters. It must not contain only spaces. |
| `created` | UTC date and time text |
| `revision` | The project revision when the editor made the checkpoint |
| `snapshot` | Object with `current_mif`, `documents`, `metadata`, `resources`, and `stamps` |

A snapshot does not contain the checkpoint list or an original MIF. A project
can have up to 24 checkpoints. When the editor adds a checkpoint to a full list,
it removes the oldest checkpoint. To restore a checkpoint, the editor replaces
the current state with the snapshot. The original MIF does not change, and the
revision increases.

### Unknown fields

A load-save cycle keeps these values:

- Unknown fields of the project record.
- Unknown fields of documents, layers, stamps, and checkpoints.
- The metadata and the resource bytes.
- The bytes of all MIF members.

A load-save cycle does not keep unknown fields of a checkpoint snapshot object.

Unknown values must be JSON values. JSON does not make a difference between
integer and floating-point numbers, so a load-save cycle keeps the numeric
value but not its storage type.

## Limits

| Item | Limit |
| --- | --- |
| Project file size | 128 MiB |
| Total size of the uncompressed ZIP members | 128 MiB |
| Project data size | 64 MiB |
| Each MIF or resource | 16 MiB |
| Documents | 1,500 |
| Layers in each document | 32 |
| Stamps | 256 |
| Resources | 1,024 |
| Checkpoints | 24 |
| JSON nesting | 32 levels |

The project data size is the sum of these values, for the current state and for
all checkpoints:

- The bytes of the original MIF and of each current MIF.
- The resource bytes.
- Two bytes for each pixel of each image.

PNG compression does not change the project data size. The reader checks the
declared sizes before it decompresses ZIP data or decodes images.

PNG palettes and ZIP headers add bytes to the file. A project with many small
images can exceed the file size limit, although its project data size is
permitted.

## ZIP rules

- Member paths use UTF-8 and forward slashes. A path cannot contain a
  backslash, a colon, a zero byte, an empty component, `.`, or `..`.
- A member uses stored data or DEFLATE compression. The writer uses DEFLATE
  only when it makes a member smaller.
- The reader accepts ZIP64 records and data descriptors in the same limits.
- The reader does not accept encryption or archives on more than one disk.
- The writer sorts the members by path and writes the fixed date 1980-01-01.
  The same project data gives the same file bytes.
- The reader never extracts members to the file system.

## Save

Before the editor writes a project, it checks the project data. Then it encodes
the file and decodes the result again to check it. If a check fails, the save
fails. The editor never removes layers or checkpoints to make a project fit.

The editor writes the bytes to a new temporary file in the destination folder.
It flushes the file and reads it again to compare the bytes. Then it renames
the temporary file to the destination name. If a step fails, the editor
removes the temporary file and the destination file does not change. A save
never removes the source MIF file or imported files.

## Autosave and recovery

While the editor is open and the project has unsaved changes, the editor writes
an autosave file every 30 seconds. The autosave file is `user://scurk/recovery.scurk`. It uses the same
format and the same safe write method as a normal save.

If the recovery file is present when the editor opens, the Recover SCURK
project dialog appears:

- Recover loads the recovery file.
- Ignore renames the recovery file to `recovery-ignored-<time>.scurk` in the
  same folder.
- Keep for later closes the dialog and does not change the file.

File > Recover Autosave opens the folder of the recovery files. If the open
project has unsaved changes, the editor asks before it replaces the project.

When the editor writes an autosave file and a recovery file from another
session is present, the editor first copies the old file to
`recovery-<time>.scurk`. After a successful save, the editor deletes its own
recovery file and the recovery file that it loaded.
