# HD sprite pack format

An HD sprite pack replaces the look of the city sprites with full-color art.
It does not replace the graphics pack. The game still needs the imported
graphics pack: its indexed sprites give the draw geometry, picking, masks,
traffic, SCURK, and the saved files. The HD art changes only what the city view
shows.

The [HD Graphics Pack](https://github.com/OpenSC2K/HD-Graphics-Pack) repository
builds an HD sprite pack.

## Select a pack

- **Settings > Data > HD sprite pack**: select the `pack.json` file of the pack.
  Keep the field empty to show the sprites of the graphics pack.
- `OPENSC2K_HD_PACK`: the path of a `pack.json` file or its folder, for one run.
  It overrides the Settings value.

These show the HD art:

- The city view and the underground view, with the GPU and the CPU renderers,
  with their moving objects, network placement previews, and query previews.
  The CPU renderer paints HD regions at 2 pixels for each view pixel. The dark
  underground view dims the art.
- The title screen city, the tool icons, the bridge choices, and the New City
  terrain preview.
- **File > Export City as PNG**, with its **Detail** option: the HD art at 1, 2
  or 4 image pixels for each view pixel.

## Effects

**Settings > Graphics** has optional effects for HD art. They are off by
default:

| Option | Effect |
| --- | --- |
| HD tile grid | Thin grid lines along the tile edges of HD ground. Shore tiles show them only on land. |
| HD waterfall flow | Falling water and foam on the faces of waterfalls, under a quiet top. With the GPU renderer only. |
| HD underground water flow | Flowing water over the watered pipes of the underground view. |
| HD palette animation | The palette animation of the original sprites over the HD art: blinking lights, and a shimmer on water. |

The SCURK editors show the original sprites. Palette animation, such as
blinking lights, shows only on original sprites; HD art animates with its
strips. The HD Graphics Pack animates its water with strips.

A SCURK tile set sprite replaces the HD art of its sprite ID.

## pack.json

```json
{
  "format": "opensc2k-hd-sprites",
  "version": 1,
  "name": "OpenSC2K HD Graphics",
  "redraw_small_highway_ground": true,
  "sprites": [
    {"id": 1001, "png": "sprites/1001.png", "logical_size": [32, 17]},
    {"id": 14, "png": "sprites/14.png", "logical_size": [8, 5], "display_height": 7},
    {
      "id": 1207,
      "png": "sprites/1207.png",
      "logical_size": [128, 106],
      "animation": {"png": "sprites/1207.strip.png", "frames": 8, "fps": 8}
    }
  ]
}
```

| Field | Rule |
| --- | --- |
| `format` | Required. `opensc2k-hd-sprites`. |
| `version` | Required. `1`. |
| `name` | Required. The name that Settings shows. |
| `redraw_small_highway_ground` | Optional boolean. The default is `false`. Set `true` when the art of small highway pieces does not cover the ground below them. |
| `sprites` | Required. A nonempty array of sprite records. |

A sprite record has these fields:

| Field | Rule |
| --- | --- |
| `id` | Required. The city sprite ID, 0 through 65535. Small sprites are below 500, medium sprites are 500 through 999, and large sprites are from 1000. Each ID can occur only one time. |
| `png` | Required. The path of an RGBA PNG file. |
| `logical_size` | Required. The width and height of the indexed sprite in the graphics pack. A record applies only when the graphics pack sprite has this size, so a pack for one game version cannot misplace art on another. |
| `display_height` | Optional. The height of the art in logical pixels, when it is taller than the sprite. The art keeps the bottom edge of the sprite and extends up. The default is the logical height. |
| `animation` | Optional. Refer to [Animation](#animation). |

Paths are relative to the folder of `pack.json`, use `/`, and must not contain
empty, `.`, or `..` components.

## Images

- The art covers the logical width of the sprite and its display height. The
  game scales the PNG to that rectangle, so the PNG can have any density. Use the
  same aspect as the rectangle.
- Keep the transparent margins of the canvas. Do not trim the art: its position
  in the canvas places it on the tile.
- Transparency can be partial. The game filters the art with premultiplied
  alpha.
- Each side is at most 4096 pixels. All decoded images together use at most
  512 MiB.
- Small and medium sprites need less density than large sprites. The HD Graphics Pack
  build uses four pixels for each logical pixel of small and medium sprites.

## Animation

```json
"animation": {"png": "sprites/1207.strip.png", "frames": 8, "fps": 8}
```

An animation strip stacks 2 through 32 equal frames from top to bottom. Each
frame has the size of the still PNG. `fps` is 5 or 8 frames each second. The
animation runs with the palette animation of the city, so it stops while the
game is paused. The still PNG stays the still image of the sprite.

The strips of one view use at most 128 MiB.

## Traffic

The traffic sprites (small 400 through 449, medium 900 through 949, and large
1400 through 1449) show only on the road pixels of the road sprite below them,
as in the original game. Draw the cars of a traffic sprite on the roads of the
tile, and animate them with a strip.
